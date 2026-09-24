import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../language.dart';
import '../photo.dart';

/// Thin Immich client. Immich types (JSON) do not leave this file.
class Immich {
  Immich(String server, this.token)
    : baseUrl = server.replaceAll(RegExp(r'/+$'), '');

  /// Major versions the app is tested against (STATUS.md).
  static const knownMajorVersions = {3};

  final String baseUrl;
  final String token;

  /// One connection for all requests (keep-alive): saves the TLS handshake per request.
  final _http = http.Client();

  /// Timeouts: short requests, loading originals, uploading.
  static const _short = Duration(seconds: 30);
  static const _long = Duration(minutes: 3);

  Map<String, String> get headers => {'Authorization': 'Bearer $token'};

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api$path').replace(queryParameters: query);

  static Future<Immich> login(
    String server,
    String email,
    String password,
  ) async {
    final baseUrl = server.replaceAll(RegExp(r'/+$'), '');
    final r = await _await(
      http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ),
      _short,
    );
    return Immich(baseUrl, _json(r)['accessToken'] as String);
  }

  /// Major version of the server, e.g. 3.
  Future<int> majorVersion() async => (await version()).major;

  /// Version of the server, e.g. 3.2.2.
  Future<({int major, int minor, int patch})> version() async {
    final v = _json(
      await _await(
        _http.get(_uri('/server/version'), headers: headers),
        _short,
      ),
    );
    return (
      major: v['major'] as int,
      minor: v['minor'] as int,
      patch: v['patch'] as int,
    );
  }

  /// Used and available space in bytes: the user's quota, otherwise the server's disk — as the
  /// Immich app shows it.
  Future<({int used, int total})> storageUsage(Account a) async {
    if (a.quota != null) {
      return (used: a.used ?? 0, total: a.quota!);
    }
    final s = _json(
      await _await(
        _http.get(_uri('/server/storage'), headers: headers),
        _short,
      ),
    );
    return (used: s['diskUseRaw'] as int, total: s['diskSizeRaw'] as int);
  }

  /// Who is logged in.
  Future<Account> me() async {
    final u = _json(
      await _await(_http.get(_uri('/users/me'), headers: headers), _short),
    );
    return (
      id: u['id'] as String,
      name: u['name'] as String,
      email: u['email'] as String,
      hasImage: (u['profileImagePath'] as String? ?? '').isNotEmpty,
      color: u['avatarColor'] as String? ?? 'primary',
      quota: u['quotaSizeInBytes'] as int?,
      used: u['quotaUsageInBytes'] as int?,
    );
  }

  Uri avatarUri(String id) => _uri('/users/$id/profile-image');

  /// The timeline's months, newest first; stacks count once.
  Future<List<Month>> months() async {
    final r = await _await(
      _http.get(
        _uri('/timeline/buckets', {
          'withStacked': 'true',
          'visibility': 'timeline',
        }),
        headers: headers,
      ),
      _short,
    );
    return [
      for (final m in _json(r) as List)
        (start: m['timeBucket'] as String, count: m['count'] as int),
    ];
  }

  /// The photos of a month, newest first — of a stack only the primary (no videos).
  Future<List<Tile>> month(String start) async {
    final r = await _await(
      _http.get(
        _uri('/timeline/bucket', {
          'timeBucket': start,
          'withStacked': 'true',
          'visibility': 'timeline',
        }),
        headers: headers,
      ),
      _short,
    );
    final d = _json(r);
    final ids = d['id'] as List, isImage = d['isImage'] as List;
    final ratio = d['ratio'] as List, stack = d['stack'] as List;
    final time = d['fileCreatedAt'] as List;
    return [
      for (var i = 0; i < ids.length; i++)
        if (isImage[i] == true)
          (
            id: ids[i] as String,
            aspectRatio: (ratio[i] as num).toDouble(),
            stackSize: stack[i] == null ? 1 : int.parse('${stack[i][1]}'),
            time: DateTime.parse(time[i] as String),
          ),
    ];
  }

  /// What the editor needs to know about a photo.
  Future<Photo> photo(String id) async => _photoFrom(await _asset(id));

  Future<Map<String, dynamic>> _asset(String id) async => _json(
    await _await(_http.get(_uri('/assets/$id'), headers: headers), _short),
  );

  static Photo _photoFrom(Map<String, dynamic> a) => Photo(
    id: a['id'],
    fileName: a['originalFileName'],
    takenAt: a['fileCreatedAt'],
    checksum: a['checksum'],
    stackPrimary: a['stack']?['primaryAssetId'],
    createdAt: a['createdAt'],
    localTime: _localTime(a),
  );

  /// Immich records the local time as UTC (`localDateTime`); what is meant is the local clock.
  static DateTime? _localTime(Map<String, dynamic> a) => DateTime.tryParse(
    (a['localDateTime'] as String? ?? '').replaceFirst(
      RegExp(r'(Z|[+-]\d\d:\d\d)$'),
      '',
    ),
  );

  /// The stack of [id]; without a stack just the photo itself.
  Future<PhotoStack> stackOf(String id) async {
    final a = await _asset(id);
    final stack = a['stack']?['id'] as String?;
    if (stack == null) return (id: null, primary: id, photos: [_photoFrom(a)]);
    final s = _json(
      await _await(_http.get(_uri('/stacks/$stack'), headers: headers), _short),
    );
    final all = [
      for (final x in s['assets'] as List)
        if (x['isTrashed'] != true) _photoFrom(x),
    ];
    return (id: stack, primary: s['primaryAssetId'] as String, photos: all);
  }

  /// Puts [id] in front of the stack [stack].
  Future<void> setPrimary(String stack, String id) async => _ok(
    await _await(
      _http.put(
        _uri('/stacks/$stack'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'primaryAssetId': id}),
      ),
      _short,
    ),
  );

  /// Dissolves the stack; the photos remain.
  Future<void> deleteStack(String stack) async => _ok(
    await _await(
      _http.delete(_uri('/stacks/$stack'), headers: headers),
      _short,
    ),
  );

  /// "City, country" for coordinates — Immich uses its own place data, no third-party service.
  Future<String?> placeAt(double lat, double lon) async {
    final r = _json(
      await _await(
        _http.get(
          _uri('/map/reverse-geocode', {'lat': '$lat', 'lon': '$lon'}),
          headers: headers,
        ),
        _short,
      ),
    ) as List;
    if (r.isEmpty) return null;
    final place = [
      r.first['city'],
      r.first['country'],
    ].whereType<String>().join(', ');
    return place.isEmpty ? null : place;
  }

  /// Capture time, place and camera as Immich read them from the EXIF.
  Future<PhotoInfo> info(String id) async {
    final a = await _asset(id);
    final e = (a['exifInfo'] ?? const {}) as Map<String, dynamic>;
    final time = e['exposureTime'] as String?; // e.g. "1/120"
    final fraction = time?.split('/');
    final place = [e['city'], e['country']].whereType<String>().join(', ');
    return (
      name: a['originalFileName'] as String,
      takenAt: _localTime(a),
      place: place.isEmpty ? null : place,
      camera: cameraFrom(e['make'], e['model']),
      lens: e['lensModel'] as String?,
      exposure: exposureFrom(
        aperture: e['fNumber'],
        seconds: fraction == null
            ? null
            : fraction.length == 2
            ? num.parse(fraction[0]) / num.parse(fraction[1])
            : num.tryParse(fraction[0]),
        iso: e['iso'],
        focalLength: e['focalLength'],
        locale: l10n.localeName,
      ),
      width: e['exifImageWidth'] as int?,
      height: e['exifImageHeight'] as int?,
      bytes: e['fileSizeInByte'] as int?,
    );
  }

  /// The first 64 KB of the original — enough for EXIF and XMP.
  Future<Uint8List> head(String id) async => _ok(
    await _await(
      _http.get(
        _uri('/assets/$id/original'),
        headers: {...headers, 'Range': 'bytes=0-65535'},
      ),
      _short,
    ),
  ).bodyBytes;

  /// The asset with checksum [sha1] (Base64), or null.
  Future<String?> byChecksum(String sha1) async {
    final r = await _await(
      _http.post(
        _uri('/search/metadata'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'checksum': sha1, 'withStacked': true, 'size': 1}),
      ),
      _short,
    );
    final items = _json(r)['assets']['items'] as List;
    return items.isEmpty ? null : items.first['id'] as String;
  }

  /// Which of the [checksums] (key → SHA-1) the server already has: key → asset ID.
  /// Archived ones too; not what is in the trash.
  Future<Map<String, String>> existing(Map<String, String> checksums) async {
    final all = checksums.entries.toList();
    // Batches of 1000, all at once: one after another took 3 s for 17,500 photos (D-51).
    final answers = await Future.wait([
      for (var i = 0; i < all.length; i += 1000)
        _await(
          _http.post(
            _uri('/assets/bulk-upload-check'),
            headers: {...headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'assets': [
                for (final e in all.skip(i).take(1000))
                  {'id': e.key, 'checksum': e.value},
              ],
            }),
          ),
          _short,
        ),
    ]);
    return {
      for (final r in answers)
        for (final x in _json(r)['results'] as List)
          if (x['assetId'] != null && x['isTrashed'] != true)
            x['id'] as String: x['assetId'] as String,
    };
  }

  /// Into the trash — it stays restorable there.
  Future<void> trash(List<String> ids) async => _ok(
    await _await(
      _http.delete(
        _uri('/assets'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'ids': ids, 'force': false}),
      ),
      _short,
    ),
  );

  Uri thumbnailUri(String id) => _uri('/assets/$id/thumbnail');

  /// Immich's thumbnail (WebP, about 250 px), over the keep-alive connection.
  Future<Uint8List> thumbnail(String id) async =>
      _ok(await _await(_http.get(thumbnailUri(id), headers: headers), _short))
          .bodyBytes;

  /// Immich's preview image (JPEG, long edge 1440 px, already uprighted, without gain map).
  Uri previewUri(String id) =>
      _uri('/assets/$id/thumbnail', {'size': 'preview'});

  Future<Uint8List> preview(String id) async =>
      _ok(await _await(_http.get(previewUri(id), headers: headers), _short))
          .bodyBytes;

  Future<Uint8List> original(String id) async => _ok(
    await _await(
      _http.get(_uri('/assets/$id/original'), headers: headers),
      _long,
    ),
  ).bodyBytes;

  /// Uploads a new asset and returns its ID.
  /// With [archived] it does not appear in the timeline, only in albums and the archive.
  Future<String> upload(
    Uint8List bytes,
    String fileName,
    String takenAt, {
    bool archived = false,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/assets'))
      ..headers.addAll(headers)
      ..fields['fileCreatedAt'] = takenAt
      ..fields['fileModifiedAt'] = DateTime.now().toUtc().toIso8601String()
      ..fields['visibility'] = archived ? 'archive' : 'timeline'
      ..files.add(
        http.MultipartFile.fromBytes('assetData', bytes, filename: fileName),
      );
    return _json(
      await _await(_http.send(req).then(http.Response.fromStream), _long),
    )['id'];
  }

  /// Stacks the assets; the first one is in front.
  Future<void> stack(List<String> ids) async => _ok(
    await _await(
      _http.post(
        _uri('/stacks'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'assetIds': ids}),
      ),
      _short,
    ),
  );

  /// The album [name] (created if missing).
  Future<String> album(String name) async {
    final all = jsonDecode(
      _ok(await _await(_http.get(_uri('/albums'), headers: headers), _short))
          .body,
    ) as List;
    for (final a in all) {
      if (a['albumName'] == name) return a['id'] as String;
    }
    return _json(
      await _await(
        _http.post(
          _uri('/albums'),
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'albumName': name}),
        ),
        _short,
      ),
    )['id'];
  }

  Future<List<String>> albumsOf(String id) async {
    final r = await _await(
      _http.get(_uri('/albums', {'assetId': id}), headers: headers),
      _short,
    );
    return [for (final a in jsonDecode(_ok(r).body) as List) a['id'] as String];
  }

  Future<void> addToAlbum(String album, List<String> ids) async => _ok(
    await _await(
      _http.put(
        _uri('/albums/$album/assets'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'ids': ids}),
      ),
      _short,
    ),
  );

  /// Waits at most [limit]; network errors become an understandable message.
  static Future<http.Response> _await(
    Future<http.Response> request,
    Duration limit,
  ) async {
    try {
      return await request.timeout(limit);
    } on TimeoutException {
      throw ImmichError(l10n.serverTimeout);
    } on SocketException catch (e) {
      throw ImmichError(l10n.serverUnreachable(e.message));
    } on http.ClientException catch (e) {
      throw ImmichError(l10n.serverConnectionLost(e.message));
    }
  }

  static http.Response _ok(http.Response r) {
    if (r.statusCode == 401) {
      throw ImmichError(l10n.serverSessionExpired);
    }
    if (r.statusCode >= 300) {
      throw ImmichError(
        'Immich ${r.request?.url.path}: ${r.statusCode} ${r.body}',
      );
    }
    return r;
  }

  static dynamic _json(http.Response r) => jsonDecode(_ok(r).body);
}

/// An error that can be shown to the user as is.
class ImmichError implements Exception {
  const ImmichError(this.message);

  final String message;

  @override
  String toString() => message;
}
