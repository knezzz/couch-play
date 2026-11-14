import 'package:controller/screens/quiz_screen.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

void main() {
  const q = QuizQuestion(1, 5, ['Zagreb', 'Split', 'Rijeka', 'Osijek'], 20);

  testWidgets('shows 4 tiles, first tap sends Answer once and locks', (t) async {
    final c = FakeConnection();
    await t.pumpWidget(MaterialApp(home: QuizScreen(c, q, null)));
    for (final s in q.choices) {
      expect(find.text(s), findsOneWidget);
    }
    expect(find.byType(ShapeMark), findsNWidgets(4)); // drawn, not font glyphs
    for (final g in ['▲', '◆', '●', '■']) {
      expect(find.text(g), findsNothing);
    }
    await t.tap(find.text('Rijeka'));
    await t.pump();
    await t.tapAt(t.getCenter(find.byType(Scaffold)));
    await t.pump();
    expect(c.sent.whereType<Answer>().map((a) => a.index), [2]);
    expect(find.text('Locked in. Watch the TV.'), findsOneWidget);
  });

  testWidgets('reveal shows points and total, or Not this time', (t) async {
    final c = FakeConnection();
    await t.pumpWidget(MaterialApp(home: QuizScreen(c, q, const QuizReveal(2, 750, 1500))));
    expect(find.text('+750'), findsOneWidget);
    expect(find.textContaining('1500'), findsOneWidget);
    await t.pumpWidget(MaterialApp(home: QuizScreen(c, q, const QuizReveal(2, 0, 900))));
    expect(find.text('Not this time'), findsOneWidget);
  });

  testWidgets('small phone: safe area insets and a 3-line choice fits', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 40, bottom: 34);
    addTearDown(t.view.reset);
    final long = 'A very long answer that needs several lines on a small phone screen ' * 2;
    final qq = QuizQuestion(1, 5, [long, 'b', long, 'd'], 20);
    await t.pumpWidget(MaterialApp(home: QuizScreen(FakeConnection(), qq, null)));
    expect(t.takeException(), isNull);
    expect(t.getTopLeft(find.byType(InkWell).first).dy, greaterThanOrEqualTo(40));
    expect(t.getBottomLeft(find.byType(InkWell).last).dy, lessThanOrEqualTo(640 - 34));
    for (final e in find.text(long).evaluate()) {
      final tile = find.ancestor(of: find.byWidget(e.widget), matching: find.byType(InkWell));
      expect(t.getRect(find.byWidget(e.widget)).bottom, lessThanOrEqualTo(t.getRect(tile).bottom));
    }
  });

  testWidgets('header shows the question number and your total; reveal shows the right answer', (t) async {
    final c = FakeConnection();
    await t.pumpWidget(MaterialApp(home: QuizScreen(c, q, null, total: 2710)));
    expect(find.textContaining('Question 1 of 5'), findsOneWidget);
    expect(find.text('2710'), findsOneWidget);
    await t.pumpWidget(MaterialApp(home: QuizScreen(c, q, const QuizReveal(2, 960, 2710), total: 2710)));
    expect(find.text('Rijeka'), findsOneWidget); // the right answer
    expect(find.text('Correct'), findsOneWidget);
    expect(find.byType(ShapeMark), findsOneWidget);
    expect(find.text('▲'), findsNothing);
  });

  testWidgets('after a tap nothing on screen shows which tile was picked', (t) async {
    for (final pick in ['Zagreb', 'Osijek']) {
      final c = FakeConnection();
      await t.pumpWidget(MaterialApp(home: QuizScreen(c, q, null, key: ValueKey(pick))));
      await t.tap(find.text(pick));
      await t.pump(const Duration(seconds: 1));
      for (final s in [...q.choices, '▲', '◆', '●', '■']) {
        expect(find.text(s), findsNothing, reason: s);
      }
      for (final col in [0xFFFF4D6D, 0xFF22B8F0, 0xFFFFB020, 0xFF2ECC71]) {
        expect(find.byWidgetPredicate((w) => w is Material && w.color == Color(col)), findsNothing);
      }
      expect(find.byType(ShapeMark), findsNothing);
      expect(find.text('Locked in. Watch the TV.'), findsOneWidget);
    }
  });
}
