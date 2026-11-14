import 'dart:math';
import 'dart:typed_data';

import 'package:core/core.dart';

/// Test opponents. Each tick a bot probes three headings (straight, and 0.6 rad
/// to either side) about 0.7 s ahead against walls and painted cells and steers
/// toward the clearest. If all three are open it heads for a nearby power-up,
/// else it wanders (random steering every 0.3-1 s). Ghost ignores trails; wrap
/// ignores walls (both handled by [CurveSim.isBlocked]).
class Bots {
  Bots(this.sim, this.ids, this.random)
      : _ticksLeft = Int32List(ids.fold(0, max) + 1),
        _dir = Int8List(ids.fold(0, max) + 1);

  final CurveSim sim;
  final List<int> ids;
  final Random random;
  final Int32List _ticksLeft; // wander timer per id
  final Int8List _dir; // -1 left, 0 straight, 1 right: current choice

  // A trail is at least one 4-unit cell wide, so sample every 4 units or a
  // probe can step over it.
  static const _step = 4.0, _reach = 100.0, _spread = 0.6, _seekRange = 260.0;
  static const _open = _reach + _step; // clearance of an unblocked probe

  /// Distance along heading [a] from (x, y) to the first blocked sample.
  double _clearance(double x, double y, double a, bool trails) {
    final dx = cos(a), dy = sin(a);
    for (var d = _step * 2; d <= _reach; d += _step) {
      if (sim.isBlocked(x + dx * d, y + dy * d, trails: trails)) return d;
    }
    return _open;
  }

  void tick() {
    final hz = sim.config.tickHz;
    for (final h in sim.heads) {
      if (!h.alive || !ids.contains(h.id)) continue;
      final trails = !sim.hasEffect(h.id, PowerUpKind.ghost);
      final ahead = _clearance(h.x, h.y, h.heading, trails);
      final left = _clearance(h.x, h.y, h.heading - _spread, trails);
      final right = _clearance(h.x, h.y, h.heading + _spread, trails);
      var dir = 0;
      if (ahead >= _open && left >= _open && right >= _open) {
        dir = _wanderOrSeek(h, hz);
      } else if (ahead < _open && (left > ahead || right > ahead)) {
        // Blocked ahead: take the clearer side; on a tie keep the last turn so
        // it doesn't flip every tick facing a wall head-on.
        if (left == right) {
          dir = _dir[h.id] != 0 ? _dir[h.id] : (random.nextBool() ? -1 : 1);
        } else {
          dir = left > right ? -1 : 1;
        }
      }
      _dir[h.id] = dir;
      sim.setInput(h.id, left: dir < 0, right: dir > 0);
    }
  }

  int _wanderOrSeek(CurveHead h, int hz) {
    CurvePowerUp? best;
    var bestD = _seekRange * _seekRange;
    for (final p in sim.powerUps) {
      final d = (p.x - h.x) * (p.x - h.x) + (p.y - h.y) * (p.y - h.y);
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    if (best != null) {
      var d = atan2(best.y - h.y, best.x - h.x) - h.heading;
      d = (d + pi) % (2 * pi) - pi; // -pi..pi; heading grows clockwise
      return d.abs() < 0.1 ? 0 : (d > 0 ? 1 : -1);
    }
    if (_ticksLeft[h.id] <= 0) {
      _ticksLeft[h.id] = ((0.3 + random.nextDouble() * 0.7) * hz).round();
      return random.nextInt(3) - 1;
    }
    _ticksLeft[h.id]--;
    return _dir[h.id];
  }
}
