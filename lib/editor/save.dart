import 'package:flutter/foundation.dart';

import '../export/export.dart';
import '../export/jpeg.dart' show recipeFrom;
import '../photo.dart';
import '../gallery/device.dart';
import '../main.dart' show storage;
import '../server/immich.dart';
import '../stacking/stacking.dart';
import 'presets.dart';
import 'recipe.dart';
import 'preview.dart' show sha1;

/// A photo ready for editing: for device photos [bytes] is the original, for server photos
/// only the head (EXIF, XMP) — whoever needs the original (megabytes) loads it.
/// If [id] was a copy made by this app, [photo] is its original, [start] its recipe and
/// [oldCopy] the copy itself (spec, *Speicherweg* 5).
typedef Loaded = ({Photo photo, Uint8List bytes, Photo? oldCopy, Recipe start});

Future<Loaded> loadPhoto(
  Immich immich,
  String id, {
  required bool onDevice,
}) async {
  Future<(Photo, Uint8List)> load(String id) async => onDevice
      ? await deviceOriginal(id)
      : (await immich.photo(id), await immich.head(id));
  var (photo, bytes) = await load(id);
  final from = recipeFrom(bytes);
  final originalId = from == null
      ? null
      : onDevice
      ? await deviceByChecksum(from.originalSha1, photo.takenAt)
      : await immich.byChecksum(from.originalSha1);
  if (from == null || originalId == null) {
    return (photo: photo, bytes: bytes, oldCopy: null, start: const Recipe());
  }
  final copy = photo;
  (photo, bytes) = await load(originalId);
  return (
    photo: photo,
    bytes: bytes,
    oldCopy: copy,
    start: Recipe.fromJson(from.recipe),
  );
}

/// Renders the copy of [photo] with [recipe] and saves it: with [toDevice] into the device
/// gallery and queued for stacking after backup (D-24, D-25), otherwise uploaded, verified
/// and stacked on top of the original. With [replace] the [oldCopy] goes to the trash
/// (D-31). [onDevice]: [photo] lives on the device. [onStep] reports what is happening.
Future<({Entry entry, Uint8List copy})> saveCopy(
  Immich immich, {
  required Photo photo,
  required Uint8List original,
  required Recipe recipe,
  required bool hdr,
  required bool toDevice,
  required bool onDevice,
  Photo? oldCopy,
  bool replace = false,
  void Function(String)? onStep,
}) async {
  onStep?.call('Wird gerendert …');
  final copy = await exportJpeg(recipe, original, photo.checksum, hdr: hdr);
  if (toDevice) {
    final local = await saveToDevice(copy, photo);
    await enqueue((
      copy: await sha1(copy),
      original: photo.checksum,
      old: replace ? oldCopy?.checksum : null,
      removeLocal: onDevice ? null : local,
    ));
    // An old copy on the device goes to its trash; one on the server only when
    // stacking (old).
    if (oldCopy != null && replace && onDevice) {
      await deviceTrash([oldCopy.id]);
    }
    return (entry: (id: local, onDevice: true), copy: copy);
  }
  onStep?.call('Wird hochgeladen …');
  final id = await immich.upload(
    copy,
    photo.fileName.replaceFirst(RegExp(r'(\.[^.]*)?$'), '.edit.jpg'),
    photo.takenAt,
  );
  // Stack only once the server has exactly the bytes we sent:
  // Immich computes the SHA-1 on receipt — it must equal ours.
  onStep?.call('Wird geprüft …');
  if ((await immich.photo(id)).checksum != await sha1(copy)) {
    throw Exception('Kopie auf dem Server weicht ab ($id)');
  }
  onStep?.call('Wird gestapelt …');
  await stackOnOriginal(
    immich,
    id,
    photo,
    oldCopy: replace ? oldCopy?.id : null,
  );
  return (entry: (id: id, onDevice: false), copy: copy);
}

/// Applies [preset] to [photos], one after another, the same way as the editor.
/// A copy made by this app is replaced: its original with the copy's crop and the
/// preset's adjustments (D-31). [onDone] reports how many are through. Returns the errors;
/// one error does not stop the rest.
// ponytail: sequential, with a waiting gallery; in the background once large selections get annoying.
Future<List<Object>> applyPreset(
  Immich immich,
  List<Entry> photos,
  Preset preset, {
  void Function(int done)? onDone,
}) async {
  final hdr = await storage.read(key: 'hdr') != 'aus';
  final online = await storage.read(key: 'online') != 'server';
  final errors = <Object>[];
  for (final (i, e) in photos.indexed) {
    try {
      final l = await loadPhoto(immich, e.id, onDevice: e.onDevice);
      await saveCopy(
        immich,
        photo: l.photo,
        original: e.onDevice ? l.bytes : await immich.original(l.photo.id),
        recipe: withPreset(l.start, preset),
        hdr: hdr,
        toDevice: e.onDevice || online,
        onDevice: e.onDevice,
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
