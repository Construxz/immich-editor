import 'dart:math';

import 'package:flutter/material.dart';

/// Pinch to zoom, one finger pans while zoomed; not zoomed, a vertical swipe on the image opens
/// (up) or closes (down) the info. Wraps the pages and works on raw pointers, outside the gesture
/// arena: the pages keep every horizontal swipe, and a second finger counts for the pinch even
/// while the pages move — inside them Flutter ignores new fingers during a scroll (D-65).
class PinchZoom extends StatefulWidget {
  const PinchZoom({
    super.key,
    required this.target,
    required this.matrix,
    required this.onHold,
    required this.onSwipe,
    required this.child,
  });

  /// The current page's image area (unzoomed); positions and bounds are taken from it.
  final GlobalKey target;

  /// The zoom of that area; the page draws its image with it.
  final ValueNotifier<Matrix4> matrix;

  /// Zoomed or two fingers down: the pages must hold still.
  final ValueChanged<bool> onHold;

  /// A vertical swipe on the image without zoom: true up, false down.
  final ValueChanged<bool> onSwipe;
  final Widget child;

  @override
  State<PinchZoom> createState() => _PinchZoomState();
}

class _PinchZoomState extends State<PinchZoom> {
  static const _maxScale = 8.0;
  final _points = <int, Offset>{}; // in the image area
  var _from = Matrix4.identity(); // at the start of the current pinch
  var _fromSpan = 1.0;
  var _fromFocal = Offset.zero;
  Offset? _down; // where a one-finger gesture began, if on the image
  var _pinched = false; // two fingers took part since the first went down
  var _held = false;

  RenderBox? get _box =>
      widget.target.currentContext?.findRenderObject() as RenderBox?;
  Matrix4 get _m => widget.matrix.value;
  double get _scale => _m.entry(0, 0);

  void _hold(bool held) {
    if (held == _held) return;
    _held = held;
    widget.onHold(held);
  }

  Offset get _focal =>
      _points.values.reduce((a, b) => a + b) / _points.length.toDouble();

  double get _span {
    final [a, b, ...] = _points.values.toList();
    return max((a - b).distance, 1);
  }

  void _pinchFrom() {
    _from = _m.clone();
    _fromSpan = _span;
    _fromFocal = _focal;
  }

  /// Scale 1 … [_maxScale]; zoomed, the image covers the area — no black margin.
  void _set(Matrix4 m, Size size) {
    final s = m.entry(0, 0);
    if (s <= 1.001) {
      widget.matrix.value = Matrix4.identity();
      return;
    }
    m.setEntry(0, 3, m.entry(0, 3).clamp(size.width * (1 - s), 0));
    m.setEntry(1, 3, m.entry(1, 3).clamp(size.height * (1 - s), 0));
    widget.matrix.value = m;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) {
      final box = _box;
      if (box == null) return;
      final at = box.globalToLocal(e.position);
      _points[e.pointer] = at;
      if (_points.length == 1) {
        _down = (Offset.zero & box.size).contains(at) ? at : null;
        _pinched = false;
      } else {
        _pinched = true;
        _hold(true);
        _pinchFrom();
      }
    },
    onPointerMove: (e) {
      final box = _box;
      if (box == null || !_points.containsKey(e.pointer)) return;
      _points[e.pointer] = box.globalToLocal(e.position);
      if (_points.length >= 2) {
        final r =
            (_from.entry(0, 0) * _span / _fromSpan).clamp(1.0, _maxScale) /
            _from.entry(0, 0);
        final f = _focal;
        _set(
          Matrix4.translationValues(f.dx, f.dy, 0)
            ..multiply(Matrix4.diagonal3Values(r, r, 1))
            ..multiply(
              Matrix4.translationValues(-_fromFocal.dx, -_fromFocal.dy, 0),
            )
            ..multiply(_from),
          box.size,
        );
      } else if (_scale > 1.001) {
        final d = e.delta;
        _set(Matrix4.translationValues(d.dx, d.dy, 0)..multiply(_m), box.size);
      }
    },
    onPointerUp: (e) => _up(e.pointer, e.position),
    onPointerCancel: (e) => _up(e.pointer, null),
    child: widget.child,
  );

  void _up(int pointer, Offset? at) {
    if (_points.remove(pointer) == null) return;
    if (_points.length >= 2) _pinchFrom();
    if (_points.isNotEmpty) return;
    final down = _down;
    final box = _box;
    if (!_pinched &&
        _scale <= 1.001 &&
        down != null &&
        at != null &&
        box != null) {
      final d = box.globalToLocal(at) - down;
      if (d.dy.abs() > 80 && d.dy.abs() > 2 * d.dx.abs()) {
        widget.onSwipe(d.dy < 0);
      }
    }
    _hold(_scale > 1.001);
  }
}

/// The image area of a page: [matrix] zooms it; [zoomKey] marks it for [PinchZoom].
class Zoomed extends StatelessWidget {
  const Zoomed({super.key, this.zoomKey, this.matrix, required this.child});

  final GlobalKey? zoomKey;
  final ValueNotifier<Matrix4>? matrix;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    key: zoomKey,
    child: matrix == null
        ? child
        : ValueListenableBuilder(
            valueListenable: matrix!,
            builder: (context, m, child) =>
                Transform(transform: m, child: child),
            child: child,
          ),
  );
}
