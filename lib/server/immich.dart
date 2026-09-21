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
  Future<int> hauptversion() async =>
      _json(
            await _warten(
              http.get(_uri('/server/version'), headers: kopf),
              _kurz,
            ),
          )['major']
          as int;

  Future<List<Foto>> fotos() async {
    final r = await _warten(
      http.post(
        _uri('/search/metadata'),
        headers: {...kopf, 'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'IMAGE', 'order': 'desc', 'size': 200}),
      ),
      _kurz,
    );
    final items = _json(r)['assets']['items'] as List;
    return [
      for (final a in items)
        Foto(
          id: a['id'],
          dateiname: a['originalFileName'],
          aufgenommen: a['fileCreatedAt'],
          pruefsumme: a['checksum'],
        ),
    ];
  }

  Uri miniatur(String id) => _uri('/assets/$id/thumbnail');

  Future<Uint8List> original(String id) async => _ok(
    await _warten(http.get(_uri('/assets/$id/original'), headers: kopf), _lang),
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
      await _warten(req.send().then(http.Response.fromStream), _lang),
    )['id'];
  }

  /// Stapelt die Assets; das erste liegt vorn.
  Future<void> stapeln(List<String> ids) async => _ok(
    await _warten(
      http.post(
        _uri('/stacks'),
        headers: {...kopf, 'Content-Type': 'application/json'},
        body: jsonEncode({'assetIds': ids}),
      ),
      _kurz,
    ),
  );

  Future<List<String>> albenVon(String id) async {
    final r = await _warten(
      http.get(_uri('/albums', {'assetId': id}), headers: kopf),
      _kurz,
    );
    return [for (final a in jsonDecode(_ok(r).body) as List) a['id'] as String];
  }

  Future<void> insAlbum(String album, List<String> ids) async => _ok(
    await _warten(
      http.put(
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
