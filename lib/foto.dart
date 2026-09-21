/// Ein Foto, wie Galerie und Editor es sehen — unabhängig vom Backend.
class Foto {
  const Foto({
    required this.id,
    required this.dateiname,
    required this.aufgenommen,
    required this.pruefsumme,
    this.stapelVorn,
  });

  final String id;
  final String dateiname;

  /// Aufnahmezeit im ISO-8601-Format des Servers, unverändert weitergereicht.
  final String aufgenommen;

  /// SHA-1 des Originals, Base64.
  final String pruefsumme;

  /// Was vorn im Stapel liegt, wenn das Foto gestapelt ist.
  final String? stapelVorn;
}

/// Ein Eintrag der Galerie, so knapp, wie die Timeline ihn liefert.
typedef Kachel = ({String id, double seitenverhaeltnis, int stapel});

/// Ein Monat der Galerie: Beginn (ISO-Datum) und Anzahl der Einträge.
typedef Monat = ({String beginn, int anzahl});
