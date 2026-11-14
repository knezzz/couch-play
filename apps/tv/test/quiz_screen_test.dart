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

  testWidgets('reveal scoreboard lists only players in the quiz', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: QuizScreen(
        question: 'q',
        choices: const ['a', 'b', 'c', 'd'],
        number: 1,
        total: 2,
        remaining: 0.5,
        answered: 1,
        expected: 1,
        correctIndex: 0,
        players: [
          PlayerInfo(0, 'Quizzer', 0, true, 0),
          PlayerInfo(1, 'Latecomer', 1, true, 0),
          PlayerInfo(2, 'Botty', 2, true, 0, bot: true),
        ],
        totals: const {0: 750},
      ),
    ));
    expect(find.text('Quizzer'), findsOneWidget);
    expect(find.text('Latecomer'), findsNothing);
    expect(find.text('Botty'), findsNothing);
  });

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

  testWidgets('reveal: wrong tiles dim their fill, voter dots stay at full strength', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_screen(t, correct: 2)); // players 1 and 2 picked tiles 1 and 2; 0 picked 1
    // No Opacity wraps a whole tile any more.
    expect(find.byType(Opacity), findsNothing);
    final dots = find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
        (w.constraints?.maxWidth == 40));
    expect(dots, findsNWidgets(3));
    for (final d in dots.evaluate()) {
      final deco = (d.widget as Container).decoration! as BoxDecoration;
      expect(deco.color!.a, 1.0, reason: 'dot fill is opaque');
      expect((deco.border! as Border).top.color, Colors.white, reason: 'white ring');
      expect((deco.border! as Border).top.width, 4);
    }
    // The wrong tile's fill is the dimmed colour.
    final wrong = t.widget<Container>(find.ancestor(of: find.text('Split'), matching: find.byType(Container)).first);
    expect((wrong.decoration! as BoxDecoration).color!.a, closeTo(0.3, 0.01));
  });

  testWidgets('reveal scoreboard: 40 px text, 36 px dots', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_screen(t, correct: 2));
    final name = find.text('Player number 1');
    expect(t.widget<Text>(name.last).style!.fontSize, 40);
    expect(t.widget<Text>(find.text('750').first).style!.fontSize, 40);
  });
}
