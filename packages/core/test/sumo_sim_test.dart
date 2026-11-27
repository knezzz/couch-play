import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Task 55: the Sumo rules, on the fixed 60 Hz tick with a seed.
void main() {
  const R = 440.0;
  SumoSim make(List<int> ids, {SumoConfig? config, int seed = 1}) =>
      SumoSim(ids, config: config ?? const SumoConfig(countdown: 0, powerUps: false), random: Random(seed));
  List<CurveEvent> run(SumoSim s, int ticks) {
    final all = <CurveEvent>[];
    for (var i = 0; i < ticks && !s.roundOver; i++) {
      all.addAll(s.tick());
    }
    return all;
  }

  double speed(SumoSim s, int id) {
    final v = s.velocityOf(id);
    return sqrt(v.$1 * v.$1 + v.$2 * v.$2);
  }

  group('pushing and mass', () {
    double bVxAfterHit({bool heavy = false, bool big = false}) {
      final s = make([0, 1]);
      s.place(0, -110, 0);
      s.setVelocity(0, 300, 0);
      s.place(1, 0, 0);
      if (heavy) s.grant(1, SumoPower.heavy);
      if (big) s.grant(1, SumoPower.big);
      var best = 0.0;
      for (var i = 0; i < 20; i++) {
        s.tick();
        best = max(best, s.velocityOf(1).$1);
      }
      return best;
    }

    test('a push moves the other wrestler', () {
      expect(bVxAfterHit(), greaterThan(150));
    });
    test('a heavier wrestler (Težak) moves less from the same push', () {
      expect(bVxAfterHit(heavy: true), lessThan(bVxAfterHit() * 0.7));
    });
    test('a bigger wrestler (Velik) is also pushed less', () {
      expect(bVxAfterHit(big: true), lessThan(bVxAfterHit()));
    });
    test('wrestlers never overlap after a tick', () {
      final s = make([0, 1]);
      s.place(0, -40, 0);
      s.place(1, 40, 0);
      s.tick();
      final a = s.heads.first, b = s.heads.last;
      expect(sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2)), greaterThanOrEqualTo(2 * 52 - 0.5));
    });
  });

  group('the edge and the ring', () {
    test('a wrestler that leaves the edge is out; the last one standing wins the round', () {
      final s = make([0, 1]);
      s.place(0, R - 1, 0);
      s.setVelocity(0, 300, 0);
      final ev = run(s, 5);
      expect(ev.whereType<Died>().single.id, 0);
      expect(ev.whereType<RoundOver>().single.survivorId, 1);
      expect(s.roundOver, isTrue);
      expect(s.scores[0], 0);
      expect(s.scores[1], 1);
    });

    test('both leaving on the same tick tie: nobody survives, same points', () {
      final s = make([0, 1, 2]);
      s.place(0, R + 5, 0);
      s.place(1, -R - 5, 0);
      final ev = run(s, 2);
      expect(ev.whereType<Died>().map((e) => e.id).toSet(), {0, 1});
      expect(ev.whereType<RoundOver>().single.survivorId, 2);
      expect(s.scores[0], 0);
      expect(s.scores[1], 0);
      expect(s.scores[2], 2);
    });

    test('the ring keeps its size for 20 s after the countdown, then shrinks, and is gone at about 65 s', () {
      final s = make([0, 1], config: const SumoConfig(countdown: 2, powerUps: false));
      for (var i = 0; i < 120; i++) {
        s.tick();
      }
      expect(s.countingDown, isFalse);
      for (var i = 0; i < 1200; i++) {
        s.tick();
      }
      expect(s.radius, R, reason: '20 s of play, still full');
      for (var i = 0; i < 600; i++) {
        s.tick();
      }
      expect(s.radius, closeTo(R * (1 - 600 / 2700), 1), reason: '10 s into the shrink');
      expect(s.roundOver, isFalse);
    });

    test('a round where nobody moves still ends, in a tie, by about 65 s', () {
      final s = make([0, 1]);
      var ticks = 0;
      while (!s.roundOver && ticks < 65 * 60 + 5) {
        s.tick();
        ticks++;
      }
      expect(s.roundOver, isTrue);
      expect(ticks, inInclusiveRange(40 * 60, 65 * 60 + 1));
    });

    test('everyone starts well inside the ring and apart, with 2 to 8 players', () {
      for (var n = 2; n <= 8; n++) {
        final s = make([for (var i = 0; i < n; i++) i], seed: n);
        final hs = s.heads.toList();
        for (final h in hs) {
          expect(sqrt(h.x * h.x + h.y * h.y), lessThan(R * 0.7));
        }
        for (var i = 0; i < n; i++) {
          for (var j = i + 1; j < n; j++) {
            expect(sqrt(pow(hs[i].x - hs[j].x, 2) + pow(hs[i].y - hs[j].y, 2)), greaterThan(2 * 52));
          }
        }
      }
    });

    test('the countdown holds everyone still', () {
      final s = make([0, 1], config: const SumoConfig(countdown: 2, powerUps: false));
      final x0 = s.heads.first.x;
      s.setMove(0, 0, 3);
      for (var i = 0; i < 60; i++) {
        s.tick();
      }
      expect(s.countingDown, isTrue);
      expect(s.heads.first.x, x0);
    });
  });

  group('the joystick', () {
    test('direction 0 pushes right, 4 pushes up the screen, 8 left, 12 down', () {
      for (final (dir, sx, sy) in [(0, 1, 0), (4, 0, -1), (8, -1, 0), (12, 0, 1)]) {
        final s = make([0, 1]);
        s.place(0, 0, 0);
        s.place(1, 300, 300);
        s.setMove(0, dir, 3);
        for (var i = 0; i < 10; i++) {
          s.tick();
        }
        final v = s.velocityOf(0);
        expect(v.$1 * sx, greaterThanOrEqualTo(sx == 0 ? -1 : 50), reason: 'dir $dir');
        expect(v.$2 * sy, greaterThanOrEqualTo(sy == 0 ? -1 : 50), reason: 'dir $dir');
      }
    });

    test('harder pull is faster; force 0 is no push', () {
      double after(int force) {
        final s = make([0, 1]);
        s.place(0, 0, 0);
        s.place(1, 300, 300);
        s.setMove(0, 0, force);
        for (var i = 0; i < 40; i++) {
          s.tick();
        }
        return speed(s, 0);
      }

      expect(after(0), 0);
      expect(after(1), greaterThan(0));
      expect(after(2), greaterThan(after(1)));
      expect(after(3), greaterThan(after(2)));
    });

    test('clearInput lets go', () {
      final s = make([0, 1]);
      s.place(0, 0, 0);
      s.place(1, 300, 300);
      s.setMove(0, 0, 3);
      s.tick();
      s.clearInput(0);
      for (var i = 0; i < 120; i++) {
        s.tick();
      }
      expect(speed(s, 0), lessThan(5));
    });
  });

  group('Dash', () {
    test('a strong push in the joystick direction, then about 2 s to recharge', () {
      final s = make([0, 1]);
      s.place(0, -100, 0);
      s.place(1, 300, 300);
      s.setMove(0, 0, 0);
      expect(s.dashLeft(0), 0, reason: 'ready');
      s.dash(0);
      final ev = s.tick();
      expect(ev.whereType<Dashed>().single.id, 0);
      expect(s.velocityOf(0).$1, greaterThan(600));
      expect(s.dashLeft(0), closeTo(1, 0.02));
      for (var i = 0; i < 60; i++) {
        s.tick();
      }
      expect(s.dashLeft(0), closeTo(0.5, 0.05));
      final before = speed(s, 0);
      s.dash(0); // too early: ignored
      s.tick();
      expect(speed(s, 0), lessThanOrEqualTo(before));
      for (var i = 0; i < 60; i++) {
        s.tick();
      }
      expect(s.dashLeft(0), 0);
      s.place(0, -100, 0);
      s.setVelocity(0, 0, 0);
      s.dash(0);
      s.tick();
      expect(s.velocityOf(0).$1, greaterThan(600));
    });

    test('a dash pressed during the countdown fires at the go, not before', () {
      final s = make([0, 1], config: const SumoConfig(countdown: 2, powerUps: false));
      s.place(0, 0, 0);
      s.place(1, 300, 300);
      s.setMove(0, 0, 0);
      s.dash(0);
      for (var i = 0; i < 120; i++) {
        expect(s.tick().whereType<Dashed>(), isEmpty, reason: 'tick $i is still the countdown');
      }
      expect(speed(s, 0), 0);
      expect(s.tick().whereType<Dashed>().single.id, 0, reason: 'the first tick of play');
      expect(s.velocityOf(0).$1, greaterThan(600));
    });

    test('a countdown press recharges from the press, like the phone\'s ring: ready 2 s after it, not 2 s after the go', () {
      final s = make([0, 1], config: const SumoConfig(countdown: 2, powerUps: false));
      s.place(0, 0, 0);
      s.place(1, 300, 300);
      s.setMove(0, 0, 0);
      for (var i = 0; i < 30; i++) {
        s.tick(); // half a second of the countdown
      }
      s.dash(0); // pressed 90 ticks before the go
      for (var i = 0; i < 90; i++) {
        s.tick();
      }
      expect(s.countingDown, isFalse);
      expect(s.tick().whereType<Dashed>().single.id, 0, reason: 'fires at the go');
      expect(s.dashLeft(0), closeTo(30 / 120, 0.02), reason: '2 s after the press = 30 ticks after the go');
      for (var i = 0; i < 31; i++) {
        s.tick();
      }
      expect(s.dashLeft(0), 0, reason: 'ready 2 s after the press');
      s.setVelocity(0, 0, 0);
      s.dash(0);
      expect(s.tick().whereType<Dashed>().single.id, 0);
    });

    test('a dash that arrives a few ticks before the recharge ends is kept and fires when it does', () {
      final s = make([0, 1]);
      s.place(1, 300, 300);
      s.setMove(0, 0, 0);
      s.dash(0);
      s.tick();
      for (var i = 0; i < 112; i++) {
        s.tick(); // 8 ticks of recharge left (cooldown 120)
      }
      expect(s.dashLeft(0), closeTo(8 / 120, 0.01));
      s.dash(0);
      var fired = 0;
      for (var i = 0; i < 20; i++) {
        fired += s.tick().whereType<Dashed>().length;
      }
      expect(fired, 1);
    });

    test('a dash long before the recharge ends is dropped, not kept', () {
      final s = make([0, 1]);
      s.place(1, 300, 300);
      s.dash(0);
      s.tick();
      s.dash(0); // 119 ticks to go
      var fired = 0;
      for (var i = 0; i < 300; i++) {
        fired += s.tick().whereType<Dashed>().length;
        if (s.heads.first.alive == false) break;
      }
      expect(fired, 0, reason: 'only the first dash; the early press is gone');
    });

    test('hammering Dash still gives at most one dash per 2 s', () {
      final s = make([0, 1], config: const SumoConfig(countdown: 0, powerUps: false, shrinkStart: 100));
      s.place(1, 0, -400);
      var fired = 0;
      for (var i = 0; i < 300 && !s.roundOver; i++) {
        s.dash(0);
        s.place(0, 0, 0); // stays in the ring
        s.setVelocity(0, 0, 0);
        fired += s.tick().whereType<Dashed>().length;
      }
      expect(fired, 3, reason: '5 s: at 0 s, 2 s and 4 s');
    });
  });

  group('the maps', () {
    double slid(SumoMap map) {
      final s = make([0, 1], config: SumoConfig(map: map, countdown: 0, powerUps: false));
      s.place(0, 0, 0);
      s.place(1, 0, -400);
      s.setVelocity(0, 400, 0);
      for (var i = 0; i < 60; i++) {
        s.tick();
      }
      return speed(s, 0);
    }

    test('ice has much less friction than Klasični: a wrestler slides on', () {
      expect(slid(SumoMap.ice), greaterThan(slid(SumoMap.classic) * 10));
    });

    test('Nasumično picks Klasični or Led each round, from the seed', () {
      final seen = <bool>{};
      final s = make([0, 1], config: const SumoConfig(map: SumoMap.random, countdown: 0, powerUps: false));
      for (var i = 0; i < 20; i++) {
        seen.add(s.ice);
        s.startRound();
      }
      expect(seen, {true, false});
    });
  });

  group('power-ups', () {
    SumoSim withPowerUp(SumoPower k) {
      final s = make([0, 1]);
      s.place(0, 0, 0);
      s.place(1, 300, 300);
      s.placePowerUp(k, 0, 0);
      return s;
    }

    test('picking one up gives the effect for 5 s, and the icon leaves the ring', () {
      for (final k in SumoPower.values) {
        final s = withPowerUp(k);
        final ev = s.tick();
        expect(ev.whereType<SumoPickedUp>().single.kind, k);
        expect(s.powerUps, isEmpty);
        expect(s.effectLeft(0, k), closeTo(1, 0.01));
        expect(s.effectLeft(1, k), 0);
        for (var i = 0; i < 150; i++) {
          s.tick();
        }
        expect(s.effectLeft(0, k), closeTo(0.5, 0.02), reason: '$k half way');
        for (var i = 0; i < 151; i++) {
          s.tick();
        }
        expect(s.effectLeft(0, k), 0, reason: '$k over after 5 s');
      }
    });

    test('Težak is heavier, Velik is bigger, only while it lasts', () {
      final s = make([0, 1]);
      s.place(0, 0, 0);
      s.place(1, 300, 300);
      final m0 = s.massOf(0), r0 = s.radiusOf(0);
      s.grant(0, SumoPower.heavy);
      s.grant(0, SumoPower.big);
      expect(s.massOf(0), greaterThan(m0 * 2));
      expect(s.radiusOf(0), closeTo(r0 * 1.5, 0.01));
      expect(s.massOf(1), m0);
      for (var i = 0; i < 301; i++) {
        s.tick();
      }
      expect(s.massOf(0), m0);
      expect(s.radiusOf(0), r0);
    });

    test('Brz is faster: a higher speed at the same pull', () {
      double top({required bool fast}) {
        final s = make([0, 1]);
        s.place(0, -300, 0);
        s.place(1, 300, 300);
        if (fast) s.grant(0, SumoPower.fast);
        s.setMove(0, 0, 3);
        for (var i = 0; i < 40; i++) {
          s.tick();
        }
        return speed(s, 0);
      }

      expect(top(fast: true), greaterThan(top(fast: false) * 1.3));
    });

    test('picking the same kind again starts the 5 s again', () {
      final s = make([0, 1]);
      s.place(0, 0, 0);
      s.place(1, 300, 300);
      s.grant(0, SumoPower.fast);
      for (var i = 0; i < 200; i++) {
        s.tick();
      }
      s.grant(0, SumoPower.fast);
      expect(s.effectLeft(0, SumoPower.fast), closeTo(1, 0.01));
    });

    test('they appear from time to time, at most 2, inside the ring; none when switched off', () {
      final on = make([0, 1], config: const SumoConfig(countdown: 0, powerUps: true));
      on.place(0, -150, 0);
      on.place(1, 150, 0); // out of the way, they just stand
      var most = 0, seen = 0;
      for (var i = 0; i < 20 * 60; i++) {
        on.tick();
        most = max(most, on.powerUps.length);
        for (final p in on.powerUps) {
          expect(sqrt(p.x * p.x + p.y * p.y), lessThan(on.radius));
        }
        if (on.powerUps.isNotEmpty) seen++;
      }
      expect(seen, greaterThan(0));
      expect(most, lessThanOrEqualTo(2));
      final off = make([0, 1]);
      for (var i = 0; i < 20 * 60; i++) {
        off.tick();
      }
      expect(off.powerUps, isEmpty);
    });
  });

  group('scoring and the match', () {
    test('points are the players outlived, as in Curve', () {
      final s = make([0, 1, 2]);
      s.place(0, R + 5, 0);
      s.tick();
      expect(s.scores[0], 0);
      expect(s.roundOver, isFalse);
      s.place(1, R + 5, 0);
      s.tick();
      expect(s.scores[1], 1);
      expect(s.roundOver, isTrue);
      expect(s.scores[2], 2);
    });

    test('the target is 10 x (players - 1); the first past it with a clear lead wins the match', () {
      final s = make([0, 1, 2]);
      expect(s.target, 20);
      var ev = <CurveEvent>[];
      for (var round = 0; round < 10 && !s.matchOver; round++) {
        s.place(1, R + 5, 0);
        s.place(2, -R - 5, 0); // both fall together: 0 survives with 2 points each round
        ev = s.tick();
        if (!s.matchOver) s.startRound();
      }
      expect(s.scores[0], 20);
      expect(s.matchOver, isTrue);
      expect(s.winner, 0);
      expect(ev.whereType<MatchOver>().single.winnerId, 0);
    });

    test('play goes on while two share the top score past the target', () {
      final s = make([0, 1]);
      s.scores[0] = 10;
      s.scores[1] = 9;
      s.place(0, R + 5, 0);
      s.tick(); // 1 outlives 0: 10 and 10, a tie at the top
      expect(s.roundOver, isTrue);
      expect(s.matchOver, isFalse);
      final t = make([0, 1]);
      t.scores[0] = 9;
      t.scores[1] = 10;
      t.place(0, R + 5, 0);
      t.tick(); // 1 outlives 0: 11 against 9
      expect(t.matchOver, isTrue);
      expect(t.winner, 1);
    });

    test('kill() takes someone out for the match until revive(); a revived one plays the next round', () {
      final s = make([0, 1, 2]);
      s.kill(2);
      final ev = s.tick();
      expect(ev.whereType<Died>().single.id, 2);
      expect(s.roundOver, isFalse);
      s.place(1, R + 5, 0);
      s.tick();
      expect(s.roundOver, isTrue);
      s.startRound();
      expect(s.heads.firstWhere((h) => h.id == 2).alive, isFalse, reason: 'still gone');
      s.revive(2);
      s.startRound();
      expect(s.heads.firstWhere((h) => h.id == 2).alive, isTrue);
    });
  });

  test('the round number counts from 1 with every startRound', () {
    final s = make([0, 1]);
    expect(s.round, 1);
    s.startRound();
    s.startRound();
    expect(s.round, 3);
  });

  test('the same seed and the same inputs give the same game', () {
    List<double> play() {
      final s = make([0, 1, 2, 3], seed: 7, config: const SumoConfig(countdown: 0, powerUps: true));
      for (var i = 0; i < 900 && !s.roundOver; i++) {
        if (i % 30 == 0) s.setMove(i ~/ 30 % 4, i % 16, 1 + i % 3);
        if (i % 97 == 0) s.dash(i % 4);
        s.tick();
      }
      return [for (final h in s.heads) ...[h.x, h.y]];
    }

    expect(play(), play());
  });
}
