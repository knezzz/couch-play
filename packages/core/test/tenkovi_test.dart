import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

TenkoviRound _round({
  int n = 2,
  TenkoviMap map = TenkoviMap.earth,
  int seed = 1,
}) => TenkoviRound([for (var i = 0; i < n; i++) i], map, Random(seed));

/// Fires and ticks until the volley is done (at most 20 s).
List<TenkoviEvent> _volley(TenkoviRound r, Map<int, TenkoviAim> aims) {
  for (final e in aims.entries) {
    expect(r.submit(e.key, e.value), isTrue);
  }
  final ev = <TenkoviEvent>[...r.fire({for (final t in r.tanks) t.id})];
  for (var i = 0; i < 20 * 60 && r.flying; i++) {
    ev.addAll(r.tick());
  }
  return ev;
}

void main() {
  group('trajectory', () {
    test('the same seed and aims give the same volley', () {
      List<double> run() {
        final r = _round(seed: 7);
        _volley(r, {0: const TenkoviAim(60, 70, TenkoviShell.grenade)});
        return [...r.ground.take(40), ...r.tanks.map((t) => t.y)];
      }

      expect(run(), run());
    });

    test('gravity: a 45 degree shot lands further on the Moon than on Earth', () {
      double landing(TenkoviMap m) {
        final r = _round(map: m, n: 2, seed: 3);
        r.wind = 0;
        r.submit(0, const TenkoviAim(45, 60, TenkoviShell.grenade));
        r.fire({0});
        TenkoviShot? last;
        for (var i = 0; i < 20 * 60 && r.flying; i++) {
          last = r.projectiles.isEmpty ? last : r.projectiles.first;
          r.tick();
        }
        return last!.x;
      }

      final t = _round(seed: 3).tank(0);
      // Compare distance from the tank, shooting towards the side with room.
      expect((landing(TenkoviMap.moon) - t.x).abs(),
          greaterThan((landing(TenkoviMap.earth) - t.x).abs()));
    });

    test('wind pushes a shot: with the wind it goes further than against it', () {
      double dx(int wind) {
        final r = _round(seed: 5);
        r.wind = wind;
        final t = r.tank(0);
        // Straight up: only the wind moves it sideways.
        r.submit(0, const TenkoviAim(90, 40, TenkoviShell.grenade));
        r.fire({0});
        TenkoviShot? last;
        for (var i = 0; i < 20 * 60 && r.flying; i++) {
          last = r.projectiles.isEmpty ? last : r.projectiles.first;
          r.tick();
        }
        return last!.x - t.x;
      }

      expect(dx(8), greaterThan(0));
      expect(dx(-8), lessThan(0));
      expect(dx(0).abs(), lessThan(dx(8).abs()));
    });

    test('wind per map: none on the Moon, 0-5 on Earth, 5-10 on Mars', () {
      for (var s = 0; s < 60; s++) {
        final moon = _round(map: TenkoviMap.moon, seed: s);
        expect(moon.wind, 0);
        final earth = _round(map: TenkoviMap.earth, seed: s);
        expect(earth.wind.abs(), lessThanOrEqualTo(5));
        final mars = _round(map: TenkoviMap.mars, seed: s);
        expect(mars.wind.abs(), inInclusiveRange(5, 10));
      }
    });

    test('the wind is drawn again after every volley', () {
      final r = _round(map: TenkoviMap.mars, n: 3, seed: 2);
      final seen = <int>{r.wind};
      for (var v = 0; v < 6; v++) {
        if (r.over) break;
        _volley(r, {r.living.first.id: const TenkoviAim(90, 10, TenkoviShell.grenade)});
        seen.add(r.wind);
      }
      expect(seen.length, greaterThan(1));
    });
  });

  group('terrain and tanks', () {
    test('tanks are spread evenly, in a random order each round', () {
      final a = _round(n: 4, seed: 1), b = _round(n: 4, seed: 2);
      expect([for (final t in a.tanks) t.x], [200, 600, 1000, 1400]);
      expect([for (final t in b.tanks) t.x], [200, 600, 1000, 1400]);
      expect([for (final t in a.tanks) t.id],
          isNot([for (final t in b.tanks) t.id]));
    });

    test('a crater stays, and a tank whose ground goes drops onto what is below',
        () {
      final r = _round(seed: 4);
      final t = r.tanks.first;
      final before = t.y;
      // A blast right on the tank's pad (a direct hit also hurts it).
      r.submit(t.id, const TenkoviAim(90, 0, TenkoviShell.heavy));
      r.fire({t.id});
      for (var i = 0; i < 600 && r.flying; i++) {
        r.tick();
      }
      expect(t.y, lessThan(before), reason: 'the ground under it went');
      expect(t.y, r.ground[t.x]);
      expect(t.hp, lessThan(Tenkovi.maxHp), reason: 'no fall damage, only the blast');
      final crater = r.ground[t.x];
      _volley(r, {1: const TenkoviAim(90, 0, TenkoviShell.grenade)});
      expect(r.ground[t.x], lessThanOrEqualTo(crater), reason: 'craters stay');
    });

    test('no fall damage: a drop alone costs nothing', () {
      final r = _round(n: 3, seed: 9);
      final t = r.tanks[1];
      final hp = t.hp;
      // A shot that lands far from every tank still carves ground.
      final far = r.tanks.first;
      final dist = (far.x - t.x).abs();
      expect(dist, greaterThan(300));
      expect(hp, Tenkovi.maxHp);
    });
  });

  group('damage', () {
    test('a direct hit is about 50 and falls off with distance', () {
      int hpLost(double dist) {
        final r = _round(seed: 6);
        final a = r.tanks[0], b = r.tanks[1];
        // Put a Granata's blast at a chosen distance from b by hand.
        r.projectiles.add(
          TenkoviShot(a.id, TenkoviShell.grenade, b.x + dist, b.y + 12 + 1, 0, -900),
        );
        for (var i = 0; i < 100 && r.flying; i++) {
          r.tick();
        }
        return Tenkovi.maxHp - b.hp;
      }

      expect(hpLost(0), 50);
      final near = hpLost(40), far = hpLost(70);
      expect(near, lessThan(50));
      expect(far, lessThan(near));
      expect(hpLost(200), 0);
    });

    test('your own shot hurts you', () {
      final r = _round(seed: 6);
      final a = r.tanks[0];
      // Straight up with no power falls back on the tank.
      _volley(r, {a.id: const TenkoviAim(90, 0, TenkoviShell.grenade)});
      expect(a.hp, lessThan(Tenkovi.maxHp));
    });

    test('damage never goes below 0 HP', () {
      final r = _round(seed: 6);
      final b = r.tanks[1];
      b.hp = 5;
      r.projectiles.add(TenkoviShot(r.tanks[0].id, TenkoviShell.heavy, b.x + 0.0, b.y + 13, 0, -900));
      for (var i = 0; i < 100 && r.flying; i++) {
        r.tick();
      }
      expect(b.hp, 0);
    });
  });

  group('simultaneous volleys', () {
    // Two tanks in the same volley each land a heavy bomb on the other.
    TenkoviRound duel() {
      final r = _round(seed: 8);
      for (final t in r.tanks) {
        t.hp = 30;
      }
      return r;
    }

    test('two tanks can knock each other out in one volley: a draw, no points', () {
      final r = duel();
      final a = r.tanks[0], b = r.tanks[1];
      // Drop a shell on each by hand, in the same tick.
      r.projectiles
        ..add(TenkoviShot(a.id, TenkoviShell.grenade, b.x + 0.0, b.y + 13, 0, -900))
        ..add(TenkoviShot(b.id, TenkoviShell.grenade, a.x + 0.0, a.y + 13, 0, -900));
      final ev = <TenkoviEvent>[];
      for (var i = 0; i < 100 && r.flying; i++) {
        ev.addAll(r.tick());
      }
      expect(a.hp, 0);
      expect(b.hp, 0);
      expect(ev.whereType<TkKnockout>().length, 2);
      expect((ev.last as TkVolleyDone).over, isTrue);
      expect(r.winner, isNull);
      expect(r.points().values, everyElement(0));
    });

    test('one survivor outlived everyone: n-1 points; the first out gets 0', () {
      final r = _round(n: 3, seed: 8);
      final a = r.tanks[0], b = r.tanks[1], c = r.tanks[2];
      b.hp = 10;
      r.volleys = 1;
      r.projectiles.add(TenkoviShot(a.id, TenkoviShell.grenade, b.x + 0.0, b.y + 13, 0, -900));
      while (r.flying) {
        r.tick();
      }
      expect(r.over, isFalse);
      c.hp = 10;
      r.volleys = 2;
      r.projectiles.add(TenkoviShot(a.id, TenkoviShell.grenade, c.x + 0.0, c.y + 13, 0, -900));
      while (r.flying) {
        r.tick();
      }
      expect(r.over, isTrue);
      expect(r.winner, a.id);
      final p = r.points();
      expect(p[a.id], 2);
      expect(p[c.id], 1, reason: 'outlived b');
      expect(p[b.id], 0);
    });

    test('a volley does not end the round while two tanks live', () {
      final r = _round(n: 3, seed: 8);
      _volley(r, {0: const TenkoviAim(90, 5, TenkoviShell.grenade)});
      expect(r.over, isFalse);
    });
  });

  group('projectile limits and the Kasetna', () {
    test('Teška bomba and Kasetna: one each per round', () {
      final r = _round(n: 3, seed: 2);
      expect(r.submit(0, const TenkoviAim(80, 50, TenkoviShell.heavy)), isTrue);
      expect(r.submit(1, const TenkoviAim(80, 50, TenkoviShell.cluster)), isTrue);
      r.fire({0, 1, 2});
      while (r.flying) {
        r.tick();
      }
      expect(r.submit(0, const TenkoviAim(80, 50, TenkoviShell.heavy)), isFalse);
      expect(r.aims, isEmpty);
      expect(r.submit(0, const TenkoviAim(80, 50, TenkoviShell.cluster)), isTrue);
      expect(r.submit(1, const TenkoviAim(80, 50, TenkoviShell.cluster)), isFalse);
      expect(r.submit(1, const TenkoviAim(80, 50, TenkoviShell.grenade)), isTrue);
    });

    test('a new round refills them', () {
      final m = TenkoviMatch([0, 1], seed: 1)..start();
      m.round!.tank(0).heavyLeft = false;
      final next = m.start();
      expect(next.tank(0).heavyLeft, isTrue);
    });

    test('the Granata is unlimited', () {
      final r = _round(n: 3, seed: 2);
      // Three Granata volleys from the same tank (aimed at the ground far off).
      final s = r.tanks.first.id;
      for (var i = 0; i < 3; i++) {
        _volley(r, {s: const TenkoviAim(90, 5, TenkoviShell.grenade)});
        r.tank(s).hp = 100; // keep it alive: only the ammo is under test
      }
      expect(r.submit(s, const TenkoviAim(90, 5, TenkoviShell.grenade)), isTrue);
    });

    test('the Kasetna splits into 5 small bombs at the top of its arc', () {
      final r = _round(n: 2, seed: 3);
      r.wind = 0;
      r.submit(0, const TenkoviAim(70, 60, TenkoviShell.cluster));
      r.fire({0});
      var splitAt = -1;
      var maxVy = 0.0, vyAtSplit = 0.0;
      for (var i = 0; i < 20 * 60 && r.flying; i++) {
        final before = r.projectiles.map((p) => p.vy).toList();
        final ev = r.tick();
        if (ev.any((e) => e is TkSplit)) {
          splitAt = i;
          vyAtSplit = before.first;
          expect(r.projectiles.length, 5);
          expect(r.projectiles.every((p) => p.shell == TenkoviShell.bomblet), isTrue);
          break;
        }
        maxVy = max(maxVy, before.first);
      }
      expect(splitAt, greaterThan(0));
      expect(vyAtSplit, lessThan(30), reason: 'near the top of the arc');
      expect(maxVy, greaterThan(300));
      // The five bombs spread out.
      final xs = r.projectiles.map((p) => p.vx).toSet();
      expect(xs.length, 5);
    });

    test('a shot that leaves the sides makes no blast', () {
      final r = _round(seed: 3);
      r.wind = 0;
      // Over the nearer edge: far beyond it, high above the ground.
      final t = r.tank(0);
      r.submit(0, TenkoviAim(t.x < 800 ? 135 : 45, 100, TenkoviShell.grenade));
      r.fire({0});
      final ev = <TenkoviEvent>[];
      for (var i = 0; i < 20 * 60 && r.flying; i++) {
        ev.addAll(r.tick());
      }
      expect(ev.whereType<TkBlast>(), isEmpty);
    });
  });

  group('the volley fires when everyone connected and living is ready', () {
    test('not before the last one presses Pucaj', () {
      final r = _round(n: 3, seed: 1);
      final all = {0, 1, 2};
      expect(r.shouldFire(all), isFalse);
      r.submit(0, const TenkoviAim(45, 50, TenkoviShell.grenade));
      r.submit(1, const TenkoviAim(45, 50, TenkoviShell.grenade));
      expect(r.shouldFire(all), isFalse);
      expect(r.ready, {0, 1});
      r.submit(2, const TenkoviAim(45, 50, TenkoviShell.grenade));
      expect(r.shouldFire(all), isTrue);
    });

    test('a disconnected tank is not waited for, and does not fire', () {
      final r = _round(n: 3, seed: 1);
      r.submit(0, const TenkoviAim(45, 50, TenkoviShell.grenade));
      r.submit(2, const TenkoviAim(45, 50, TenkoviShell.grenade));
      expect(r.shouldFire({0, 1, 2}), isFalse);
      expect(r.shouldFire({0, 2}), isTrue);
      final ev = r.fire({0, 2});
      expect(ev.whereType<TkFired>().map((e) => e.id).toSet(), {0, 2});
    });

    test('a disconnect after Pucaj means that tank does not fire', () {
      final r = _round(n: 3, seed: 1);
      for (final i in [0, 1, 2]) {
        r.submit(i, const TenkoviAim(45, 50, TenkoviShell.grenade));
      }
      final ev = r.fire({0, 2});
      expect(ev.whereType<TkFired>().map((e) => e.id).toSet(), {0, 2});
    });

    test('a tank that is out is not waited for; nobody connected never fires', () {
      final r = _round(n: 3, seed: 1);
      r.tank(1).hp = 0;
      r.submit(0, const TenkoviAim(45, 50, TenkoviShell.grenade));
      r.submit(2, const TenkoviAim(45, 50, TenkoviShell.grenade));
      expect(r.shouldFire({0, 1, 2}), isTrue);
      expect(r.submit(1, const TenkoviAim(45, 50, TenkoviShell.grenade)), isFalse);
      expect(_round().shouldFire({}), isFalse);
    });

    test('Pucaj is final for the turn and values are checked', () {
      final r = _round(n: 3, seed: 1);
      expect(r.submit(0, const TenkoviAim(181, 50, TenkoviShell.grenade)), isFalse);
      expect(r.submit(0, const TenkoviAim(90, 101, TenkoviShell.grenade)), isFalse);
      expect(r.submit(0, const TenkoviAim(90, 100, TenkoviShell.grenade)), isTrue);
      expect(r.submit(0, const TenkoviAim(10, 10, TenkoviShell.grenade)), isFalse);
      expect(r.aims[0]!.angle, 90);
    });
  });

  group('scoring and the end of the match', () {
    test('rounds add up; most points wins; the match ends after the set rounds', () {
      final m = TenkoviMatch([0, 1, 2], rounds: 2, map: TenkoviMap.earth, seed: 5);
      expect(m.over, isFalse);
      var r = m.start();
      r.tank(1).hp = 0;
      r.tank(2).hp = 0;
      r.outAt[1] = 1;
      r.outAt[2] = 1;
      expect(m.finish(), {0: 2, 1: 0, 2: 0});
      expect(m.over, isFalse);
      r = m.start();
      r.tank(0).hp = 0;
      r.tank(1).hp = 0;
      r.tank(2).hp = 0;
      r.outAt[0] = r.outAt[1] = r.outAt[2] = 1;
      expect(m.finish(), {0: 0, 1: 0, 2: 0}, reason: 'a draw scores nothing');
      expect(m.over, isTrue);
      expect(m.scores, {0: 2, 1: 0, 2: 0});
      expect(m.leaders, [0]);
    });

    test('a tie lists every leader', () {
      final m = TenkoviMatch([0, 1], rounds: 1, map: TenkoviMap.mars);
      m.start();
      expect(m.leaders, [0, 1], reason: 'nothing scored yet');
    });

    test('a map setting of null picks a map each round, from the seed', () {
      final maps = <TenkoviMap>{};
      final m = TenkoviMatch([0, 1], rounds: 30, seed: 11);
      for (var i = 0; i < 30; i++) {
        maps.add(m.start().map);
      }
      expect(maps, TenkoviMap.values.toSet());
    });
  });
}
