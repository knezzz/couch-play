import 'dart:math';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/ui/curve/curve_game.dart';

import 'session_test.dart' show join;

/// From the BRAVIA: "Null check operator used on a null value" in the game loop's
/// onBeforeTick (_session.bots!.tick()) after the session had dropped its bots.
void main() {
  Session curveWithBots() {
    final s = Session(random: Random(1));
    final a = join(s, 'Ana', token: 'ta');
    join(s, 'Ben', token: 'tb');
    s.setBotCount(2);
    a.say(const StartGame(GameKind.curve, null));
    expect(s.phase, Phase.curve);
    expect(s.bots, isNotNull);
    return s;
  }

  test('a tick after the game ended does not throw (back to the home, bots gone)', () {
    final s = curveWithBots();
    s.endGame();
    expect(s.phase, isNot(Phase.curve));
    expect(s.bots, isNull);
    expect(s.beforeGameTick, returnsNormally);
    s.dispose();
  });

  test('a tick with no game at all does not throw either', () {
    final s = Session(random: Random(1));
    expect(s.beforeGameTick, returnsNormally);
    s.dispose();
  });

  test('during the game it still counts the countdown and moves the bots', () {
    final s = curveWithBots();
    final head = s.sim!.heads.firstWhere((h) => s.bots!.ids.contains(h.id));
    final before = head.heading;
    for (var i = 0; i < 400; i++) {
      s.beforeGameTick();
      s.sim!.tick();
    }
    // The bots steer: over 400 ticks at least one bot has turned.
    final turned = s.sim!.heads.where((h) => s.bots!.ids.contains(h.id)).any((h) => h.heading != before || !h.alive);
    expect(turned, isTrue);
    s.dispose();
  });

  test('the real game loop: the match ends inside a tick, the loop ticks on, nothing throws', () {
    final s = curveWithBots();
    final game = CurveGame(
      s.sim!,
      const [],
      onBeforeTick: s.beforeGameTick,
      onEvents: (e) {
        s.curveEvents(e);
        s.endGame(); // the session leaves Phase.curve in the middle of the loop
      },
    )..onGameResize(Vector2(1600, 900));
    // Many ticks' worth of time at once: the loop runs several ticks after the end.
    expect(() {
      for (var i = 0; i < 2000; i++) {
        game.update(0.25);
      }
    }, returnsNormally);
    s.dispose();
  });
}
