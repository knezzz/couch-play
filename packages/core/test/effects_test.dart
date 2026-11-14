import 'package:core/core.dart';
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
    expect(effects, findsNWidgets(3));
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
}
