import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/curve/curve_game.dart';
import 'package:tv/ui/sumo/sumo_game.dart';

/// Task 55: the Sumo field on the TV (boards SumoTv, SumoTvIce).
void main() {
  SumoGame make(SumoSim sim, {double band = CurveGame.bandFraction, bool Function()? hold, void Function(List<CurveEvent>)? onEvents}) =>
      SumoGame(sim, playerColors, bottomBand: band, holdWhen: hold, onEvents: onEvents)..onGameResize(Vector2(1920, 1080));

  SumoSim sim({SumoMap map = SumoMap.classic, double countdown = 0, int n = 4}) => SumoSim(
        [for (var i = 0; i < n; i++) i],
        config: SumoConfig(map: map, countdown: countdown, powerUps: false),
        random: Random(3),
      );

  Future<ByteData> shot(WidgetTester t, SumoGame g) async {
    late ByteData d;
    await t.runAsync(() async {
      final rec = PictureRecorder();
      g.render(Canvas(rec));
      d = (await (await rec.endRecording().toImage(1920, 1080)).toByteData())!;
    });
    return d;
  }

  int px(ByteData d, int x, int y) => d.getUint32((y * 1920 + x) * 4);
  int alpha(ByteData d, int x, int y) => d.getUint8((y * 1920 + x) * 4 + 3);

  testWidgets('it runs the sim on a fixed 60 Hz tick and passes the events on', (t) async {
    final s = sim();
    final seen = <CurveEvent>[];
    final g = make(s, onEvents: seen.addAll);
    s.place(0, 430, 0); // about to fall off
    s.setVelocity(0, 400, 0);
    g.update(1 / 60);
    g.update(1 / 60);
    expect(seen.whereType<Died>().single.id, 0);
    expect(s.heads.firstWhere((h) => h.id == 0).alive, isFalse);
  });

  testWidgets('a long frame catches up at most a quarter second; a hold stops it', (t) async {
    final s = sim(countdown: 100);
    var held = false;
    final g = make(s, hold: () => held);
    g.update(5); // a stall: capped
    expect(g.countdownSeconds, lessThanOrEqualTo(100));
    final left = s.countingDown;
    held = true;
    g.update(1);
    g.update(1);
    expect(s.countingDown, left);
    expect(s.elapsed, 0);
  });

  testWidgets('the countdown number: 2, then 1, then none', (t) async {
    final s = sim(countdown: 2);
    final g = make(s);
    expect(g.countdownSeconds, 2);
    for (var i = 0; i < 60; i++) {
      g.update(1 / 60);
    }
    expect(g.countdownSeconds, 1);
    for (var i = 0; i < 60; i++) {
      g.update(1 / 60);
    }
    expect(g.countdownSeconds, 0);
  });

  testWidgets('the ring is centred above the names strip, with the band free', (t) async {
    final s = sim();
    final g = make(s);
    final d = await shot(t, g);
    // The free height is 1080 x (1 - 0.058); the ring is centred in it.
    final cy = ((1080 * (1 - CurveGame.bandFraction) - SumoGame.hintRoom) / 2).round();
    expect(alpha(d, 960, cy + 6), 255, reason: 'the floor');
    expect(alpha(d, 960, 1070), 0, reason: 'the band under the ring is free for the names');
    expect(alpha(d, 20, 540), 0, reason: 'outside the ring there is the TV background, nothing drawn');
  });

  testWidgets('the ring shows the shrunk edge: a dark floor beyond, the lit floor inside', (t) async {
    final s = sim();
    final g = make(s);
    for (var i = 0; i < 60 * 40; i++) {
      s.tick(); // 40 s: the ring is about half size
    }
    final cy = ((1080 * (1 - CurveGame.bandFraction) - SumoGame.hintRoom) / 2).round();
    final k = min(1920.0, 1080 * (1 - CurveGame.bandFraction) - SumoGame.hintRoom) / (2 * 440 * 1.07);
    final d = await shot(t, g);
    final inside = px(d, 960 + (s.radius * k * 0.5).round(), cy);
    final beyond = px(d, 960 + ((s.radius + 40) * k).round(), cy);
    expect(inside, isNot(beyond), reason: 'the floor changes at the ring edge');
    expect(s.radius, lessThan(300));
  });

  testWidgets('ice and classic look different', (t) async {
    final a = await shot(t, make(sim()));
    final b = await shot(t, make(sim(map: SumoMap.ice)));
    final cy = ((1080 * (1 - CurveGame.bandFraction) - SumoGame.hintRoom) / 2).round();
    expect(px(a, 960 + 300, cy), isNot(px(b, 960 + 300, cy)));
  });

  testWidgets('the winner moment rings the wrestler in white', (t) async {
    final s = sim(n: 2);
    final g = make(s);
    s.place(0, 0, 0);
    s.place(1, 300, 300);
    final plain = await shot(t, g);
    g.ring = {0};
    final ringed = await shot(t, g);
    final cy = ((1080 * (1 - CurveGame.bandFraction) - SumoGame.hintRoom) / 2).round();
    final k = min(1920.0, 1080 * (1 - CurveGame.bandFraction) - SumoGame.hintRoom) / (2 * 440 * 1.07);
    final x = 960, y = cy - ((52 + 22) * k).round(); // the ring's top (radius r + 22), above the wrestler
    expect(px(ringed, x, y), isNot(px(plain, x, y)));
    expect(px(ringed, x, y) >> 8, 0xFFFFFF, reason: 'white');
  });

  testWidgets('every part draws without an exception: power-ups, effects, countdown, 8 wrestlers', (t) async {
    final s = SumoSim([for (var i = 0; i < 8; i++) i],
        config: const SumoConfig(countdown: 2, powerUps: true), random: Random(5));
    final g = SumoGame(s, playerColors, characters: {for (var i = 0; i < 8; i++) i: characterIds[i]}, bottomBand: CurveGame.bandFraction)
      ..onGameResize(Vector2(1920, 1080));
    await shot(t, g); // the countdown
    for (var i = 0; i < 130; i++) {
      s.tick();
    }
    s.placePowerUp(SumoPower.heavy, 100, 100);
    s.placePowerUp(SumoPower.fast, -100, 100);
    s.grant(0, SumoPower.big);
    s.grant(0, SumoPower.heavy);
    s.grant(1, SumoPower.fast);
    await shot(t, g);
    final ice = SumoSim([0, 1, 2], config: const SumoConfig(map: SumoMap.ice, countdown: 0), random: Random(2));
    final gi = make(ice);
    ice.setMove(0, 0, 3);
    for (var i = 0; i < 30; i++) {
      ice.tick();
    }
    await shot(t, gi);
    expect(t.takeException(), isNull);
  });
}
