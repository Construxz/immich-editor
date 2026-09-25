import 'dart:convert';
import 'dart:typed_data';

/// Namespace of the recipe in the XMP.
const recipeNamespace = 'https://github.com/Construxz/immich-editor/ns/1.0/';

const _exifId = 'Exif\x00\x00';
const _xmpId = 'http://ns.adobe.com/xap/1.0/\x00';
const _mpfId = 'MPF\x00';

/// A segment in a JPEG header: marker (e.g. 0xE1) and payload without the length field.
typedef Segment = ({int marker, Uint8List data});

/// Splits [jpeg] into the segments before the image data and the rest from SOS on. Also copes
/// with the head of a file (partial fetch): a truncated segment ends the list.
(List<Segment>, Uint8List) parseSegments(Uint8List jpeg) {
  final segments = <Segment>[];
  var i = 2;
  while (i + 4 <= jpeg.length && jpeg[i] == 0xFF && jpeg[i + 1] != 0xDA) {
    final length = (jpeg[i + 2] << 8) | jpeg[i + 3];
    if (i + 2 + length > jpeg.length) break;
    segments.add((
      marker: jpeg[i + 1],
      data: Uint8List.sublistView(jpeg, i + 4, i + 2 + length),
    ));
    i += 2 + length;
  }
  return (segments, Uint8List.sublistView(jpeg, i));
}

bool _is(Segment s, int marker, String id) =>
    s.marker == marker &&
    s.data.length >= id.length &&
    latin1.decode(s.data.sublist(0, id.length)) == id;

/// The EXIF payload (`Exif\0\0` + TIFF) from [jpeg], or null.
Uint8List? exifFrom(Uint8List jpeg) {
  for (final s in parseSegments(jpeg).$1) {
    if (_is(s, 0xE1, _exifId)) return Uint8List.fromList(s.data);
  }
  return null;
}

/// Recipe (JSON) and original checksum from the XMP of a copy this app wrote — or null if
/// [jpeg] is no such copy.
({Map<String, dynamic> recipe, String originalSha1})? recipeFrom(
  Uint8List jpeg,
) {
  for (final s in parseSegments(jpeg).$1) {
    if (!_is(s, 0xE1, _xmpId)) continue;
    final xml = utf8.decode(
      s.data.sublist(_xmpId.length),
      allowMalformed: true,
    );
    if (!xml.contains(recipeNamespace)) return null;
    String? value(String name) =>
        RegExp('ife:$name="([^"]*)"')
            .firstMatch(xml)
            ?.group(1)
            ?.replaceAll('&quot;', '"')
            .replaceAll('&lt;', '<')
            .replaceAll('&amp;', '&');
    final recipe = value('recipe'), sha1 = value('originalSha1');
    if (recipe == null || sha1 == null) return null;
    // Anyone can write this namespace: broken JSON means no copy of ours (D-78).
    final json = _tryJson(recipe);
    return json is Map<String, dynamic>
        ? (recipe: json, originalSha1: sha1)
        : null;
  }
  return null;
}

Object? _tryJson(String s) {
  try {
    return jsonDecode(s);
  } on FormatException {
    return null;
  }
}

/// Sets the orientation in the EXIF payload [exif] to 1 ("normal"): the renderer has already
/// uprighted the image (`Geometry.afterExif`).
void normalizeOrientation(Uint8List exif) {
  const tiff = 6; // after "Exif\0\0"
  final d = ByteData.sublistView(exif);
  final e = exif[tiff] == 0x49 ? Endian.little : Endian.big; // II / MM
  final ifd0 = tiff + d.getUint32(tiff + 4, e);
  for (var n = 0; n < d.getUint16(ifd0, e); n++) {
    final entry = ifd0 + 2 + n * 12;
    if (d.getUint16(entry, e) == 0x0112) {
      d.setUint16(entry + 8, 1, e);
      return;
    }
  }
}

/// Assembles the copy from the encoder's output:
///
/// - the original's EXIF ([exif]) replaces the encoder's;
/// - the recipe goes into the XMP — into the existing packet if the encoder wrote one
///   (Ultra HDR: gain map directory), otherwise into a new one;
/// - an MPF directory (Ultra HDR) is adjusted to the changed lengths so it still points
///   at the gain map.
Uint8List assemble(
  Uint8List encoded, {
  Uint8List? exif,
  required Map<String, Object> recipe,
  required String originalSha1,
}) {
  final (old, rest) = parseSegments(encoded);
  final attributes =
      ' xmlns:ife="$recipeNamespace"'
      ' ife:originalSha1="${_attr(originalSha1)}"'
      ' ife:recipe="${_attr(jsonEncode(recipe))}"';

  final out = <Segment>[];
  var hasExif = false, hasXmp = false;
  for (final s in old) {
    if (exif != null && _is(s, 0xE1, _exifId)) {
      if (!hasExif) out.add((marker: 0xE1, data: exif));
      hasExif = true;
    } else if (!hasXmp && _is(s, 0xE1, _xmpId)) {
      final xml = utf8.decode(s.data.sublist(_xmpId.length));
      final i = xml.indexOf('<rdf:Description');
      if (i < 0) throw StateError('encoder XMP without rdf:Description');
      final withRecipe = xml.replaceRange(i + 16, i + 16, attributes);
      out.add((marker: 0xE1, data: _xmpData(withRecipe)));
      hasXmp = true;
    } else {
      out.add(s);
    }
  }
  var front = out.isNotEmpty && out.first.marker == 0xE0 ? 1 : 0; // after JFIF
  if (exif != null && !hasExif) out.insert(front++, (marker: 0xE1, data: exif));
  if (!hasXmp) {
    out.insert(front, (
      marker: 0xE1,
      data: _xmpData(
        '<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>'
        '<x:xmpmeta xmlns:x="adobe:ns:meta/">'
        '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">'
        '<rdf:Description rdf:about=""$attributes/>'
        '</rdf:RDF></x:xmpmeta><?xpacket end="w"?>',
      ),
    ));
  }
  _adjustMpf(old, out);

  return Uint8List.fromList([
    0xFF,
    0xD8,
    for (final s in out) ..._segmentBytes(s),
    ...rest,
  ]);
}

/// Fixes the MPF directory in [out]: the primary image's size grows by everything added to the
/// header; offsets of further images count from the MPF header and grow only by what was added
/// after it.
void _adjustMpf(List<Segment> old, List<Segment> out) {
  final iOld = old.indexWhere((s) => _is(s, 0xE2, _mpfId));
  if (iOld < 0) return;
  final iOut = out.indexWhere((s) => identical(s.data, old[iOld].data));
  int sum(Iterable<Segment> l) => l.fold(0, (n, s) => n + s.data.length + 4);
  final total = sum(out) - sum(old);
  final after = sum(out.skip(iOut + 1)) - sum(old.skip(iOld + 1));

  final mpf = Uint8List.fromList(old[iOld].data);
  const tiff = 4; // after "MPF\0"
  final d = ByteData.sublistView(mpf);
  final e = mpf[tiff] == 0x49 ? Endian.little : Endian.big;
  final ifd = tiff + d.getUint32(tiff + 4, e);
  for (var n = 0; n < d.getUint16(ifd, e); n++) {
    final entry = ifd + 2 + n * 12;
    if (d.getUint16(entry, e) != 0xB002) continue; // MP Entry
    final count = d.getUint32(entry + 4, e) ~/ 16;
    final start = tiff + d.getUint32(entry + 8, e);
    for (var j = 0; j < count; j++) {
      final image = start + j * 16;
      if (j == 0) {
        d.setUint32(image + 4, d.getUint32(image + 4, e) + total, e);
      } else if (d.getUint32(image + 8, e) != 0) {
        d.setUint32(image + 8, d.getUint32(image + 8, e) + after, e);
      }
    }
  }
  out[iOut] = (marker: 0xE2, data: mpf);
}

String _attr(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;');

Uint8List _xmpData(String xml) =>
    Uint8List.fromList([...latin1.encode(_xmpId), ...utf8.encode(xml)]);

Uint8List _segmentBytes(Segment s) {
  // ponytail: a segment holds at most 64 KB; masks (M4) need Extended XMP.
  final length = s.data.length + 2;
  if (length > 0xFFFF) throw StateError('segment too large (${s.marker})');
  return Uint8List.fromList([
    0xFF,
    s.marker,
    length >> 8,
    length & 0xFF,
    ...s.data,
  ]);
}
