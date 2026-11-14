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
}
