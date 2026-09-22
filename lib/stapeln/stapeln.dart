import 'dart:convert';

import '../export/jpeg.dart' show rezeptAus;
import '../foto.dart';
import '../gallery/geraet.dart' show geraetPapierkorb;
import '../main.dart' show speicher;
import '../server/immich.dart';

/// Stapelt die Kopie [kopie] vor das [original], legt sie in dessen Alben und schiebt frühere
/// Kopien in den Papierkorb: [alteKopie] und die bisher vordere, wenn sie von dieser App ist —
/// Immich löst den alten Stapel auf, sie stünden sonst allein (D-23).
Future<void> vorOriginal(
  Immich immich,
  String kopie,
  Foto original, {
  String? alteKopie,
}) async {
  await immich.stapeln([kopie, original.id]);
  for (final album in await immich.albenVon(original.id)) {
    await immich.insAlbum(album, [kopie]);
  }
  final weg = {?alteKopie};
  final vorn = original.stapelVorn;
  if (vorn != null &&
      vorn != original.id &&
      !weg.contains(vorn) &&
      rezeptAus(await immich.anfang(vorn)) != null) {
    weg.add(vorn);
  }
  if (weg.isNotEmpty) await immich.papierkorb(weg.toList());
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

Future<void> vormerken(Vorgemerkt neu) async =>
    _schreiben(vormerkenIn(await _lesen(), neu));

Future<void>? _laeuft;

/// Stapelt, was vorgemerkt ist und inzwischen auf dem Server liegt. Läuft höchstens einmal
/// gleichzeitig.
Future<void> ausstehendeStapeln(Immich immich) =>
    _laeuft ??= _stapeln(immich).whenComplete(() => _laeuft = null);

Future<void> _stapeln(Immich immich) async {
  final erledigt = <Vorgemerkt>{};
  for (final v in await _lesen()) {
    final kopie = await immich.perPruefsumme(v.kopie);
    final original = await immich.perPruefsumme(v.original);
    if (kopie == null || original == null) continue;
    final alt = v.alt == null ? null : await immich.perPruefsumme(v.alt!);
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
