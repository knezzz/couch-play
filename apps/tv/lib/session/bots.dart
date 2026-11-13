import 'dart:math';

import 'package:core/core.dart';

/// Test opponents: random steering every 0.3-1 s, and a turn toward the
/// arena centre whenever a wall is within 80 units. They don't dodge trails.
class Bots {
  Bots(this.sim, this.ids, this.random);

  final CurveSim sim;
  final List<int> ids;
  final Random random;
  final Map<int, int> _ticksLeft = {};
  final Map<int, (bool, bool)> _steer = {};

  void tick() {
    final c = sim.config;
    final hz = c.tickHz;
    for (final h in sim.heads) {
      if (!ids.contains(h.id) || !h.alive) continue;
      final nearWall = h.x < 80 || h.x > c.arenaW - 80 || h.y < 80 || h.y > c.arenaH - 80;
      if (nearWall) {
        var d = atan2(c.arenaH / 2 - h.y, c.arenaW / 2 - h.x) - h.heading;
        d = (d + pi) % (2 * pi) - pi; // -pi..pi; heading grows clockwise
        if (d.abs() < 0.1) {
          _steer[h.id] = (false, false);
        } else {
          _steer[h.id] = d > 0 ? (false, true) : (true, false);
        }
        _ticksLeft[h.id] = 0; // pick a fresh random move once clear
      } else if ((_ticksLeft[h.id] ?? 0) <= 0) {
        _ticksLeft[h.id] = ((0.3 + random.nextDouble() * 0.7) * hz).round();
        final r = random.nextInt(3); // 0 left, 1 right, 2 straight
        _steer[h.id] = (r == 0, r == 1);
      } else {
        _ticksLeft[h.id] = _ticksLeft[h.id]! - 1;
      }
      final (left, right) = _steer[h.id]!;
      sim.setInput(h.id, left: left, right: right);
    }
  }
}
