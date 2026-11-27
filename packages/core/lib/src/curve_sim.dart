import 'dart:math';
import 'dart:typed_data';

import 'protocol.dart' show CurveMode;

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
    this.cheeseGapEveryMin = 0.3,
    this.cheeseGapEveryMax = 0.7,
    this.cheeseGapLength = 0.45,
    this.selfGraceTicks = 12,
    this.tickHz = 60,
    this.countdown = 2.0,
    this.powerUps = true,
    this.powerUpEveryMin = 4,
    this.powerUpEveryMax = 8,
    this.powerUpMax = 3,
    this.powerUpRadius = 24,
    this.effectSeconds = 5,
    this.powerUpKinds,
  });

  /// A mode is only a set of these values. [countdown] is the host's setting.
  factory CurveConfig.forMode(CurveMode mode, {double countdown = 2.0}) => switch (mode) {
        // Many, often: a power-up every 1-2.5 s and up to 8 on the board.
        CurveMode.chaos => CurveConfig(
            countdown: countdown, powerUpEveryMin: 1, powerUpEveryMax: 2.5, powerUpMax: 8),
        CurveMode.balanced => CurveConfig(countdown: countdown),
        CurveMode.peaceful => CurveConfig(countdown: countdown, powerUps: false),
        // Only the kinds that act on you: speed up, slow down, ghost, cheese.
        CurveMode.onlyYou => CurveConfig(
            countdown: countdown,
            powerUpKinds: [PowerUpKind.speed, PowerUpKind.slow, PowerUpKind.ghost, PowerUpKind.cheese]),
      };

  final int arenaW, arenaH;
  final double speed, turnRate, lineWidth;
  final int cell;
  final double gapEveryMin, gapEveryMax, gapLength;

  /// While cheese lasts the line has gaps much more often and longer than the
  /// normal random ones: one every 0.3-0.7 s, each 0.45 s (normal: every
  /// 1.5-3.5 s, 0.25 s).
  final double cheeseGapEveryMin, cheeseGapEveryMax, cheeseGapLength;
  final int selfGraceTicks, tickHz;
  final double countdown;

  /// Power-ups: seconds between spawns (min..max, counted after the
  /// countdown), at most [powerUpMax] on the board, picked up within
  /// [powerUpRadius] of a head, effects last [effectSeconds].
  final bool powerUps;
  final double powerUpEveryMin, powerUpEveryMax, powerUpRadius, effectSeconds;
  final int powerUpMax;

  /// Which kinds may spawn; null means all of them.
  final List<PowerUpKind>? powerUpKinds;
}

/// Green ones act on the picker (speed up, slow down, ghost, cheese), red ones
/// on everyone else (speedOthers, slowOthers, fatOthers, reverseOthers,
/// squareOthers), blue ones on the board (clear, wrap).
enum PowerUpKind {
  speed,
  slow,
  ghost,
  cheese,
  speedOthers,
  slowOthers,
  fatOthers,
  reverseOthers,
  squareOthers,
  clear,
  wrap
}

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

/// Sumo's power-ups: heavier, bigger, faster.
enum SumoPower { heavy, big, fast }

/// Sumo: a wrestler dashed (for the sound).
class Dashed extends CurveEvent {
  Dashed(this.id);
  final int id;
}

/// Sumo: two wrestlers hit hard.
class Bumped extends CurveEvent {
  Bumped();
}

/// Sumo: a wrestler took a power-up.
class SumoPickedUp extends CurveEvent {
  SumoPickedUp(this.playerId, this.kind);
  final int playerId;
  final SumoPower kind;
}

/// What the session needs of a head to run a match: who it is and whether it is still in.
abstract interface class RoundHead {
  int get id;
  bool get alive;
}

/// What the session needs of a real-time round game (Curve, Sumo): rounds, scores to a target,
/// a countdown, fixed ticks that return events, and the drop-out hooks. The session and the
/// TV loop never look at anything game-specific through this.
abstract interface class RoundSim {
  Iterable<RoundHead> get heads;

  /// Player names by sim id, for the renderer (the sim itself never reads them).
  Map<int, String> get names;
  Map<int, int> get scores;
  int get target;
  bool get roundOver;
  bool get matchOver;
  bool get countingDown;
  int get tickHz;
  List<CurveEvent> tick();
  void startRound();
  void kill(int id);
  void revive(int id);

  /// Lets go of the controls (a phone that left, or a new round).
  void clearInput(int id);
}

class CurveHead implements RoundHead {
  const CurveHead(this.id, this.x, this.y, this.heading, this.alive, this.inGap);
  @override
  final int id;
  final double x, y, heading;
  @override
  final bool alive;
  final bool inGap;
}

/// [width] is the line width when painted: lineWidth x 1..4 (1 + fat stacks).
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
  /// Speed up (yours or the others') and slow down (yours or the others') can
  /// all run at once: the factors multiply.
  double get speedFactor =>
      (has(PowerUpKind.speed) || has(PowerUpKind.speedOthers) ? _speedUp : 1) *
      (has(PowerUpKind.slow) || has(PowerUpKind.slowOthers) ? _slowDown : 1);

  /// The steering input of the last tick (-1, 0, 1): square turns turn on a new press.
  int lastSteer = 0;

  /// A press that arrived (setInput) since the last tick, even if the button
  /// was released again before the tick: Wi-Fi can batch a tap's press and
  /// release into one frame, and a square turn must not be lost.
  bool pressedLeft = false, pressedRight = false;
  /// Fat pickups running on this head (0 when fat is off), 1..[maxFatStacks].
  int fatStacks = 0;
  double get widthFactor => has(PowerUpKind.fatOthers) ? 1.0 + fatStacks : 1;
}

/// Each fat pickup widens the others' lines by one more line width, up to this.
const maxFatStacks = 3;

const _speedUp = 1.6, _slowDown = 0.6;

class CurveSim implements RoundSim {
  CurveSim(List<int> playerIds,
      {this.config = const CurveConfig(),
      Random? random,
      Map<int, String>? names,

      /// Points that win the match; null = 10 x (players - 1).
      int? target})
      : _random = random ?? Random(),
        names = names ?? const {},
        target = target ?? 10 * (playerIds.length - 1),
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
  @override
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

  @override
  final Map<int, int> scores = {};
  @override
  final int target;
  @override
  bool roundOver = false, matchOver = false;
  int? winner;

  @override
  Iterable<CurveHead> get heads => _heads.values
      .map((h) => CurveHead(h.id, h.x, h.y, h.heading, h.alive, h.inGap));

  @override
  int get tickHz => config.tickHz;

  @override
  void clearInput(int id) => setInput(id, left: false, right: false);

  /// True while the pre-round countdown runs (heads are frozen).
  @override
  bool get countingDown => _countdownLeft > 0;

  Iterable<CurvePowerUp> get powerUps => _powerUps;

  bool hasEffect(int playerId, PowerUpKind kind) {
    if (kind == PowerUpKind.wrap) return _wrapLeft > 0;
    return _heads[playerId]?.has(kind) ?? false;
  }

  /// Fat lasts this much longer than the other effects.
  static const _longFactor = 1.5;

  int _ticksFor(PowerUpKind k) => (config.effectSeconds *
          (k == PowerUpKind.fatOthers ? _longFactor : 1) *
          config.tickHz)
      .round();

  /// Time left on [kind] for [playerId], 1 (just picked up) down to 0; 0 when
  /// it isn't running, the player is unknown, or the kind is [PowerUpKind.clear]
  /// (instant). Wrap is global: any id gets the wrap fraction. Allocates nothing,
  /// so the renderer can ask for every head and kind each frame.
  double effectLeft(int playerId, PowerUpKind kind) {
    if (kind == PowerUpKind.wrap) return wrapLeft;
    final ticks = _heads[playerId]?.fx[kind.index] ?? 0;
    return ticks <= 0 ? 0 : ticks / _ticksFor(kind);
  }

  /// Fat pickups stacked on [playerId] (0 when none, or for any other kind).
  int effectStacks(int playerId, PowerUpKind kind) =>
      kind == PowerUpKind.fatOthers && hasEffect(playerId, kind) ? _heads[playerId]!.fatStacks : 0;

  /// The wrap fraction left, 1 down to 0 (0 when wrap is off).
  double get wrapLeft => _wrapLeft <= 0 ? 0 : _wrapLeft / _ticksFor(PowerUpKind.wrap);

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
    if (left && !h.left) h.pressedLeft = true;
    if (right && !h.right) h.pressedRight = true;
    h.left = left;
    h.right = right;
  }

  @override
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
  @override
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

  @override
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
      h.lastSteer = 0;
      h.pressedLeft = h.pressedRight = false;
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

  int _nextCheeseGap() => ((config.cheeseGapEveryMin +
              _random.nextDouble() * (config.cheeseGapEveryMax - config.cheeseGapEveryMin)) *
          config.tickHz)
      .round();

  int _nextSpawn() => ((config.powerUpEveryMin +
              _random.nextDouble() *
                  (config.powerUpEveryMax - config.powerUpEveryMin)) *
          config.tickHz)
      .round();

  void _emit(CurveEvent e) => (_events ??= <CurveEvent>[]).add(e);

  /// Events of this tick; an empty const list when nothing happened.
  @override
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
        if (f[k] > 0 && --f[k] == 0 && k == PowerUpKind.cheese.index && !h.inGap) {
          h.gapTicks = _nextGap(); // cheese is over: normal gaps again
        }
      }
      final steer = (h.right ? 1 : 0) - (h.left ? 1 : 0);
      final turn = h.has(PowerUpKind.reverseOthers) ? -steer : steer;
      if (h.has(PowerUpKind.squareOthers)) {
        // Square turns: a new press (also switching sides) turns exactly 90
        // degrees at once; a held button then goes straight.
        // A tap whose press and release both came between two ticks still counts.
        final pressed = h.pressedRight && !h.pressedLeft
            ? 1
            : h.pressedLeft && !h.pressedRight
                ? -1
                : (steer != 0 && steer != h.lastSteer ? steer : 0);
        if (pressed != 0) h.heading += (h.has(PowerUpKind.reverseOthers) ? -pressed : pressed) * pi / 2;
      } else {
        h.heading += config.turnRate * dt * turn;
      }
      h.lastSteer = steer;
      h.pressedLeft = h.pressedRight = false;
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
        final cheese = h.has(PowerUpKind.cheese);
        h.gapTicks = h.inGap
            ? ((cheese ? config.cheeseGapLength : config.gapLength) * config.tickHz).round()
            : (cheese ? _nextCheeseGap() : _nextGap());
      }
      if (h.inGap || h.has(PowerUpKind.ghost)) continue; // a ghost paints nothing
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
                  _tick - _paintTick[i] <= _grace(h))) {
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
    final ticks = _ticksFor(kind);
    switch (kind) {
      case PowerUpKind.speed:
      case PowerUpKind.slow:
      case PowerUpKind.ghost:
        picker.fx[kind.index] = ticks;
      case PowerUpKind.cheese:
        picker.fx[kind.index] = ticks;
        // The first hole comes soon, not after the normal gap timer.
        if (!picker.inGap) picker.gapTicks = min(picker.gapTicks, _nextCheeseGap());
      case PowerUpKind.speedOthers:
      case PowerUpKind.slowOthers:
      case PowerUpKind.fatOthers:
      case PowerUpKind.reverseOthers:
      case PowerUpKind.squareOthers:
        for (final h in _heads.values) {
          if (h == picker) continue;
          if (kind == PowerUpKind.fatOthers) {
            h.fatStacks = h.has(kind) ? min(h.fatStacks + 1, maxFatStacks) : 1;
          }
          h.fx[kind.index] = ticks;
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
    final kinds = config.powerUpKinds ?? PowerUpKind.values;
    final kind = kinds[_random.nextInt(kinds.length)];
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
    return _tick - _paintTick[i] > _grace(h);
  }

  /// Own cells this young are harmless. It is a distance in disguise: a wider
  /// line reaches further back along a turn and a slower head covers less
  /// ground per tick, so the tick count scales with width / speed (12 at normal).
  int _grace(_Head h) =>
      (config.selfGraceTicks * h.widthFactor / h.speedFactor).ceil();

  bool _hits(_Head h, bool wrap) {
    final cell = config.cell;
    final cx = h.x ~/ cell, cy = h.y ~/ cell;
    final fat = h.widthFactor > 1;
    if (!wrap) {
      if (h.x < 0 || h.y < 0 || cx >= _cols || cy >= _rows) return true;
      if (fat) {
        // A fat line is wider, so it touches the wall earlier.
        final r = config.lineWidth * h.widthFactor / 2;
        if (h.x - r < 0 || h.y - r < 0 ||
            h.x + r >= config.arenaW || h.y + r >= config.arenaH) {
          return true;
        }
      }
    }
    if (h.has(PowerUpKind.ghost)) return false; // passes trails, not walls
    if (!fat) return _cellKills(cy * _cols + cx, h);
    // Fat: every cell under the wide line. Out-of-grid cells (wrap) are empty.
    final r = config.lineWidth * h.widthFactor / 2;
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
