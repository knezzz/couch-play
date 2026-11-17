import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
    expect(kolikoNum(2864), '2864', reason: 'under 10 000 no grouping, so years read right');
    expect(kolikoNum(1886), '1886');
    expect(kolikoNum(9999), '9999');
    expect(kolikoNum(12500), '12.500');
    expect(kolikoNum(1234567.5), '1.234.567,5');
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
    await t.pump(const Duration(seconds: 3));
    expect(t.widget<Text>(find.byKey(const ValueKey('answer'))).data, 'Točno: 2864 m');
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

  testWidgets('the reveal animates and stops: guesses slide in from the left, the answer line drops, then nothing runs', (t) async {
    await _show(t, _reveal());
    double x(String k) => t.getCenter(find.byKey(ValueKey(k))).dx;
    final startX = x('marker-1');
    final answerTop0 = t.getTopLeft(find.byKey(const ValueKey('marker-answer'))).dy;
    await t.pump(const Duration(milliseconds: 800));
    expect(x('marker-1'), greaterThan(startX + 200), reason: 'sliding right toward its number');
    await t.pump(const Duration(milliseconds: 2200));
    final endX = x('marker-1');
    expect(endX, greaterThan(x('marker-2')), reason: 'at its number: 2864 is right of 1200');
    expect(t.getTopLeft(find.byKey(const ValueKey('marker-answer'))).dy, greaterThan(answerTop0 + 300), reason: 'the line has dropped in');
    expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'a finite animation: it stops');
    await t.pump(const Duration(seconds: 5));
    expect(x('marker-1'), endX);
  });

  testWidgets('the closest player is ringed in gold; a tie rings both; the others are not', (t) async {
    await _show(t, _reveal());
    await t.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('closest-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('closest-0')), findsNothing);
    expect(find.byKey(const ValueKey('closest-2')), findsNothing);
    BoxDecoration ring(int id) => t.widget<Container>(find.byKey(ValueKey('closest-$id'))).decoration! as BoxDecoration;
    expect((ring(1).border! as Border).top.color.a, closeTo(1, 0.01), reason: 'the ring has faded in');
    final tie = KolikoBoard(
      number: 4, total: 10, question: 'q', unit: '', players: [for (var i = 0; i < 3; i++) _p(i)], answered: const {}, secondsLeft: 0, seconds: 30, answer: 100,
      rows: [KolikoRow(_p(0), 90, 1, 1000, false, 1000), KolikoRow(_p(1), 110, 1, 1000, false, 1000), KolikoRow(_p(2), 50, 3, 500, false, 500)]);
    await _show(t, tie);
    await t.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('closest-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('closest-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('closest-2')), findsNothing);
  });

  testWidgets('with animations off the reveal is at its end state at once', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MediaQuery(data: const MediaQueryData(disableAnimations: true), child: Directionality(textDirection: TextDirection.ltr, child: KolikoScreen(_reveal()))));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(t.getCenter(find.byKey(const ValueKey('marker-1'))).dx, greaterThan(t.getCenter(find.byKey(const ValueKey('marker-2'))).dx));
  });

  testWidgets('confetti plays once at the reveal when someone is closest', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var at = Duration.zero;
    final s = Session(random: Random(1), clock: () => at)
      ..kolikoTvReady = true
      ..kolikoPacks = [KolikoPack('k', 'K', [for (var i = 0; i < 12; i++) KolikoQuestion('Pitanje $i?', 1000.0 + i, 'm', null, 'izvor')])];
    final ps = [for (var i = 0; i < 3; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.koliko, null));
    for (final p in ps) {
      p.say(const NumberAnswer(1000));
    }
    expect(s.koliko!.reveal, isNotNull, reason: 'everyone answered: the reveal');
    await t.pumpWidget(MaterialApp(home: EffectLayer(child: KolikoView(match: s.koliko!, players: s.playerInfos))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(CustomPaint), findsWidgets);
    final running = SchedulerBinding.instance.transientCallbackCount;
    expect(running, greaterThan(1), reason: 'the line animation and the confetti controller are both running');
    await t.pump(const Duration(seconds: 6));
    expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'both end');
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });

  for (final size in [const Size(1280, 720), const Size(1920, 1080), const Size(1272, 715)]) {
    final longQ = 'Koje je godine u Zagrebu otvoren prvi javni park za sve građane koji su tada živjeli u gradu i okolici, a danas je jedan od najpoznatijih?';
    final eight = [for (var i = 0; i < 8; i++) PlayerInfo(i, 'Igrac$i-duže', i, true, 0, character: characterIds[i])];
    testWidgets('${size.width.toInt()}x${size.height.toInt()}: a 4-line question and 8 players fit on screen, ask and reveal', (t) async {
      t.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      Rect screen() => Offset.zero & size;
      void inside(Finder f, String what) {
        final r = t.getRect(f);
        expect(screen().inflate(1).contains(r.topLeft) && screen().inflate(1).contains(r.bottomRight), isTrue, reason: '$what $r is outside $size');
      }

      await t.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: KolikoScreen(KolikoBoard(number: 1, total: 5, question: longQ, unit: 'm', players: eight, answered: const {0, 1, 2, 3}, secondsLeft: 20, seconds: 30))));
      expect(t.takeException(), isNull);
      inside(find.byKey(const ValueKey('question')), 'question');
      inside(find.byKey(const ValueKey('count')), 'count');
      final q = t.getRect(find.byKey(const ValueKey('question'))), faces = t.getRect(find.byKey(const ValueKey('who-0-yes')));
      expect(q.bottom, lessThanOrEqualTo(faces.top), reason: 'the question does not run into the faces');

      final rows = [for (var i = 0; i < 8; i++) KolikoRow(eight[i], 1500.0 + i * 120, i + 1, 100, i == 0, 100 * i)];
      await t.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: KolikoScreen(KolikoBoard(number: 1, total: 5, question: longQ, unit: 'm', players: eight, answered: const {}, secondsLeft: 0, seconds: 30, answer: 1500, rows: rows))));
      await t.pump(const Duration(seconds: 3));
      expect(t.takeException(), isNull);
      for (var i = 0; i < 8; i++) {
        inside(find.byKey(ValueKey('row-$i')), 'row $i');
        inside(find.byKey(ValueKey('marker-$i')), 'marker $i');
      }
      inside(find.byKey(const ValueKey('marker-answer')), 'answer line');
      expect(t.getRect(find.byKey(const ValueKey('row-7'))).bottom, lessThanOrEqualTo(size.height * 1030 / 1080), reason: 'above the overscan edge');
    });
  }

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
