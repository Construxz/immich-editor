import 'package:photo_manager/photo_manager.dart';

import '../server/immich.dart';
import 'geraet.dart';
import 'pruefsummen.dart';

/// Was auf dem Gerät schon gesichert ist (D-36): [nurGeraet] liegt nur hier (neueste zuerst),
/// [geraetGesichert] sind Gerätefotos mit Gegenstück auf dem Server, [serverAufGeraet] die
/// Server-Fotos, die auch hier liegen.
typedef Abgleich = ({
  List<AssetEntity> nurGeraet,
  Set<String> geraetGesichert,
  Set<String> serverAufGeraet,
});

const Abgleich leererAbgleich = (
  nurGeraet: [],
  geraetGesichert: {},
  serverAufGeraet: {},
);

/// Ob Immich den Geräteordner [ordner] (`relative_path`, etwa „DCIM/Camera/") sichert — geraten:
/// ja, sobald eines seiner Fotos auf dem Server liegt (D-36).
Future<bool> ordnerGesichert(Immich immich, String ordner) async {
  final ids = await geraetIdsIn(ordner);
  final summen = await geraetPruefsummen();
  final da = await immich.vorhanden({
    for (final id in ids)
      if (summen[id] != null) id: summen[id]!,
  });
  return da.isNotEmpty;
}

/// Gleicht die Gerätefotos über ihre Prüfsummen mit dem Server ab; [fortschritt] meldet das
/// Rechnen neuer Prüfsummen. Ohne Berechtigung für Gerätefotos: leer.
Future<Abgleich> abgleich(
  Immich immich, {
  void Function(int fertig, int gesamt)? fortschritt,
}) async {
  if (!await geraetErlaubt()) return leererAbgleich;
  final summen = await geraetPruefsummen(fortschritt: fortschritt);
  final da = await immich.vorhanden(summen); // Geräte-ID → Server-ID
  final anzahl = await geraetAnzahl();
  final alle = anzahl == 0 ? <AssetEntity>[] : await geraetFotos(0, anzahl);
  return (
    nurGeraet: [
      for (final a in alle)
        if (!da.containsKey(a.id)) a,
    ],
    geraetGesichert: da.keys.toSet(),
    serverAufGeraet: da.values.toSet(),
  );
}
