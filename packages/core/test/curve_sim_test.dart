import 'dart:math';

import 'package:core/src/curve_sim.dart';
import 'package:flutter_test/flutter_test.dart';

const _noCountdown = CurveConfig(countdown: 0);

/// Ticks until [pred] is true or [max] ticks pass; returns ticks run.
int _run(CurveSim s, bool Function() pred, int max) {
  var n = 0;
  while (n < max && !pred()) {
    s.tick();
    n++;
  }
  return n;
}

bool _alive(CurveSim s, int id) => s.heads.firstWhere((h) => h.id == id).alive;

void main() {
  test('target_is_10_times_players_minus_one', () {
    final s = CurveSim([0, 1, 2], random: Random(1));
    expect(s.target, 20);
    s.kill(1);
    s.tick();
    expect(s.target, 20);
  });

  test('straight_line_hits_wall_and_dies', () {
    final s = CurveSim([0], config: _noCountdown, random: Random(1));
    s.place(0, 400, 450, 0);
    final ticks = _run(s, () => !_alive(s, 0), 2000);
    const expected = (1600 - 400) / 140 * 60;
    expect((ticks - expected).abs(), lessThanOrEqualTo(2));
  });

  test('turning_left_changes_heading_by_turnRate_per_second', () {
    final s = CurveSim([0, 1], config: _noCountdown, random: Random(1));
    s.place(0, 800, 450, 0);
    s.setInput(0, left: true, right: false);
    for (var i = 0; i < 60; i++) {
      s.tick();
    }
    // Left is counter-clockwise on a y-down screen: heading decreases.
    expect(s.heads.firstWhere((h) => h.id == 0).heading, closeTo(-pi, 0.01));
  });

  test('crossing_another_trail_kills', () {
    final s = CurveSim([0, 1], config: _noCountdown, random: Random(1));
    s.place(0, 400, 450, 0); // A heads right
    s.place(1, 500, 380, pi / 2); // B heads down, painting x=500
    _run(s, () => s.roundOver, 200);
    expect(_alive(s, 0), isFalse);
    expect(_alive(s, 1), isTrue);
    expect(s.scores[1], 1);
  });

  test('gap_lets_you_pass', () {
    final s = CurveSim(
      [0, 1],
      config: const CurveConfig(
          countdown: 0, gapEveryMin: 0.1, gapEveryMax: 0.1, gapLength: 100),
      random: Random(1),
    );
    s.place(0, 400, 450, 0);
    s.place(1, 500, 380, pi / 2);
    for (var i = 0; i < 100; i++) {
      s.tick();
    }
    expect(_alive(s, 0), isTrue);
    expect(s.roundOver, isFalse);
  });

  test('own_fresh_trail_does_not_kill', () {
    final s = CurveSim([0, 1], config: _noCountdown, random: Random(1));
    s.place(0, 800, 450, 0);
    s.place(1, 100, 100, 0);
    s.setInput(0, left: true, right: false);
    for (var i = 0; i < 60; i++) {
      s.tick();
    }
    expect(_alive(s, 0), isTrue);
  });

  test('outlive_scoring', () {
    final s = CurveSim([0, 1, 2, 3], config: _noCountdown, random: Random(1));
    for (final id in [1, 2, 3]) {
      s.kill(id);
      s.tick();
    }
    expect(s.roundOver, isTrue);
    expect([for (var i = 0; i < 4; i++) s.scores[i]], [3, 0, 1, 2]);
  });

  test('match_over_at_target_with_unique_leader', () {
    final s = CurveSim([0, 1, 2], config: _noCountdown, random: Random(1));
    s.scores
      ..[0] = 19
      ..[1] = 18;
    s.kill(2);
    s.tick();
    s.kill(0); // 0 gets 1 -> 20, survivor 1 gets 2 -> 20
    s.tick();
    expect(s.roundOver, isTrue);
    expect(s.scores[0], 20);
    expect(s.scores[1], 20);
    expect(s.matchOver, isFalse);

    // Next round: player 1 outlives player 0 and takes the lead.
    s.startRound();
    s.kill(2);
    s.tick();
    s.kill(0);
    s.tick();
    expect(s.matchOver, isTrue);
    expect(s.winner, 1);
  });

  test('countdown_freezes_movement', () {
    final s = CurveSim([0, 1], random: Random(1));
    final before = [for (final h in s.heads) (h.x, h.y)];
    for (var i = 0; i < 120; i++) {
      s.tick();
    }
    expect([for (final h in s.heads) (h.x, h.y)], before);
    s.tick();
    expect([for (final h in s.heads) (h.x, h.y)], isNot(before));
  });
}
