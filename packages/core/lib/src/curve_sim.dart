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
  });

  final int arenaW, arenaH;
  final double speed, turnRate, lineWidth;
  final int cell;
  final double gapEveryMin, gapEveryMax, gapLength;
  final int selfGraceTicks, tickHz;
  final double countdown;
}

sealed class CurveEvent {}

class Died extends CurveEvent {
  Died(this.id);
  final int id;
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

class TrailSegment {
  const TrailSegment(this.id, this.x1, this.y1, this.x2, this.y2);
  final int id;
  final double x1, y1, x2, y2;
}

class _Head {
  _Head(this.id);
  final int id;
  double x = 0, y = 0, heading = 0;
  bool alive = true, inGap = false, left = false, right = false;
  int gapTicks = 0; // ticks until the gap state toggles
}

class CurveSim {
  CurveSim(List<int> playerIds,
      {this.config = const CurveConfig(), Random? random})
      : _random = random ?? Random(),
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
  final Random _random;
  final int _cols, _rows;
  final Uint16List _owner; // player id + 1, 0 = empty
  final Uint32List _paintTick;
  final Map<int, _Head> _heads = {};
  final List<_Head> _pending = []; // deaths to resolve this tick
  final Set<int> _gone = {}; // killed via kill(): dead for the rest of the match
  var _segments = <TrailSegment>[];
  int _tick = 0, _countdownLeft = 0, _dead = 0;

  final Map<int, int> scores = {};
  final int target;
  bool roundOver = false, matchOver = false;
  int? winner;

  Iterable<CurveHead> get heads => _heads.values
      .map((h) => CurveHead(h.id, h.x, h.y, h.heading, h.alive, h.inGap));

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

  /// Test hook: put a head somewhere specific.
  void place(int id, double x, double y, double heading) {
    _heads[id]!
      ..x = x
      ..y = y
      ..heading = heading;
  }

  void startRound() {
    _owner.fillRange(0, _owner.length, 0);
    _paintTick.fillRange(0, _paintTick.length, 0);
    _segments = <TrailSegment>[];
    _pending.clear();
    _tick = 0;
    _dead = _gone.length; // everyone still racing has outlived them
    roundOver = false;
    _countdownLeft = (config.countdown * config.tickHz).round();
    final placed = <_Head>[];
    for (final h in _heads.values) {
      h.alive = !_gone.contains(h.id);
      h.inGap = false;
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

  List<CurveEvent> tick() {
    final events = <CurveEvent>[];
    if (roundOver) return events;
    _tick++;
    if (_countdownLeft > 0) {
      _countdownLeft--;
    } else {
      _step();
    }
    if (_pending.isNotEmpty) _resolve(events);
    return events;
  }

  void _step() {
    final dt = 1 / config.tickHz;
    final moved = <_Head>[];
    // Pass 1: move and test against the grid as it was before this tick.
    for (final h in _heads.values) {
      if (!h.alive) continue;
      h.heading += config.turnRate * dt * ((h.right ? 1 : 0) - (h.left ? 1 : 0));
      h.x += cos(h.heading) * config.speed * dt;
      h.y += sin(h.heading) * config.speed * dt;
      if (_hits(h)) {
        h.alive = false;
        _pending.add(h);
      } else {
        moved.add(h);
      }
    }
    // Pass 2: survivors paint (unless in a gap) and advance their gap timer.
    final r = config.lineWidth / 2;
    for (final h in moved) {
      if (--h.gapTicks <= 0) {
        h.inGap = !h.inGap;
        h.gapTicks = h.inGap
            ? (config.gapLength * config.tickHz).round()
            : _nextGap();
      }
      if (h.inGap) continue;
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
      final vx = cos(h.heading) * config.speed * dt;
      final vy = sin(h.heading) * config.speed * dt;
      _segments.add(TrailSegment(h.id, h.x - vx, h.y - vy, h.x, h.y));
    }
  }

  bool _hits(_Head h) {
    final cx = h.x ~/ config.cell, cy = h.y ~/ config.cell;
    if (h.x < 0 || h.y < 0 || cx >= _cols || cy >= _rows) return true;
    final i = cy * _cols + cx;
    final o = _owner[i];
    if (o == 0) return false;
    if (o != h.id + 1) return true;
    return _tick - _paintTick[i] > config.selfGraceTicks;
  }

  void _resolve(List<CurveEvent> events) {
    // Everyone dying on the same tick ties for the same points.
    for (final h in _pending) {
      scores[h.id] = scores[h.id]! + _dead;
      events.add(Died(h.id));
    }
    _dead += _pending.length;
    _pending.clear();
    final n = _heads.length;
    if (n - _dead > (n > 1 ? 1 : 0)) return;
    roundOver = true;
    final survivor = _heads.values.where((h) => h.alive).firstOrNull;
    if (survivor != null) scores[survivor.id] = scores[survivor.id]! + _dead;
    events.add(RoundOver(survivor?.id));
    final best = scores.values.fold(0, max);
    final leaders = scores.entries.where((e) => e.value == best);
    if (best >= target && leaders.length == 1) {
      matchOver = true;
      winner = leaders.first.key;
      events.add(MatchOver(winner!));
    }
  }
}
