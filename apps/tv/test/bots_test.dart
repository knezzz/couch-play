import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/bots.dart';

void main() {
  test('bots_turn_away_from_walls', () {
    // Head 70 units from the left wall, flying straight at it.
    for (final startY in [450.0, 60.0, 840.0]) {
      final sim = CurveSim([1, 2], random: Random(1));
      final bots = Bots(sim, [1], Random(2));
      sim.place(1, 70, startY, pi);
      sim.place(2, 1500, 450, 0);
      for (var i = 0; i < 100; i++) {
        bots.tick();
        sim.tick();
      }
      final h = sim.heads.firstWhere((h) => h.id == 1);
      expect(h.alive, isTrue, reason: 'startY=$startY');
    }
  });
}
