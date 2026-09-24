import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Snaps a raw value to the displayed [step] and — within [snapRange] displayed units
/// around 0 — to 0. So what shows as 0 is 0 (no "changed" dot).
double snap(
  double raw, {
  required double scale,
  required double step,
  required double snapRange,
}) {
  final shown = (raw * scale / step).round() * step;
  return shown.abs() <= snapRange ? 0 : shown / scale;
}

/// Scale ruler as in Google Photos: the ticks move under a fixed center,
/// the value sits above. Zero is magnetic; double tap resets to 0.
class Ruler extends StatefulWidget {
  const Ruler({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onEnd,
    this.scale = 100,
    this.unit = '',
    this.tick = 5,
    this.step = 1,
    this.snapRange = 2,
    this.pill = false,
    this.onReset,
    this.resetLabel,
  });

  /// As in Google Photos (D-72): a pill with the value on the left, the ticks from zero to the
  /// value filled amber, every 50 longer, a reset button on the right ([onReset]).
  final bool pill;
  final VoidCallback? onReset;
  final String? resetLabel;

  final double value, min, max;
  final ValueChanged<double> onChanged;

  /// After release — e.g. for undo.
  final VoidCallback? onEnd;

  /// Displayed value = [value] × [scale] (adjustments −100 … 100, angle in degrees with 1).
  final double scale;
  final String unit;

  /// Displayed units per tick.
  final double tick;

  /// Finest displayed step (adjustments 1, angle 0.1°) and snap range of zero.
  final double step, snapRange;

  static const _pixelsPerTick = 10.0;

  double get _pixelsPerValue => _pixelsPerTick / tick * scale;

  @override
  State<Ruler> createState() => _RulerState();
}

class _RulerState extends State<Ruler> {
  // While dragging, our own value counts: with several moves in the same frame, motion
  // would otherwise be lost, since each computed from the old widget.value.
  var _raw = 0.0;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _raw = w.value,
      onHorizontalDragUpdate: (d) {
        _raw = (_raw - d.delta.dx / w._pixelsPerValue)
            .clamp(w.min, w.max)
            .toDouble();
        final next = snap(
          _raw,
          scale: w.scale,
          step: w.step,
          snapRange: w.snapRange,
        );
        if (next == 0 && w.value != 0) HapticFeedback.selectionClick();
        if (next != w.value) w.onChanged(next);
      },
      onHorizontalDragEnd: (_) => w.onEnd?.call(),
      onDoubleTap: () {
        w.onChanged(0);
        w.onEnd?.call();
      },
      child: w.pill
          ? _pill(colors)
          : SizedBox(
              height: 64,
              child: Column(
                children: [
                  Text(
                    _shown,
                    style: TextStyle(color: colors.primary, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _Ticks(
                        offset: w.value * w._pixelsPerValue,
                        from: w.min * w._pixelsPerValue,
                        to: w.max * w._pixelsPerValue,
                        color: colors.onSurface,
                        center: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Ticks extends CustomPainter {
  _Ticks({
    required this.offset,
    required this.from,
    required this.to,
    required this.color,
    required this.center,
    this.filled = false,
    this.longEvery = 5,
  });

  final double offset, from, to;
  final Color color, center;

  /// Ticks between zero and the value amber (D-72); every [longEvery]th tick long.
  final bool filled;
  final int longEvery;

  /// The zero point, conspicuous and unlike the center: you see where it snaps.
  static const _zero = Color(0xFFFFB300);

  @override
  void paint(Canvas canvas, Size size) {
    final m = size.width / 2;
    // Center first: when the value is 0, the zero lies on top and colors it.
    canvas.drawLine(
      Offset(m, 0),
      Offset(m, size.height),
      Paint()
        ..color = center
        ..strokeWidth = 2.5,
    );
    final pen = Paint()..strokeWidth = 1.5;
    for (var x = from; x <= to + 0.01; x += Ruler._pixelsPerTick) {
      final px = m + x - offset;
      if (px < 0 || px > size.width) continue;
      if (x.abs() < 0.01) {
        final zero = Paint()
          ..color = _zero
          ..strokeWidth = 3;
        canvas
          ..drawLine(
            Offset(px, size.height * 0.08),
            Offset(px, size.height),
            zero,
          )
          ..drawCircle(Offset(px, size.height * 0.08), 3, zero);
        continue;
      }
      final long = (x / Ruler._pixelsPerTick).round() % longEvery == 0;
      final reached =
          filled &&
          (offset >= 0
              ? x > 0 && x <= offset + 0.01
              : x < 0 && x >= offset - 0.01);
      pen.color = reached ? _zero : color.withValues(alpha: long ? 0.7 : 0.35);
      final h = long ? size.height * 0.7 : size.height * 0.4;
      canvas.drawLine(
        Offset(px, (size.height - h) / 2),
        Offset(px, (size.height + h) / 2),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(_Ticks old) => old.offset != offset || old.color != color;
}

extension on _RulerState {
  String get _shown =>
      '${(widget.value * widget.scale).toStringAsFixed(widget.step < 1 ? 1 : 0)}${widget.unit}';

  Widget _pill(ColorScheme colors) {
    final w = widget;
    return Container(
      height: 52,
      padding: const EdgeInsets.only(left: 20, right: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              _shown,
              style: TextStyle(
                color: w.value == 0 ? colors.onSurface : _Ticks._zero,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _Ticks(
                offset: w.value * w._pixelsPerValue,
                from: w.min * w._pixelsPerValue,
                to: w.max * w._pixelsPerValue,
                color: colors.onSurface,
                center: _Ticks._zero,
                filled: true,
                longEvery: 10,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: w.resetLabel,
            onPressed: w.value == 0 ? null : w.onReset,
          ),
        ],
      ),
    );
  }
}
