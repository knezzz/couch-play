import 'dart:math';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/ui/curve/curve_game.dart';
import 'package:tv/ui/curve/name_strip.dart';
import 'package:tv/ui/curve/winner_banner.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 52: the names strip under the field, and the winner moment before the scores.
void main() {
  group('names strip', () {
    Widget strip(List<StripName> names) => MaterialApp(
          home: Scaffold(body: SizedBox(width: 1920, height: 80, child: NameStrip(names: names))),
        );
    final names = [
      const StripName(name: 'Ana', colorIndex: 0, alive: true),
      const StripName(name: 'Bruno', colorIndex: 3, alive: false),
      const StripName(name: 'Cvita', colorIndex: 6, alive: true),
    ];

    testWidgets('every name, in its line colour, at least 44 px, no scores', (t) async {
      await t.pumpWidget(strip(names));
      for (final n in names) {
        final text = t.widget<Text>(find.descendant(of: find.byKey(ValueKey('strip-${n.colorIndex}')), matching: find.byType(Text)));
        expect(text.data, contains(n.name));
        expect(text.style!.color, playerColors[n.colorIndex]);
        expect(text.style!.fontSize, greaterThanOrEqualTo(44));
      }
      expect(find.textContaining(RegExp(r'\d')), findsNothing, reason: 'names only');
    });

    testWidgets('a crashed player keeps place and colour, dimmed to 35% with an x before the name', (t) async {
      await t.pumpWidget(strip(names));
      double opacity(int i) => t.widget<Opacity>(find.byKey(ValueKey('strip-$i'))).opacity;
      expect(opacity(0), 1);
      expect(opacity(3), closeTo(0.35, 0.001));
      final dead = t.widget<Text>(find.descendant(of: find.byKey(const ValueKey('strip-3')), matching: find.byType(Text)));
      expect(dead.data, startsWith('×'));
      expect(dead.style!.color, playerColors[3], reason: 'same colour');
      expect(dead.style!.decoration, isNot(TextDecoration.lineThrough));
      final xs = [for (final i in [0, 3, 6]) t.getTopLeft(find.byKey(ValueKey('strip-$i'))).dx];
      expect(xs, [...xs]..sort(), reason: 'same order');
    });

    test('every line colour reads on the arena background (large text contrast >= 3)', () {
      double lum(Color c) {
        double f(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
      }

      final bg = lum(const Color(0xFF14141E));
      for (final c in playerColors) {
        expect((lum(c) + 0.05) / (bg + 0.05), greaterThanOrEqualTo(3), reason: '$c');
      }
    });

    testWidgets('eight long names still fit one line in 1920 px', (t) async {
      t.view.physicalSize = const Size(1920, 1080);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(strip([
        for (var i = 0; i < 8; i++) StripName(name: 'Dugačkoime$i', colorIndex: i, alive: true),
      ]));
      expect(t.takeException(), isNull);
      expect(t.getSize(find.byType(NameStrip)).width, 1920);
      final line = t.getRect(find.byType(Row).first);
      expect(line.left, greaterThanOrEqualTo(0));
      expect(line.right, lessThanOrEqualTo(1920));
      for (final w in t.widgetList<Text>(find.textContaining('Dugačkoime'))) {
        expect(w.overflow, isNot(TextOverflow.ellipsis), reason: 'whole names, never cut');
      }
    });

    testWidgets('the arena leaves the band free under it', (t) async {
      await t.runAsync(() async {
        final sim = CurveSim([0, 1], names: const {0: 'A', 1: 'B'});
        final game = CurveGame(sim, playerColors, bottomBand: CurveGame.bandFraction)..onGameResize(Vector2(1920, 1080));
        final rec = PictureRecorder();
        game.render(Canvas(rec));
        final d = (await (await rec.endRecording().toImage(1920, 1080)).toByteData())!;
        int alpha(int x, int y) => d.getUint8((y * 1920 + x) * 4 + 3);
        expect(alpha(960, 1000), 255, reason: 'arena');
        expect(alpha(960, 1070), 0, reason: 'the band is free for the names');
        expect(alpha(70, 540), 255, reason: 'the arena is centred');
        expect(alpha(20, 540), 0, reason: 'the arena is narrower than the screen now');
      });
    });
  });

  group('winner moment', () {
    late Session s;
    var at = Duration.zero;

    Future<void> wait(WidgetTester t, int ms) async {
      await t.pump(Duration(milliseconds: ms));
      at += Duration(milliseconds: ms);
    }

    void startMatch() {
      at = Duration.zero;
      s = Session(random: Random(1), clock: () => at);
      final FakePeer a = join(s, 'A', token: 'ta');
      join(s, 'B', token: 'tb');
      a.say(const StartGame(GameKind.curve, null));
    }

    testWidgets('the last crash freezes the field 1.5 s with the winner named, then the scores card', (t) async {
      startMatch();
      expect(Session.momentTime, const Duration(milliseconds: 1500));
      s.sim!.roundOver = true;
      s.curveEvents([Died(1), RoundOver(0)]);
      expect(s.moment, isNotNull);
      expect(s.moment!.ids, [0]);
      expect(s.moment!.tie, isFalse);
      expect(s.moment!.match, isFalse);
      expect(s.roundBreak, isFalse, reason: 'the field stays up first');
      await wait(t, 1400);
      expect(s.moment, isNotNull);
      expect(s.roundBreak, isFalse);
      await wait(t, 100);
      expect(s.moment, isNull);
      expect(s.roundBreak, isTrue, reason: 'then the card, as before');
      s.dispose();
    });

    testWidgets('a tie (both crash on the same tick) names both colours', (t) async {
      startMatch();
      s.sim!.roundOver = true;
      s.curveEvents([Died(0), Died(1), RoundOver(null)]);
      expect(s.moment!.tie, isTrue);
      expect(s.moment!.ids, [0, 1]);
      await wait(t, 1500);
      expect(s.roundBreak, isTrue);
      s.dispose();
    });

    testWidgets('the end of the match shows the match winner first, then the results', (t) async {
      startMatch();
      s.sim!.scores
        ..[0] = 20
        ..[1] = 3;
      s.sim!.matchOver = true;
      s.sim!.roundOver = true;
      s.curveEvents([Died(1), RoundOver(0), MatchOver(0)]);
      expect(s.moment!.match, isTrue);
      expect(s.moment!.ids, [0]);
      expect(s.phase, Phase.curve, reason: 'not the results yet');
      await wait(t, 1500);
      expect(s.phase, Phase.results);
      expect(s.moment, isNull);
      s.dispose();
    });

    testWidgets('Back during the moment ends it: no break and no results later', (t) async {
      startMatch();
      s.sim!.roundOver = true;
      s.curveEvents([Died(1), RoundOver(0)]);
      s.endGame();
      expect(s.moment, isNull);
      await wait(t, 3000);
      expect(s.phase, Phase.lobby);
      expect(s.roundBreak, isFalse);
      s.dispose();
    });

    testWidgets('someone leaving mid-moment ends the match; the late timer does nothing', (t) async {
      startMatch();
      s.sim!.roundOver = true;
      s.curveEvents([Died(1), RoundOver(0)]);
      s.finishGame({0: 1, 1: 0});
      await wait(t, 3000);
      expect(s.phase, Phase.results);
      expect(s.roundBreak, isFalse);
      s.dispose();
    });
  });

  group('winner banner', () {
    Widget banner({required List<StripName> who, bool match = false, bool tie = false}) => MaterialApp(
          home: Scaffold(body: WinnerBanner(who: who, match: match, tie: tie)),
        );

    testWidgets('a round winner: name, colour, the round words', (t) async {
      await t.pumpWidget(banner(who: const [StripName(name: 'Ana', colorIndex: 2, alive: true, character: 'fox')]));
      expect(find.text('Ana'), findsOneWidget);
      expect(t.widget<Text>(find.text('Ana')).style!.color, playerColors[2]);
      expect(find.text('RUNDU OSVAJA'), findsOneWidget);
    });

    testWidgets('the match winner says so', (t) async {
      await t.pumpWidget(banner(who: const [StripName(name: 'Ana', colorIndex: 2, alive: true)], match: true));
      expect(find.text('IGRU OSVAJA'), findsOneWidget);
    });

    testWidgets('a tie says Neriješeno with both names in their colours', (t) async {
      await t.pumpWidget(banner(who: const [
        StripName(name: 'Ana', colorIndex: 0, alive: false),
        StripName(name: 'Bruno', colorIndex: 3, alive: false),
      ], tie: true));
      expect(find.text('Neriješeno'), findsOneWidget);
      expect(t.widget<Text>(find.text('Ana')).style!.color, playerColors[0]);
      expect(t.widget<Text>(find.text('Bruno')).style!.color, playerColors[3]);
    });
  });
}
