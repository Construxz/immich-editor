import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

/// Ein Regler im Bereich „Anpassen": JSON-Schlüssel (wie im Renderer), Name, Symbol.
typedef Werkzeug = ({String schluessel, String name, IconData symbol});

/// Die Regler der Stufe 1, in der Reihenfolge der Werkzeugleiste (Spec, *Bedienung*).
const werkzeuge = <Werkzeug>[
  (schluessel: 'brightness', name: 'Helligkeit', symbol: Icons.brightness_6),
  (schluessel: 'contrast', name: 'Kontrast', symbol: Icons.contrast),
  (schluessel: 'whitePoint', name: 'Weißpunkt', symbol: Icons.circle),
  (schluessel: 'highlights', name: 'Spitzlichter', symbol: Icons.wb_sunny),
  (schluessel: 'shadows', name: 'Schatten', symbol: Icons.nights_stay),
  (
    schluessel: 'blackPoint',
    name: 'Schwarzpunkt',
    symbol: Icons.circle_outlined,
  ),
  (schluessel: 'saturation', name: 'Sättigung', symbol: Icons.water_drop),
  (schluessel: 'warmth', name: 'Wärme', symbol: Icons.thermostat),
  (schluessel: 'tint', name: 'Färbung', symbol: Icons.colorize),
  (schluessel: 'blueTones', name: 'Blautöne', symbol: Icons.water),
  (schluessel: 'vignette', name: 'Vignette', symbol: Icons.vignette),
  (schluessel: 'sharpness', name: 'Schärfe', symbol: Icons.details),
];

/// Die Einstellungen einer Bearbeitung. Wird als JSON im XMP der Kopie
/// gespeichert und an den nativen Renderer gegeben; ab dem ersten Release lesen
/// spätere Fassungen ältere.
@immutable
class Rezept {
  const Rezept({
    this.regler = const {},
    this.viertel = 0,
    this.spiegeln = false,
    this.winkel = 0,
    this.zuschnitt = const [0, 0, 1, 1],
  });

  /// Werte der [werkzeuge], je −1 … 1; fehlend = 0 = unverändert.
  final Map<String, double> regler;

  /// Vierteldrehungen im Uhrzeigersinn, 0 … 3.
  final int viertel;

  /// Waagerecht spiegeln, so wie man das gedrehte Bild sieht.
  final bool spiegeln;

  /// Geraderichten in Grad, −45 … 45; der Renderer zoomt, damit keine Ecken leer bleiben.
  final double winkel;

  /// x, y, Breite, Höhe; 0 … 1 im gedrehten Rahmen.
  final List<double> zuschnitt;

  double wert(String schluessel) => regler[schluessel] ?? 0;

  bool get geometrieNeutral =>
      viertel == 0 &&
      !spiegeln &&
      winkel == 0 &&
      zuschnitt.join(',') == '0.0,0.0,1.0,1.0';

  bool get istNeutral => geometrieNeutral && regler.values.every((v) => v == 0);

  Rezept mitWert(String schluessel, double wert) =>
      kopie(regler: {...regler, schluessel: wert});

  Rezept kopie({
    Map<String, double>? regler,
    int? viertel,
    bool? spiegeln,
    double? winkel,
    List<double>? zuschnitt,
  }) => Rezept(
    regler: regler ?? this.regler,
    viertel: viertel ?? this.viertel,
    spiegeln: spiegeln ?? this.spiegeln,
    winkel: winkel ?? this.winkel,
    zuschnitt: zuschnitt ?? this.zuschnitt,
  );

  /// Liest ein Rezept, wie [toJson] es schreibt; Unbekanntes wird übergangen.
  factory Rezept.fromJson(Map<String, dynamic> j) {
    final g = j['geometry'] as Map<String, dynamic>?;
    return Rezept(
      regler: {
        for (final w in werkzeuge)
          if (j[w.schluessel] is num)
            w.schluessel: (j[w.schluessel] as num).toDouble(),
      },
      viertel: (g?['quarterTurns'] as num?)?.toInt() ?? 0,
      spiegeln: g?['flip'] == true,
      winkel: (g?['angle'] as num?)?.toDouble() ?? 0,
      zuschnitt: [
        for (final z in (g?['crop'] as List?) ?? const [0, 0, 1, 1])
          (z as num).toDouble(),
      ],
    );
  }

  /// Gleich im Sinn des Rezepts (was gespeichert würde).
  bool gleich(Rezept o) => jsonEncode(toJson()) == jsonEncode(o.toJson());

  Map<String, Object> toJson() => {
    'v': 1,
    for (final MapEntry(:key, :value) in regler.entries)
      if (value != 0) key: value,
    if (!geometrieNeutral)
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
