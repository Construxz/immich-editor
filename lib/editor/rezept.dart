import 'dart:ui';

/// Die Einstellungen einer Bearbeitung. Wird als JSON im XMP der Kopie
/// gespeichert; ab dem ersten Release lesen spätere Fassungen ältere.
class Rezept {
  const Rezept({this.helligkeit = 0});

  /// −1 … 1; 0 lässt das Bild unverändert.
  final double helligkeit;

  /// Derselbe Filter für Vorschau und Export — es gibt nur einen Renderer.
  ColorFilter get filter {
    final o = helligkeit * 128;
    return ColorFilter.matrix([
      1, 0, 0, 0, o, //
      0, 1, 0, 0, o, //
      0, 0, 1, 0, o, //
      0, 0, 0, 1, 0, //
    ]);
  }

  Map<String, Object> toJson() => {'v': 1, 'brightness': helligkeit};
}
