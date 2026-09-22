import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import '../editor/vorschau.dart' show sha1;
import '../foto.dart';

/// Fotos auf dem Gerät (`photo_manager`), neueste Aufnahme zuerst.
final _neuesteZuerst = CustomFilter.sql(
  where: '',
  orderBy: [OrderByItem.desc(CustomColumns.android.dateTaken)],
);

/// Mit Zugriff auf den Ort im EXIF: Nur dann liefert Android die unveränderten Bytes — sonst
/// stimmt die Prüfsumme nicht mit der des Backups überein.
Future<bool> geraetErlaubt() async =>
    (await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: true,
        ),
      ),
    )).hasAccess;

Future<int> geraetAnzahl() => PhotoManager.getAssetCount(
  filterOption: _neuesteZuerst,
  type: RequestType.image,
);

Future<List<AssetEntity>> geraetFotos(int start, int ende) =>
    PhotoManager.getAssetListRange(
      start: start,
      end: ende,
      filterOption: _neuesteZuerst,
      type: RequestType.image,
    );

/// Das Original eines Gerätefotos und was der Editor darüber wissen muss.
Future<(Foto, Uint8List)> geraetOriginal(String id) async {
  final a = await AssetEntity.fromId(id);
  final bytes = await a?.originBytes;
  if (a == null || bytes == null) {
    throw Exception('Foto nicht mehr auf dem Gerät');
  }
  final foto = Foto(
    id: a.id,
    dateiname: a.title ?? 'foto.jpg',
    aufgenommen: a.createDateTime.toUtc().toIso8601String(),
    pruefsumme: await sha1(bytes),
    ordner: a.relativePath ?? 'DCIM/Camera/',
  );
  return (foto, bytes);
}

/// Das Gerätefoto mit der Prüfsumme [sha1Wert], aufgenommen um [aufgenommen] — so findet man zu
/// einer Kopie das Original: Die Kopie trägt dessen Aufnahmezeit (s. [geraetSpeichern]).
Future<String?> geraetPerPruefsumme(String sha1Wert, String aufgenommen) async {
  final ms = DateTime.parse(aufgenommen).millisecondsSinceEpoch ~/ 1000 * 1000;
  final kandidaten = await PhotoManager.getAssetListRange(
    start: 0,
    end: 50,
    type: RequestType.image,
    filterOption: CustomFilter.sql(
      where: '${CustomColumns.android.dateTaken} BETWEEN $ms AND ${ms + 999}',
    ),
  );
  for (final a in kandidaten) {
    final bytes = await a.originBytes;
    if (bytes != null && await sha1(bytes) == sha1Wert) return a.id;
  }
  return null;
}

/// Legt die Kopie neben das [original] in die Gerätegalerie — derselbe Ordner, damit die
/// Immich-App sie mit sichert, und dieselbe Aufnahmezeit, damit sie daneben steht. Liegt das
/// Original nur auf dem Server, in den Kameraordner. Gibt die ID der Kopie zurück.
// ponytail: fester Kameraordner; wählbar machen, falls ihn jemand nicht sichern lässt.
Future<String> geraetSpeichern(Uint8List kopie, Foto original) async {
  final name = original.dateiname.replaceFirst(
    RegExp(r'(\.[^.]*)?$'),
    '.edit.jpg',
  );
  // Den Dateinamen setzt photo_manager auf Android aus title, nicht aus filename.
  final a = await PhotoManager.editor.saveImage(
    kopie,
    filename: name,
    title: name,
    relativePath: original.ordner ?? 'DCIM/Camera/',
    creationDate: DateTime.parse(original.aufgenommen),
  );
  return a.id;
}

/// In den Papierkorb des Geräts; Android fragt den Nutzer, einmal für alle.
Future<void> geraetPapierkorb(List<String> ids) async {
  final fotos = [for (final id in ids) ?await AssetEntity.fromId(id)];
  if (fotos.isNotEmpty) await PhotoManager.editor.android.moveToTrash(fotos);
}
