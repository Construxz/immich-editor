import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../foto.dart';

/// Schmaler Immich-Client. Immich-Typen (JSON) verlassen diese Datei nicht.
class Immich {
  Immich(String server, this.token)
    : basis = server.replaceAll(RegExp(r'/+$'), '');

  /// Hauptversionen, gegen die die App geprüft ist (STATUS.md).
  static const bekannteHauptversionen = {3};

  final String basis;
  final String token;

  /// Eine Verbindung für alle Anfragen (Keep-Alive): spart je Anfrage den TLS-Handshake.
  final _http = http.Client();

  /// Zeitgrenzen: kurze Anfragen, Originale laden, Hochladen.
  static const _kurz = Duration(seconds: 30);
  static const _lang = Duration(minutes: 3);

  Map<String, String> get kopf => {'Authorization': 'Bearer $token'};

  Uri _uri(String pfad, [Map<String, String>? query]) =>
      Uri.parse('$basis/api$pfad').replace(queryParameters: query);

  static Future<Immich> anmelden(
    String server,
    String email,
    String passwort,
  ) async {
    final basis = server.replaceAll(RegExp(r'/+$'), '');
    final r = await _warten(
      http.post(
        Uri.parse('$basis/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': passwort}),
      ),
      _kurz,
    );
    return Immich(basis, _json(r)['accessToken'] as String);
  }

  /// Hauptversion des Servers, etwa 3.
  Future<int> hauptversion() async => (await version()).major;

  /// Version des Servers, etwa 3.2.2.
  Future<({int major, int minor, int patch})> version() async {
    final v = _json(
      await _warten(_http.get(_uri('/server/version'), headers: kopf), _kurz),
    );
    return (
      major: v['major'] as int,
      minor: v['minor'] as int,
      patch: v['patch'] as int,
    );
  }

  /// Belegter und verfügbarer Platz in Bytes: das Kontingent des Nutzers, sonst die Platte des
  /// Servers — wie die Immich-App es zeigt.
  Future<({int belegt, int gesamt})> speicherplatz(Konto k) async {
    if (k.kontingent != null) {
      return (belegt: k.belegt ?? 0, gesamt: k.kontingent!);
    }
    final s = _json(
      await _warten(_http.get(_uri('/server/storage'), headers: kopf), _kurz),
    );
    return (belegt: s['diskUseRaw'] as int, gesamt: s['diskSizeRaw'] as int);
  }

  /// Wer angemeldet ist.
  Future<Konto> ich() async {
    final u = _json(
      await _warten(_http.get(_uri('/users/me'), headers: kopf), _kurz),
    );
    return (
      id: u['id'] as String,
      name: u['name'] as String,
      email: u['email'] as String,
      hatBild: (u['profileImagePath'] as String? ?? '').isNotEmpty,
      farbe: u['avatarColor'] as String? ?? 'primary',
      kontingent: u['quotaSizeInBytes'] as int?,
      belegt: u['quotaUsageInBytes'] as int?,
    );
  }

  Uri profilbild(String id) => _uri('/users/$id/profile-image');

  /// Die Monate der Timeline, neueste zuerst; Stapel zählen einmal.
  Future<List<Monat>> monate() async {
    final r = await _warten(
      _http.get(
        _uri('/timeline/buckets', {
          'withStacked': 'true',
          'visibility': 'timeline',
        }),
        headers: kopf,
      ),
      _kurz,
    );
    return [
      for (final m in _json(r) as List)
        (beginn: m['timeBucket'] as String, anzahl: m['count'] as int),
    ];
  }

  /// Die Fotos eines Monats, neueste zuerst — von einem Stapel nur das vordere (Videos nicht).
  Future<List<Kachel>> monat(String beginn) async {
    final r = await _warten(
      _http.get(
        _uri('/timeline/bucket', {
          'timeBucket': beginn,
          'withStacked': 'true',
          'visibility': 'timeline',
        }),
        headers: kopf,
      ),
      _kurz,
    );
    final d = _json(r);
    final ids = d['id'] as List, bild = d['isImage'] as List;
    final verhaeltnis = d['ratio'] as List, stapel = d['stack'] as List;
    return [
      for (var i = 0; i < ids.length; i++)
        if (bild[i] == true)
          (
            id: ids[i] as String,
            seitenverhaeltnis: (verhaeltnis[i] as num).toDouble(),
            stapel: stapel[i] == null ? 1 : int.parse('${stapel[i][1]}'),
          ),
    ];
  }

  /// Was der Editor über ein Foto wissen muss.
  Future<Foto> foto(String id) async => _fotoAus(await _asset(id));

  Future<Map<String, dynamic>> _asset(String id) async => _json(
    await _warten(_http.get(_uri('/assets/$id'), headers: kopf), _kurz),
  );

  static Foto _fotoAus(Map<String, dynamic> a) => Foto(
    id: a['id'],
    dateiname: a['originalFileName'],
    aufgenommen: a['fileCreatedAt'],
    pruefsumme: a['checksum'],
    stapelVorn: a['stack']?['primaryAssetId'],
    angelegt: a['createdAt'],
    ortszeit: _ortszeit(a),
  );

  /// Immich notiert die Uhrzeit vor Ort als UTC (`localDateTime`); gemeint ist die Uhr vor Ort.
  static DateTime? _ortszeit(Map<String, dynamic> a) => DateTime.tryParse(
    (a['localDateTime'] as String? ?? '').replaceFirst(
      RegExp(r'(Z|[+-]\d\d:\d\d)$'),
      '',
    ),
  );

  /// Der Stapel von [id]; ohne Stapel nur das Foto selbst.
  Future<Stapel> stapelMit(String id) async {
    final a = await _asset(id);
    final stapel = a['stack']?['id'] as String?;
    if (stapel == null) return (id: null, vorn: id, fotos: [_fotoAus(a)]);
    final s = _json(
      await _warten(_http.get(_uri('/stacks/$stapel'), headers: kopf), _kurz),
    );
    final alle = [
      for (final x in s['assets'] as List)
        if (x['isTrashed'] != true) _fotoAus(x),
    ];
    return (id: stapel, vorn: s['primaryAssetId'] as String, fotos: alle);
  }

  /// Legt [id] im Stapel [stapel] nach vorn.
  Future<void> vornSetzen(String stapel, String id) async => _ok(
    await _warten(
      _http.put(
        _uri('/stacks/$stapel'),
        headers: {...kopf, 'Content-Type': 'application/json'},
        body: jsonEncode({'primaryAssetId': id}),
      ),
      _kurz,
    ),
  );

  /// Löst den Stapel auf; die Fotos bleiben.
  Future<void> stapelAufloesen(String stapel) async => _ok(
    await _warten(_http.delete(_uri('/stacks/$stapel'), headers: kopf), _kurz),
  );

  /// „Stadt, Land" zu Koordinaten — Immich rechnet mit eigenen Ortsdaten, kein fremder Dienst.
  Future<String?> ortVon(double lat, double lon) async {
    final r = _json(
      await _warten(
        _http.get(
          _uri('/map/reverse-geocode', {'lat': '$lat', 'lon': '$lon'}),
          headers: kopf,
        ),
        _kurz,
      ),
    ) as List;
    if (r.isEmpty) return null;
    final ort = [
      r.first['city'],
      r.first['country'],
    ].whereType<String>().join(', ');
    return ort.isEmpty ? null : ort;
  }

  /// Aufnahme, Ort und Kamera, wie Immich sie aus dem EXIF gelesen hat.
  Future<FotoInfo> info(String id) async {
    final a = await _asset(id);
    final e = (a['exifInfo'] ?? const {}) as Map<String, dynamic>;
    final zeit = e['exposureTime'] as String?; // etwa „1/120"
    final bruch = zeit?.split('/');
    final ort = [e['city'], e['country']].whereType<String>().join(', ');
    return (
      name: a['originalFileName'] as String,
      aufgenommen: _ortszeit(a),
      ort: ort.isEmpty ? null : ort,
      kamera: kameraAus(e['make'], e['model']),
      objektiv: e['lensModel'] as String?,
      belichtung: belichtungAus(
        blende: e['fNumber'],
        sekunden: bruch == null
            ? null
            : bruch.length == 2
            ? num.parse(bruch[0]) / num.parse(bruch[1])
            : num.tryParse(bruch[0]),
        iso: e['iso'],
        brennweite: e['focalLength'],
      ),
      breite: e['exifImageWidth'] as int?,
      hoehe: e['exifImageHeight'] as int?,
      bytes: e['fileSizeInByte'] as int?,
    );
  }

  /// Die ersten 64 KB des Originals — genug für EXIF und XMP.
  Future<Uint8List> anfang(String id) async => _ok(
    await _warten(
      _http.get(
        _uri('/assets/$id/original'),
        headers: {...kopf, 'Range': 'bytes=0-65535'},
      ),
      _kurz,
    ),
  ).bodyBytes;

  /// Das Asset mit der Prüfsumme [sha1] (Base64), oder null.
  Future<String?> perPruefsumme(String sha1) async {
    final r = await _warten(
      _http.post(
        _uri('/search/metadata'),
        headers: {...kopf, 'Content-Type': 'application/json'},
        body: jsonEncode({'checksum': sha1, 'withStacked': true, 'size': 1}),
      ),
      _kurz,
    );
    final items = _json(r)['assets']['items'] as List;
    return items.isEmpty ? null : items.first['id'] as String;
  }

  /// In den Papierkorb — dort bleibt es wiederherstellbar.
  Future<void> papierkorb(List<String> ids) async => _ok(
    await _warten(
      _http.delete(
        _uri('/assets'),
        headers: {...kopf, 'Content-Type': 'application/json'},
        body: jsonEncode({'ids': ids, 'force': false}),
      ),
      _kurz,
    ),
  );

  Uri miniatur(String id) => _uri('/assets/$id/thumbnail');

  /// Immichs Vorschaubild (JPEG, lange Kante 1440 px, schon aufgerichtet, ohne Gain-Map).
  Uri vorschauUri(String id) =>
      _uri('/assets/$id/thumbnail', {'size': 'preview'});

  Future<Uint8List> vorschau(String id) async =>
      _ok(await _warten(_http.get(vorschauUri(id), headers: kopf), _kurz))
          .bodyBytes;

  Future<Uint8List> original(String id) async => _ok(
    await _warten(
      _http.get(_uri('/assets/$id/original'), headers: kopf),
      _lang,
    ),
  ).bodyBytes;

  /// Lädt ein neues Asset hoch und gibt seine ID zurück.
  Future<String> hochladen(
    Uint8List bytes,
    String dateiname,
    String aufgenommen,
  ) async {
    final req = http.MultipartRequest('POST', _uri('/assets'))
      ..headers.addAll(kopf)
      ..fields['fileCreatedAt'] = aufgenommen
      ..fields['fileModifiedAt'] = DateTime.now().toUtc().toIso8601String()
      ..files.add(
        http.MultipartFile.fromBytes('assetData', bytes, filename: dateiname),
      );
    return _json(
      await _warten(_http.send(req).then(http.Response.fromStream), _lang),
    )['id'];
  }

  /// Stapelt die Assets; das erste liegt vorn.
  Future<void> stapeln(List<String> ids) async => _ok(
    await _warten(
      _http.post(
        _uri('/stacks'),
        headers: {...kopf, 'Content-Type': 'application/json'},
        body: jsonEncode({'assetIds': ids}),
      ),
      _kurz,
    ),
  );

  Future<List<String>> albenVon(String id) async {
    final r = await _warten(
      _http.get(_uri('/albums', {'assetId': id}), headers: kopf),
      _kurz,
    );
    return [for (final a in jsonDecode(_ok(r).body) as List) a['id'] as String];
  }

  Future<void> insAlbum(String album, List<String> ids) async => _ok(
    await _warten(
      _http.put(
        _uri('/albums/$album/assets'),
        headers: {...kopf, 'Content-Type': 'application/json'},
        body: jsonEncode({'ids': ids}),
      ),
      _kurz,
    ),
  );

  /// Wartet höchstens [grenze]; Netzfehler werden zu einer verständlichen Meldung.
  static Future<http.Response> _warten(
    Future<http.Response> anfrage,
    Duration grenze,
  ) async {
    try {
      return await anfrage.timeout(grenze);
    } on TimeoutException {
      throw const ServerFehler(
        'Der Server antwortet nicht (Zeitüberschreitung).',
      );
    } on SocketException catch (e) {
      throw ServerFehler('Server nicht erreichbar: ${e.message}');
    } on http.ClientException catch (e) {
      throw ServerFehler('Verbindung abgebrochen: ${e.message}');
    }
  }

  static http.Response _ok(http.Response r) {
    if (r.statusCode == 401) {
      throw const ServerFehler('Anmeldung abgelaufen — bitte neu anmelden.');
    }
    if (r.statusCode >= 300) {
      throw ServerFehler(
        'Immich ${r.request?.url.path}: ${r.statusCode} ${r.body}',
      );
    }
    return r;
  }

  static dynamic _json(http.Response r) => jsonDecode(_ok(r).body);
}

/// Ein Fehler, den man dem Nutzer so zeigen kann.
class ServerFehler implements Exception {
  const ServerFehler(this.text);

  final String text;

  @override
  String toString() => text;
}
