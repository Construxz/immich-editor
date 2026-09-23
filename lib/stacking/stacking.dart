import 'dart:convert';

import '../photo.dart';
import '../gallery/device.dart' show deviceTrash;
import '../main.dart' show storage;
import '../server/immich.dart';

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

Future<void> enqueue(Pending added) async =>
    _write(enqueueIn(await _read(), added));

Future<void>? _running;

/// Stacks what is pending and has meanwhile reached the server. Runs at most once at a time.
Future<void> stackPending(Immich immich) =>
    _running ??= _stackAll(immich).whenComplete(() => _running = null);

Future<void> _stackAll(Immich immich) async {
  final done = <Pending>{};
  final queue = await _read();
  if (queue.isEmpty) return;
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
  // Read again: the editor may have enqueued something while we were stacking.
  await _write([
    for (final p in await _read())
      if (!done.contains(p)) p,
  ]);
  await deviceTrash([for (final p in done) ?p.removeLocal]);
}
