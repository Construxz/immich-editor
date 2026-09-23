import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import '../editor/preview.dart' show readExif, sha1;
import '../photo.dart';

/// Photos on the device (`photo_manager`), newest capture first.
final _newestFirst = CustomFilter.sql(
  where: '',
  orderBy: [OrderByItem.desc(CustomColumns.android.dateTaken)],
);

/// With access to the location in EXIF: only then does Android deliver the unmodified bytes —
/// otherwise the checksum does not match the backup's.
Future<bool> devicePermitted() async =>
    (await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: true,
        ),
      ),
    )).hasAccess;

Future<int> deviceCount() => PhotoManager.getAssetCount(
  filterOption: _newestFirst,
  type: RequestType.image,
);

Future<List<AssetEntity>> devicePhotos(int start, int end) =>
    PhotoManager.getAssetListRange(
      start: start,
      end: end,
      filterOption: _newestFirst,
      type: RequestType.image,
    );

/// The original of a device photo and what the editor needs to know about it.
Future<(Photo, Uint8List)> deviceOriginal(String id) async {
  final a = await AssetEntity.fromId(id);
  final bytes = await a?.originBytes;
  if (a == null || bytes == null) {
    throw Exception('Foto nicht mehr auf dem Gerät');
  }
  final photo = Photo(
    id: a.id,
    fileName: a.title ?? 'foto.jpg',
    takenAt: a.createDateTime.toUtc().toIso8601String(),
    checksum: await sha1(bytes),
    folder: a.relativePath ?? 'DCIM/Camera/',
  );
  return (photo, bytes);
}

/// The device photo with checksum [sha1Value], taken at [takenAt] — this is how a copy finds
/// its original: the copy carries its capture time (see [saveToDevice]).
Future<String?> deviceByChecksum(String sha1Value, String takenAt) async {
  final ms = DateTime.parse(takenAt).millisecondsSinceEpoch ~/ 1000 * 1000;
  final candidates = await PhotoManager.getAssetListRange(
    start: 0,
    end: 50,
    type: RequestType.image,
    filterOption: CustomFilter.sql(
      where: '${CustomColumns.android.dateTaken} BETWEEN $ms AND ${ms + 999}',
    ),
  );
  for (final a in candidates) {
    final bytes = await a.originBytes;
    if (bytes != null && await sha1(bytes) == sha1Value) return a.id;
  }
  return null;
}

/// Puts the copy next to the [original] in the device gallery — same folder, so the Immich app
/// backs it up too, and same capture time, so it sits next to it. If the original is only on
/// the server, into the camera folder. Returns the copy's ID.
// ponytail: fixed camera folder; make it selectable if someone does not back it up.
Future<String> saveToDevice(Uint8List copy, Photo original) async {
  final name = original.fileName.replaceFirst(
    RegExp(r'(\.[^.]*)?$'),
    '.edit.jpg',
  );
  // On Android photo_manager sets the file name from title, not from filename.
  final a = await PhotoManager.editor.saveImage(
    copy,
    filename: name,
    title: name,
    relativePath: original.folder ?? 'DCIM/Camera/',
    creationDate: DateTime.parse(original.takenAt),
  );
  return a.id;
}

/// Capture time, place and camera of a device photo; the camera data from the EXIF at the start
/// of the file, the place name for the GPS coordinates comes from [placeAt].
Future<PhotoInfo> deviceInfo(
  String id,
  Future<String?> Function(double lat, double lon) placeAt,
) async {
  final a = await AssetEntity.fromId(id);
  final bytes = await a?.originBytes;
  if (a == null || bytes == null) {
    throw Exception('Foto nicht mehr auf dem Gerät');
  }
  final e = await readExif(
    Uint8List.sublistView(bytes, 0, bytes.length.clamp(0, 256 * 1024)),
  );
  num? number(String k) => e[k] as num?;
  final lat = number('lat'), lon = number('lon');
  return (
    name: a.title ?? '',
    takenAt: a.createDateTime,
    place: lat == null
        ? null
        : await placeAt(
            lat.toDouble(),
            lon!.toDouble(),
          ).catchError((_) => null),
    camera: cameraFrom(e['Make'] as String?, e['Model'] as String?),
    lens: e['LensModel'] as String?,
    exposure: exposureFrom(
      aperture: number('FNumber'),
      seconds: number('ExposureTime'),
      iso: number('PhotographicSensitivity'),
      focalLength: number('FocalLength'),
    ),
    width: a.orientatedWidth,
    height: a.orientatedHeight,
    bytes: bytes.length,
  );
}

/// Into the device's trash; Android asks the user, once for all.
Future<void> deviceTrash(List<String> ids) async {
  final photos = [for (final id in ids) ?await AssetEntity.fromId(id)];
  if (photos.isNotEmpty) await PhotoManager.editor.android.moveToTrash(photos);
}

/// The IDs of the photos in the device folder [folder] (`relative_path`), at most 200.
Future<List<String>> deviceIdsIn(String folder) async => [
  for (final a in await PhotoManager.getAssetListRange(
    start: 0,
    end: 200,
    type: RequestType.image,
    filterOption: CustomFilter.sql(
      where: "relative_path = '${folder.replaceAll("'", "''")}'",
    ),
  ))
    a.id,
];

/// The folders on the device (without "All"), with photos.
Future<List<AssetPathEntity>> deviceFolders() => PhotoManager.getAssetPathList(
  type: RequestType.image,
  hasAll: false,
  filterOption: _newestFirst,
);
