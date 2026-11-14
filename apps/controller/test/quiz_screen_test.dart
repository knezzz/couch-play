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
    await t.tap(find.text('Rijeka'));
    await t.pump();
    await t.tap(find.text('Split'));
    await t.pump();
    expect(c.sent.whereType<Answer>().map((a) => a.index), [2]);
    expect(find.text('Locked in'), findsOneWidget);
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
}
