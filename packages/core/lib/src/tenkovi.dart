import 'dart:math';
import 'dart:typed_data';

// Tenkovi rules: a side view, y goes UP (0 is the bottom edge). Pure and
// deterministic: the same seed and the same inputs give the same volley, tick
// by tick. No Flutter, no clock: the TV calls [TenkoviRound.tick] at 60 Hz.

enum TenkoviMap { earth, moon, mars }

enum TenkoviShell { grenade, heavy, cluster, bomblet }

/// The host's choice of map: one of the three, or a new one every round.
enum TenkoviMapPick { earth, moon, mars, random }

extension TenkoviMapRules on TenkoviMap {
  /// px/s^2 downwards.
  double get gravity => switch (this) {
        TenkoviMap.earth => 600,
        TenkoviMap.moon => 240,
        TenkoviMap.mars => 380,
      };

  /// Wind strength in steps of -10..10 (sign = direction), drawn every turn:
  /// Zemlja 0-5, Mjesec none, Mars 5-10.
  (int, int) get windSteps => switch (this) {
        TenkoviMap.earth => (0, 5),
        TenkoviMap.moon => (0, 0),
        TenkoviMap.mars => (5, 10),
      };
}

/// What one player sends with Pucaj.
class TenkoviAim {
  const TenkoviAim(this.angle, this.power, this.shell);

  /// 0 right, 90 up, 180 left.
  final int angle;

  /// 0-100.
  final int power;
  final TenkoviShell shell;

  @override
  bool operator ==(Object o) =>
      o is TenkoviAim && o.angle == angle && o.power == power && o.shell == shell;
  @override
  int get hashCode => Object.hash(angle, power, shell);
}

class TenkoviTank {
  TenkoviTank(this.id, this.x);
  final int id;
  final int x;
  int hp = Tenkovi.maxHp;

  /// Ground height under the tank (it follows the terrain).
  double y = 0;
  bool get alive => hp > 0;

  /// Left at 1 each of the two special shells; refilled every round.
  bool heavyLeft = true, clusterLeft = true;
}

class TenkoviShot {
  TenkoviShot(this.owner, this.shell, this.x, this.y, this.vx, this.vy);
  final int owner;
  final TenkoviShell shell;
  double x, y, vx, vy;
  int age = 0;
}

sealed class TenkoviEvent {}

class TkFired extends TenkoviEvent {
  TkFired(this.id, this.shell);
  final int id;
  final TenkoviShell shell;
}

class TkSplit extends TenkoviEvent {
  TkSplit(this.x, this.y);
  final double x, y;
}

class TkBlast extends TenkoviEvent {
  TkBlast(this.x, this.y, this.radius, this.shell);
  final double x, y, radius;
  final TenkoviShell shell;
}

class TkHurt extends TenkoviEvent {
  TkHurt(this.id, this.damage, this.by);
  final int id, damage;

  /// The shooter; equal to [id] for your own shot.
  final int by;
}

class TkKnockout extends TenkoviEvent {
  TkKnockout(this.id);
  final int id;
}

class TkVolleyDone extends TenkoviEvent {
  TkVolleyDone(this.over);

  /// One tank or none is left.
  final bool over;
}

class Tenkovi {
  static const w = 1600, h = 900, tickHz = 60;
  static const maxHp = 100;
  static const tankR = 22.0;
  static const barrel = 30.0;
  static const powerToSpeed = 10.0;
  static const windAccel = 8.0;

  /// (blast radius, damage at a direct hit, falloff distance) per shell.
  static (double, int, double) blast(TenkoviShell s) => switch (s) {
        TenkoviShell.grenade => (40, 50, 70),
        TenkoviShell.heavy => (70, 75, 100),
        TenkoviShell.cluster => (40, 50, 70), // never explodes itself
        TenkoviShell.bomblet => (22, 20, 40),
      };
}

/// One round: terrain, tanks, the pending aims and a volley in flight.
class TenkoviRound {
  TenkoviRound(List<int> ids, this.map, Random rng) : _rng = rng {
    final order = [...ids]..shuffle(rng);
    final p1 = rng.nextDouble() * 2 * pi, p2 = rng.nextDouble() * 2 * pi;
    final p3 = rng.nextDouble() * 2 * pi;
    final base = 260 + rng.nextDouble() * 120;
    for (var x = 0; x < Tenkovi.w; x++) {
      ground[x] = base +
          70 * sin(x / 230 + p1) +
          45 * sin(x / 97 + p2) +
          20 * sin(x / 41 + p3);
    }
    for (var i = 0; i < order.length; i++) {
      final cx = (Tenkovi.w * (i + 0.5) / order.length).round();
      final t = TenkoviTank(order[i], cx)..y = ground[cx];
      // A flat pad under the tank.
      for (var x = max(0, cx - 24); x <= min(Tenkovi.w - 1, cx + 24); x++) {
        ground[x] = t.y;
      }
      tanks.add(t);
    }
    newTurn();
  }

  final TenkoviMap map;
  final Random _rng;

  /// Ground height per column.
  final Float64List ground = Float64List(Tenkovi.w);
  final tanks = <TenkoviTank>[];
  final projectiles = <TenkoviShot>[];

  /// The aims waiting for the volley; never leave the TV before it fires.
  final aims = <int, TenkoviAim>{};

  /// -10..10, negative blows left. The coming turn's wind.
  int wind = 0;
  int volleys = 0;

  /// Tanks knocked out, by volley number (1-based); the same number is a tie.
  final outAt = <int, int>{};

  /// Bumped for every crater: the TV redraws the ground only when this changes.
  int terrainVersion = 0;

  /// True while shells are in the air.
  bool get flying => projectiles.isNotEmpty;
  List<TenkoviTank> get living => [for (final t in tanks) if (t.alive) t];
  bool get over => living.length <= 1;

  TenkoviTank tank(int id) => tanks.firstWhere((t) => t.id == id);

  void newTurn() {
    final (lo, hi) = map.windSteps;
    final mag = lo + (hi > lo ? _rng.nextInt(hi - lo + 1) : 0);
    wind = _rng.nextBool() ? mag : -mag;
  }

  /// Pucaj. False (and nothing stored) for a tank that is out, a second Pucaj
  /// in the same turn, a bad value, or a special shell that is used up.
  bool submit(int id, TenkoviAim a) {
    final t = tanks.where((t) => t.id == id).firstOrNull;
    if (t == null || !t.alive || flying || aims.containsKey(id)) return false;
    if (a.angle < 0 || a.angle > 180 || a.power < 0 || a.power > 100) {
      return false;
    }
    if (a.shell == TenkoviShell.bomblet) return false;
    if (a.shell == TenkoviShell.heavy && !t.heavyLeft) return false;
    if (a.shell == TenkoviShell.cluster && !t.clusterLeft) return false;
    aims[id] = a;
    return true;
  }

  /// Who has pressed Pucaj (the TV's ticks).
  Set<int> get ready => aims.keys.toSet();

  /// Every connected living tank has pressed Pucaj. A disconnected tank is not
  /// waited for.
  bool shouldFire(Set<int> connected) {
    final waiting = living.where((t) => connected.contains(t.id));
    return !flying && waiting.isNotEmpty && waiting.every((t) => aims.containsKey(t.id));
  }

  /// Everything leaves together. Only connected, living tanks fire.
  List<TenkoviEvent> fire(Set<int> connected) {
    final ev = <TenkoviEvent>[];
    for (final e in aims.entries) {
      final t = tank(e.key);
      if (!t.alive || !connected.contains(t.id)) continue;
      final a = e.value;
      if (a.shell == TenkoviShell.heavy) t.heavyLeft = false;
      if (a.shell == TenkoviShell.cluster) t.clusterLeft = false;
      final r = a.angle * pi / 180;
      final v = a.power * Tenkovi.powerToSpeed;
      projectiles.add(TenkoviShot(
        t.id,
        a.shell,
        t.x + cos(r) * Tenkovi.barrel,
        t.y + 12 + sin(r) * Tenkovi.barrel,
        cos(r) * v,
        sin(r) * v,
      ));
      ev.add(TkFired(t.id, a.shell));
    }
    aims.clear();
    volleys++;
    return ev;
  }

  /// One step of 1/60 s. Returns what happened; [TkVolleyDone] is last.
  List<TenkoviEvent> tick() {
    final ev = <TenkoviEvent>[];
    if (projectiles.isEmpty) return ev;
    const dt = 1 / Tenkovi.tickHz;
    final g = map.gravity, ax = wind * Tenkovi.windAccel;
    final blasts = <(TenkoviShot, double, double)>[];
    final born = <TenkoviShot>[];
    for (final p in projectiles) {
      p.age++;
      p.vx += ax * dt;
      p.vy -= g * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.x < 0 || p.x >= Tenkovi.w) {
        p.age = -1; // gone, no blast
        continue;
      }
      if (p.shell == TenkoviShell.cluster && p.vy <= 0) {
        ev.add(TkSplit(p.x, p.y));
        for (var i = -2; i <= 2; i++) {
          born.add(TenkoviShot(p.owner, TenkoviShell.bomblet, p.x, p.y, p.vx + i * 70, p.vy));
        }
        p.age = -1;
        continue;
      }
      var hit = p.y <= ground[p.x.floor()];
      if (!hit) {
        for (final t in tanks) {
          // The shooter's own tank is safe for the first instant (the barrel).
          if (t.id == p.owner && p.age < 12) continue;
          final dx = p.x - t.x, dy = p.y - (t.y + 12);
          if (dx * dx + dy * dy <= Tenkovi.tankR * Tenkovi.tankR) {
            hit = true;
            break;
          }
        }
      }
      if (hit) {
        blasts.add((p, p.x, p.y));
        p.age = -1;
      }
    }
    projectiles
      ..removeWhere((p) => p.age < 0)
      ..addAll(born);

    // All damage of this tick is worked out before any ground goes.
    final dmg = <(int, int), int>{}; // (tank, shooter) -> damage
    for (final (p, bx, by) in blasts) {
      final (r, maxD, fall) = Tenkovi.blast(p.shell);
      ev.add(TkBlast(bx, by, r, p.shell));
      for (final t in tanks) {
        final d = sqrt(pow(bx - t.x, 2) + pow(by - (t.y + 12), 2));
        final f = ((d - Tenkovi.tankR) / fall).clamp(0.0, 1.0);
        final n = (maxD * (1 - f)).round();
        if (n > 0) dmg[(t.id, p.owner)] = (dmg[(t.id, p.owner)] ?? 0) + n;
      }
    }
    for (final e in dmg.entries) {
      final t = tank(e.key.$1);
      t.hp = max(0, t.hp - e.value);
      ev.add(TkHurt(t.id, e.value, e.key.$2));
    }
    for (final (p, bx, by) in blasts) {
      _crater(bx, by, Tenkovi.blast(p.shell).$1);
    }
    for (final t in tanks) {
      t.y = ground[t.x]; // a tank drops onto what is left; no fall damage
    }

    if (projectiles.isEmpty) {
      for (final t in tanks) {
        if (!t.alive && !outAt.containsKey(t.id)) {
          outAt[t.id] = volleys;
          ev.add(TkKnockout(t.id));
        }
      }
      newTurn();
      ev.add(TkVolleyDone(over));
    }
    return ev;
  }

  /// Takes a bowl out of the ground: the surface only ever goes down.
  void _crater(double cx, double cy, double r) {
    terrainVersion++;
    for (var x = max(0, (cx - r).floor()); x <= min(Tenkovi.w - 1, (cx + r).ceil()); x++) {
      final dx = x - cx;
      if (dx * dx > r * r) continue;
      final low = cy - sqrt(r * r - dx * dx);
      if (ground[x] > low) ground[x] = max(0, low);
    }
  }

  /// Points for the round, as in Curve: the players you outlived. A tank that
  /// went out in a later volley outlived the ones out earlier; the survivor
  /// outlived everyone. Everyone out in the last volley: a draw, no points.
  Map<int, int> points() {
    final live = living;
    if (live.isEmpty) return {for (final t in tanks) t.id: 0};
    return {
      for (final t in tanks)
        t.id: t.alive
            ? tanks.length - 1
            : outAt.values.where((v) => v < outAt[t.id]!).length,
    };
  }

  /// The one tank left, or null (a draw).
  int? get winner => living.length == 1 ? living.first.id : null;
}

/// A match: [rounds] rounds, most points wins. [map] null picks one for every
/// round ("Nasumično").
class TenkoviMatch {
  TenkoviMatch(this.ids, {this.rounds = 3, this.map, int seed = 0})
      : _rng = Random(seed);
  final List<int> ids;
  final int rounds;
  final TenkoviMap? map;
  final Random _rng;
  final scores = <int, int>{};
  int played = 0;
  TenkoviRound? round;

  bool get over => played >= rounds;

  TenkoviRound start() {
    for (final id in ids) {
      scores.putIfAbsent(id, () => 0);
    }
    return round = TenkoviRound(
      ids,
      map ?? TenkoviMap.values[_rng.nextInt(TenkoviMap.values.length)],
      Random(_rng.nextInt(1 << 30)),
    );
  }

  /// Book the finished round; its points are returned.
  Map<int, int> finish() {
    final p = round!.points();
    for (final e in p.entries) {
      scores[e.key] = (scores[e.key] ?? 0) + e.value;
    }
    played++;
    return p;
  }

  /// Highest score; several ids on a tie.
  List<int> get leaders {
    final best = scores.values.fold(0, max);
    return [for (final e in scores.entries) if (e.value == best) e.key];
  }
}
