import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/curve/curve_game.dart';
import 'package:tv/ui/curve/name_strip.dart';
import 'package:tv/ui/curve/round_break_card.dart';
import 'package:tv/ui/curve/winner_banner.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 52 follow-up: points of the round on the winner screen, the tie-at-the-top line,
/// the countdown number's contrast and the sofa text sizes.
void main() {
  group('round points', () {
    late Session s;
    late FakePeer a;
    var at = Duration.zero;

    void startMatch() {
      at = Duration.zero;
      s = Session(random: Random(1), clock: () => at);
      a = join(s, "A", token: "ta");
      join(s, 'B', token: 'tb');
      join(s, 'C', token: 'tc');
      a.say(const StartGame(GameKind.curve, null));
    }

    testWidgets('the moment carries what each player scored in this round only', (t) async {
      startMatch();
      s.sim!.scores
        ..[0] = 2
        ..[1] = 1
        ..[2] = 0;
      s.sim!.roundOver = true;
      s.curveEvents([Died(2), Died(1), RoundOver(0)]);
      expect(s.moment!.points, {0: 2, 1: 1, 2: 0});
      s.nextRound(); // by hand: the moment ends, round 2 starts
      expect(s.moment, isNull);
      s.sim!.scores
        ..[0] = 3
        ..[1] = 3
        ..[2] = 0;
      s.sim!.roundOver = true;
      s.curveEvents([Died(2), Died(0), RoundOver(1)]);
      expect(s.moment!.points, {0: 1, 1: 2, 2: 0}, reason: 'against the scores at the start of round 2');
      await t.pump(Session.momentTime);
      s.dispose();
    });

    testWidgets('a new match starts from zero again', (t) async {
      startMatch();
      s.sim!.scores
        ..[0] = 2
        ..[1] = 1;
      s.sim!.roundOver = true;
      s.curveEvents([Died(2), Died(1), RoundOver(0)]);
      await t.pump(Session.momentTime);
      s.endGame();

      a.say(const StartGame(GameKind.curve, null));
      s.sim!.scores[0] = 1;
      s.sim!.roundOver = true;
      s.curveEvents([Died(1), Died(2), RoundOver(0)]);
      expect(s.moment!.points[0], 1);
      await t.pump(Session.momentTime);
      s.dispose();
    });
  });

  group('winner banner rows', () {
    Widget banner(List<StripName> who, List<StripName> others, {bool tie = false}) => MaterialApp(
          home: Scaffold(body: WinnerBanner(who: who, others: others, tie: tie)),
        );
    const ana = StripName(name: 'Ana', colorIndex: 0, alive: true);

    testWidgets('every other player: place, name in colour, +N this round; equal points share a place', (t) async {
      t.view
        ..physicalSize = const Size(1920, 1080)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(banner([ana], const [
        StripName(name: 'Bruno', colorIndex: 3, alive: false, points: 2, place: 2),
        StripName(name: 'Cvita', colorIndex: 6, alive: false, points: 2, place: 2),
        StripName(name: 'Dora', colorIndex: 1, alive: false, points: 0, place: 4),
      ]));
      expect(find.byKey(const ValueKey('moment-row-3')), findsOneWidget);
      expect(find.text('+2'), findsNWidgets(2));
      expect(find.text('+0'), findsOneWidget);
      expect(find.text('2.'), findsNWidgets(2), reason: 'a shared place');
      expect(find.text('4.'), findsOneWidget);
      expect(t.widget<Text>(find.text('Bruno')).style!.color, playerColors[3]);
      for (final w in t.widgetList<Text>(find.descendant(of: find.byKey(const ValueKey('moment-row-3')), matching: find.byType(Text)))) {
        expect(w.style!.fontSize, greaterThanOrEqualTo(40));
      }
    });

    testWidgets('eight players fit the screen', (t) async {
      t.view
        ..physicalSize = const Size(1920, 1080)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(banner([ana], [
        for (var i = 1; i < 8; i++) StripName(name: 'Igrac$i', colorIndex: i, alive: false, points: 8 - i, place: i + 1),
      ]));
      final r = t.getRect(find.byKey(const ValueKey('winner-banner')));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(1030));
    });

    testWidgets('a tie lists the others too', (t) async {
      t.view
        ..physicalSize = const Size(1920, 1080)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(banner(const [
        StripName(name: 'Ana', colorIndex: 0, alive: false),
        StripName(name: 'Bruno', colorIndex: 3, alive: false),
      ], const [
        StripName(name: 'Cvita', colorIndex: 6, alive: false, points: 0, place: 3),
      ], tie: true));
      expect(find.text('Neriješeno'), findsOneWidget);
      expect(find.text('Cvita'), findsOneWidget);
      expect(find.text('+0'), findsOneWidget);
    });
  });

  group('break card', () {
    Widget card({bool tiedAtTop = false}) => MaterialApp(
          home: RoundBreakCard(
            round: 3,
            target: 30,
            tiedAtTop: tiedAtTop,
            remaining: () => const Duration(seconds: 3),
            players: const [
              BreakPlayer(name: 'Ana', colorIndex: 0, score: 31),
              BreakPlayer(name: 'Ben', colorIndex: 1, score: 31),
            ],
          ),
        );

    testWidgets('a tie at the top says why play goes on', (t) async {
      t.view
        ..physicalSize = const Size(1920, 1080)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(card(tiedAtTop: true));
      expect(find.text('Izjednačeno na vrhu – igra se dalje'), findsOneWidget);
      expect(Strings.curveTopTie, 'Izjednačeno na vrhu – igra se dalje');
      await t.pumpWidget(card());
      expect(find.text(Strings.curveTopTie), findsNothing);
    });

    testWidgets('the target line is at least 40 px', (t) async {
      t.view
        ..physicalSize = const Size(1920, 1080)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(card());
      expect(t.widget<Text>(find.text(Strings.curveBreakTarget(30))).style!.fontSize, greaterThanOrEqualTo(40));
    });
  });

  group('countdown', () {
    double lum(Color c) {
      double f(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    test('the big number reads on the arena (contrast >= 7:1)', () {
      final bg = lum(const Color(0xFF14141E));
      expect((lum(CurveGame.countdownColor) + 0.05) / (bg + 0.05), greaterThanOrEqualTo(7));
    });

    test('the hint is at least 40 px on a 1080p screen (arena scale x1.13)', () {
      const scale = 1080 * (1 - CurveGame.bandFraction) / 900;
      expect(CurveGame.hintSize * scale, greaterThanOrEqualTo(40));
    });
  });
}
