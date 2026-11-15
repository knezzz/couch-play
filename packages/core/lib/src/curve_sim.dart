import 'dart:math';
import 'dart:typed_data';

class CurveConfig {
  const CurveConfig({
    this.arenaW = 1600,
    this.arenaH = 900,
    this.speed = 140,
    this.turnRate = pi,
    this.lineWidth = 6,
    this.cell = 4,
    this.gapEveryMin = 1.5,
    this.gapEveryMax = 3.5,
    this.gapLength = 0.25,
    this.selfGraceTicks = 12,
    this.tickHz = 60,
    this.countdown = 2.0,
    this.powerUps = true,
    this.powerUpEveryMin = 4,
    this.powerUpEveryMax = 8,
    this.powerUpMax = 3,
    this.powerUpRadius = 24,
    this.effectSeconds = 5,
  });

  final int arenaW, arenaH;
  final double speed, turnRate, lineWidth;
  final int cell;
  final double gapEveryMin, gapEveryMax, gapLength;
  final int selfGraceTicks, tickHz;
  final double countdown;

  /// Power-ups: seconds between spawns (min..max, counted after the
  /// countdown), at most [powerUpMax] on the board, picked up within
  /// [powerUpRadius] of a head, effects last [effectSeconds].
  final bool powerUps;
  final double powerUpEveryMin, powerUpEveryMax, powerUpRadius, effectSeconds;
  final int powerUpMax;
}

enum PowerUpKind { speed, thin, ghost, slowOthers, fatOthers, clear, wrap }

class CurvePowerUp {
  const CurvePowerUp(this.id, this.kind, this.x, this.y);
  final int id;
  final PowerUpKind kind;
  final double x, y;
}

sealed class CurveEvent {}

class Died extends CurveEvent {
  Died(this.id);
  final int id;
}

class PickedUp extends CurveEvent {
  PickedUp(this.playerId, this.kind);
  final int playerId;
  final PowerUpKind kind;
}

class RoundOver extends CurveEvent {
  RoundOver(this.survivorId);
  final int? survivorId;
}

class MatchOver extends CurveEvent {
  MatchOver(this.winnerId);
  final int winnerId;
}

class CurveHead {
  const CurveHead(this.id, this.x, this.y, this.heading, this.alive, this.inGap);
  final int id;
  final double x, y, heading;
  final bool alive, inGap;
}

/// [width] is the line width when painted: lineWidth x 0.5 (thin), 1, or 2 (fat).
class TrailSegment {
  const TrailSegment(this.id, this.x1, this.y1, this.x2, this.y2, [this.width = 6]);
  final int id;
  final double x1, y1, x2, y2, width;
}

class _Head {
  _Head(this.id);
  final int id;
  double x = 0, y = 0, heading = 0;
  bool alive = true, inGap = false, left = false, right = false;
  int gapTicks = 0; // ticks until the gap state toggles
  // Ticks left per PowerUpKind index. wrap is global (see _wrapLeft); clear is
  // instant, so those two slots stay 0.
  final Int32List fx = Int32List(PowerUpKind.values.length);

  bool has(PowerUpKind k) => fx[k.index] > 0;
  double get speedFactor =>
      (has(PowerUpKind.speed) ? _speedUp : 1) *
      (has(PowerUpKind.slowOthers) ? _slowDown : 1);
  double get widthFactor =>
      (has(PowerUpKind.thin) ? 0.5 : 1) * (has(PowerUpKind.fatOthers) ? 2 : 1);
}

const _speedUp = 1.6, _slowDown = 0.6;

class CurveSim {
  CurveSim(List<int> playerIds,
      {this.config = const CurveConfig(),
      Random? random,
      Map<int, String>? names})
      : _random = random ?? Random(),
        names = names ?? const {},
        target = 10 * (playerIds.length - 1),
        _cols = config.arenaW ~/ config.cell,
        _rows = config.arenaH ~/ config.cell,
        _owner = Uint16List((config.arenaW ~/ config.cell) *
            (config.arenaH ~/ config.cell)),
        _paintTick = Uint32List((config.arenaW ~/ config.cell) *
            (config.arenaH ~/ config.cell)) {
    for (final id in playerIds) {
      _heads[id] = _Head(id);
      scores[id] = 0;
    }
    startRound();
  }

  final CurveConfig config;

  /// Player names for the renderer; the sim itself never reads them.
  final Map<int, String> names;
  final Random _random;
  final int _cols, _rows;
  final Uint16List _owner; // player id + 1, 0 = empty
  final Uint32List _paintTick;
  final Map<int, _Head> _heads = {};
  final List<_Head> _pending = []; // deaths to resolve this tick
  final List<_Head> _moved = []; // reused every tick
  final Set<int> _gone = {}; // killed via kill(): dead for the rest of the match
  final List<CurvePowerUp> _powerUps = [];
  var _segments = <TrailSegment>[];
  List<CurveEvent>? _events;
  int _tick = 0, _countdownLeft = 0, _dead = 0;
  int _spawnLeft = 0, _wrapLeft = 0, _nextPowerUpId = 0;
  bool _cleared = false;

  final Map<int, int> scores = {};
  final int target;
  bool roundOver = false, matchOver = false;
  int? winner;

  Iterable<CurveHead> get heads => _heads.values
      .map((h) => CurveHead(h.id, h.x, h.y, h.heading, h.alive, h.inGap));

  /// True while the pre-round countdown runs (heads are frozen).
  bool get countingDown => _countdownLeft > 0;

  Iterable<CurvePowerUp> get powerUps => _powerUps;

  bool hasEffect(int playerId, PowerUpKind kind) {
    if (kind == PowerUpKind.wrap) return _wrapLeft > 0;
    return _heads[playerId]?.has(kind) ?? false;
  }

  int get _effectTicks => (config.effectSeconds * config.tickHz).round();

  /// Time left on [kind] for [playerId], 1 (just picked up) down to 0; 0 when
  /// it isn't running, the player is unknown, or the kind is [PowerUpKind.clear]
  /// (instant). Wrap is global: any id gets the wrap fraction. Allocates nothing,
  /// so the renderer can ask for every head and kind each frame.
  double effectLeft(int playerId, PowerUpKind kind) {
    if (kind == PowerUpKind.wrap) return wrapLeft;
    final ticks = _heads[playerId]?.fx[kind.index] ?? 0;
    return ticks <= 0 ? 0 : ticks / _effectTicks;
  }

  /// The wrap fraction left, 1 down to 0 (0 when wrap is off).
  double get wrapLeft => _wrapLeft <= 0 ? 0 : _wrapLeft / _effectTicks;

  /// True once after a "clear" pickup or a round start, then false. Call it
  /// before [takeNewSegments] in the same frame: segments dropped at the clear
  /// were old trail, anything returned afterwards is new.
  bool takeCleared() {
    final c = _cleared;
    _cleared = false;
    return c;
  }

  List<TrailSegment> takeNewSegments() {
    final out = _segments;
    _segments = <TrailSegment>[];
    return out;
  }

  void setInput(int id, {required bool left, required bool right}) {
    final h = _heads[id];
    if (h == null) return;
    h.left = left;
    h.right = right;
  }

  void kill(int id) {
    final h = _heads[id];
    if (h == null) return;
    _gone.add(id);
    if (!h.alive || roundOver) return;
    h.alive = false;
    _pending.add(h);
  }

  /// Takes [id] back into the match: it races again from the next [startRound]
  /// (this round stays lost). Its score is kept.
  void revive(int id) => _gone.remove(id);

  /// Test hook: put a head somewhere specific.
  void place(int id, double x, double y, double heading) {
    _heads[id]!
      ..x = x
      ..y = y
      ..heading = heading;
  }

  /// Read-only probe for bots: would a head at (x, y) hit the wall or a painted
  /// cell? With wrap active the walls are not deadly. [trails] false ignores
  /// painted cells (ghost).
  bool isBlocked(double x, double y, {bool trails = true}) {
    final w = config.arenaW, hh = config.arenaH;
    if (_wrapLeft > 0) {
      x %= w;
      y %= hh;
    } else if (x < 0 || y < 0 || x >= w || y >= hh) {
      return true;
    }
    return trails && _owner[(y ~/ config.cell) * _cols + (x ~/ config.cell)] != 0;
  }

  /// Test hook: put a power-up on the board (ignores the cap and `powerUps`).
  void placePowerUp(PowerUpKind kind, double x, double y) =>
      _powerUps.add(CurvePowerUp(_nextPowerUpId++, kind, x, y));

  void startRound() {
    _owner.fillRange(0, _owner.length, 0);
    _paintTick.fillRange(0, _paintTick.length, 0);
    _segments = <TrailSegment>[];
    _cleared = true;
    _powerUps.clear();
    _wrapLeft = 0;
    _spawnLeft = _nextSpawn();
    _pending.clear();
    _tick = 0;
    _dead = _gone.length; // everyone still racing has outlived them
    roundOver = false;
    _countdownLeft = (config.countdown * config.tickHz).round();
    final placed = <_Head>[];
    for (final h in _heads.values) {
      h.alive = !_gone.contains(h.id);
      h.inGap = false;
      h.fx.fillRange(0, h.fx.length, 0);
      h.gapTicks = _nextGap();
      // Rejection sampling; after 100 tries accept the spot (tiny arenas).
      for (var i = 0; i < 100; i++) {
        h.x = 100 + _random.nextDouble() * (config.arenaW - 200);
        h.y = 100 + _random.nextDouble() * (config.arenaH - 200);
        if (placed.every((o) => (o.x - h.x) * (o.x - h.x) +
                (o.y - h.y) * (o.y - h.y) >=
            150 * 150)) {
          break;
        }
      }
      h.heading = _random.nextDouble() * 2 * pi;
      placed.add(h);
    }
  }

  int _nextGap() => ((config.gapEveryMin +
              _random.nextDouble() * (config.gapEveryMax - config.gapEveryMin)) *
          config.tickHz)
      .round();

  int _nextSpawn() => ((config.powerUpEveryMin +
              _random.nextDouble() *
                  (config.powerUpEveryMax - config.powerUpEveryMin)) *
          config.tickHz)
      .round();

  void _emit(CurveEvent e) => (_events ??= <CurveEvent>[]).add(e);

  /// Events of this tick; an empty const list when nothing happened.
  List<CurveEvent> tick() {
    _events = null;
    if (roundOver) return const [];
    _tick++;
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
    final wrap = _wrapLeft > 0;
    final w = config.arenaW.toDouble(), hh = config.arenaH.toDouble();
    _moved.clear();
    // Pass 1: move and test against the grid as it was before this tick.
    for (final h in _heads.values) {
      if (!h.alive) continue;
      final f = h.fx;
      for (var k = 0; k < f.length; k++) {
        if (f[k] > 0) f[k]--;
      }
      h.heading += config.turnRate * dt * ((h.right ? 1 : 0) - (h.left ? 1 : 0));
      final step = config.speed * h.speedFactor * dt;
      h.x += cos(h.heading) * step;
      h.y += sin(h.heading) * step;
      if (wrap) {
        if (h.x < 0) {
          h.x += w;
        } else if (h.x >= w) {
          h.x -= w;
        }
        if (h.y < 0) {
          h.y += hh;
        } else if (h.y >= hh) {
          h.y -= hh;
        }
      }
      if (_hits(h, wrap)) {
        h.alive = false;
        _pending.add(h);
      } else {
        _moved.add(h);
      }
    }
    if (_wrapLeft > 0) _wrapLeft--;
    // Pass 2: survivors paint (unless in a gap) and advance their gap timer.
    for (final h in _moved) {
      if (--h.gapTicks <= 0) {
        h.inGap = !h.inGap;
        h.gapTicks = h.inGap
            ? (config.gapLength * config.tickHz).round()
            : _nextGap();
      }
      if (h.inGap) continue;
      final width = config.lineWidth * h.widthFactor;
      final r = width / 2;
      final c0 = max(0, ((h.x - r) / config.cell).floor());
      final c1 = min(_cols - 1, ((h.x + r) / config.cell).floor());
      final r0 = max(0, ((h.y - r) / config.cell).floor());
      final r1 = min(_rows - 1, ((h.y + r) / config.cell).floor());
      for (var cy = r0; cy <= r1; cy++) {
        for (var cx = c0; cx <= c1; cx++) {
          final i = cy * _cols + cx;
          // Own cells are refreshed only while fresh; re-stamping old ones
          // made a line immune to its own old trail.
          if (_owner[i] == 0 ||
              (_owner[i] == h.id + 1 &&
                  _tick - _paintTick[i] <= config.selfGraceTicks)) {
            _owner[i] = h.id + 1;
            _paintTick[i] = _tick;
          }
        }
      }
      // After a wrap the start lies just outside the arena on the far side,
      // so the segment stays short instead of crossing the whole board.
      final vx = cos(h.heading) * config.speed * h.speedFactor * dt;
      final vy = sin(h.heading) * config.speed * h.speedFactor * dt;
      _segments.add(TrailSegment(h.id, h.x - vx, h.y - vy, h.x, h.y, width));
    }
    // Pass 3: pickups, then spawns (spawn timer runs only after the countdown).
    if (_powerUps.isNotEmpty) _pickups();
    if (config.powerUps && --_spawnLeft <= 0) {
      _spawn();
      _spawnLeft = _nextSpawn();
    }
  }

  void _pickups() {
    final r2 = config.powerUpRadius * config.powerUpRadius;
    for (var p = _powerUps.length - 1; p >= 0; p--) {
      final pu = _powerUps[p];
      for (final h in _moved) {
        final dx = h.x - pu.x, dy = h.y - pu.y;
        if (dx * dx + dy * dy <= r2) {
          _powerUps.removeAt(p);
          _apply(h, pu.kind);
          _emit(PickedUp(h.id, pu.kind));
          break;
        }
      }
    }
  }

  void _apply(_Head picker, PowerUpKind kind) {
    final ticks = (config.effectSeconds * config.tickHz).round();
    switch (kind) {
      case PowerUpKind.speed:
      case PowerUpKind.thin:
      case PowerUpKind.ghost:
        picker.fx[kind.index] = ticks;
      case PowerUpKind.slowOthers:
      case PowerUpKind.fatOthers:
        for (final h in _heads.values) {
          if (h != picker) h.fx[kind.index] = ticks;
        }
      case PowerUpKind.wrap:
        _wrapLeft = ticks;
      case PowerUpKind.clear:
        _owner.fillRange(0, _owner.length, 0);
        _paintTick.fillRange(0, _paintTick.length, 0);
        _segments = <TrailSegment>[]; // pre-clear trail the renderer has not seen
        _cleared = true;
    }
  }

  void _spawn() {
    if (_powerUps.length >= config.powerUpMax) return;
    final kind = PowerUpKind.values[_random.nextInt(PowerUpKind.values.length)];
    final keep = config.powerUpRadius * 3;
    for (var i = 0; i < 10; i++) {
      final x = 60 + _random.nextDouble() * (config.arenaW - 120);
      final y = 60 + _random.nextDouble() * (config.arenaH - 120);
      var free = true;
      for (final h in _heads.values) {
        if (h.alive && (h.x - x) * (h.x - x) + (h.y - y) * (h.y - y) < keep * keep) {
          free = false;
          break;
        }
      }
      if (free) {
        _powerUps.add(CurvePowerUp(_nextPowerUpId++, kind, x, y));
        return;
      }
    }
  }

  // A cell kills unless it is empty or the player's own fresh trail.
  bool _cellKills(int i, _Head h) {
    final o = _owner[i];
    if (o == 0) return false;
    if (o != h.id + 1) return true;
    return _tick - _paintTick[i] > config.selfGraceTicks;
  }

  bool _hits(_Head h, bool wrap) {
    final cell = config.cell;
    final cx = h.x ~/ cell, cy = h.y ~/ cell;
    final fat = h.widthFactor > 1;
    if (!wrap) {
      if (h.x < 0 || h.y < 0 || cx >= _cols || cy >= _rows) return true;
      if (fat) {
        // A fat line has radius lineWidth, so it touches the wall earlier.
        final r = config.lineWidth;
        if (h.x - r < 0 || h.y - r < 0 ||
            h.x + r >= config.arenaW || h.y + r >= config.arenaH) {
          return true;
        }
      }
    }
    if (h.has(PowerUpKind.ghost)) return false; // passes trails, not walls
    if (!fat) return _cellKills(cy * _cols + cx, h);
    // Fat: every cell under the wide line. Out-of-grid cells (wrap) are empty.
    final r = config.lineWidth;
    final c0 = max(0, ((h.x - r) / cell).floor());
    final c1 = min(_cols - 1, ((h.x + r) / cell).floor());
    final r0 = max(0, ((h.y - r) / cell).floor());
    final r1 = min(_rows - 1, ((h.y + r) / cell).floor());
    for (var y = r0; y <= r1; y++) {
      for (var x = c0; x <= c1; x++) {
        if (_cellKills(y * _cols + x, h)) return true;
      }
    }
    return false;
  }

  void _resolve() {
    // Everyone dying on the same tick ties for the same points.
    for (final h in _pending) {
      scores[h.id] = scores[h.id]! + _dead;
      _emit(Died(h.id));
    }
    _dead += _pending.length;
    _pending.clear();
    final n = _heads.length;
    if (n - _dead > (n > 1 ? 1 : 0)) return;
    roundOver = true;
    final survivor = _heads.values.where((h) => h.alive).firstOrNull;
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
