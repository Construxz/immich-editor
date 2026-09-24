import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_editor/gallery/zoom.dart';

/// Pages like the viewer: each page a [PinchZoom]; holding stops the paging.
class _Pages extends StatefulWidget {
  const _Pages(this.swipes);
  final List<bool> swipes;
  @override
  State<_Pages> createState() => _PagesState();
}

class _PagesState extends State<_Pages> {
  final pages = PageController();
  final zoom = ValueNotifier(Matrix4.identity());
  final areas = [GlobalKey(), GlobalKey()];
  var held = false;
  var page = 0;
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: PinchZoom(
      target: areas[page],
      matrix: zoom,
      onHold: (h) => setState(() => held = h),
      onSwipe: widget.swipes.add,
      child: PageView(
        controller: pages,
        physics: held ? const NeverScrollableScrollPhysics() : null,
        onPageChanged: (i) => setState(() => page = i),
        children: [
          for (final (i, c) in [Colors.red, Colors.blue].indexed)
            Zoomed(
              zoomKey: areas[i],
              matrix: i == page ? zoom : noZoom,
              child: _Counted(color: c),
            ),
        ],
      ),
    ),
  );
}

/// Counts how often a page's content is built from scratch — each time an image would reload.
var inits = 0;

class _Counted extends StatefulWidget {
  const _Counted({required this.color});
  final Color color;
  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    inits++;
  }

  @override
  Widget build(BuildContext context) => ColoredBox(color: widget.color);
}

void main() {
  _PagesState state(WidgetTester t) =>
      t.state<_PagesState>(find.byType(_Pages));
  double scale(WidgetTester t) => state(t).zoom.value.entry(0, 0);
  double page(WidgetTester t) => state(t).pages.page!;

  testWidgets('one finger turns the page, the pages keep their content', (
    t,
  ) async {
    inits = 0;
    await t.pumpWidget(_Pages([]));
    await t.fling(find.byType(PageView), const Offset(-300, 0), 1500);
    await t.pumpAndSettle();
    expect(page(t), 1);
    expect(scale(t), 1);
    expect(state(t).held, isFalse);
    expect(
      inits,
      2,
    ); // each page once — no rebuild when the zoom moves to the new page
  });

  testWidgets(
    'a pinch zooms even if the first finger drifted into a page drag',
    (t) async {
      await t.pumpWidget(_Pages([]));
      final a = await t.startGesture(const Offset(300, 300), pointer: 1);
      await a.moveBy(
        const Offset(-40, 0),
      ); // past the page view's slop: it takes this finger
      await t.pump();
      final b = await t.startGesture(const Offset(400, 300), pointer: 2);
      for (var i = 0; i < 10; i++) {
        await a.moveBy(const Offset(-10, 0));
        await b.moveBy(const Offset(10, 0));
        await t.pump();
      }
      await a.up();
      await b.up();
      await t.pumpAndSettle();
      expect(scale(t), greaterThan(1.5));
      expect(page(t), 0); // the page sprang back
    },
  );

  testWidgets('not zoomed, swiping up or down reports the direction', (
    t,
  ) async {
    final swipes = <bool>[];
    await t.pumpWidget(_Pages(swipes));
    await t.dragFrom(const Offset(300, 400), const Offset(0, -200));
    await t.pumpAndSettle();
    await t.dragFrom(const Offset(300, 200), const Offset(0, 200));
    await t.pumpAndSettle();
    expect(swipes, [true, false]);
    expect(page(t), 0);
  });
}
