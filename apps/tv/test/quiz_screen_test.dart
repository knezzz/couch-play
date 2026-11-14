import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/quiz_screen.dart';
import 'package:tv/ui/tv_theme.dart';

const _svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="red"/></svg>';
final _long = 'Extraordinarily long answer text that goes on and on ' * 3;

void _big(WidgetTester t) {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

QuizScreen _quiz({int? correct, bool svg = true, Map<int, int>? picks, Map<int, int>? points, double remaining = 0.6}) =>
    QuizScreen(
      question: 'Which of these is the capital of the country in the picture? ' * 2,
      packTitle: 'World Flags',
      svg: svg ? utf8.encode(_svg) : null,
      choices: [_long, 'Split', _long, 'Osijek'],
      number: 3,
      total: 10,
      remaining: remaining,
      answered: 2,
      expected: 4,
      correctIndex: correct,
      picks: picks ?? (correct == null ? const {} : const {0: 1, 1: 2, 2: 2}),
      points: points ?? const {0: 0, 1: 960, 2: 771, 3: 0},
      players: [for (var i = 0; i < 4; i++) PlayerInfo(i, 'Player number $i', i, true, 0)],
      totals: const {0: 0, 1: 2710, 2: 12480, 3: 0},
    );

Future<void> _pump(WidgetTester t, QuizScreen s) {
  _big(t);
  return t.pumpWidget(MaterialApp(theme: tvTheme(), home: s));
}

double _fs(WidgetTester t, Finder f) => t.widget<Text>(f).style!.fontSize!;

void main() {
  group('question', () {
    testWidgets('header row: question N of M, pack title, answered count', (t) async {
      await _pump(t, _quiz());
      expect(t.takeException(), isNull);
      expect(find.text('Question 3 of 10'), findsOneWidget);
      expect(find.text('World Flags'), findsOneWidget);
      expect(find.text('2 of 4 answered'), findsOneWidget);
      expect(_fs(t, find.text('2 of 4 answered')), 40);
    });

    testWidgets('accent progress bar follows the countdown', (t) async {
      await _pump(t, _quiz(remaining: 0.6));
      final bar = t.widget<FractionallySizedBox>(find.byKey(const ValueKey('timer-bar')));
      expect(bar.widthFactor, 0.6);
      expect(t.getSize(find.byKey(const ValueKey('timer-bar'))).height, 16);
      final deco = t.widget<DecoratedBox>(find.descendant(of: find.byKey(const ValueKey('timer-bar')), matching: find.byType(DecoratedBox)));
      expect((deco.decoration as BoxDecoration).color, tvAccent);
    });

    testWidgets('80 px question, 520 px picture card on the right', (t) async {
      await _pump(t, _quiz());
      expect(_fs(t, find.textContaining('Which of these')), 80);
      expect(t.getSize(find.byKey(const ValueKey('picture-card'))).width, 520);
      expect(t.getTopLeft(find.byKey(const ValueKey('picture-card'))).dx,
          greaterThan(t.getTopLeft(find.textContaining('Which of these')).dx + 400));
    });

    testWidgets('four 168 px tiles in a 2x2 grid; long answers wrap to 3 lines inside the tile', (t) async {
      await _pump(t, _quiz(svg: false));
      for (var i = 0; i < 4; i++) {
        expect(t.getSize(find.byKey(ValueKey('tile-$i'))).height, 168);
      }
      expect(t.getTopLeft(find.byKey(const ValueKey('tile-0'))).dy, t.getTopLeft(find.byKey(const ValueKey('tile-1'))).dy);
      expect(t.getTopLeft(find.byKey(const ValueKey('tile-2'))).dy, greaterThan(t.getTopLeft(find.byKey(const ValueKey('tile-0'))).dy));
      for (final e in find.text(_long).evaluate()) {
        final h = t.getSize(find.byWidget(e.widget)).height;
        expect(h, lessThanOrEqualTo(168));
        expect((e.widget as Text).maxLines, 3);
        expect((e.widget as Text).style!.fontSize, greaterThanOrEqualTo(28));
      }
      expect(_fs(t, find.text('Split')), 52, reason: 'short answers are big');
    });

    testWidgets('the tile shapes are drawn, not typed', (t) async {
      await _pump(t, _quiz());
      for (final g in ['▲', '◆', '●', '■']) {
        expect(find.text(g), findsNothing, reason: 'a glyph needs a symbol font on the TV');
      }
      expect(find.descendant(of: find.byKey(const ValueKey('tile-0')), matching: find.byType(CustomPaint)), findsWidgets);
    });

    testWidgets('timer bar spans the full width', (t) async {
      await _pump(t, _quiz(remaining: 1));
      expect(t.getSize(find.byKey(const ValueKey('timer-bar'))).width, 1728);
    });

    testWidgets('answers stay at 40 px or more up to 3 lines', (t) async {
      await _pump(t, _quiz());
      expect(_fs(t, find.text('Split')), greaterThanOrEqualTo(40));
    });
  });

  group('reveal', () {
    testWidgets('no overflow with long text; header says The answer is', (t) async {
      await _pump(t, _quiz(correct: 2));
      expect(t.takeException(), isNull);
      expect(find.textContaining('The answer is'), findsOneWidget);
      expect(find.text('2 of 4 answered'), findsNothing);
    });

    testWidgets('the correct tile is large, outlined white, with a check', (t) async {
      await _pump(t, _quiz(correct: 2));
      final big = find.byKey(const ValueKey('tile-2'));
      expect(t.getSize(big).height, 168);
      expect(find.descendant(of: big, matching: find.byIcon(Icons.check)), findsOneWidget);
      final deco = t.widget<Container>(big).decoration! as BoxDecoration;
      expect(deco.border!.top.color, tvText);
      for (final i in [0, 1, 3]) {
        expect(t.getSize(find.byKey(ValueKey('tile-$i'))).height, 120);
        expect(find.descendant(of: find.byKey(ValueKey('tile-$i')), matching: find.byIcon(Icons.check)), findsNothing);
      }
    });

    testWidgets('the 3 wrong tiles sit in one row as 25% tints', (t) async {
      await _pump(t, _quiz(correct: 2));
      final ys = [0, 1, 3].map((i) => t.getTopLeft(find.byKey(ValueKey('tile-$i'))).dy).toSet();
      expect(ys.length, 1);
      expect(ys.single, greaterThan(t.getTopLeft(find.byKey(const ValueKey('tile-2'))).dy));
      final fill = (t.widget<Container>(find.byKey(const ValueKey('tile-1'))).decoration! as BoxDecoration).color!;
      expect(fill.a, closeTo(0.25, 0.01));
      expect(find.byType(Opacity), findsNothing, reason: 'the voter dots must not be dimmed');
    });

    testWidgets('voters: white-ringed dots, 48 px on the correct tile, 44 px on wrong ones', (t) async {
      await _pump(t, _quiz(correct: 2)); // picks {0:1, 1:2, 2:2}
      Iterable<Size> dots(int tile) => find
          .descendant(of: find.byKey(ValueKey('tile-$tile')), matching: find.byType(PlayerDot))
          .evaluate()
          .map((e) => t.getSize(find.byWidget(e.widget)));
      expect(dots(2), [const Size(48, 48), const Size(48, 48)]);
      expect(dots(1), [const Size(44, 44)]);
      expect(dots(0), isEmpty);
      for (final e in find.byType(PlayerDot).evaluate().where((e) => (e.widget as PlayerDot).ring)) {
        final box = (find.descendant(of: find.byWidget(e.widget), matching: find.byType(Container)).evaluate().first.widget as Container)
            .decoration! as BoxDecoration;
        expect(box.border!.top.color, Colors.white);
        expect(box.color!.a, 1.0);
      }
    });

    testWidgets('Scores panel: grouped totals, +points green, +0 muted, 40 px', (t) async {
      await _pump(t, _quiz(correct: 2));
      expect(find.text('Scores'), findsOneWidget);
      expect(_fs(t, find.text('Scores')), 44);
      expect(find.text('12 480'), findsOneWidget);
      expect(find.text('2 710'), findsOneWidget);
      expect(_fs(t, find.text('12 480')), 40);
      expect(t.widget<Text>(find.text('+960')).style!.color, const Color(0xFF2ECC71));
      expect(t.widget<Text>(find.text('+0').first).style!.color, tvMuted);
      double y(String s) => t.getTopLeft(find.text(s)).dy;
      expect(y('12 480'), lessThan(y('2 710')), reason: 'sorted by total');
    });

    testWidgets('Scores lists only players in the quiz', (t) async {
      _big(t);
      await t.pumpWidget(MaterialApp(
        theme: tvTheme(),
        home: QuizScreen(
          question: 'q',
          packTitle: 'P',
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
          points: const {0: 750},
        ),
      ));
      expect(find.text('Quizzer'), findsOneWidget);
      expect(find.text('Latecomer'), findsNothing);
      expect(find.text('Botty'), findsNothing);
    });
  });
    testWidgets('8 voters on a wrong tile: at most 3 marks, the answer keeps its room', (t) async {
      _big(t);
      await t.pumpWidget(MaterialApp(
        theme: tvTheme(),
        home: QuizScreen(
          question: 'q',
          packTitle: 'P',
          choices: const ['The right one', 'A fairly long wrong answer here', 'c', 'd'],
          number: 1,
          total: 2,
          remaining: 0.5,
          answered: 8,
          expected: 8,
          correctIndex: 0,
          picks: {for (var i = 0; i < 8; i++) i: 1},
          points: const {},
          players: [for (var i = 0; i < 8; i++) PlayerInfo(i, 'P$i', i, true, 0)],
          totals: {for (var i = 0; i < 8; i++) i: 0},
        ),
      ));
      expect(t.takeException(), isNull);
      final tile = find.byKey(const ValueKey('tile-1'));
      expect(find.descendant(of: tile, matching: find.byType(PlayerDot)).evaluate().length, lessThanOrEqualTo(3));
      expect(find.descendant(of: tile, matching: find.text('+6')), findsOneWidget, reason: '8 voters: 2 dots and +6');
      final answer = find.descendant(of: tile, matching: find.text('A fairly long wrong answer here'));
      expect(t.getSize(answer).width, greaterThan(150), reason: 'the answer keeps its room');
      // 1 or 2 voters never show a +N.
    });

    testWidgets('1 or 2 voters get dots and no +N', (t) async {
      await _pump(t, _quiz(correct: 2));
      for (final i in [1, 2]) {
        expect(find.descendant(of: find.byKey(ValueKey('tile-$i')), matching: find.textContaining('+')), findsNothing);
      }
    });
}
