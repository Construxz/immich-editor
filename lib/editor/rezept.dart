/// Die Einstellungen einer Bearbeitung. Wird als JSON im XMP der Kopie
/// gespeichert und an den nativen Renderer gegeben; ab dem ersten Release lesen
/// spätere Fassungen ältere.
class Rezept {
  const Rezept({this.helligkeit = 0});

  /// −1 … 1; 0 lässt das Bild unverändert.
  final double helligkeit;

  Map<String, Object> toJson() => {'v': 1, 'brightness': helligkeit};
}
