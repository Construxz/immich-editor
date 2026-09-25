import 'package:flutter/foundation.dart';

import '../export/export.dart';
import '../export/jpeg.dart' show recipeFrom;
import '../photo.dart';
import '../gallery/checksums.dart' show deviceIdWithChecksum;
import '../gallery/device.dart';
import '../hdr.dart';
import '../language.dart';
import '../main.dart' show storage;
import '../server/immich.dart';
import '../stacking/stacking.dart';
import 'presets.dart';
import 'recipe.dart';
import 'preview.dart' show optimize, sha1;

/// A photo ready for editing: [original] holds a device photo's bytes (null for server
/// photos — whoever needs the original, megabytes, loads it), [preview] with `preview: true`
/// Immich's preview image of a server photo. If [id] was a copy made by this app, [photo] is its
/// original, [start] its recipe and [oldCopy] the copy itself (spec, *Speicherweg* 5).
typedef Loaded = ({
  Photo photo,
  Uint8List? original,
  Uint8List? preview,
  Photo? oldCopy,
  Recipe start,
});

Future<Loaded> loadPhoto(
  Immich? immich, // null: without a server (D-79), device photos only
  String id, {
  required bool onDevice,
  bool preview = false,
}) async {
  if (onDevice) {
    var (photo, bytes) = await deviceOriginal(id);
    final from = recipeFrom(bytes);
    final originalId = from == null
        ? null
        : await deviceByChecksum(from.originalSha1, photo.takenAt);
    if (from == null || originalId == null) {
      return (
        photo: photo,
        original: bytes,
        preview: null,
        oldCopy: null,
        start: const Recipe(),
      );
    }
    final copy = photo;
    (photo, bytes) = await deviceOriginal(originalId);
    return (
      photo: photo,
      original: bytes,
      preview: null,
      oldCopy: copy,
      start: Recipe.fromJson(from.recipe),
    );
  }
  // Server: details and head (EXIF, XMP) at once. The preview (the slow part, ~1 s) loads
  // alongside unless the name says copy — only a guess for prefetching, the XMP decides.
  Future<Uint8List?> shown(String id) async =>
      preview ? await immich!.preview(id) : null;
  // Started together, awaited one by one: an error surfaces as itself, not as a
  // ParallelWaitError, and ignore() keeps the others from being reported unhandled.
  final details = immich!.photo(id);
  final early = details.then(
    (p) => p.fileName.contains('.edit') ? null : shown(id),
  )..ignore();
  final headStarted = immich.head(id)..ignore();
  final photo = await details;
  final head = await headStarted;
  final from = recipeFrom(head);
  // An original that also lives on the device is edited there, without the server (D-24).
  final here = await _onDevice(
    from?.originalSha1 ?? photo.checksum,
    from == null ? null : photo,
    from == null ? const Recipe() : Recipe.fromJson(from.recipe),
  );
  if (here != null) return here;
  final originalId = from == null
      ? null
      : await immich.byChecksum(from.originalSha1);
  if (from == null || originalId == null) {
    return (
      photo: photo,
      original: null,
      preview: await early ?? await shown(id),
      oldCopy: null,
      start: const Recipe(),
    );
  }
  final originalImage = shown(originalId)..ignore();
  final original = await immich.photo(originalId);
  return (
    photo: original,
    original: null,
    preview: await originalImage,
    oldCopy: photo,
    start: Recipe.fromJson(from.recipe),
  );
}

/// The device's file with [checksum] as a [Loaded], or null: unknown, gone or changed since the
/// checksum was stored.
Future<Loaded?> _onDevice(String checksum, Photo? oldCopy, Recipe start) async {
  final id = await deviceIdWithChecksum(checksum);
  if (id == null) return null;
  try {
    final (photo, bytes) = await deviceOriginal(id);
    if (photo.checksum != checksum) return null;
    return (
      photo: photo,
      original: bytes,
      preview: null,
      oldCopy: oldCopy,
      start: start,
    );
  } catch (_) {
    return null;
  }
}

/// Renders the copy of [photo] with [recipe] and saves it: with [toDevice] into the device
/// gallery and queued for stacking after backup (D-24, D-25), otherwise uploaded, verified
/// and stacked on top of the original. With [replace] the [oldCopy] goes to the trash
/// (D-31), on the device or the server, wherever it lives. [onStep] reports what is happening.
Future<({Entry entry, Uint8List copy})> saveCopy(
  Immich? immich, { // null: without a server (D-79), only toDevice
  required Photo photo,
  required Uint8List original,
  required Recipe recipe,
  required bool hdr,
  required bool toDevice,
  Photo? oldCopy,
  bool replace = false,
  void Function(String)? onStep,
}) async {
  onStep?.call(l10n.stepRendering);
  final copy = await exportJpeg(recipe, original, photo.checksum, hdr: hdr);
  if (toDevice) {
    final local = await saveToDevice(copy, photo);
    // Without a server there is nothing to stack on.
    if (immich != null) {
      await enqueue((
        copy: await sha1(copy),
        original: photo.checksum,
        old: replace ? oldCopy?.checksum : null,
        removeLocal: photo.folder != null ? null : local,
      ));
    }
    // The old copy leaves the device: itself, or its twin when it was opened from the server
    // (D-24). The server's goes when stacking (old).
    if (replace && oldCopy != null) {
      final here = oldCopy.folder != null
          ? oldCopy.id
          : await deviceIdWithChecksum(oldCopy.checksum);
      if (here != null) await deviceTrash([here]);
    }
    return (entry: (id: local, onDevice: true), copy: copy);
  }
  onStep?.call(l10n.stepUploading);
  final id = await immich!.upload(
    copy,
    photo.fileName.replaceFirst(RegExp(r'(\.[^.]*)?$'), '.edit.jpg'),
    photo.takenAt,
  );
  // Stack only once the server has exactly the bytes we sent:
  // Immich computes the SHA-1 on receipt — it must equal ours.
  onStep?.call(l10n.stepChecking);
  if ((await immich.photo(id)).checksum != await sha1(copy)) {
    throw Exception(l10n.saveCopyMismatch(id));
  }
  onStep?.call(l10n.stepStacking);
  await stackOnOriginal(
    immich,
    id,
    photo,
    oldCopy: replace ? oldCopy?.id : null,
  );
  return (entry: (id: id, onDevice: false), copy: copy);
}

/// Applies [preset] to [photos], one after another, the same way as the editor; no preset:
/// "Optimieren", computed for each photo on its original (D-71).
/// A copy made by this app is replaced: its original with the copy's crop and the
/// preset's adjustments (D-31). [onDone] reports how many are through. Returns the errors;
/// one error does not stop the rest.
// ponytail: sequential, with a waiting gallery; in the background once large selections get annoying.
Future<List<Object>> applyPreset(
  Immich? immich,
  List<Entry> photos,
  Preset? preset, {
  void Function(int done)? onDone,
}) async {
  final hdr = hdrOn.value;
  final online = await storage.read(key: 'online') != 'server';
  final errors = <Object>[];
  for (final (i, e) in photos.indexed) {
    try {
      final l = await loadPhoto(immich, e.id, onDevice: e.onDevice);
      final original = l.original ?? await immich!.original(l.photo.id);
      await saveCopy(
        immich,
        photo: l.photo,
        original: original,
        recipe: preset != null
            ? withPreset(l.start, preset)
            : withOptimized(l.start, await optimize(original)),
        hdr: hdr,
        toDevice: l.original != null || online || immich == null,
        oldCopy: l.oldCopy,
        replace: true,
      );
    } catch (x) {
      errors.add(x);
    }
    onDone?.call(i + 1);
  }
  return errors;
}
