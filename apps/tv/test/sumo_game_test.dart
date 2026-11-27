import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/curve/curve_game.dart';
import 'package:tv/ui/sumo/sumo_game.dart';

/// Task 55: the Sumo field on the TV (boards SumoTv, SumoTvIce).
/// One frame into a recorder that is finished and released (a bare recorder is left dangling).
void _frame(SumoGame g) {
  final rec = PictureRecorder();
  g.render(Canvas(rec));
  rec.endRecording().dispose();
}

void main() {
  SumoGame make(SumoSim sim, {double band = CurveGame.bandFraction, bool Function()? hold, void Function(List<CurveEvent>)? onEvents}) =>
      SumoGame(sim, playerColors, bottomBand: band, holdWhen: hold, onEvents: onEvents)..onGameResize(Vector2(1920, 1080));

  SumoSim sim({SumoMap map = SumoMap.classic, double countdown = 0, int n = 4}) => SumoSim(
        [for (var i = 0; i < n; i++) i],
        config: SumoConfig(map: map, countdown: countdown, powerUps: false),
        random: Random(3),
      );

  Future<ByteData> shot(WidgetTester t, SumoGame g, [int w = 1920, int h = 1080]) async {
    late ByteData d;
    await t.runAsync(() async {
      final rec = PictureRecorder();
      g.render(Canvas(rec));
      d = (await (await rec.endRecording().toImage(w, h)).toByteData())!;
    });
    return d;
  }

  int px(ByteData d, int x, int y, [int w = 1920]) => d.getUint32((y * w + x) * 4);
  int alpha(ByteData d, int x, int y, [int w = 1920]) => d.getUint8((y * w + x) * 4 + 3);

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
    final cy = (SumoGame.topBar + (1080 * (1 - CurveGame.bandFraction) - SumoGame.topBar - SumoGame.hintRoom) / 2).round();
    expect(alpha(d, 960, cy + 6), 255, reason: 'the floor');
    expect(alpha(d, 960, 1070), 0, reason: 'the band under the ring is free for the names');
    expect(alpha(d, 20, 540), 0, reason: 'outside the ring there is the TV background, nothing drawn');
  });

  testWidgets('the top bar: each player\'s face in its colour, the round and the map, over the ring', (t) async {
    final s = sim(n: 3);
    s.scores[0] = 12;
    final g = SumoGame(s, playerColors, bottomBand: CurveGame.bandFraction)..onGameResize(Vector2(1920, 1080));
    final d = await shot(t, g);
    // Under the bar's height there is something drawn (text and faces), and the ring starts below it.
    var lit = 0;
    for (var x = 0; x < 1920; x += 2) {
      for (var y = 10; y < 78; y += 2) {
        if (alpha(d, x, y) > 0) lit++;
      }
    }
    expect(lit, greaterThan(300), reason: 'text and faces in the bar');
    expect(alpha(d, 960, SumoGame.topBar.toInt() - 6), 0, reason: 'the ring does not reach into the bar');
    // The face of player 0 (colour 0) sits right after the round text: some pixel of that colour in the bar.
    var coloured = 0;
    for (var x = 0; x < 900; x++) {
      for (var y = 30; y < 60; y++) {
        if (px(d, x, y) >> 8 == (playerColors[0].toARGB32() & 0xFFFFFF)) coloured++;
      }
    }
    expect(coloured, greaterThan(50), reason: 'player 0 face colour');
  });

  testWidgets('each face is recorded once per game, not painted anew for every wrestler every frame', (t) async {
    final s = sim(n: 4);
    final g = make(s);
    _frame(g);
    expect(g.debugFaces, 4);
    for (var i = 0; i < 20; i++) {
      _frame(g);
    }
    expect(g.debugFaces, 4);
    s.grant(0, SumoPower.big);
    _frame(g);
    expect(g.debugFaces, 4, reason: 'Velik scales the same picture');
  });

  testWidgets('the recorded pictures are released when the game leaves the screen', (t) async {
    final g = make(sim(n: 3));
    _frame(g);
    expect(g.debugFaces, 3);
    expect(g.debugBar, isNotNull);
    g.onRemove();
    expect(g.debugFaces, 0);
    expect(g.debugBar, isNull);
    g.onRemove(); // twice is harmless
    _frame(g); // and drawing again just records again
    expect(g.debugFaces, 3);
  });

  // The TV reports 1920x1080, or 960x540 (device pixel ratio 2), or a window: the bar is designed on a 1920x1080 box
  // and scales with the view like the ring and the other screens, so nothing overlaps at any of these.
  for (final (w, h) in [(1920.0, 1080.0), (960.0, 540.0), (800.0, 450.0), (800.0, 628.0)]) {
    for (final n in [2, 4, 8]) {
      testWidgets('the top bar with $n players at ${w.toInt()}x${h.toInt()}: nothing overlaps, all inside the view, above the ring', (t) async {
        final s = sim(n: n);
        for (var i = 0; i < n; i++) {
          s.scores[i] = 100 + i; // the widest scores
        }
        final g = SumoGame(s, playerColors, bottomBand: CurveGame.bandFraction)..onGameResize(Vector2(w, h));
        _frame(g);
        final boxes = g.debugBarRects;
        expect(boxes.length, greaterThanOrEqualTo(2 + 2 * n), reason: 'round text, map, a face and a score per player');
        for (var i = 0; i < boxes.length; i++) {
          expect(boxes[i].left, greaterThanOrEqualTo(0), reason: 'box $i');
          expect(boxes[i].right, lessThanOrEqualTo(w), reason: 'box $i inside the view');
          expect(boxes[i].bottom, lessThanOrEqualTo(g.barHeight + 0.5), reason: 'box $i inside the bar');
          for (var j = i + 1; j < boxes.length; j++) {
            expect(boxes[i].overlaps(boxes[j]), isFalse, reason: 'box $i ${boxes[i]} and box $j ${boxes[j]}');
          }
        }
        final scale = min(w / 1920, h / 1080);
        expect(boxes.last.height, lessThanOrEqualTo(60 * scale), reason: 'the map name scales with the view, not a fixed 40 px');
        expect(boxes.last.height, greaterThan(20 * scale), reason: 'and is not shrunk to nothing');
      });
    }
  }

  testWidgets('the ring starts below the bar at a small size too', (t) async {
    final g = SumoGame(sim(n: 2), playerColors, bottomBand: CurveGame.bandFraction)..onGameResize(Vector2(960, 540));
    final d = await shot(t, g, 960, 540);
    for (var y = 0; y < g.barHeight.floor() - 1; y++) {
      expect(alpha(d, 480, y, 960), 0, reason: 'row $y at the middle is empty: only the ring could be there');
    }
    expect(alpha(d, 480, (g.barHeight + 20).round(), 960), 255, reason: 'the ring just below');
  });

  testWidgets('the bar is laid out once: not again frame after frame, redone only on a resize', (t) async {
    final g = make(sim());
    void frame() {
      final rec = PictureRecorder();
      g.render(Canvas(rec));
      rec.endRecording().dispose();
    }

    frame();
    expect(g.debugBarBuilds, 1);
    for (var i = 0; i < 10; i++) {
      frame();
    }
    expect(g.debugBarBuilds, 1);
    g.onGameResize(Vector2(1280, 720));
    frame();
    frame();
    expect(g.debugBarBuilds, 2);
  });

  testWidgets('the ring shows the shrunk edge: a dark floor beyond, the lit floor inside', (t) async {
    final s = sim();
    final g = make(s);
    for (var i = 0; i < 60 * 40; i++) {
      s.tick(); // 40 s: the ring is about half size
    }
    final cy = (SumoGame.topBar + (1080 * (1 - CurveGame.bandFraction) - SumoGame.topBar - SumoGame.hintRoom) / 2).round();
    final k = min(1920.0, 1080 * (1 - CurveGame.bandFraction) - SumoGame.topBar - SumoGame.hintRoom) / (2 * 440 * 1.02);
    final d = await shot(t, g);
    final inside = px(d, 960 + (s.radius * k * 0.5).round(), cy);
    final beyond = px(d, 960 + ((s.radius + 40) * k).round(), cy);
    expect(inside, isNot(beyond), reason: 'the floor changes at the ring edge');
    expect(s.radius, lessThan(300));
  });

  testWidgets('ice and classic look different', (t) async {
    final a = await shot(t, make(sim()));
    final b = await shot(t, make(sim(map: SumoMap.ice)));
    final cy = (SumoGame.topBar + (1080 * (1 - CurveGame.bandFraction) - SumoGame.topBar - SumoGame.hintRoom) / 2).round();
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
    final cy = (SumoGame.topBar + (1080 * (1 - CurveGame.bandFraction) - SumoGame.topBar - SumoGame.hintRoom) / 2).round();
    final k = min(1920.0, 1080 * (1 - CurveGame.bandFraction) - SumoGame.topBar - SumoGame.hintRoom) / (2 * 440 * 1.02);
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
