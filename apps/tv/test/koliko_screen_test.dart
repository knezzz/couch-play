import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/ui/koliko/koliko_screen.dart';
import 'package:tv/ui/koliko/koliko_view.dart';

import 'session_test.dart' show join;

PlayerInfo _p(int i) => PlayerInfo(i, 'Igrac$i', i, true, 0, character: characterIds[i]);

KolikoBoard _ask({Set<int> answered = const {}, int left = 20, String unit = 'm'}) =>
    KolikoBoard(number: 3, total: 10, question: 'Koliko je visok Triglav?', unit: unit, players: [for (var i = 0; i < 4; i++) _p(i)], answered: answered, secondsLeft: left, seconds: 30);

KolikoBoard _reveal() => KolikoBoard(
      number: 3,
      total: 10,
      question: 'Koliko je visok Triglav?',
      unit: 'm',
      players: [for (var i = 0; i < 4; i++) _p(i)],
      answered: const {0, 1, 2},
      secondsLeft: 0,
      seconds: 30,
      answer: 2864,
      rows: [
        KolikoRow(_p(1), 2864, 1, 1500, true, 2500),
        KolikoRow(_p(0), 2900, 2, 1000, false, 2000),
        KolikoRow(_p(2), 1200, 3, 500, false, 700),
        KolikoRow(_p(3), null, null, 0, false, 0),
      ],
    );

Future<void> _show(WidgetTester t, KolikoBoard b) async {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: KolikoScreen(b)));
}

void main() {
  test('numbers read the Croatian way', () {
    expect(kolikoNum(2864), '2 864');
    expect(kolikoNum(1234567.5), '1 234 567,5');
    expect(kolikoNum(-3), '-3');
    expect(kolikoNum(0.25), '0,25');
  });

  testWidgets('asking: the question, the unit, who has answered (never what), the clock', (t) async {
    await _show(t, _ask(answered: const {0, 2}));
    expect(find.text('Koliko je visok Triglav?'), findsOneWidget);
    expect(find.text('Pitanje 3 od 10'), findsOneWidget);
    expect(find.text('Odgovor u: m'), findsOneWidget);
    expect(find.text('Odgovorilo: 2 od 4'), findsOneWidget);
    expect(find.byKey(const ValueKey('who-0-yes')), findsOneWidget);
    expect(find.byKey(const ValueKey('who-1-no')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('seconds'))).data, '20');
    expect(find.byKey(const ValueKey('answer')), findsNothing, reason: 'the answer is not shown while asking');
    expect(t.takeException(), isNull);
  });

  testWidgets('no unit, no unit line', (t) async {
    await _show(t, _ask(unit: ''));
    expect(find.byKey(const ValueKey('unit')), findsNothing);
  });

  testWidgets('the clock is the 20-segment ticker and goes red in the last 5 s', (t) async {
    await _show(t, _ask(left: 15));
    var lit = 0;
    for (var i = 0; i < 20; i++) {
      if ((t.widget<Container>(find.byKey(ValueKey('tick-$i'))).decoration as BoxDecoration).color!.a > 0.5) lit++;
    }
    expect(lit, 10);
    await _show(t, _ask(left: 5));
    expect(t.widget<Text>(find.byKey(const ValueKey('seconds'))).style!.color, const Color(0xFFFF4D6D));
  });

  testWidgets('the reveal: the true answer, every number on the line, ranks with points and totals', (t) async {
    await _show(t, _reveal());
    expect(t.widget<Text>(find.byKey(const ValueKey('answer'))).data, 'Točno: 2 864 m');
    expect(find.byKey(const ValueKey('marker-answer')), findsOneWidget);
    for (final id in [0, 1, 2]) {
      expect(find.byKey(ValueKey('marker-$id')), findsOneWidget, reason: 'player $id is on the line');
    }
    expect(find.byKey(const ValueKey('marker-3')), findsNothing, reason: 'no answer, no marker');
    // Left to right on the line follows the numbers: 1200 < 2864 < 2900.
    double xOf(String k) => t.getCenter(find.byKey(ValueKey(k))).dx;
    expect(xOf('marker-2'), lessThan(xOf('marker-1')));
    expect(xOf('marker-1'), lessThan(xOf('marker-0')));
    expect(xOf('marker-answer'), closeTo(xOf('marker-1'), 40));
    expect(find.descendant(of: find.byKey(const ValueKey('row-1')), matching: find.text('+1500')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('row-3')), matching: find.text('bez odgovora')), findsOneWidget);
    // Rows sit inside the picture, above the overscan edge.
    for (final id in [0, 1, 2, 3]) {
      expect(t.getRect(find.byKey(ValueKey('row-$id'))).bottom, lessThanOrEqualTo(1030));
    }
    expect(t.takeException(), isNull);
  });

  testWidgets('all numbers equal and eight players still draw', (t) async {
    final rows = [for (var i = 0; i < 8; i++) KolikoRow(_p(i % 8 < 8 ? i : 0), 50, i + 1, 100, true, 100)];
    await _show(
        t,
        KolikoBoard(
            number: 1, total: 5, question: 'q', unit: '', players: [for (var i = 0; i < 8; i++) _p(i)], answered: const {}, secondsLeft: 0, seconds: 30, answer: 50, rows: rows));
    expect(t.takeException(), isNull);
  });

  testWidgets('the view shows the live match and never a number while the question is open', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = Session(random: Random(1))
      ..kolikoTvReady = true
      ..kolikoPacks = [KolikoPack('k', 'K', [for (var i = 0; i < 12; i++) KolikoQuestion('Pitanje $i?', 1000.0 + i, 'm', null, 'izvor')])];
    final ps = [for (var i = 0; i < 3; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.koliko, null));
    expect(s.phase, Phase.koliko);
    await t.pumpWidget(MaterialApp(home: KolikoView(match: s.koliko!, players: s.playerInfos)));
    expect(find.textContaining('Pitanje '), findsWidgets);
    expect(find.byKey(const ValueKey('answer')), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
