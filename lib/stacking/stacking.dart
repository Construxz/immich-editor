import 'dart:convert';

import '../photo.dart';
import '../gallery/checksums.dart' show deviceChecksums;
import '../gallery/device.dart' show devicePermitted, deviceTrash;
import '../main.dart' show storage;
import '../server/immich.dart';
import 'background.dart';

/// Stacks the [copy] in front of the [original] and adds it to the original's albums. The
/// previous primary joins the list: only then does Immich merge its stack with the new one,
/// otherwise earlier copies would stand alone (D-23, D-31). The replaced [oldCopy] goes to trash.
Future<void> stackOnOriginal(
  Immich immich,
  String copy,
  Photo original, {
  String? oldCopy,
}) async {
  final primary = original.stackPrimary;
  await immich.stack([
    copy,
    original.id,
    if (primary != null && primary != original.id) primary,
  ]);
  for (final album in await immich.albumsOf(original.id)) {
    await immich.addToAlbum(album, [copy]);
  }
  if (oldCopy != null) await immich.trash([oldCopy]);
}

/// A copy made on the device, stacked as soon as the Immich app has backed it up together with
/// the original (D-24). Checksums SHA-1, Base64. With [removeLocal] (ID on the device) the copy
/// then leaves the device — the original was on the server only (D-25).
typedef Pending = ({
  String copy,
  String original,
  String? old,
  String? removeLocal,
});

/// Enqueues [added]; a still-waiting copy that [added] replaces drops out — otherwise it might
/// end up in front afterwards.
List<Pending> enqueueIn(List<Pending> queue, Pending added) => [
  for (final p in queue)
    if (p.copy != added.old) p,
  added,
];

const _key = 'stapeln'; // persisted: do not rename

Future<List<Pending>> _read() async => [
  for (final p in jsonDecode(await storage.read(key: _key) ?? '[]'))
    // persisted: do not rename the JSON fields
    (
      copy: p['kopie'],
      original: p['original'],
      old: p['alt'],
      removeLocal: p['entfernen'],
    ),
];

Future<void> _write(List<Pending> queue) => storage.write(
  key: _key,
  value: jsonEncode([
    for (final p in queue)
      // persisted: do not rename the JSON fields
      {
        'kopie': p.copy,
        'original': p.original,
        'alt': p.old,
        'entfernen': p.removeLocal,
      },
  ]),
);

/// How many copies are still waiting for the backup.
Future<int> pendingCount() async => (await _read()).length;

/// What is waiting, for the settings (D-53).
Future<List<Pending>> pendingList() => _read();

/// Takes [p] out of the queue; the copy stays where it is (D-53).
Future<void> discard(Pending p) async => _write([
  for (final q in await _read())
    if (q != p) q,
]);

Future<void> enqueue(Pending added) async {
  await _write(enqueueIn(await _read(), added));
  await scheduleBackgroundStacking();
}

/// Device copies stacked by a background run, to be removed at the next start in the foreground
/// — only an activity can show Android's delete dialog.
const _trashLaterKey = 'deviceTrashLater'; // persisted: do not rename

Future<List<String>> _trashLater() async => [
  for (final id in jsonDecode(await storage.read(key: _trashLaterKey) ?? '[]'))
    id as String,
];

/// What can never be stacked: its copy or its original is neither on the server nor on the
/// device any more (deleted, D-24). A copy that exists but isn't backed up keeps waiting.
List<Pending> unreachable(
  List<Pending> queue,
  Set<String> onServer,
  Set<String> onDevice,
) => [
  for (final p in queue)
    if ([
      p.copy,
      p.original,
    ].any((s) => !onServer.contains(s) && !onDevice.contains(s)))
      p,
];

Future<void>? _running;

/// Stacks what is pending and has meanwhile reached the server. Runs at most once at a time.
/// With [background] (no activity, D-46): no checksum pass and no delete dialog — copies to
/// remove from the device wait for the next foreground run.
// ponytail: a foreground and a background run can overlap (two isolates); stacking twice is
// harmless, a lock in storage if it ever isn't.
Future<void> stackPending(Immich immich, {bool background = false}) =>
    _running ??= _stackAll(
      immich,
      background,
    ).whenComplete(() => _running = null);

Future<void> _stackAll(Immich immich, bool background) async {
  final done = <Pending>{};
  final queue = await _read();
  if (queue.isEmpty) {
    await cancelBackgroundStacking();
    if (!background) await _trashNow(const []);
    return;
  }
  // One request for all: which checksums does the server know (archived too, D-36)?
  final found = await immich.existing({
    for (final p in queue)
      for (final sum in [p.copy, p.original, ?p.old]) sum: sum,
  });
  for (final p in queue) {
    final copy = found[p.copy];
    final original = found[p.original];
    if (copy == null || original == null) continue;
    final old = found[p.old];
    await stackOnOriginal(
      immich,
      copy,
      await immich.photo(original),
      oldCopy: old,
    );
    done.add(p);
  }
  // Drop what can never arrive. Only a checksum pass started after reading the queue counts —
  // an earlier one may miss a copy saved just before; without access to photos drop nothing.
  if (!background && await devicePermitted()) {
    await deviceChecksums();
    final onDevice = (await deviceChecksums()).values.toSet();
    done.addAll(unreachable(queue, found.keys.toSet(), onDevice));
  }
  // Read again: the editor may have enqueued something while we were stacking.
  final rest = [
    for (final p in await _read())
      if (!done.contains(p)) p,
  ];
  await _write(rest);
  await (rest.isEmpty
      ? cancelBackgroundStacking()
      : scheduleBackgroundStacking());
  final remove = [
    for (final p in done)
      if (found.containsKey(p.copy)) ?p.removeLocal,
  ];
  if (background) {
    await storage.write(
      key: _trashLaterKey,
      value: jsonEncode([...await _trashLater(), ...remove]),
    );
  } else {
    await _trashNow(remove);
  }
}

/// Removes [ids] and what background runs left from the device (one Android dialog).
Future<void> _trashNow(List<String> ids) async {
  final later = await _trashLater();
  await deviceTrash([...ids, ...later]);
  if (later.isNotEmpty) await storage.delete(key: _trashLaterKey);
}
