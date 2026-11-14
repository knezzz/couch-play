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
    // Head 70 units from the left wall, flying straight at it.
    for (final startY in [450.0, 60.0, 840.0]) {
      final sim = CurveSim([1, 2], random: Random(1));
      final bots = Bots(sim, [1], Random(2));
      sim.place(1, 70, startY, pi);
      sim.place(2, 1500, 450, 0);
      for (var i = 0; i < 100; i++) {
        bots.tick();
        sim.tick();
      }
      expect(_head(sim, 1).alive, isTrue, reason: 'startY=$startY');
    }
  });

  test('bot_turns_away_from_wall_ahead', () {
    // 90 units from the wall the old bot had not reacted yet (it waits for
    // 80). Every seed must already be turning after one tick.
    for (var seed = 0; seed < 10; seed++) {
      final sim = CurveSim([0, 1, 2], config: _cfg, random: Random(1));
      final bots = Bots(sim, [0], Random(seed));
      sim.place(0, 90, 450, pi);
      sim.place(1, 1500, 100, 0);
      sim.place(2, 1500, 800, pi);
      bots.tick();
      sim.tick();
      expect((_head(sim, 0).heading - pi).abs(), greaterThan(0.01), reason: 'seed=$seed');
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
    sim.place(0, 620, 450, 0); // 80 units from the trail, flying at it
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
    sim.placePowerUp(PowerUpKind.ghost, 621, 450);
    final bots = Bots(sim, [0], Random(1));
    sim.tick(); // picks the ghost up
    expect(sim.hasEffect(0, PowerUpKind.ghost), isTrue);
    sim.placePowerUp(PowerUpKind.speed, 790, 450);
    var picked = false;
    var maxOff = 0.0;
    for (var i = 0; i < 120 && !picked; i++) {
      bots.tick();
      picked = sim.tick().any((e) => e is PickedUp && e.kind == PowerUpKind.speed);
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
      sim.placePowerUp(PowerUpKind.speed, 800, 600); // straight below
      final bots = Bots(sim, [0], Random(seed));
      var picked = false;
      for (var i = 0; i < 150 && !picked; i++) {
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
}
