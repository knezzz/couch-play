import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/curve/curve_game.dart';

/// TvCountdown (docs/design/couchplay-screens/TvCountdown.dc.html): a big faint number in the
/// middle, each player's name on a dark pill with their face, an arrow from the head, and a
/// line at the bottom that says what to do.
const _pill = Color(0xFF1F1F2C), _digit = Color(0xFF2A2A3A), _muted = Color(0xFFA9A9BC), _ink = Color(0xFFF4F4F8);

CurveGame _game({int countdown = 3, Map<int, String> characters = const {0: 'fox', 1: 'owl'}}) {
  final sim = CurveSim([0, 1],
      config: CurveConfig(countdown: countdown.toDouble(), gapEveryMin: 1e6, gapEveryMax: 1e6 + 1, powerUps: false),
      random: Random(2),
      names: const {0: 'Ana', 1: 'Luka'});
  sim.place(0, 400, 300, 0);
  sim.place(1, 1200, 600, pi);
  return CurveGame(sim, const [Color(0xFFFF4D6D), Color(0xFFFFB020)], characters: characters)..onGameResize(Vector2(1600, 900));
}

Future<ByteData> _render(CurveGame g) async {
  final rec = PictureRecorder();
  g.render(Canvas(rec));
  final img = await rec.endRecording().toImage(1600, 900);
  return (await img.toByteData())!;
}

int _count(ByteData d, Color c, {int x0 = 0, int y0 = 0, int x1 = 1600, int y1 = 900}) {
  var n = 0;
  for (var y = y0; y < y1; y += 2) {
    for (var x = x0; x < x1; x += 2) {
      final i = (y * 1600 + x) * 4;
      if (d.getUint8(i) == (c.r * 255).round() && d.getUint8(i + 1) == (c.g * 255).round() && d.getUint8(i + 2) == (c.b * 255).round()) n++;
    }
  }
  return n;
}

void _tick(CurveGame g, int n) {
  for (var i = 0; i < n; i++) {
    g.update(1 / 60);
  }
}

void main() {
  testWidgets('the number in the middle counts down 3, 2, 1 and goes when the round starts', (t) async {
    final g = _game();
    expect(g.countdownSeconds, 3);
    _tick(g, 61);
    expect(g.countdownSeconds, 2);
    _tick(g, 60);
    expect(g.countdownSeconds, 1);
    _tick(g, 70);
    expect(g.countdownSeconds, 0, reason: 'the round has started');
  });

  testWidgets('the big number is drawn faint in the middle, only while counting', (t) async {
    await t.runAsync(() async {
      final g = _game();
      var d = await _render(g);
      expect(_count(d, _digit, x0: 500, y0: 150, x1: 1100, y1: 600), greaterThan(500), reason: 'a faint number in the middle');
      _tick(g, 200);
      d = await _render(g);
      expect(_count(d, _digit, x0: 500, y0: 150, x1: 1100, y1: 600), 0, reason: 'gone when the round runs');
    });
  });

  testWidgets('each name sits on a dark pill with the face in it, the name itself in the text colour', (t) async {
    await t.runAsync(() async {
      final g = _game();
      final d = await _render(g);
      // Above the first head at (400, 300).
      expect(_count(d, _pill, x0: 200, y0: 160, x1: 700, y1: 300), greaterThan(800), reason: 'the pill behind Ana');
      expect(_count(d, _ink, x0: 200, y0: 160, x1: 700, y1: 300), greaterThan(100), reason: 'the name is not in the player colour any more');
      // The pill is the full-round shape: its left end is a half circle, so a corner of its box is empty.
      expect(_count(d, _pill, x0: 200, y0: 160, x1: 700, y1: 300), lessThan(60000));
    });
  });

  testWidgets('a line at the bottom says what to do; it goes with the countdown', (t) async {
    await t.runAsync(() async {
      final g = _game();
      var d = await _render(g);
      expect(_count(d, _muted, x0: 0, y0: 800, x1: 1600, y1: 900), greaterThan(200), reason: 'the hint');
      _tick(g, 200);
      d = await _render(g);
      expect(_count(d, _muted, x0: 0, y0: 800, x1: 1600, y1: 900), 0);
    });
  });

  testWidgets('the start arrow and the dot stay in the player\'s colour', (t) async {
    await t.runAsync(() async {
      final g = _game();
      final d = await _render(g);
      expect(_count(d, const Color(0xFFFF4D6D), x0: 380, y0: 280, x1: 560, y1: 320), greaterThan(20));
    });
  });

  testWidgets('a name never goes into the hint band at the bottom, wherever the player starts', (t) async {
    await t.runAsync(() async {
      for (final heading in [pi / 2, -pi / 2, 0.0]) {
        final g = _game();
        g.sim.place(0, 800, 880, heading); // right at the bottom
        final d = await _render(g);
        expect(_count(d, _pill, x0: 0, y0: 900 - 80, x1: 1600, y1: 900), 0, reason: 'heading $heading: the pill is clear of the hint band');
        expect(_count(d, _muted, x0: 0, y0: 800, x1: 1600, y1: 900), greaterThan(200), reason: 'the hint is still drawn');
      }
    });
  });
}
