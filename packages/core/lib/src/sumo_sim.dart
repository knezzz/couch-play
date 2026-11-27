import 'dart:math';
import 'dart:typed_data';

import 'curve_sim.dart';
import 'protocol.dart' show SumoMap;

/// The Sumo rules (Task 55). Units: the ring is centred on (0, 0), y grows down the screen,
/// a wrestler is a circle of [wrestlerRadius]. Everything runs on a fixed [tickHz] tick.
class SumoConfig {
  const SumoConfig({
    this.map = SumoMap.classic,
    this.arenaRadius = 440,
    this.wrestlerRadius = 52,
    this.tickHz = 60,
    this.countdown = 2.0,
    this.powerUps = true,
    this.shrinkStart = 20,
    this.shrinkSeconds = 45,
    this.dashSpeed = 800,
    this.dashCooldown = 2.0,
    this.powerUpEveryMin = 4,
    this.powerUpEveryMax = 8,
    this.powerUpMax = 2,
    this.effectSeconds = 5,
  });

  /// The host's settings: the map and whether power-ups appear.
  factory SumoConfig.forSettings(SumoMap map, {required bool powerUps, double countdown = 2.0}) =>
      SumoConfig(map: map, powerUps: powerUps, countdown: countdown);

  final SumoMap map;
  final double arenaRadius, wrestlerRadius;
  final int tickHz;
  final double countdown;
  final bool powerUps;

  /// Seconds of full ring after the countdown, then the seconds the ring takes to shrink to
  /// nothing (so a round where nobody moves ends in a tie at about 65 s).
  final double shrinkStart, shrinkSeconds;

  /// Dash: the speed added in the joystick direction, and the seconds before the next one.
  final double dashSpeed, dashCooldown;
  final double powerUpEveryMin, powerUpEveryMax, effectSeconds;
  final int powerUpMax;
}

class SumoPowerUp {
  const SumoPowerUp(this.id, this.kind, this.x, this.y);
  final int id;
  final SumoPower kind;
  final double x, y;
}

class SumoHead implements RoundHead {
  const SumoHead(this.id, this.x, this.y, this.r, this.alive, this.vx, this.vy);
  @override
  final int id;
  final double x, y, r, vx, vy;
  @override
  final bool alive;
}

class _W {
  _W(this.id);
  final int id;
  double x = 0, y = 0, vx = 0, vy = 0;
  bool alive = true, wantDash = false;
  int dir = 0, force = 0, dashCd = 0;
  final Int32List fx = Int32List(SumoPower.values.length);
  bool has(SumoPower k) => fx[k.index] > 0;
}

// How hard each joystick step pulls (0 = let go).
const _levels = [0.0, 0.45, 0.75, 1.0];
// Grip: how fast a wrestler speeds up, the speed the push alone can reach, and how fast it slows.
const _accelClassic = 1400.0, _capClassic = 420.0, _dampClassic = 3.5;
const _accelIce = 500.0, _capIce = 560.0, _dampIce = 0.45;
const _restitution = 0.85;
const _dashGrace = 12; // ticks (0.2 s) before the recharge ends within which a press is kept
const _heavyMass = 3.0, _bigMass = 1.6, _bigRadius = 1.5, _fastFactor = 1.5, _heavyAccel = 0.85;

class SumoSim implements RoundSim {
  SumoSim(List<int> playerIds, {this.config = const SumoConfig(), Random? random, Map<int, String>? names})
      : _random = random ?? Random(),
        names = names ?? const {},
        target = 10 * (playerIds.length - 1) {
    for (final id in playerIds) {
      _ws.add(_W(id));
      scores[id] = 0;
    }
    startRound();
  }

  final SumoConfig config;

  /// Player names for the renderer; the sim itself never reads them.
  @override
  final Map<int, String> names;
  final Random _random;
  final List<_W> _ws = [];
  final List<_W> _pending = [];
  final Set<int> _gone = {};
  final List<SumoPowerUp> _powerUps = [];
  List<CurveEvent>? _events;
  int _t = 0, _countdownLeft = 0, _dead = 0, _spawnLeft = 0, _nextPowerUpId = 0;
  bool _ice = false;

  @override
  final Map<int, int> scores = {};
  @override
  final int target;
  @override
  bool roundOver = false, matchOver = false;
  int? winner;

  @override
  int get tickHz => config.tickHz;
  @override
  bool get countingDown => _countdownLeft > 0;

  /// True on an ice round (the map, or the draw for Nasumično).
  bool get ice => _ice;

  @override
  Iterable<SumoHead> get heads => _ws.map((w) => SumoHead(w.id, w.x, w.y, _radius(w), w.alive, w.vx, w.vy));

  Iterable<SumoPowerUp> get powerUps => _powerUps;

  /// Seconds of play this round (the countdown does not count).
  double get elapsed => _t / config.tickHz;

  /// The ring's radius now: full for [SumoConfig.shrinkStart] seconds, then it shrinks to nothing.
  double get radius {
    final s = _t - config.shrinkStart * config.tickHz;
    if (s <= 0) return config.arenaRadius;
    final f = 1 - s / (config.shrinkSeconds * config.tickHz);
    return f <= 0 ? 0 : config.arenaRadius * f;
  }

  _W _w(int id) => _ws.firstWhere((w) => w.id == id);
  _W? _wOrNull(int id) {
    for (final w in _ws) {
      if (w.id == id) return w;
    }
    return null;
  }

  double _mass(_W w) => (w.has(SumoPower.heavy) ? _heavyMass : 1) * (w.has(SumoPower.big) ? _bigMass : 1);
  double _radius(_W w) => config.wrestlerRadius * (w.has(SumoPower.big) ? _bigRadius : 1);

  double massOf(int id) => _mass(_w(id));
  double radiusOf(int id) => _radius(_w(id));

  (double, double) velocityOf(int id) {
    final w = _w(id);
    return (w.vx, w.vy);
  }

  int _ticksFor() => (config.effectSeconds * config.tickHz).round();

  /// Time left on [kind] for [id], 1 (just picked up) down to 0.
  double effectLeft(int id, SumoPower kind) {
    final t = _wOrNull(id)?.fx[kind.index] ?? 0;
    return t <= 0 ? 0 : t / _ticksFor();
  }

  /// How much of the Dash recharge is left: 1 just after a dash, 0 when it is ready.
  double dashLeft(int id) {
    final w = _wOrNull(id);
    if (w == null) return 0;
    return w.dashCd / (config.dashCooldown * config.tickHz);
  }

  // --- input ---

  /// The joystick: [dir] 0-15 (0 right, 4 up the screen, counter-clockwise), [force] 0-3.
  void setMove(int id, int dir, int force) {
    final w = _wOrNull(id);
    if (w == null) return;
    w.dir = dir & 15;
    w.force = force.clamp(0, 3);
  }

  /// A Dash press. It is kept until it fires: at the go when pressed in the countdown, or when the
  /// recharge ends when pressed within [_dashGrace] ticks of it (the phone's ring and the TV's count
  /// differ by the trip). A press long before that is dropped, so hammering gives one dash per cooldown.
  void dash(int id) {
    final w = _wOrNull(id);
    if (w == null || !w.alive) return;
    if (countingDown || w.dashCd <= _dashGrace) w.wantDash = true;
  }

  @override
  void clearInput(int id) {
    final w = _wOrNull(id);
    if (w == null) return;
    w.force = 0;
    w.wantDash = false;
  }

  @override
  void kill(int id) {
    final w = _wOrNull(id);
    if (w == null) return;
    _gone.add(id);
    if (!w.alive || roundOver) return;
    w.alive = false;
    _pending.add(w);
  }

  @override
  void revive(int id) => _gone.remove(id);

  // --- test hooks ---

  void place(int id, double x, double y) {
    final w = _w(id);
    w
      ..x = x
      ..y = y;
  }

  void setVelocity(int id, double vx, double vy) {
    final w = _w(id);
    w
      ..vx = vx
      ..vy = vy;
  }

  /// Gives [id] a power-up as if it had picked it up.
  void grant(int id, SumoPower kind) => _w(id).fx[kind.index] = _ticksFor();

  void placePowerUp(SumoPower kind, double x, double y) => _powerUps.add(SumoPowerUp(_nextPowerUpId++, kind, x, y));

  // --- rounds ---

  @override
  void startRound() {
    _t = 0;
    _powerUps.clear();
    _pending.clear();
    _dead = _gone.length;
    roundOver = false;
    _countdownLeft = (config.countdown * config.tickHz).round();
    _spawnLeft = _nextSpawn();
    _ice = switch (config.map) {
      SumoMap.classic => false,
      SumoMap.ice => true,
      SumoMap.random => _random.nextBool(),
    };
    final order = [..._ws]..shuffle(_random);
    final rot = _random.nextDouble() * 2 * pi;
    for (var i = 0; i < order.length; i++) {
      final w = order[i];
      final a = rot + i * 2 * pi / order.length;
      w
        ..x = cos(a) * config.arenaRadius * 0.55
        ..y = sin(a) * config.arenaRadius * 0.55
        ..vx = 0
        ..vy = 0
        ..alive = !_gone.contains(w.id)
        ..force = 0
        ..wantDash = false
        ..dashCd = 0
        ..dir = ((atan2(w.y, -w.x) / (pi / 8)).round()) & 15;
      w.fx.fillRange(0, w.fx.length, 0);
    }
  }

  int _nextSpawn() =>
      ((config.powerUpEveryMin + _random.nextDouble() * (config.powerUpEveryMax - config.powerUpEveryMin)) * config.tickHz)
          .round();

  void _emit(CurveEvent e) => (_events ??= <CurveEvent>[]).add(e);

  @override
  List<CurveEvent> tick() {
    _events = null;
    if (roundOver) return const [];
    if (_countdownLeft > 0) {
      _countdownLeft--;
    } else {
      _step();
    }
    if (_pending.isNotEmpty) _resolve();
    return _events ?? const [];
  }

  void _step() {
    final dt = 1 / config.tickHz;
    _t++;
    final damp = exp(-(_ice ? _dampIce : _dampClassic) * dt);
    final accel = _ice ? _accelIce : _accelClassic, cap = _ice ? _capIce : _capClassic;
    for (final w in _ws) {
      if (!w.alive) continue;
      for (var k = 0; k < w.fx.length; k++) {
        if (w.fx[k] > 0) w.fx[k]--;
      }
      if (w.dashCd > 0) w.dashCd--;
      final a = w.dir * pi / 8, ux = cos(a), uy = -sin(a);
      if (w.wantDash && w.dashCd == 0) {
        w.vx += ux * config.dashSpeed;
        w.vy += uy * config.dashSpeed;
        w.dashCd = (config.dashCooldown * config.tickHz).round();
        w.wantDash = false;
        _emit(Dashed(w.id));
      }
      if (w.force > 0) {
        final f = _levels[w.force];
        final fast = w.has(SumoPower.fast) ? _fastFactor : 1.0;
        final acc = accel * f * fast * (w.has(SumoPower.heavy) ? _heavyAccel : 1.0);
        if (w.vx * ux + w.vy * uy < cap * f * fast) {
          w.vx += ux * acc * dt;
          w.vy += uy * acc * dt;
        }
      }
      w.vx *= damp;
      w.vy *= damp;
      w.x += w.vx * dt;
      w.y += w.vy * dt;
    }
    _collide();
    final ring = radius;
    for (final w in _ws) {
      if (w.alive && (ring <= 0 || w.x * w.x + w.y * w.y > ring * ring)) {
        w.alive = false;
        _pending.add(w);
      }
    }
    if (_powerUps.isNotEmpty) _pickups(ring);
    if (config.powerUps && --_spawnLeft <= 0) {
      _spawn(ring);
      _spawnLeft = _nextSpawn();
    }
  }

  void _collide() {
    var bumped = false;
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < _ws.length; i++) {
        final a = _ws[i];
        if (!a.alive) continue;
        for (var j = i + 1; j < _ws.length; j++) {
          final b = _ws[j];
          if (!b.alive) continue;
          final ra = _radius(a), rb = _radius(b);
          var dx = b.x - a.x, dy = b.y - a.y;
          var d = sqrt(dx * dx + dy * dy);
          if (d >= ra + rb) continue;
          if (d < 1e-6) {
            dx = 1;
            dy = 0;
            d = 1;
          }
          final nx = dx / d, ny = dy / d;
          final ma = _mass(a), mb = _mass(b);
          final over = ra + rb - d;
          a.x -= nx * over * mb / (ma + mb);
          a.y -= ny * over * mb / (ma + mb);
          b.x += nx * over * ma / (ma + mb);
          b.y += ny * over * ma / (ma + mb);
          final vn = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny; // closing speed
          if (vn > 0) {
            final imp = (1 + _restitution) * vn / (1 / ma + 1 / mb);
            a.vx -= imp / ma * nx;
            a.vy -= imp / ma * ny;
            b.vx += imp / mb * nx;
            b.vy += imp / mb * ny;
            if (vn > 250) bumped = true;
          }
        }
      }
    }
    if (bumped) _emit(Bumped());
  }

  void _pickups(double ring) {
    for (var p = _powerUps.length - 1; p >= 0; p--) {
      final pu = _powerUps[p];
      if (pu.x * pu.x + pu.y * pu.y > (ring - 30) * (ring - 30)) {
        _powerUps.removeAt(p); // the ring shrank past it
        continue;
      }
      for (final w in _ws) {
        if (!w.alive) continue;
        final dx = w.x - pu.x, dy = w.y - pu.y, rr = radiusOf(w.id) + 30;
        if (dx * dx + dy * dy <= rr * rr) {
          _powerUps.removeAt(p);
          w.fx[pu.kind.index] = _ticksFor();
          _emit(SumoPickedUp(w.id, pu.kind));
          break;
        }
      }
    }
  }

  void _spawn(double ring) {
    if (_powerUps.length >= config.powerUpMax || ring < 150) return;
    final kind = SumoPower.values[_random.nextInt(SumoPower.values.length)];
    for (var i = 0; i < 10; i++) {
      final a = _random.nextDouble() * 2 * pi, d = sqrt(_random.nextDouble()) * ring * 0.7;
      final x = cos(a) * d, y = sin(a) * d;
      if (_ws.every((w) => !w.alive || (w.x - x) * (w.x - x) + (w.y - y) * (w.y - y) > 120 * 120)) {
        _powerUps.add(SumoPowerUp(_nextPowerUpId++, kind, x, y));
        return;
      }
    }
  }

  void _resolve() {
    // Everyone going out on the same tick ties for the same points.
    for (final w in _pending) {
      scores[w.id] = scores[w.id]! + _dead;
      _emit(Died(w.id));
    }
    _dead += _pending.length;
    _pending.clear();
    final n = _ws.length;
    if (n - _dead > (n > 1 ? 1 : 0)) return;
    roundOver = true;
    final survivor = _ws.where((w) => w.alive).firstOrNull;
    if (survivor != null) scores[survivor.id] = scores[survivor.id]! + _dead;
    _emit(RoundOver(survivor?.id));
    final best = scores.values.fold(0, max);
    final leaders = scores.entries.where((e) => e.value == best);
    if (best >= target && leaders.length == 1) {
      matchOver = true;
      winner = leaders.first.key;
      _emit(MatchOver(winner!));
    }
  }
}
