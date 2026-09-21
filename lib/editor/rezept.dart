import 'dart:math';

/// Die Einstellungen einer Bearbeitung. Wird als JSON im XMP der Kopie
/// gespeichert und an den nativen Renderer gegeben; ab dem ersten Release lesen
/// spätere Fassungen ältere.
class Rezept {
  const Rezept({
    this.helligkeit = 0,
    this.viertel = 0,
    this.spiegeln = false,
    this.winkel = 0,
    this.zuschnitt = const [0, 0, 1, 1],
  });

  /// −1 … 1; 0 lässt das Bild unverändert.
  final double helligkeit;

  /// Vierteldrehungen im Uhrzeigersinn, 0 … 3.
  final int viertel;

  /// Waagerecht spiegeln, so wie man das gedrehte Bild sieht.
  final bool spiegeln;

  /// Geraderichten in Grad, −45 … 45; der Renderer zoomt, damit keine Ecken leer bleiben.
  final double winkel;

  /// x, y, Breite, Höhe; 0 … 1 im gedrehten Rahmen.
  final List<double> zuschnitt;

  bool get _geometrieNeutral =>
      viertel == 0 &&
      !spiegeln &&
      winkel == 0 &&
      zuschnitt.join(',') == '0.0,0.0,1.0,1.0';

  bool get istNeutral => helligkeit == 0 && _geometrieNeutral;

  Rezept kopie({
    double? helligkeit,
    int? viertel,
    bool? spiegeln,
    double? winkel,
    List<double>? zuschnitt,
  }) => Rezept(
    helligkeit: helligkeit ?? this.helligkeit,
    viertel: viertel ?? this.viertel,
    spiegeln: spiegeln ?? this.spiegeln,
    winkel: winkel ?? this.winkel,
    zuschnitt: zuschnitt ?? this.zuschnitt,
  );

  Map<String, Object> toJson() => {
    'v': 1,
    'brightness': helligkeit,
    if (!_geometrieNeutral)
      'geometry': {
        'quarterTurns': viertel,
        'flip': spiegeln,
        'angle': winkel,
        'crop': zuschnitt,
      },
  };
}

/// Größter mittiger Zuschnitt mit Seitenverhältnis [verhaeltnis] (Breite/Höhe) in einem
/// Rahmen [breite]×[hoehe]; `null` heißt frei (ganzer Rahmen).
List<double> zuschnittFuer(double? verhaeltnis, double breite, double hoehe) {
  if (verhaeltnis == null) return const [0, 0, 1, 1];
  final w = min(1.0, verhaeltnis * hoehe / breite);
  final h = min(1.0, breite / (verhaeltnis * hoehe));
  return [(1 - w) / 2, (1 - h) / 2, w, h];
}
