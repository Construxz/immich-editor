import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Rastet einen Rohwert auf die angezeigte [stufe] und — innerhalb von [fang] angezeigten
/// Einheiten um 0 — auf 0 ein. So ist, was als 0 dasteht, auch 0 (kein „verändert"-Punkt).
double rasten(
  double roh, {
  required double anzeige,
  required double stufe,
  required double fang,
}) {
  final angezeigt = (roh * anzeige / stufe).round() * stufe;
  return angezeigt.abs() <= fang ? 0 : angezeigt / anzeige;
}

/// Skalen-Lineal wie bei Google Fotos: Die Striche wandern unter einer festen Mitte,
/// der Wert steht darüber. Die Null ist magnetisch; Doppeltippen setzt auf 0 zurück.
class Lineal extends StatefulWidget {
  const Lineal({
    super.key,
    required this.wert,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onEnde,
    this.anzeige = 100,
    this.einheit = '',
    this.strich = 5,
    this.stufe = 1,
    this.fang = 2,
  });

  final double wert, min, max;
  final ValueChanged<double> onChanged;

  /// Nach dem Loslassen — etwa für Rückgängig.
  final VoidCallback? onEnde;

  /// Angezeigter Wert = [wert] × [anzeige] (Regler −100 … 100, Winkel in Grad mit 1).
  final double anzeige;
  final String einheit;

  /// Angezeigte Einheiten je Strich.
  final double strich;

  /// Feinste angezeigte Stufe (Regler 1, Winkel 0,1°) und Fangbereich der Null.
  final double stufe, fang;

  static const _pixelProStrich = 10.0;

  double get _pixelProWert => _pixelProStrich / strich * anzeige;

  @override
  State<Lineal> createState() => _LinealState();
}

class _LinealState extends State<Lineal> {
  // Während des Ziehens zählt der eigene Wert: kommen mehrere Züge im selben Frame, ginge
  // sonst Bewegung verloren, weil jeder vom alten widget.wert aus rechnete.
  var _roh = 0.0;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final farbe = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _roh = w.wert,
      onHorizontalDragUpdate: (d) {
        _roh = (_roh - d.delta.dx / w._pixelProWert)
            .clamp(w.min, w.max)
            .toDouble();
        final neu = rasten(
          _roh,
          anzeige: w.anzeige,
          stufe: w.stufe,
          fang: w.fang,
        );
        if (neu == 0 && w.wert != 0) HapticFeedback.selectionClick();
        if (neu != w.wert) w.onChanged(neu);
      },
      onHorizontalDragEnd: (_) => w.onEnde?.call(),
      onDoubleTap: () {
        w.onChanged(0);
        w.onEnde?.call();
      },
      child: SizedBox(
        height: 64,
        child: Column(
          children: [
            Text(
              '${(w.wert * w.anzeige).toStringAsFixed(w.stufe < 1 ? 1 : 0)}${w.einheit}',
              style: TextStyle(color: farbe.primary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: CustomPaint(
                size: Size.infinite,
                painter: _Striche(
                  versatz: w.wert * w._pixelProWert,
                  von: w.min * w._pixelProWert,
                  bis: w.max * w._pixelProWert,
                  farbe: farbe.onSurface,
                  mitte: farbe.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Striche extends CustomPainter {
  _Striche({
    required this.versatz,
    required this.von,
    required this.bis,
    required this.farbe,
    required this.mitte,
  });

  final double versatz, von, bis;
  final Color farbe, mitte;

  @override
  void paint(Canvas canvas, Size size) {
    final m = size.width / 2;
    final stift = Paint()..strokeWidth = 1.5;
    for (var x = von; x <= bis + 0.01; x += Lineal._pixelProStrich) {
      final px = m + x - versatz;
      if (px < 0 || px > size.width) continue;
      final lang = (x / Lineal._pixelProStrich).round() % 5 == 0;
      stift.color = farbe.withValues(
        alpha: x.abs() < 0.01 ? 1 : (lang ? 0.7 : 0.35),
      );
      final h = lang ? size.height * 0.7 : size.height * 0.4;
      canvas.drawLine(
        Offset(px, (size.height - h) / 2),
        Offset(px, (size.height + h) / 2),
        stift,
      );
    }
    canvas.drawLine(
      Offset(m, 0),
      Offset(m, size.height),
      Paint()
        ..color = mitte
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_Striche alt) =>
      alt.versatz != versatz || alt.farbe != farbe;
}
