import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/quiz_screen.dart';

const _svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="red"/></svg>';
final _long = 'Extraordinarily long answer text that goes on and on ' * 3;

Widget _screen(WidgetTester t, {int? correct, bool svg = true}) => MaterialApp(
      home: QuizScreen(
        question: 'Which of these is the capital of the country in the picture? ' * 2,
        svg: svg ? utf8.encode(_svg) : null,
        choices: [_long, 'Split', _long, 'Osijek'],
        number: 3,
        total: 10,
        remaining: 0.6,
        answered: 2,
        expected: 4,
        correctIndex: correct,
        picks: correct == null ? const {} : {0: 1, 1: 2, 2: 2},
        players: [for (var i = 0; i < 4; i++) PlayerInfo(i, 'Player number $i', i, true, 0)],
        totals: const {0: 0, 1: 750, 2: 750, 3: 0},
      ),
    );

void main() {
  for (final correct in [null, 2]) {
    testWidgets('1080p long choices, no overflow (correct=$correct)', (t) async {
      t.view.physicalSize = const Size(1920, 1080);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_screen(t, correct: correct));
      await t.pump();
      expect(t.takeException(), isNull);
      // Row doesn't flag vertical overflow, so check long answers stay in their tile (two lines).
      for (final e in find.text(_long).evaluate()) {
        expect(t.getSize(find.byWidget(e.widget)).height, lessThanOrEqualTo(2 * 48 * 1.5));
      }
      expect(find.text('2 of 4 answered'), correct == null ? findsOneWidget : findsNothing);
      expect(find.text('Question 3 of 10'), findsOneWidget);
    });
  }

  testWidgets('tiles fill the grid, not just their text', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_screen(t));
    final tile = find.ancestor(of: find.text('Split'), matching: find.byType(Container)).first;
    expect(t.getSize(tile).height, greaterThan(200));
  });

  testWidgets('answer text is at least 40 px on the TV', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_screen(t));
    final fs = t.widget<Text>(find.text('Split')).style!.fontSize!;
    expect(fs, greaterThanOrEqualTo(40));
  });
}
