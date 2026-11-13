import 'dart:math';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/curve/curve_game.dart';

void main() {
  test('trail is one subpath unless a gap breaks it', () {
    final sim = CurveSim([0],
        config: const CurveConfig(countdown: 0, gapEveryMin: 1, gapEveryMax: 1, gapLength: 0.5),
        random: Random(1));
    sim.place(0, 400, 450, 0);
    final game = CurveGame(sim, const [Color(0xFFFF0000)]);
    for (var i = 0; i < 60 * 2; i++) {
      game.update(1 / 60);
    }
    // ~2 s with one 0.5 s gap: 2 subpaths, not ~90.
    final n = game.debugSubpathCount(0);
    expect(n, 2);
  });
}
