/// A photo as gallery and editor see it — independent of the backend.
class Photo {
  const Photo({
    required this.id,
    required this.fileName,
    required this.takenAt,
    required this.checksum,
    this.stackPrimary,
    this.folder,
    this.createdAt,
    this.localTime,
  });

  final String id;
  final String fileName;

  /// Capture time in the server's ISO 8601 format, passed through unchanged.
  final String takenAt;

  /// SHA-1 of the original, Base64.
  final String checksum;

  /// What sits in front of the stack, if the photo is stacked.
  final String? stackPrimary;

  /// Folder in the device gallery if the photo is on the device; otherwise null (server).
  final String? folder;

  /// When the asset was created on the server (ISO 8601) — orders copies in the stack.
  final String? createdAt;

  /// Capture time as local wall-clock time.
  final DateTime? localTime;
}

/// A stack on the server: [id] (null without a stack), the primary photo, all members.
typedef PhotoStack = ({String? id, String primary, List<Photo> photos});

/// A photo in gallery and viewer: on the device ([onDevice]) or on the server.
typedef Entry = ({String id, bool onDevice});

/// What the viewer shows on swipe-up; whatever is missing stays null.
typedef PhotoInfo = ({
  String name,
  DateTime? takenAt,
  String? place,
  String? camera,
  String? lens,
  String? exposure,
  int? width,
  int? height,
  int? bytes,
});

/// "Google Pixel 7 Pro" instead of "Google Google Pixel 7 Pro".
String? cameraFrom(String? make, String? model) {
  if (model == null) return make;
  if (make == null || model.startsWith(make)) return model;
  return '$make $model';
}

/// "f/1,9 · 1/120 s · ISO 50 · 6,8 mm" — only what is known.
String? exposureFrom({
  num? aperture,
  num? seconds,
  num? iso,
  num? focalLength,
}) {
  String number(num x) =>
      (x == x.roundToDouble() ? x.round().toString() : x.toStringAsFixed(1))
          .replaceAll('.', ',');
  final parts = [
    if (aperture != null && aperture > 0) 'f/${number(aperture)}',
    if (seconds != null && seconds > 0)
      seconds < 1 ? '1/${(1 / seconds).round()} s' : '${number(seconds)} s',
    if (iso != null && iso > 0) 'ISO ${iso.round()}',
    if (focalLength != null && focalLength > 0) '${number(focalLength)} mm',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The logged-in user: [color] is Immich's avatar color, [hasImage] a custom profile image,
/// [quota] and [used] in bytes (null without a quota).
typedef Account = ({
  String id,
  String name,
  String email,
  bool hasImage,
  String color,
  int? quota,
  int? used,
});

/// A gallery entry, as lean as the timeline delivers it; [time] is the capture time.
typedef Tile = ({String id, double aspectRatio, int stackSize, DateTime time});

/// Where a photo lives — the Immich app's clouds: device only, server only, both (D-36).
enum Presence { device, server, both }

/// A month of the gallery: start (ISO date) and number of entries.
typedef Month = ({String start, int count});
