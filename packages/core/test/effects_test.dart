import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final effects = find.descendant(of: find.byType(EffectLayer), matching: find.byType(CustomPaint));

Future<BuildContext> pumpLayer(WidgetTester t, {bool reduced = false}) async {
  late BuildContext ctx;
  await t.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: EffectLayer(
        child: Builder(builder: (c) {
          ctx = c;
          return const SizedBox.expand();
        }),
      ),
    ),
  ));
  return ctx;
}

void main() {
  testWidgets('play_confetti_then_clears', (t) async {
    final ctx = await pumpLayer(t);
    expect(effects, findsNothing);
    EffectLayer.play(ctx, EffectName.confetti);
    await t.pump();
    expect(effects, findsOneWidget);
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await t.pump(const Duration(milliseconds: 1500));
    expect(effects, findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(effects, findsNothing);
    expect(t.binding.transientCallbackCount, 0);
  });

  testWidgets('every effect clears within 3 s', (t) async {
    final ctx = await pumpLayer(t);
    EffectLayer.play(ctx, EffectName.colorPulse, color: const Color(0xFFFF4D4D));
    EffectLayer.play(ctx, EffectName.scorePop, text: '+1000');
    await t.pump();
    expect(effects, findsNWidgets(2));
    await t.pump(const Duration(seconds: 3));
    expect(effects, findsNothing);
  });

  testWidgets('disableAnimations shows a still frame with no tickers, then clears', (t) async {
    final ctx = await pumpLayer(t, reduced: true);
    for (final n in EffectName.values) {
      EffectLayer.play(ctx, n, text: '+1');
    }
    await t.pump();
    expect(effects, findsNWidgets(EffectName.values.length));
    expect(t.binding.transientCallbackCount, 0);
    await t.pump(const Duration(seconds: 3));
    expect(effects, findsNothing);
  });

  testWidgets('play with no layer above does nothing', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    EffectLayer.play(ctx, EffectName.confetti);
  });

  testWidgets('each effect repaints in its own boundary', (t) async {
    final ctx = await pumpLayer(t);
    EffectLayer.play(ctx, EffectName.confetti);
    EffectLayer.play(ctx, EffectName.colorPulse);
    await t.pump();
    final boundaries = find.descendant(of: find.byType(EffectLayer), matching: find.byType(RepaintBoundary));
    expect(boundaries, findsNWidgets(2));
    expect(find.ancestor(of: effects.first, matching: boundaries), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });

  // --- the TV death glow: edge only, stacked glows capped ---

  /// The layer drawn over black, as RGBA bytes.
  Future<(ByteData, int, int)> shot(WidgetTester t, GlobalKey key) async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    return (await t.runAsync(() async {
      final img = await boundary.toImage();
      return ((await img.toByteData())!, img.width, img.height);
    }))!;
  }

  int red(ByteData d, int w, int x, int y) => d.getUint8((y * w + x) * 4);

  Future<(ByteData, int, int)> glows(WidgetTester t, int n) async {
    final key = GlobalKey();
    late BuildContext ctx;
    t.view
      ..physicalSize = const Size(400, 300)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: RepaintBoundary(
          key: key,
          child: EffectLayer(
            child: Builder(builder: (c) {
              ctx = c;
              return const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand());
            }),
          ),
        ),
      ),
    ));
    for (var i = 0; i < n; i++) {
      EffectLayer.play(ctx, EffectName.edgeGlow, color: const Color(0xFFFF0000));
    }
    await t.pump();
    await t.pump(const Duration(milliseconds: 300)); // half way: the peak
    return shot(t, key);
  }

  testWidgets('a death glow lights the border and leaves the playfield alone', (t) async {
    final (d, w, h) = await glows(t, 1);
    expect(red(d, w, 1, h ~/ 2), greaterThan(40), reason: 'left edge glows');
    expect(red(d, w, w ~/ 2, 1), greaterThan(40), reason: 'top edge glows');
    expect(red(d, w, w ~/ 2, h ~/ 2), 0, reason: 'the middle is untouched');
    expect(red(d, w, w ~/ 4, h ~/ 2), 0, reason: 'so is everything away from the border');
    await t.pump(const Duration(seconds: 3));
  });

  for (final n in [3, 8]) {
    testWidgets('$n glows at once never exceed the ~25% cap', (t) async {
      final (d, w, h) = await glows(t, n);
      var most = 0;
      for (var y = 0; y < h; y += 7) {
        for (var x = 0; x < w; x += 7) {
          most = most > red(d, w, x, y) ? most : red(d, w, x, y);
        }
      }
      expect(most, lessThanOrEqualTo((0.25 * 255).ceil() + 2));
      expect(most, greaterThan(30), reason: 'still visible');
      await t.pump(const Duration(seconds: 3));
    });
  }

  // --- confetti is sized for the screen, not for pixels ---

  testWidgets('confetti covers the same share of a big screen as of a small one', (t) async {
    Future<double> coverage(Size size) async {
      final key = GlobalKey();
      late BuildContext ctx;
      t.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      await t.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: RepaintBoundary(
            key: key,
            child: EffectLayer(
              child: Builder(builder: (c) {
                ctx = c;
                return const ColoredBox(color: Color(0xFF000000), child: SizedBox.expand());
              }),
            ),
          ),
        ),
      ));
      EffectLayer.play(ctx, EffectName.confetti);
      await t.pump();
      await t.pump(const Duration(milliseconds: 1000));
      final (d, w, h) = await shot(t, key);
      var lit = 0;
      for (var i = 0; i < w * h; i++) {
        if (d.getUint8(i * 4) + d.getUint8(i * 4 + 1) + d.getUint8(i * 4 + 2) > 0) lit++;
      }
      await t.pump(const Duration(seconds: 3));
      return lit / (w * h);
    }

    addTearDown(t.view.reset);
    final small = await coverage(const Size(800, 600));
    // The TV is 960x540 logical (2x): a few large pieces, not a haze of specks.
    final tv = await coverage(const Size(960, 540));
    expect(tv, inInclusiveRange(0.003, 0.03), reason: 'tv=$tv');
    // A phone (390x844) keeps pieces readable.
    final phone = await coverage(const Size(390, 844));
    expect(phone, inInclusiveRange(0.003, 0.03), reason: 'phone=$phone');
    final big = await coverage(const Size(1600, 1200));
    expect(small, greaterThan(0));
    expect(big / small, inInclusiveRange(0.7, 1.4), reason: 'small=$small big=$big');
  });
}
