import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ▲ ◆ ● ■, drawn at 40 px in red over transparent: is a pixel painted?
  Future<bool Function(int, int)> paint(WidgetTester t, int index) async {
    final key = GlobalKey();
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(key: key, child: ShapeMark(index, 40, const Color(0xFFFF0000))),
      ),
    ));
    final data = await t.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
      return (await img.toByteData())!;
    });
    ByteData d = data!;
    return (x, y) => d.getUint8((y * 40 + x) * 4 + 3) > 128;
  }

  testWidgets('each mark is a distinct shape inside its box', (t) async {
    final tri = await paint(t, 0), dia = await paint(t, 1), circ = await paint(t, 2), sq = await paint(t, 3);
    for (final p in [tri, dia, circ, sq]) {
      expect(p(20, 25), isTrue, reason: 'the middle is filled');
    }
    // Top-left corner: only the square reaches it.
    expect([tri(1, 1), dia(1, 1), circ(1, 1), sq(1, 1)], [false, false, false, true]);
    // Bottom-left corner: the triangle and the square reach it; diamond and circle don't.
    expect([tri(1, 38), dia(1, 38), circ(1, 38), sq(1, 38)], [true, false, false, true]);
    // Top-middle: the triangle's tip and the diamond's tip; the circle's top; the square.
    expect([tri(20, 2), dia(20, 2), circ(20, 2), sq(20, 2)], [true, true, true, true]);
    // Left-middle: only the diamond, circle and square.
    expect([tri(2, 20), dia(2, 20), circ(2, 20), sq(2, 20)], [false, true, true, true]);
  });
}
