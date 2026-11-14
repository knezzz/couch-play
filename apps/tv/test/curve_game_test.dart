import 'dart:math';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/curve/curve_game.dart';

void main() {
  test('trail is one subpath unless a gap breaks it', () {
    final sim = CurveSim(
      [0],
      config: const CurveConfig(
        countdown: 0,
        gapEveryMin: 1,
        gapEveryMax: 1,
        gapLength: 0.5,
      ),
      random: Random(1),
    );
    sim.place(0, 400, 450, 0);
    final game = CurveGame(sim, const [Color(0xFFFF0000)]);
    for (var i = 0; i < 60 * 2; i++) {
      game.update(1 / 60);
    }
    // ~2 s with one 0.5 s gap: 2 subpaths, not ~90.
    final n = game.debugSubpathCount(0);
    expect(n, 2);
  });

  test('clear signal resets trail paths and ends', () {
    final sim = _ClearOnce(
      [0],
      config: const CurveConfig(countdown: 0),
      random: Random(1),
    );
    sim.place(0, 400, 450, 0);
    final game = CurveGame(sim, const [Color(0xFFFF0000)]);
    for (var i = 0; i < 10; i++) {
      game.update(1 / 60);
    }
    expect(game.debugPathCount, 1);
    sim.clearNext = true;
    game.update(1 / 60); // clear, then this tick's new segment only
    expect(game.debugPathCount, 1);
    expect(game.debugSubpathCount(0), 1);
    // Only one tick of trail remains: the path is a single short segment.
    final m = game.debugTrailLength(0);
    expect(m, lessThan(3));
  });

  test('renders countdown names, power-ups and trails without throwing', () {
    final sim = CurveSim(
      [0, 1],
      names: {0: 'Ana', 1: 'Luka'},
      random: Random(1),
    );
    sim.placePowerUp(PowerUpKind.clear, 800, 450);
    final game = CurveGame(sim, const [Color(0xFFFF0000), Color(0xFF00FF00)])
      ..onGameResize(Vector2(1920, 1080));
    final canvas = Canvas(PictureRecorder());
    game.render(canvas); // countdown
    for (var i = 0; i < 200; i++) {
      game.update(1 / 60);
    }
    game.render(canvas); // running
  });

  test('name sits above the dot, or below when the arrow points up', () {
    expect(CurveGame.nameTop(450, 12, 50, 0, 900), 450 - 12 - 50); // right: above
    expect(CurveGame.nameTop(450, 12, 50, -pi / 2, 900), 450 + 12); // up: below
    expect(CurveGame.nameTop(450, 12, 50, pi / 2, 900), 450 - 12 - 50); // down: above
    expect(CurveGame.nameTop(880, 12, 50, -pi / 2, 900), 850); // clamped in arena
  });

  test('a very wide name does not throw in render', () {
    final sim = CurveSim([0], names: {0: 'W' * 300}, random: Random(1));
    final game = CurveGame(sim, const [Color(0xFFFF0000)])
      ..onGameResize(Vector2(1920, 1080));
    game.render(Canvas(PictureRecorder())); // countdown
  });
}

class _ClearOnce extends CurveSim {
  _ClearOnce(super.ids, {super.config, super.random});
  bool clearNext = false;
  @override
  bool takeCleared() {
    final c = clearNext;
    clearNext = false;
    return c;
  }
}
