/// Ein Foto, wie Galerie und Editor es sehen — unabhängig vom Backend.
class Foto {
  const Foto({
    required this.id,
    required this.dateiname,
    required this.aufgenommen,
    required this.pruefsumme,
    this.stapelVorn,
    this.ordner,
    this.angelegt,
    this.ortszeit,
  });

  final String id;
  final String dateiname;

  /// Aufnahmezeit im ISO-8601-Format des Servers, unverändert weitergereicht.
  final String aufgenommen;

  /// SHA-1 des Originals, Base64.
  final String pruefsumme;

  /// Was vorn im Stapel liegt, wenn das Foto gestapelt ist.
  final String? stapelVorn;

  /// Ordner in der Gerätegalerie, wenn das Foto auf dem Gerät liegt; sonst null (Server).
  final String? ordner;

  /// Wann das Asset auf dem Server entstand (ISO 8601) — ordnet Kopien im Stapel.
  final String? angelegt;

  /// Aufnahmezeit als Uhrzeit vor Ort.
  final DateTime? ortszeit;
}

/// Ein Stapel auf dem Server: [id] (null ohne Stapel), das vordere Foto, alle Mitglieder.
typedef Stapel = ({String? id, String vorn, List<Foto> fotos});

/// Ein Foto in Galerie und Betrachter: auf dem Gerät ([geraet]) oder auf dem Server.
typedef Eintrag = ({String id, bool geraet});

/// Was der Betrachter beim Hochwischen zeigt; was fehlt, bleibt null.
typedef FotoInfo = ({
  String name,
  DateTime? aufgenommen,
  String? ort,
  String? kamera,
  String? objektiv,
  String? belichtung,
  int? breite,
  int? hoehe,
  int? bytes,
});

/// „Google Pixel 7 Pro" statt „Google Google Pixel 7 Pro".
String? kameraAus(String? hersteller, String? modell) {
  if (modell == null) return hersteller;
  if (hersteller == null || modell.startsWith(hersteller)) return modell;
  return '$hersteller $modell';
}

/// „f/1,9 · 1/120 s · ISO 50 · 6,8 mm" — nur, was bekannt ist.
String? belichtungAus({num? blende, num? sekunden, num? iso, num? brennweite}) {
  String zahl(num x) =>
      (x == x.roundToDouble() ? x.round().toString() : x.toStringAsFixed(1))
          .replaceAll('.', ',');
  final teile = [
    if (blende != null && blende > 0) 'f/${zahl(blende)}',
    if (sekunden != null && sekunden > 0)
      sekunden < 1 ? '1/${(1 / sekunden).round()} s' : '${zahl(sekunden)} s',
    if (iso != null && iso > 0) 'ISO ${iso.round()}',
    if (brennweite != null && brennweite > 0) '${zahl(brennweite)} mm',
  ];
  return teile.isEmpty ? null : teile.join(' · ');
}

/// Der angemeldete Nutzer: [farbe] ist Immichs Avatarfarbe, [hatBild] ein eigenes Profilbild.
typedef Konto = ({
  String id,
  String name,
  String email,
  bool hatBild,
  String farbe,
});

/// Ein Eintrag der Galerie, so knapp, wie die Timeline ihn liefert.
typedef Kachel = ({String id, double seitenverhaeltnis, int stapel});

/// Ein Monat der Galerie: Beginn (ISO-Datum) und Anzahl der Einträge.
typedef Monat = ({String beginn, int anzahl});
