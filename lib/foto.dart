/// Ein Foto, wie Galerie und Editor es sehen — unabhängig vom Backend.
class Foto {
  const Foto({
    required this.id,
    required this.dateiname,
    required this.aufgenommen,
    required this.pruefsumme,
  });

  final String id;
  final String dateiname;

  /// Aufnahmezeit im ISO-8601-Format des Servers, unverändert weitergereicht.
  final String aufgenommen;

  /// SHA-1 des Originals, Base64.
  final String pruefsumme;
}
