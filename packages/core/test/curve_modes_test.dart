import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every power-up that appears over [rounds] rounds of a seeded 2-head sim.
List<PowerUpKind> spawned(CurveConfig config, {int rounds = 30}) {
  final sim = CurveSim([0, 1], config: config, random: Random(7));
  final seen = <int, PowerUpKind>{};
  for (var r = 0; r < rounds; r++) {
    for (var t = 0; t < 1500 && !sim.roundOver; t++) {
      sim.tick();
      for (final p in sim.powerUps) {
        seen[p.id] = p.kind;
      }
    }
    sim.startRound();
  }
  return seen.values.toList();
}

void main() {
  test('balanced_is_todays_values', () {
    const today = CurveConfig();
    final c = CurveConfig.forMode(CurveMode.balanced);
    expect(
        [c.powerUps, c.powerUpEveryMin, c.powerUpEveryMax, c.powerUpMax, c.powerUpKinds, c.countdown],
        [today.powerUps, today.powerUpEveryMin, today.powerUpEveryMax, today.powerUpMax, null, today.countdown]);
  });

  test('forMode_keeps_the_countdown', () {
    expect(CurveConfig.forMode(CurveMode.chaos, countdown: 7).countdown, 7);
  });

  test('peaceful_spawns_nothing', () {
    final c = CurveConfig.forMode(CurveMode.peaceful);
    expect(c.powerUps, isFalse);
    expect(spawned(c), isEmpty);
    expect(spawned(CurveConfig.forMode(CurveMode.balanced)), isNotEmpty, reason: 'the check can see spawns');
  });

  test('chaos_spawns_much_more_than_balanced_and_puts_more_on_the_board', () {
    final chaos = spawned(CurveConfig.forMode(CurveMode.chaos)).length;
    final balanced = spawned(CurveConfig.forMode(CurveMode.balanced)).length;
    expect(chaos, greaterThan(balanced * 2), reason: 'chaos $chaos, balanced $balanced');
    expect(CurveConfig.forMode(CurveMode.chaos).powerUpMax, greaterThan(const CurveConfig().powerUpMax));
  });

  test('a_kinds_list_limits_what_spawns', () {
    final got = spawned(const CurveConfig(powerUpKinds: [PowerUpKind.slow, PowerUpKind.ghost]));
    expect(got, isNotEmpty);
    expect(got.toSet().difference({PowerUpKind.slow, PowerUpKind.ghost}), isEmpty);
  });

  test('only_you_spawns_only_the_green_kinds_at_balanced_pace', () {
    const green = {PowerUpKind.speed, PowerUpKind.slow, PowerUpKind.ghost, PowerUpKind.cheese};
    final c = CurveConfig.forMode(CurveMode.onlyYou);
    final got = spawned(c, rounds: 300);
    expect(got, isNotEmpty);
    expect(got.toSet().difference(green), isEmpty);
    expect(got.toSet(), green, reason: 'all four green kinds turn up');
    expect([c.powerUpEveryMin, c.powerUpEveryMax, c.powerUpMax], [4, 8, 3]);
  });

  test('no_thin_kind_exists_or_spawns_in_any_mode', () {
    expect(PowerUpKind.values.map((k) => k.name), isNot(contains('thin')));
    for (final m in CurveMode.values) {
      final got = spawned(CurveConfig.forMode(m), rounds: 300);
      expect(got.map((k) => k.name), isNot(contains('thin')));
    }
    expect(spawned(CurveConfig.forMode(CurveMode.balanced), rounds: 300).toSet(),
        contains(PowerUpKind.reverseOthers));
  });

  test('cheese and square turns spawn in Kaos and Uravnoteženo, and all four speed kinds exist', () {
    for (final m in [CurveMode.chaos, CurveMode.balanced]) {
      final got = spawned(CurveConfig.forMode(m), rounds: 1500).toSet();
      expect(got, containsAll([PowerUpKind.cheese, PowerUpKind.squareOthers, PowerUpKind.speed, PowerUpKind.slow, PowerUpKind.speedOthers, PowerUpKind.slowOthers]), reason: '$m');
    }
    expect(spawned(CurveConfig.forMode(CurveMode.peaceful), rounds: 30), isEmpty);
  });
}
