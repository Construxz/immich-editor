import 'dart:convert';

import '../foto.dart';
import '../gallery/geraet.dart' show geraetPapierkorb;
import '../main.dart' show speicher;
import '../server/immich.dart';

/// Stapelt die Kopie [kopie] vor das [original] und legt sie in dessen Alben. Die bisher vordere
/// kommt mit in die Liste: Nur dann führt Immich ihren Stapel mit dem neuen zusammen, sonst
/// stünden frühere Kopien allein (D-23, D-31). Die ersetzte [alteKopie] geht in den Papierkorb.
Future<void> vorOriginal(
  Immich immich,
  String kopie,
  Foto original, {
  String? alteKopie,
}) async {
  final vorn = original.stapelVorn;
  await immich.stapeln([
    kopie,
    original.id,
    if (vorn != null && vorn != original.id) vorn,
  ]);
  for (final album in await immich.albenVon(original.id)) {
    await immich.insAlbum(album, [kopie]);
  }
  if (alteKopie != null) await immich.papierkorb([alteKopie]);
}

/// Eine Kopie, die auf dem Gerät entstand und gestapelt wird, sobald die Immich-App sie und das
/// Original gesichert hat (D-24). Prüfsummen SHA-1, Base64. Mit [entfernen] (ID auf dem Gerät)
/// verlässt die Kopie danach das Gerät — das Original lag nur auf dem Server (D-25).
typedef Vorgemerkt = ({
  String kopie,
  String original,
  String? alt,
  String? entfernen,
});

/// Merkt [neu] vor; eine noch wartende Kopie, die [neu] ersetzt, fällt heraus — sonst läge sie
/// womöglich nachher vorn.
List<Vorgemerkt> vormerkenIn(List<Vorgemerkt> liste, Vorgemerkt neu) => [
  for (final v in liste)
    if (v.kopie != neu.alt) v,
  neu,
];

const _schluessel = 'stapeln';

Future<List<Vorgemerkt>> _lesen() async => [
  for (final v in jsonDecode(await speicher.read(key: _schluessel) ?? '[]'))
    (
      kopie: v['kopie'],
      original: v['original'],
      alt: v['alt'],
      entfernen: v['entfernen'],
    ),
];

Future<void> _schreiben(List<Vorgemerkt> liste) => speicher.write(
  key: _schluessel,
  value: jsonEncode([
    for (final v in liste)
      {
        'kopie': v.kopie,
        'original': v.original,
        'alt': v.alt,
        'entfernen': v.entfernen,
      },
  ]),
);

/// Wie viele Kopien noch auf das Backup warten.
Future<int> wartendeStapel() async => (await _lesen()).length;

Future<void> vormerken(Vorgemerkt neu) async =>
    _schreiben(vormerkenIn(await _lesen(), neu));

Future<void>? _laeuft;

/// Stapelt, was vorgemerkt ist und inzwischen auf dem Server liegt. Läuft höchstens einmal
/// gleichzeitig.
Future<void> ausstehendeStapeln(Immich immich) =>
    _laeuft ??= _stapeln(immich).whenComplete(() => _laeuft = null);

Future<void> _stapeln(Immich immich) async {
  final erledigt = <Vorgemerkt>{};
  final liste = await _lesen();
  if (liste.isEmpty) return;
  // Eine Anfrage für alle: welche Prüfsummen kennt der Server (auch archiviert, D-36)?
  final da = await immich.vorhanden({
    for (final v in liste)
      for (final summe in [v.kopie, v.original, ?v.alt]) summe: summe,
  });
  for (final v in liste) {
    final kopie = da[v.kopie];
    final original = da[v.original];
    if (kopie == null || original == null) continue;
    final alt = da[v.alt];
    await vorOriginal(
      immich,
      kopie,
      await immich.foto(original),
      alteKopie: alt,
    );
    erledigt.add(v);
  }
  // Neu lesen: Während wir stapelten, kann der Editor etwas vorgemerkt haben.
  await _schreiben([
    for (final v in await _lesen())
      if (!erledigt.contains(v)) v,
  ]);
  await geraetPapierkorb([for (final v in erledigt) ?v.entfernen]);
}
