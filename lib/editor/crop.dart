import 'dart:math';

import 'package:flutter/material.dart';

/// Crop frame over the preview, which in this mode shows the whole (rotated) image:
/// drag corners and edges, move from inside. Values 0 … 1 in the frame, as in the recipe.
class CropFrame extends StatefulWidget {
  const CropFrame({
    super.key,
    required this.aspectRatio,
    required this.crop,
    required this.onChanged,
    this.ratio,
    this.onEnd,
  });

  /// Width/height of the rotated image (as the renderer fits it).
  final double aspectRatio;
  final List<double> crop;

  /// Fixed aspect ratio of the crop (width/height), `null` = free.
  final double? ratio;
  final ValueChanged<List<double>> onChanged;
  final VoidCallback? onEnd;

  @override
  State<CropFrame> createState() => _CropFrameState();
}

class _CropFrameState extends State<CropFrame> {
  static const _handle = 36.0; // hit area around corners and edges
  static const _minimum = 0.08;

  // which sides the drag moves: left, top, right, bottom; all = move
  var _sides = (l: false, t: false, r: false, b: false);
  var _dragging = false;
  var _c = <double>[0, 0, 1, 1]; // running crop while dragging

  Rect _image(Size s) {
    final a = widget.aspectRatio;
    final w = s.width / s.height > a ? s.height * a : s.width;
    final h = w / a;
    return Rect.fromLTWH((s.width - w) / 2, (s.height - h) / 2, w, h);
  }

  Rect _frame(Rect image) {
    final c = widget.crop;
    return Rect.fromLTWH(
      image.left + c[0] * image.width,
      image.top + c[1] * image.height,
      c[2] * image.width,
      c[3] * image.height,
    );
  }

  void _start(Offset p, Rect r) {
    bool near(double a, double b) => (a - b).abs() < _handle;
    final inside = r.inflate(_handle).contains(p);
    var l = inside && near(p.dx, r.left), rr = inside && near(p.dx, r.right);
    var t = inside && near(p.dy, r.top), b = inside && near(p.dy, r.bottom);
    if (widget.ratio != null && (l || rr) != (t || b)) {
      l = rr = t = b = false; // with a fixed ratio only corners
    }
    _sides = (l || t || rr || b)
        ? (l: l, t: t, r: rr, b: b)
        : (l: true, t: true, r: true, b: true);
    _c = [...widget.crop];
    setState(() => _dragging = true);
  }

  void _drag(Offset d, Rect image) {
    var [x, y, w, h] = _c;
    final dx = d.dx / image.width, dy = d.dy / image.height;
    final s = _sides;
    if (s.l && s.t && s.r && s.b) {
      x = (x + dx).clamp(0, 1 - w).toDouble();
      y = (y + dy).clamp(0, 1 - h).toDouble();
    } else {
      var r = x + w, b = y + h;
      if (s.l) x = (x + dx).clamp(0, r - _minimum).toDouble();
      if (s.r) r = (r + dx).clamp(x + _minimum, 1).toDouble();
      if (s.t) y = (y + dy).clamp(0, b - _minimum).toDouble();
      if (s.b) b = (b + dy).clamp(y + _minimum, 1).toDouble();
      w = r - x;
      h = b - y;
      final v = widget.ratio;
      if (v != null) {
        // height follows width; if it does not fit, width follows height
        final hNew = w * image.width / v / image.height;
        final room = s.t ? b : 1 - y;
        if (hNew <= room) {
          if (s.t) y = b - hNew;
          h = hNew;
        } else {
          h = room;
          if (s.t) y = b - h;
          final wNew = h * image.height * v / image.width;
          if (s.l) x = x + w - wNew;
          w = wNew;
        }
      }
    }
    _c = [x, y, w, h];
    widget.onChanged(_c);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final image = _image(c.biggest);
      final r = _frame(image);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _start(d.localPosition, r),
        onPanUpdate: (d) => _drag(d.delta, image),
        onPanEnd: (_) {
          setState(() => _dragging = false);
          widget.onEnd?.call();
        },
        child: CustomPaint(
          size: c.biggest,
          painter: _FramePainter(r, grid: _dragging),
        ),
      );
    },
  );
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.r, {required this.grid});

  final Rect r;
  final bool grid;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRect(r)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(outside, Paint()..color = Colors.black54);
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(r, line);
    if (grid) {
      line.color = Colors.white54;
      for (final t in [1 / 3, 2 / 3]) {
        canvas.drawLine(
          Offset(r.left + r.width * t, r.top),
          Offset(r.left + r.width * t, r.bottom),
          line,
        );
        canvas.drawLine(
          Offset(r.left, r.top + r.height * t),
          Offset(r.right, r.top + r.height * t),
          line,
        );
      }
    }
    final corner = Paint()
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
      canvas.drawLine(p, p + Offset(l * sx, 0), corner);
      canvas.drawLine(p, p + Offset(0, l * sy), corner);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.r != r || old.grid != grid;
}
