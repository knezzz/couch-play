import 'dart:math';
import 'dart:typed_data';

import 'package:core/core.dart';

/// Test opponents meant to look like people.
///
/// Purpose: each bot keeps a target (a power-up in reach, else a point in open
/// space) and re-plans only when it is gone, reached, blocked, or after 2-4 s.
/// Danger (a wall or painted cell ahead) overrides the target.
///
/// Human feel: every bot has its own seeded personality, a reaction delay of
/// 150-250 ms (it acts on what it saw that long ago), a minimum time it holds a
/// steer once it changes (150-350 ms), and a small chance per tick of a lapse
/// in which it stops looking for 170-420 ms.
///
/// Ghost ignores trails and wrap ignores walls, both through
/// [CurveSim.isBlocked]. Per-tick state lives in typed lists; nothing is
/// allocated per tick except the head snapshots from `sim.heads`.
class Bots {
  Bots(this.sim, this.ids, this.random) {
    final n = ids.fold(0, max) + 1;
    _rnd = List<Random?>.filled(n, null);
    _react = Int32List(n);
    _hold = Int32List(n);
    _bold = Float64List(n);
    _lapseRate = Float64List(n);
    _lapseUntil = Int32List(n);
    _lastChange = Int32List(n);
    _applied = Int8List(n);
    _sqDir = Int8List(n);
    _sqAt = Int32List(n);
    _lastWant = Int8List(n);
    _replanAt = Int32List(n);
    _calmUntil = Int32List(n);
    _dodgeDir = Int8List(n);
    _dodgeStart = Int32List(n);
    _targetId = Int32List(n);
    _tx = Float64List(n);
    _ty = Float64List(n);
    _ring = Int8List(n * _ringSize);
    _urgent = Uint8List(n * _ringSize);
    for (final id in ids) {
      final r = _rnd[id] = Random(random.nextInt(0x7fffffff));
      _react[id] = 9 + r.nextInt(7); // 150-250 ms at 60 Hz
      _hold[id] = 9 + r.nextInt(12); // 150-350 ms
      _bold[id] = r.nextDouble();
      _lapseRate[id] = 0.0006 + 0.0012 * r.nextDouble(); // about 1 per 10-25 s
      _lastChange[id] = -1000;
      _targetId[id] = -1;
    }
  }

  final CurveSim sim;
  final List<int> ids;
  final Random random; // only seeds each bot's own Random

  late final List<Random?> _rnd;
  late final Int32List _react, _hold, _lapseUntil, _lastChange, _replanAt, _targetId, _calmUntil, _dodgeStart;
  late final Int8List _dodgeDir; // direction of the last dodge
  late final Float64List _bold, _lapseRate, _tx, _ty;
  late final Int8List _applied, _lastWant, _ring; // -1 left, 0 straight, 1 right
  late final Int8List _sqDir; // the press last sent under square turns
  late final Int32List _sqAt; // and when
  late final Uint8List _urgent; // ring slots written by a danger dodge
  bool _dodging = false; // set by _perceive: this decision is a dodge
  int _t = 0;

  static const _ringSize = 32; // power of two, larger than the longest reaction
  // A trail is at least one 4-unit grid cell wide, so sample every 4 units or
  // a probe can step over it.
  static const _step = 4.0, _reach = 140.0, _spread = 0.6;
  // Start past the bot's own freshly painted brush (up to 8 units wide on the
  // grid), or it sees its own tail as an obstacle.
  static const _start = 16.0;
  static const _open = _reach + _step; // clearance of an unblocked probe
  static const _sideSafe = 60.0; // do not steer toward a side with less room

  /// Distance along heading [a] from (x, y) to the first blocked sample.
  double _clearance(double x, double y, double a, bool trails) {
    final dx = cos(a), dy = sin(a);
    for (var d = _start; d <= _reach; d += _step) {
      if (sim.isBlocked(x + dx * d, y + dy * d, trails: trails)) return d;
    }
    return _open;
  }

  void tick() {
    _t++;
    for (final h in sim.heads) {
      final id = h.id;
      if (!h.alive || !ids.contains(id)) continue;
      final r = _rnd[id]!;
      var want = _lastWant[id];
      _dodging = false;
      if (_t >= _lapseUntil[id]) {
        if (r.nextDouble() < _lapseRate[id]) {
          _lapseUntil[id] = _t + 10 + r.nextInt(16); // not looking: keep going
        } else {
          want = _perceive(h, r);
        }
      }
      _lastWant[id] = want;
      _ring[id * _ringSize + (_t & (_ringSize - 1))] = want;
      _urgent[id * _ringSize + (_t & (_ringSize - 1))] = _dodging ? 1 : 0;
      // Act on what it decided _react ticks ago, and hold any change a while.
      // A change must hold steady for 3 ticks of what it saw before it acts.
      final base = id * _ringSize;
      final k = _t - _react[id];
      final out = _ring[base + (k & (_ringSize - 1))];
      final steady = out == _ring[base + ((k - 1) & (_ringSize - 1))] &&
          out == _ring[base + ((k - 2) & (_ringSize - 1))];
      // A dodge does not wait out the steer hold; the reaction delay and the
      // confirmation above still apply.
      final urgent = _urgent[base + (k & (_ringSize - 1))] == 1;
      if (steady &&
          out != _applied[id] &&
          (urgent || _t - _lastChange[id] >= _hold[id])) {
        _applied[id] = out;
        _lastChange[id] = _t;
      }
      var left = _applied[id] < 0, right = _applied[id] > 0;
      if (sim.hasEffect(id, PowerUpKind.squareOthers)) {
        // Square turns: a held button turns only once, so press for one tick
        // when the wish starts and again every quarter second while it stands.
        final a = _applied[id];
        final press = a != 0 && (a != _sqDir[id] || _t - _sqAt[id] >= 15);
        if (press) {
          _sqDir[id] = a;
          _sqAt[id] = _t;
        } else if (a == 0) {
          _sqDir[id] = 0;
        }
        left = press && a < 0;
        right = press && a > 0;
      }
      sim.setInput(id, left: left, right: right);
    }
  }

  int _perceive(CurveHead h, Random r) {
    final trails = !sim.hasEffect(h.id, PowerUpKind.ghost);
    final ahead = _clearance(h.x, h.y, h.heading, trails);
    final left = _clearance(h.x, h.y, h.heading - _spread, trails);
    final right = _clearance(h.x, h.y, h.heading + _spread, trails);
    if (ahead < _open && (left > ahead || right > ahead)) {
      if (_t >= _calmUntil[h.id]) _dodgeStart[h.id] = _t;
      _calmUntil[h.id] = _t + 30;
      _replanAt[h.id] = 0; // fresh target once clear
      // Keep a turn already chosen unless the other side is clearly better:
      // the probes sample every 4 units, so near-equal sides flicker.
      final dir = (left - right).abs() < 16
          ? (_lastWant[h.id] != 0 ? _lastWant[h.id] : (r.nextBool() ? -1 : 1))
          : (left > right ? -1 : 1);
      _dodgeDir[h.id] = dir;
      _dodging = true;
      return dir;
    }
    if (_t < _calmUntil[h.id]) {
      // Dead ahead is open, but keep turning until the side that faced the
      // obstacle is clear too; stopping early left bots aimed at the wall.
      final d = _dodgeDir[h.id];
      final facing = d > 0 ? left : right;
      if (facing < _open && _t < _dodgeStart[h.id] + 90) {
        _calmUntil[h.id] = _t + 10;
        _dodging = true;
        return d;
      }
      return 0;
    }
    _ensureTarget(h, r, trails);
    // Judge the aim by where the heading will be once this decision lands
    // (the turn already under way keeps going for the reaction time).
    final c = sim.config;
    final ahead0 = h.heading + _applied[h.id] * _react[h.id] * c.turnRate / c.tickHz;
    var d = atan2(_ty[h.id] - h.y, _tx[h.id] - h.x) - ahead0;
    d = (d + pi) % (2 * pi) - pi; // -pi..pi; heading grows clockwise
    var want = d.abs() < 0.1 ? 0 : (d > 0 ? 1 : -1);
    if (want > 0 && right < _sideSafe) want = 0;
    if (want < 0 && left < _sideSafe) want = 0;
    return want;
  }

  void _ensureTarget(CurveHead h, Random r, bool trails) {
    final id = h.id;
    var need = _t >= _replanAt[id];
    if (!need) {
      final dx = _tx[id] - h.x, dy = _ty[id] - h.y;
      if (_targetId[id] >= 0) {
        need = !_powerUpExists(_targetId[id]);
      } else {
        need = dx * dx + dy * dy < 40 * 40; // reached
      }
      if (!need && ((_t + id) & 3) == 0) {
        final dist = sqrt(dx * dx + dy * dy);
        need = _clearance(h.x, h.y, atan2(dy, dx), trails) < min(dist, _reach) - 8;
      }
    }
    if (need) _plan(h, r);
  }

  bool _powerUpExists(int puId) {
    for (final p in sim.powerUps) {
      if (p.id == puId) return true;
    }
    return false;
  }

  void _plan(CurveHead h, Random r) {
    final id = h.id;
    final range = 280 + 320 * _bold[id]; // bolder bots notice items farther off
    CurvePowerUp? nearest, other;
    var best = range * range;
    final trails = !sim.hasEffect(id, PowerUpKind.ghost);
    for (final p in sim.powerUps) {
      final d = (p.x - h.x) * (p.x - h.x) + (p.y - h.y) * (p.y - h.y);
      if (d < range * range &&
          _clearance(h.x, h.y, atan2(p.y - h.y, p.x - h.x), trails) <
              min(sqrt(d), _reach) - 8) {
        continue; // something is in the way
      }
      if (d < best) {
        best = d;
        other = nearest;
        nearest = p;
      } else if (d < range * range) {
        other = p;
      }
    }
    // Usually the nearest item; now and then a different one.
    final pick = (other != null && r.nextDouble() < 0.2) ? other : nearest;
    if (pick != null) {
      _targetId[id] = pick.id;
      _tx[id] = pick.x;
      _ty[id] = pick.y;
    } else {
      _targetId[id] = -1;
      _tx[id] = sim.config.arenaW / 2;
      _ty[id] = sim.config.arenaH / 2;
      for (var i = 0; i < 6; i++) {
        final x = 120 + r.nextDouble() * (sim.config.arenaW - 240);
        final y = 120 + r.nextDouble() * (sim.config.arenaH - 240);
        final d2 = (x - h.x) * (x - h.x) + (y - h.y) * (y - h.y);
        if (d2 < 150 * 150 || d2 > 600 * 600) continue;
        if (sim.isBlocked(x, y) ||
            sim.isBlocked(x + 30, y) ||
            sim.isBlocked(x - 30, y) ||
            sim.isBlocked(x, y + 30) ||
            sim.isBlocked(x, y - 30)) {
          continue;
        }
        _tx[id] = x;
        _ty[id] = y;
        break;
      }
    }
    _replanAt[id] = _t + 120 + r.nextInt(121); // 2-4 s
  }
}
