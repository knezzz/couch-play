import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/bots.dart';

/// The old bot, kept here as the baseline: random steering every 0.3-1 s and
/// a turn toward the centre within 80 units of a wall. It never sees trails.
class _RandomBots {
  _RandomBots(this.sim, this.ids, this.random);
  final CurveSim sim;
  final List<int> ids;
  final Random random;
  final _ticksLeft = <int, int>{};
  final _steer = <int, (bool, bool)>{};

  void tick() {
    final c = sim.config;
    for (final h in sim.heads) {
      if (!ids.contains(h.id) || !h.alive) continue;
      final near = h.x < 80 || h.x > c.arenaW - 80 || h.y < 80 || h.y > c.arenaH - 80;
      if (near) {
        var d = atan2(c.arenaH / 2 - h.y, c.arenaW / 2 - h.x) - h.heading;
        d = (d + pi) % (2 * pi) - pi;
        _steer[h.id] = d.abs() < 0.1 ? (false, false) : d > 0 ? (false, true) : (true, false);
        _ticksLeft[h.id] = 0;
      } else if ((_ticksLeft[h.id] ?? 0) <= 0) {
        _ticksLeft[h.id] = ((0.3 + random.nextDouble() * 0.7) * c.tickHz).round();
        final r = random.nextInt(3);
        _steer[h.id] = (r == 0, r == 1);
      } else {
        _ticksLeft[h.id] = _ticksLeft[h.id]! - 1;
      }
      final (l, r) = _steer[h.id]!;
      sim.setInput(h.id, left: l, right: r);
    }
  }
}

const _cfg = CurveConfig(
  countdown: 0,
  gapEveryMin: 1e6,
  gapEveryMax: 1e6 + 1,
  powerUps: false,
);

CurveHead _head(CurveSim s, int id) => s.heads.firstWhere((h) => h.id == id);

void main() {
  test('bots_turn_away_from_walls', () {
    // Head 130 units from the left wall, flying straight at it. A bot reacts
    // 150-250 ms late (21-35 units), so this is the closest it should handle.
    for (final startY in [450.0, 60.0, 840.0]) {
      final sim = CurveSim([1, 2], random: Random(1));
      final bots = Bots(sim, [1], Random(2));
      sim.place(1, 130, startY, pi);
      sim.place(2, 1500, 450, 0);
      for (var i = 0; i < 100; i++) {
        bots.tick();
        sim.tick();
      }
      expect(_head(sim, 1).alive, isTrue, reason: 'startY=$startY');
    }
  });

  test('bot_turns_away_from_wall_ahead', () {
    // 110 units from the wall the old bot had not reacted yet (it waits for
    // 80). Every seed must start turning within 25 ticks and live to tick 100.
    for (var seed = 0; seed < 10; seed++) {
      final sim = CurveSim([0, 1, 2], config: _cfg, random: Random(1));
      final bots = Bots(sim, [0], Random(seed));
      sim.place(0, 110, 450, pi);
      sim.place(1, 1500, 100, 0);
      sim.place(2, 1500, 800, pi);
      var turned = false;
      for (var i = 0; i < 100; i++) {
        bots.tick();
        sim.tick();
        if (i < 25 && (_head(sim, 0).heading - pi).abs() > 0.1) turned = true;
      }
      expect(turned, isTrue, reason: 'seed=$seed');
      expect(_head(sim, 0).alive, isTrue, reason: 'seed=$seed');
    }
  });

  /// Player 1 paints a vertical trail through x=700 (y 380..480), then leaves.
  CurveSim withTrail() {
    final sim = CurveSim([0, 1, 2], config: _cfg, random: Random(1));
    sim.place(0, 100, 700, 0);
    sim.place(1, 700, 380, pi / 2);
    sim.place(2, 100, 100, 0);
    for (var i = 0; i < 40; i++) {
      sim.tick();
    }
    sim.kill(1);
    sim.place(0, 590, 450, 0); // 110 units from the trail, flying at it
    return sim;
  }

  test('bot_avoids_trail_ahead', () {
    for (var seed = 0; seed < 10; seed++) {
      final sim = withTrail();
      final bots = Bots(sim, [0], Random(seed));
      for (var i = 0; i < 90; i++) {
        bots.tick();
        sim.tick();
      }
      expect(_head(sim, 0).alive, isTrue, reason: 'seed=$seed');
    }
  });

  test('ghost_bot_drives_through_a_trail_to_reach_a_power_up', () {
    // A normal bot swerves from this trail (bot_avoids_trail_ahead). A ghost
    // sees it as open and goes straight for the item on the far side.
    final sim = withTrail();
    sim.placePowerUp(PowerUpKind.ghost, 595, 450);
    final bots = Bots(sim, [0], Random(1));
    sim.tick(); // picks the ghost up
    expect(sim.hasEffect(0, PowerUpKind.ghost), isTrue);
    sim.placePowerUp(PowerUpKind.slow, 790, 450);
    var picked = false;
    var maxOff = 0.0;
    for (var i = 0; i < 120 && !picked; i++) {
      bots.tick();
      picked = sim.tick().any((e) => e is PickedUp && e.kind == PowerUpKind.slow);
      maxOff = max(maxOff, (_head(sim, 0).y - 450).abs());
    }
    expect(picked, isTrue);
    expect(_head(sim, 0).alive, isTrue);
    expect(maxOff, lessThan(15), reason: 'it should drive straight through, not around');
  });

  test('bot_heads_for_a_power_up_when_nothing_blocks_it', () {
    for (var seed = 0; seed < 10; seed++) {
      final sim = CurveSim([0, 1, 2], config: _cfg, random: Random(1));
      sim.place(0, 800, 450, 0);
      sim.place(1, 100, 100, 0);
      sim.place(2, 100, 800, 0);
      sim.placePowerUp(PowerUpKind.slow, 800, 600); // straight below
      final bots = Bots(sim, [0], Random(seed));
      var picked = false;
      for (var i = 0; i < 150 && !picked; i++) {
        bots.tick();
        picked = sim.tick().any((e) => e is PickedUp && e.playerId == 0);
      }
      expect(picked, isTrue, reason: 'seed=$seed');
    }
  });

  test('bots_do_not_flip_steering_every_tick', () {
    // Three bots in open space for 2 s, short enough that none reaches a wall
    // or trail (a dodge may legitimately cut a hold short, see
    // dodge_does_not_wait_out_the_steer_hold). Steering is read back from the
    // heading change each tick; no held steer (or straight run) may be shorter
    // than 9 ticks, apart from the first, which the window starts in the middle
    // of, and the last, which it cuts.
    for (var seed = 0; seed < 5; seed++) {
      final sim = CurveSim([0, 1, 2], config: _cfg, random: Random(seed));
      final bots = Bots(sim, [0, 1, 2], Random(seed));
      sim.place(0, 400, 450, 0);
      sim.place(1, 800, 450, pi / 2);
      sim.place(2, 1200, 450, pi);
      final last = [for (var i = 0; i < 3; i++) _head(sim, i).heading];
      final prev = [0, 0, 0], run = [0, 0, 0];
      final runs = <List<int>>[[], [], []];
      final seen = [false, false, false];
      for (var i = 0; i < 120 && !sim.roundOver; i++) {
        bots.tick();
        sim.tick();
        for (var id = 0; id < 3; id++) {
          final h = _head(sim, id);
          if (!h.alive) continue;
          final d = h.heading - last[id];
          last[id] = h.heading;
          final cur = d.abs() < 1e-9 ? 0 : (d > 0 ? 1 : -1);
          if (i > 0 && cur != prev[id]) {
            if (seen[id]) runs[id].add(run[id]);
            seen[id] = true;
            run[id] = 0;
          }
          run[id]++;
          prev[id] = cur;
        }
      }
      for (var id = 0; id < 3; id++) {
        expect(runs[id].where((r) => r < 9), isEmpty,
            reason: 'seed=$seed id=$id runs=${runs[id]}');
      }
    }
  });

  test('dodge_does_not_wait_out_the_steer_hold', () {
    // A bot has just started a right turn toward an item. We then drop it at a
    // wall: dead ahead is blocked and the bottom wall is close on its right, so
    // the right dodge is wrong and it has to switch to left. That must take
    // about a reaction time (9-15 ticks + 2 to confirm), not a whole steer hold
    // (9-20 ticks) plus the reaction.
    for (var seed = 0; seed < 20; seed++) {
      final sim = CurveSim([0, 1, 2], config: _cfg, random: Random(1));
      sim.place(0, 1000, 700, 0);
      sim.place(1, 100, 100, 0);
      sim.place(2, 100, 800, 0);
      sim.placePowerUp(PowerUpKind.slow, 1300, 860);
      final bots = Bots(sim, [0], Random(seed));
      var last = _head(sim, 0).heading;
      var turning = false;
      for (var i = 0; i < 200 && !turning; i++) {
        bots.tick();
        sim.tick();
        final h = _head(sim, 0).heading;
        turning = h > last + 1e-9;
        last = h;
      }
      expect(turning, isTrue, reason: 'seed=$seed never started its target turn');

      sim.place(0, 1500, 870, 0); // wall ahead (100), bottom wall 30 below
      last = _head(sim, 0).heading;
      int? switched;
      for (var i = 1; i <= 40 && switched == null; i++) {
        bots.tick();
        sim.tick();
        final h = _head(sim, 0);
        if (!h.alive) break;
        if (h.heading < last - 1e-9) switched = i;
        last = h.heading;
      }
      expect(switched, isNotNull, reason: 'seed=$seed never dodged left');
      expect(switched!, lessThanOrEqualTo(18), reason: 'seed=$seed took $switched ticks');
    }
  });

  test('bot_commits_to_a_power_up_target', () {
    // The item is 300 units away, off to the side, with nothing in the way.
    // Within 6 s every seed must have picked it up.
    for (var seed = 0; seed < 10; seed++) {
      final sim = CurveSim([0, 1, 2], config: _cfg, random: Random(1));
      sim.place(0, 600, 450, 0);
      sim.place(1, 100, 100, 0);
      sim.place(2, 100, 800, 0);
      sim.placePowerUp(PowerUpKind.slow, 750, 700);
      final bots = Bots(sim, [0], Random(seed));
      var picked = false;
      for (var i = 0; i < 360 && !picked && _head(sim, 0).alive; i++) {
        bots.tick();
        picked = sim.tick().any((e) => e is PickedUp && e.playerId == 0);
      }
      expect(picked, isTrue, reason: 'seed=$seed');
    }
  });

  /// Mean ticks player 0 lasts (or until the round ends) against 7 opponents of
  /// the old random kind, over 20 seeded rounds.
  double meanSurvival(void Function() Function(CurveSim, Random) botFor) {
    var total = 0;
    for (var seed = 0; seed < 20; seed++) {
      final sim = CurveSim([for (var i = 0; i < 8; i++) i],
          config: _cfg, random: Random(seed));
      final tick0 = botFor(sim, Random(seed + 100));
      final others = _RandomBots(sim, [1, 2, 3, 4, 5, 6, 7], Random(seed + 200));
      var n = 0;
      while (!sim.roundOver && _head(sim, 0).alive && n < 3000) {
        tick0();
        others.tick();
        sim.tick();
        n++;
      }
      total += n;
    }
    return total / 20;
  }

  test('bot_survives_longer_than_random', () {
    final smart = meanSurvival((sim, r) => Bots(sim, [0], r).tick);
    final random = meanSurvival((sim, r) => _RandomBots(sim, [0], r).tick);
    // ignore: avoid_print
    print('mean survival (ticks): smart=${smart.toStringAsFixed(0)} random=${random.toStringAsFixed(0)}');
    expect(smart, greaterThan(random * 1.3));
  });

  group('square turns', () {
    /// Ticks until the first of the bots dies (or [limit]) when player 0 hands
    /// out square turns on the first tick.
    int firstDeath({required bool square, required int seed, int limit = 900}) {
      final sim = CurveSim([0, 1, 2, 3, 4], config: _cfg, random: Random(seed));
      final bots = Bots(sim, [1, 2, 3, 4], Random(seed + 100));
      if (square) {
        sim.placePowerUp(PowerUpKind.squareOthers, _head(sim, 0).x, _head(sim, 0).y);
        sim.tick();
      }
      for (var t = 1; t <= limit; t++) {
        bots.tick();
        sim.setInput(0, left: false, right: false);
        sim.tick();
        // player 0 just flies straight; it may die, that does not matter
        if ([1, 2, 3, 4].any((i) => !_head(sim, i).alive)) return t;
      }
      return limit;
    }

    test('bots under square turns are hit by the power-up and do not crash at once', () {
      final sim = CurveSim([0, 1], config: _cfg, random: Random(1));
      sim.placePowerUp(PowerUpKind.squareOthers, _head(sim, 0).x, _head(sim, 0).y);
      sim.tick();
      expect(sim.hasEffect(1, PowerUpKind.squareOthers), isTrue);
      // The bots steer through the same input. Four bots and a straight-flying
      // human in the open arena: the first crash comes about as late with square
      // turns as without them (the bots do meet each other's trails either way).
      var square = 0, normal = 0, earliest = 1 << 30;
      for (var seed = 1; seed <= 12; seed++) {
        final t = firstDeath(square: true, seed: seed, limit: 300);
        square += t;
        normal += firstDeath(square: false, seed: seed, limit: 300);
        earliest = min(earliest, t);
      }
      expect(earliest, greaterThan(45), reason: 'no bot crashes within the first 0.75 s');
      expect(square, greaterThan(normal * 0.7), reason: 'square $square vs normal $normal (sum of first-crash ticks)');
    });

    test('a bot flying at a wall still turns away under square turns', () {
      for (final startY in [450.0, 60.0, 840.0]) {
        final sim = CurveSim([1, 2], config: _cfg, random: Random(1));
        final bots = Bots(sim, [1], Random(2));
        sim.place(1, 130, startY, pi);
        sim.place(2, 1500, 450, 0);
        sim.placePowerUp(PowerUpKind.squareOthers, 1500, 450);
        sim.tick(); // 2 picks it up; 1 is hit
        expect(sim.hasEffect(1, PowerUpKind.squareOthers), isTrue);
        for (var i = 0; i < 100; i++) {
          bots.tick();
          sim.tick();
          expect(_head(sim, 1).alive, isTrue, reason: 'startY $startY, tick $i');
        }
      }
    });
  });
}
