import 'dart:math';

import 'package:flutter/material.dart';

/// Zuschnittrahmen über der Vorschau, die in diesem Modus das ganze (gedrehte) Bild zeigt:
/// Ecken und Kanten ziehen, innen verschieben. Werte 0 … 1 im Rahmen, wie im Rezept.
class ZuschnittRahmen extends StatefulWidget {
  const ZuschnittRahmen({
    super.key,
    required this.seitenverhaeltnis,
    required this.zuschnitt,
    required this.onChanged,
    this.verhaeltnis,
    this.onEnde,
  });

  /// Breite/Höhe des gedrehten Bildes (so, wie der Renderer es einpasst).
  final double seitenverhaeltnis;
  final List<double> zuschnitt;

  /// Festes Seitenverhältnis des Zuschnitts (Breite/Höhe), `null` = frei.
  final double? verhaeltnis;
  final ValueChanged<List<double>> onChanged;
  final VoidCallback? onEnde;

  @override
  State<ZuschnittRahmen> createState() => _ZuschnittRahmenState();
}

class _ZuschnittRahmenState extends State<ZuschnittRahmen> {
  static const _griff = 36.0; // Trefferbereich um Ecken und Kanten
  static const _minimal = 0.08;

  // welche Seiten der Zug bewegt: links, oben, rechts, unten; alle = verschieben
  var _seiten = (l: false, o: false, r: false, u: false);
  var _zieht = false;
  var _z = <double>[0, 0, 1, 1]; // laufender Zuschnitt während des Ziehens

  Rect _bild(Size s) {
    final a = widget.seitenverhaeltnis;
    final w = s.width / s.height > a ? s.height * a : s.width;
    final h = w / a;
    return Rect.fromLTWH((s.width - w) / 2, (s.height - h) / 2, w, h);
  }

  Rect _rahmen(Rect bild) {
    final z = widget.zuschnitt;
    return Rect.fromLTWH(
      bild.left + z[0] * bild.width,
      bild.top + z[1] * bild.height,
      z[2] * bild.width,
      z[3] * bild.height,
    );
  }

  void _start(Offset p, Rect r) {
    bool nah(double a, double b) => (a - b).abs() < _griff;
    final innen = r.inflate(_griff).contains(p);
    var l = innen && nah(p.dx, r.left), rr = innen && nah(p.dx, r.right);
    var o = innen && nah(p.dy, r.top), u = innen && nah(p.dy, r.bottom);
    if (widget.verhaeltnis != null && (l || rr) != (o || u)) {
      l = rr = o = u = false; // mit festem Verhältnis nur Ecken
    }
    _seiten = (l || o || rr || u)
        ? (l: l, o: o, r: rr, u: u)
        : (l: true, o: true, r: true, u: true);
    _z = [...widget.zuschnitt];
    setState(() => _zieht = true);
  }

  void _ziehen(Offset d, Rect bild) {
    var [x, y, w, h] = _z;
    final dx = d.dx / bild.width, dy = d.dy / bild.height;
    final s = _seiten;
    if (s.l && s.o && s.r && s.u) {
      x = (x + dx).clamp(0, 1 - w).toDouble();
      y = (y + dy).clamp(0, 1 - h).toDouble();
    } else {
      var r = x + w, b = y + h;
      if (s.l) x = (x + dx).clamp(0, r - _minimal).toDouble();
      if (s.r) r = (r + dx).clamp(x + _minimal, 1).toDouble();
      if (s.o) y = (y + dy).clamp(0, b - _minimal).toDouble();
      if (s.u) b = (b + dy).clamp(y + _minimal, 1).toDouble();
      w = r - x;
      h = b - y;
      final v = widget.verhaeltnis;
      if (v != null) {
        // Höhe folgt der Breite; passt sie nicht, folgt die Breite der Höhe
        final hNeu = w * bild.width / v / bild.height;
        final platz = s.o ? b : 1 - y;
        if (hNeu <= platz) {
          if (s.o) y = b - hNeu;
          h = hNeu;
        } else {
          h = platz;
          if (s.o) y = b - h;
          final wNeu = h * bild.height * v / bild.width;
          if (s.l) x = x + w - wNeu;
          w = wNeu;
        }
      }
    }
    _z = [x, y, w, h];
    widget.onChanged(_z);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final bild = _bild(c.biggest);
      final r = _rahmen(bild);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _start(d.localPosition, r),
        onPanUpdate: (d) => _ziehen(d.delta, bild),
        onPanEnd: (_) {
          setState(() => _zieht = false);
          widget.onEnde?.call();
        },
        child: CustomPaint(
          size: c.biggest,
          painter: _RahmenMaler(r, raster: _zieht),
        ),
      );
    },
  );
}

class _RahmenMaler extends CustomPainter {
  _RahmenMaler(this.r, {required this.raster});

  final Rect r;
  final bool raster;

  @override
  void paint(Canvas canvas, Size size) {
    final aussen = Path()
      ..addRect(Offset.zero & size)
      ..addRect(r)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(aussen, Paint()..color = Colors.black54);
    final linie = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(r, linie);
    if (raster) {
      linie.color = Colors.white54;
      for (final t in [1 / 3, 2 / 3]) {
        canvas.drawLine(
          Offset(r.left + r.width * t, r.top),
          Offset(r.left + r.width * t, r.bottom),
          linie,
        );
        canvas.drawLine(
          Offset(r.left, r.top + r.height * t),
          Offset(r.right, r.top + r.height * t),
          linie,
        );
      }
    }
    final ecke = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final l = min(22.0, min(r.width, r.height) / 3);
    for (final (p, sx, sy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(p, p + Offset(l * sx, 0), ecke);
      canvas.drawLine(p, p + Offset(0, l * sy), ecke);
    }
  }

  @override
  bool shouldRepaint(_RahmenMaler alt) => alt.r != r || alt.raster != raster;
}
