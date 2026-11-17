import 'dart:math';

import 'package:core/src/curve_sim.dart';
import 'package:flutter_test/flutter_test.dart';

/// No countdown, no gaps, no random spawns, 1 s effects: tests place power-ups
/// themselves and run for a second or two.
CurveConfig _cfg({double effectSeconds = 1, bool powerUps = false}) => CurveConfig(
      countdown: 0,
      gapEveryMin: 1e6,
      gapEveryMax: 1e6 + 1,
      powerUps: powerUps,
      effectSeconds: effectSeconds,
    );

/// Player 0 is the subject at (800,450) heading right; 1 and 2 fly far from it.
CurveSim _sim({double effectSeconds = 1}) {
  final s = CurveSim([0, 1, 2],
      config: _cfg(effectSeconds: effectSeconds), random: Random(1));
  s.place(0, 800, 450, 0);
  s.place(1, 100, 100, 0);
  s.place(2, 100, 800, 0);
  return s;
}

CurveHead _head(CurveSim s, int id) => s.heads.firstWhere((h) => h.id == id);

List<CurveEvent> _ticks(CurveSim s, int n) =>
    [for (var i = 0; i < n; i++) ...s.tick()];

/// Distance player [id] covers in the next [n] ticks, flying straight.
double _travel(CurveSim s, int id, int n) {
  final a = _head(s, id);
  _ticks(s, n);
  final b = _head(s, id);
  return sqrt(pow(b.x - a.x, 2) + pow(b.y - a.y, 2));
}

void _pickUp(CurveSim s, PowerUpKind k) {
  s.placePowerUp(k, _head(s, 0).x, _head(s, 0).y);
  s.tick();
}

void main() {
  test('fat_lasts_one_and_a_half_times_as_long', () {
    // 1 s effects = 60 ticks; fat gets 90, the rest 60.
    final s = _sim();
    _pickUp(s, PowerUpKind.slow);
    s.placePowerUp(PowerUpKind.fatOthers, _head(s, 0).x, _head(s, 0).y);
    s.tick();
    expect(s.effectLeft(1, PowerUpKind.fatOthers), 1.0);
    _ticks(s, 60);
    expect(s.hasEffect(0, PowerUpKind.slow), isFalse);
    expect(s.hasEffect(1, PowerUpKind.fatOthers), isTrue);
    _ticks(s, 30);
    expect(s.hasEffect(1, PowerUpKind.fatOthers), isFalse);
  });

  test('slow_slows_you_down_then_expires', () {
    final s = _sim();
    final base = _travel(s, 0, 10);
    _pickUp(s, PowerUpKind.slow);
    expect(s.hasEffect(0, PowerUpKind.slow), isTrue);
    expect(_travel(s, 0, 10), lessThan(base * 0.7));
    expect(_travel(s, 1, 10), closeTo(base, 0.01), reason: 'others unaffected');
    _ticks(s, 60);
    expect(s.hasEffect(0, PowerUpKind.slow), isFalse);
    expect(_travel(s, 0, 10), closeTo(base, 0.01));
  });

  test('pickup_emits_event_and_removes_the_item', () {
    final s = _sim();
    s.placePowerUp(PowerUpKind.slow, 800, 450);
    expect(s.powerUps.length, 1);
    final events = s.tick();
    final picked = events.whereType<PickedUp>().toList();
    expect(picked.length, 1);
    expect(picked.single.playerId, 0);
    expect(picked.single.kind, PowerUpKind.slow);
    expect(s.powerUps, isEmpty);
  });

  test('first_head_to_arrive_gets_it_and_only_one_pickup_happens', () {
    final s = _sim();
    s.place(1, 800, 450, 0); // same spot as the subject
    s.placePowerUp(PowerUpKind.slow, 800, 450);
    final picked = s.tick().whereType<PickedUp>().toList();
    expect(picked.length, 1);
    final winner = picked.single.playerId;
    expect(s.hasEffect(winner, PowerUpKind.slow), isTrue);
    expect(s.hasEffect(winner == 0 ? 1 : 0, PowerUpKind.slow), isFalse);
  });

  test('speed_others_speeds_everyone_but_the_picker', () {
    final s = _sim();
    final base = _travel(s, 1, 10);
    _pickUp(s, PowerUpKind.speedOthers);
    expect(s.hasEffect(1, PowerUpKind.speedOthers), isTrue);
    expect(s.hasEffect(0, PowerUpKind.speedOthers), isFalse);
    expect(_travel(s, 1, 10), greaterThan(base * 1.4));
    expect(_travel(s, 0, 10), closeTo(base, 0.01));
    _ticks(s, 60);
    expect(s.hasEffect(1, PowerUpKind.speedOthers), isFalse);
  });

  test('fat_others_widens_and_collides_wider_but_not_for_the_picker', () {
    final s = _sim();
    _pickUp(s, PowerUpKind.fatOthers);
    expect(s.hasEffect(1, PowerUpKind.fatOthers), isTrue);
    expect(s.hasEffect(0, PowerUpKind.fatOthers), isFalse);
    s.takeNewSegments();
    s.tick();
    final segs = s.takeNewSegments();
    expect(segs.firstWhere((g) => g.id == 1).width, 12);
    expect(segs.firstWhere((g) => g.id == 0).width, 6);

    // Collision uses the fat width: 8 units from the wall is safe for a
    // normal line but not for a fat one (radius 6, and it moves 2.3 closer).
    Iterable<bool> alive(bool fat) {
      final t = _sim();
      if (fat) _pickUp(t, PowerUpKind.fatOthers);
      t.place(2, 8, 450, pi);
      t.tick();
      return [_head(t, 2).alive];
    }

    expect(alive(false), [true]);
    expect(alive(true), [false]);
  });

  /// Width of the newest segment player [id] paints.
  double width(CurveSim s, int id) {
    s.takeNewSegments();
    s.tick();
    return s.takeNewSegments().firstWhere((g) => g.id == id).width;
  }

  test('fat_stacks_fatter_each_pickup_up_to_three_and_the_picker_is_spared', () {
    final s = _sim(effectSeconds: 20);
    expect(width(s, 1), 6);
    final seen = <double>[];
    for (var i = 0; i < 5; i++) {
      s.placePowerUp(PowerUpKind.fatOthers, _head(s, 0).x, _head(s, 0).y);
      s.tick();
      seen.add(width(s, 1));
    }
    expect(seen, [12, 18, 24, 24, 24], reason: 'x2, x3, x4, then capped at 3 stacks');
    expect(width(s, 2), 24);
    expect(width(s, 0), 6);
    expect([for (final id in [0, 1, 2]) s.effectStacks(id, PowerUpKind.fatOthers)], [0, 3, 3]);
  });

  test('a_fat_pickup_restarts_the_timer_and_stacks_start_over_after_it_ends', () {
    final s = _sim(); // fat = 90 ticks
    s.placePowerUp(PowerUpKind.fatOthers, _head(s, 0).x, _head(s, 0).y);
    s.tick();
    _ticks(s, 60);
    s.placePowerUp(PowerUpKind.fatOthers, _head(s, 0).x, _head(s, 0).y);
    s.tick();
    expect(s.effectLeft(1, PowerUpKind.fatOthers), 1.0);
    expect(s.effectStacks(1, PowerUpKind.fatOthers), 2);
    _ticks(s, 100);
    expect(s.hasEffect(1, PowerUpKind.fatOthers), isFalse);
    expect(s.effectStacks(1, PowerUpKind.fatOthers), 0);
    s.placePowerUp(PowerUpKind.fatOthers, _head(s, 0).x, _head(s, 0).y);
    s.tick();
    expect(s.effectStacks(1, PowerUpKind.fatOthers), 1, reason: 'a new run starts at one stack');
  });

  test('stacked_fat_collides_with_its_full_width', () {
    // Radius 12 at 3 stacks: 13 units from the wall is safe for normal and one
    // stack (radius 6) but not for three stacks.
    bool survives(int stacks) {
      final t = _sim(effectSeconds: 20);
      for (var i = 0; i < stacks; i++) {
        t.placePowerUp(PowerUpKind.fatOthers, _head(t, 0).x, _head(t, 0).y);
        t.tick();
      }
      t.place(2, 13, 450, pi);
      t.tick();
      return _head(t, 2).alive;
    }

    expect(survives(1), isTrue);
    expect(survives(3), isFalse);
  });

  /// Head 1 gets [stacks] fat (from head 0) and maybe slow, then holds right
  /// from the centre. Heads 0 and 2 turn ghost in the corners so the round never
  /// ends. Returns the tick head 1 died, or -1. (Probe from check-review.)
  int circle(int stacks, bool slow, [bool fast = false]) {
    final s = CurveSim([0, 1, 2],
        config: const CurveConfig(
            countdown: 0, gapEveryMin: 1e6, gapEveryMax: 1e6 + 1, powerUps: false, effectSeconds: 100),
        random: Random(1));
    s.place(0, 300, 200, 0);
    s.place(1, 300, 800, -pi / 2);
    s.place(2, 1300, 700, pi);
    for (var i = 0; i < stacks; i++) {
      s.placePowerUp(PowerUpKind.fatOthers, _head(s, 0).x, _head(s, 0).y);
      s.tick();
    }
    if (slow) {
      s.placePowerUp(PowerUpKind.slow, _head(s, 1).x, _head(s, 1).y);
      s.tick();
    }
    if (fast) {
      s.placePowerUp(PowerUpKind.speed, _head(s, 1).x, _head(s, 1).y);
      s.tick();
    }
    s.placePowerUp(PowerUpKind.ghost, _head(s, 0).x, _head(s, 0).y);
    s.tick();
    s.placePowerUp(PowerUpKind.ghost, _head(s, 2).x, _head(s, 2).y);
    s.tick();
    s.place(0, 200, 200, 0);
    s.place(2, 1400, 700, 0);
    s.place(1, 800, 450, 0);
    s.setInput(0, left: false, right: true);
    s.setInput(2, left: false, right: true);
    s.setInput(1, left: false, right: true);
    for (var t = 1; t <= 95; t++) {
      s.tick();
      if (!_head(s, 1).alive) return t;
    }
    return -1;
  }

  test('a_fat_or_slow_head_does_not_die_on_its_own_fresh_trail_while_turning', () {
    // The grace for own cells is a distance, not a fixed tick count: fat x4 at
    // 0.6 speed died at tick 38. The circle closes into its own start at about tick 100 (x4, slow) to 120, so
    // 95 ticks is the longest check that cannot be a real self-hit.
    for (final slow in [false, true]) {
      for (var stacks = 0; stacks <= 3; stacks++) {
        expect(circle(stacks, slow), -1, reason: 'stacks=$stacks slow=$slow');
      }
    }
  });

  test('reverse_others_swaps_left_and_right_for_the_others_only_then_expires', () {
    final s = _sim(); // 60 ticks
    for (final id in [0, 1, 2]) {
      s.place(id, id == 0 ? 800 : 100, id == 0 ? 450 : id == 1 ? 100 : 800, 0);
      s.setInput(id, left: true, right: false);
    }
    _pickUp(s, PowerUpKind.reverseOthers);
    expect(s.hasEffect(0, PowerUpKind.reverseOthers), isFalse);
    expect(s.hasEffect(1, PowerUpKind.reverseOthers), isTrue);
    expect(s.hasEffect(2, PowerUpKind.reverseOthers), isTrue);
    final h0 = _head(s, 0).heading, h1 = _head(s, 1).heading;
    _ticks(s, 10);
    expect(_head(s, 0).heading, lessThan(h0), reason: 'the picker steers left as asked');
    expect(_head(s, 1).heading, greaterThan(h1), reason: 'the others go right');
    _ticks(s, 60);
    expect(s.hasEffect(1, PowerUpKind.reverseOthers), isFalse);
    final before = _head(s, 1).heading;
    _ticks(s, 5);
    expect(_head(s, 1).heading, lessThan(before), reason: 'back to normal');
  });

  test('a_second_reverse_pickup_restarts_the_timer', () {
    final s = _sim();
    _pickUp(s, PowerUpKind.reverseOthers);
    _ticks(s, 40);
    _pickUp(s, PowerUpKind.reverseOthers);
    expect(s.effectLeft(1, PowerUpKind.reverseOthers), 1.0);
    expect(s.effectLeft(0, PowerUpKind.reverseOthers), 0);
    _ticks(s, 30);
    expect(s.hasEffect(1, PowerUpKind.reverseOthers), isTrue);
  });

  test('a_ghost_paints_no_line_and_leaves_no_grid_cells_while_it_lasts', () {
    final s = _sim(effectSeconds: 20);
    s.place(0, 300, 450, 0);
    s.placePowerUp(PowerUpKind.ghost, 301, 450);
    s.tick();
    s.takeNewSegments();
    _ticks(s, 30);
    expect(s.takeNewSegments().where((g) => g.id == 0), isEmpty);
    // Nothing on the grid behind it: no probe along its path is blocked.
    for (var x = 310.0; x < _head(s, 0).x; x += 4) {
      expect(s.isBlocked(x, 450), isFalse, reason: 'x=$x');
    }
    // Control: a head without ghost leaves a trail the probe finds.
    final c = _sim();
    c.place(0, 300, 450, 0);
    _ticks(c, 30);
    expect(c.isBlocked(_head(c, 0).x - 40, 450), isTrue);
    // After the ghost ends the line comes back.
    final e = _sim(effectSeconds: 1);
    e.place(0, 300, 450, 0);
    e.placePowerUp(PowerUpKind.ghost, 301, 450);
    e.tick();
    _ticks(e, 70);
    e.takeNewSegments();
    e.tick();
    expect(e.takeNewSegments().where((g) => g.id == 0), isNotEmpty);
  });

  test('ghost_passes_trail_not_wall', () {
    final s = _sim(effectSeconds: 20);
    s.place(0, 600, 450, 0);
    s.place(1, 700, 380, pi / 2); // lays a vertical trail across y=450
    s.place(2, 100, 100, 0); // stays clear of that trail
    s.placePowerUp(PowerUpKind.ghost, 601, 450);
    s.tick();
    expect(s.hasEffect(0, PowerUpKind.ghost), isTrue);
    _ticks(s, 60); // crosses x=700 at about tick 43
    expect(_head(s, 0).x, greaterThan(740));
    expect(_head(s, 0).alive, isTrue);

    // Control: without the ghost the same crossing kills.
    final c = _sim();
    c.place(0, 600, 450, 0);
    c.place(1, 700, 380, pi / 2);
    _ticks(c, 60);
    expect(_head(c, 0).alive, isFalse);

    // The ghost still dies at the wall.
    _ticks(s, 500);
    expect(_head(s, 0).alive, isFalse);
  });

  test('wrap_comes_out_opposite_side', () {
    final s = _sim(effectSeconds: 5);
    s.place(0, 1595, 450, 0);
    _pickUp(s, PowerUpKind.wrap);
    _ticks(s, 5); // would have left the arena after about 2 ticks
    final h = _head(s, 0);
    expect(h.alive, isTrue);
    expect(h.x, lessThan(100));
    expect(h.x, greaterThanOrEqualTo(0));

    // It wraps for everyone, vertically too.
    s.place(1, 500, 3, -pi / 2);
    _ticks(s, 3);
    expect(_head(s, 1).alive, isTrue);
    expect(_head(s, 1).y, greaterThan(800));
  });

  test('wrap_trail_is_never_a_long_line', () {
    final s = _sim(effectSeconds: 5);
    s.place(0, 1597, 450, 0);
    _pickUp(s, PowerUpKind.wrap);
    s.takeNewSegments();
    _ticks(s, 6);
    for (final g in s.takeNewSegments()) {
      expect((g.x2 - g.x1).abs(), lessThan(10));
      expect((g.y2 - g.y1).abs(), lessThan(10));
    }
  });

  test('wrap_ends_after_the_effect', () {
    final s = _sim(effectSeconds: 1);
    _pickUp(s, PowerUpKind.wrap);
    _ticks(s, 65); // effect (60 ticks) is over
    expect(s.hasEffect(0, PowerUpKind.wrap), isFalse);
    s.place(0, 1595, 450, 0);
    _ticks(s, 5);
    expect(_head(s, 0).alive, isFalse); // the wall kills again
  });

  test('clear_empties_grid', () {
    // Player 1 lays a vertical trail through (700, 450), then leaves.
    CurveSim crossing({required bool withClear}) {
      final s = _sim();
      s.place(0, 100, 600, 0); // out of the way while the trail is laid
      s.place(1, 700, 380, pi / 2);
      _ticks(s, 40);
      s.kill(1);
      s.place(0, 600, 450, 0);
      if (withClear) s.placePowerUp(PowerUpKind.clear, 650, 450);
      return s;
    }

    final control = crossing(withClear: false);
    _ticks(control, 60);
    expect(_head(control, 0).alive, isFalse); // the trail kills

    final s = crossing(withClear: true);
    s.takeCleared();
    var cleared = false;
    for (var i = 0; i < 60; i++) {
      s.tick();
      cleared |= s.takeCleared();
    }
    expect(cleared, isTrue);
    expect(s.takeCleared(), isFalse); // true only once
    expect(_head(s, 0).alive, isTrue); // crossed where the trail used to be
    expect(_head(s, 0).x, greaterThan(720));
  });

  test('clear_drops_segments_from_before_it', () {
    final s = _sim();
    _ticks(s, 5);
    s.placePowerUp(PowerUpKind.clear, _head(s, 0).x, _head(s, 0).y);
    s.tick();
    expect(s.takeCleared(), isTrue);
    expect(s.takeNewSegments(), isEmpty);
    s.tick();
    expect(s.takeNewSegments(), isNotEmpty); // new trail after the clear
  });

  test('second_pickup_restarts_the_timer', () {
    final s = _sim(effectSeconds: 1); // 60 ticks
    _pickUp(s, PowerUpKind.slow);
    _ticks(s, 40);
    _pickUp(s, PowerUpKind.slow);
    _ticks(s, 30); // 71 ticks after the first pickup
    expect(s.hasEffect(0, PowerUpKind.slow), isTrue);
    _ticks(s, 40);
    expect(s.hasEffect(0, PowerUpKind.slow), isFalse);
  });

  test('effects_and_items_end_with_the_round', () {
    final s = _sim(effectSeconds: 20);
    _pickUp(s, PowerUpKind.slow);
    _pickUp(s, PowerUpKind.wrap);
    s.placePowerUp(PowerUpKind.ghost, 1000, 100);
    s.startRound();
    expect(s.hasEffect(0, PowerUpKind.slow), isFalse);
    expect(s.powerUps, isEmpty);
    s.place(0, 1595, 450, 0);
    _ticks(s, 5);
    expect(_head(s, 0).alive, isFalse); // wrap did not carry over
  });

  test('no_spawn_during_countdown', () {
    final s = CurveSim([0, 1],
        config: const CurveConfig(
            countdown: 1,
            powerUpEveryMin: 0.05,
            powerUpEveryMax: 0.05,
            gapEveryMin: 1e6,
            gapEveryMax: 1e6 + 1),
        random: Random(1));
    _ticks(s, 60);
    expect(s.countingDown, isFalse);
    expect(s.powerUps, isEmpty);
    _ticks(s, 10);
    expect(s.powerUps, isNotEmpty);
  });

  test('spawns_are_capped', () {
    final s = CurveSim([0, 1],
        config: const CurveConfig(
            countdown: 0,
            powerUpEveryMin: 0.05,
            powerUpEveryMax: 0.05,
            powerUpMax: 3,
            gapEveryMin: 1e6,
            gapEveryMax: 1e6 + 1),
        random: Random(7));
    s.place(0, 800, 450, 0);
    s.place(1, 100, 100, 0);
    s.setInput(0, left: true, right: false); // keep both alive and near home
    s.setInput(1, left: true, right: false);
    var most = 0;
    for (var i = 0; i < 100; i++) {
      s.tick();
      most = max(most, s.powerUps.length);
    }
    expect(most, lessThanOrEqualTo(3));
    expect(most, greaterThan(0));
  });

  test('effect_time_left_drains_to_zero', () {
    final s = _sim(); // 1 s effects = 60 ticks
    expect(s.effectLeft(0, PowerUpKind.slow), 0);
    _pickUp(s, PowerUpKind.slow);
    expect(s.effectLeft(0, PowerUpKind.slow), 1.0);
    _ticks(s, 30);
    expect(s.effectLeft(0, PowerUpKind.slow), closeTo(0.5, 0.02));
    _ticks(s, 30);
    expect(s.effectLeft(0, PowerUpKind.slow), 0);
    expect(s.effectLeft(1, PowerUpKind.slow), 0, reason: 'only the picker had it');
    expect(s.effectLeft(99, PowerUpKind.slow), 0, reason: 'unknown player');
  });

  test('others_effects_report_for_the_others_only', () {
    final s = _sim();
    _pickUp(s, PowerUpKind.speedOthers);
    expect(s.effectLeft(0, PowerUpKind.speedOthers), 0);
    expect(s.effectLeft(1, PowerUpKind.speedOthers), 1.0);
    expect(s.effectLeft(2, PowerUpKind.speedOthers), 1.0);
  });

  test('second_pickup_restarts_time_left', () {
    final s = _sim();
    _pickUp(s, PowerUpKind.slow);
    _ticks(s, 40);
    expect(s.effectLeft(0, PowerUpKind.slow), lessThan(0.4));
    _pickUp(s, PowerUpKind.slow);
    expect(s.effectLeft(0, PowerUpKind.slow), 1.0);
  });

  test('wrap_reports_everyone', () {
    final s = _sim();
    expect(s.wrapLeft, 0);
    _pickUp(s, PowerUpKind.wrap);
    expect(s.wrapLeft, 1.0);
    for (final id in [0, 1, 2]) {
      expect(s.effectLeft(id, PowerUpKind.wrap), 1.0);
    }
    _ticks(s, 30);
    expect(s.wrapLeft, closeTo(0.5, 0.02));
    _ticks(s, 30);
    expect(s.wrapLeft, 0);
  });

  test('a_killed_head_is_back_at_the_next_round_after_revive', () {
    final s = _sim();
    s.kill(1);
    expect(_head(s, 1).alive, isFalse);
    s.revive(1);
    expect(_head(s, 1).alive, isFalse, reason: 'this round stays lost');
    s.roundOver = true;
    s.startRound();
    expect(_head(s, 1).alive, isTrue);
    s.kill(2);
    s.roundOver = true;
    s.startRound();
    expect(_head(s, 2).alive, isFalse, reason: 'not revived: still gone');
  });

  test('clear_has_no_time_left', () {
    final s = _sim();
    _pickUp(s, PowerUpKind.clear);
    expect(s.effectLeft(0, PowerUpKind.clear), 0);
  });

  test('names_are_kept_for_the_renderer', () {
    final s = CurveSim([0, 1], names: {0: 'Ana', 1: 'Bot 1'});
    expect(s.names[0], 'Ana');
    expect(CurveSim([0, 1]).names, isEmpty);
  });

  test('powerups_off_never_spawn', () {
    final s = CurveSim([0, 1],
        config: const CurveConfig(
            countdown: 0,
            powerUps: false,
            powerUpEveryMin: 0.05,
            powerUpEveryMax: 0.05),
        random: Random(1));
    s.setInput(0, left: true, right: false);
    s.setInput(1, left: true, right: false);
    _ticks(s, 100);
    expect(s.powerUps, isEmpty);
  });

  group('cheese (green): your line gets many long gaps', () {
    /// Gaps that start (inGap false -> true) in the next [n] ticks for head 0.
    int gapStarts(CurveSim s, int n) {
      var was = _head(s, 0).inGap, starts = 0;
      for (var i = 0; i < n; i++) {
        s.tick();
        final now = _head(s, 0).inGap;
        if (now && !was) starts++;
        was = now;
      }
      return starts;
    }

    /// The longest run of ticks head 0 spends in a gap.
    int longestGap(CurveSim s, int n) {
      var run = 0, best = 0;
      for (var i = 0; i < n; i++) {
        s.tick();
        run = _head(s, 0).inGap ? run + 1 : 0;
        if (run > best) best = run;
      }
      return best;
    }

    CurveSim cheeseSim({double effectSeconds = 3, double gapEvery = 1e6}) {
      final s = CurveSim([0, 1, 2],
          config: CurveConfig(
              countdown: 0,
              arenaW: 4000,
              gapEveryMin: gapEvery,
              gapEveryMax: gapEvery + 1,
              powerUps: false,
              effectSeconds: effectSeconds),
          random: Random(1));
      s.place(0, 100, 450, 0);
      s.place(1, 100, 100, 0);
      s.place(2, 100, 800, 0);
      return s;
    }

    test('only the picker gets it', () {
      final s = _sim();
      _pickUp(s, PowerUpKind.cheese);
      expect(s.hasEffect(0, PowerUpKind.cheese), isTrue);
      expect(s.hasEffect(1, PowerUpKind.cheese), isFalse);
      expect(s.hasEffect(2, PowerUpKind.cheese), isFalse);
    });

    test('while it lasts there are many gaps (normal gaps are switched off here), then none', () {
      final s = cheeseSim(); // 3 s = 180 ticks
      expect(gapStarts(s, 240), 0, reason: 'no gaps without cheese in this setup');
      s.place(0, 100, 300, 0); // a fresh lane: not across the trail just laid
      s.placePowerUp(PowerUpKind.cheese, _head(s, 0).x, _head(s, 0).y);
      s.tick();
      final during = gapStarts(s, 175);
      expect(during, greaterThanOrEqualTo(3), reason: 'many gaps in 3 s: $during');
      s.tick();
      s.tick();
      s.tick();
      s.tick();
      s.tick();
      expect(s.hasEffect(0, PowerUpKind.cheese), isFalse);
      final startedGap = _head(s, 0).inGap;
      final after = gapStarts(s, 600);
      expect(startedGap, isFalse, reason: 'no gap is opened by the end of cheese itself');
      expect(after, 0, reason: 'normal gaps again, and those are off here');
    });

    test('the first cheese gap comes soon after the pickup, even when the normal gap is far off', () {
      final s = cheeseSim(effectSeconds: 5);
      s.placePowerUp(PowerUpKind.cheese, _head(s, 0).x, _head(s, 0).y);
      s.tick();
      expect(gapStarts(s, 90), greaterThanOrEqualTo(1), reason: 'within 1.5 s');
    });

    test('cheese gaps are longer than the normal gap', () {
      final normal = cheeseSim(gapEvery: 0.3)..place(0, 100, 450, 0);
      final normalLongest = longestGap(normal, 300);
      expect(normalLongest, lessThanOrEqualTo((const CurveConfig().gapLength * 60).round()));
      final s = cheeseSim(effectSeconds: 5);
      s.placePowerUp(PowerUpKind.cheese, _head(s, 0).x, _head(s, 0).y);
      s.tick();
      expect(longestGap(s, 280), greaterThan(normalLongest * 1.4));
    });

    test('a gap leaves no trail: the cheese line really has holes', () {
      final s = cheeseSim(effectSeconds: 4);
      s.placePowerUp(PowerUpKind.cheese, _head(s, 0).x, _head(s, 0).y);
      s.tick();
      var segments = 0, ticks = 0;
      for (var i = 0; i < 200; i++) {
        s.tick();
        ticks++;
        segments += s.takeNewSegments().where((t) => t.id == 0).length;
      }
      expect(segments, lessThan(ticks * 0.8), reason: 'painted in fewer than 80% of the ticks: $segments of $ticks');
    });

    test('it ends with the round', () {
      final s = _sim(effectSeconds: 10);
      _pickUp(s, PowerUpKind.cheese);
      s.startRound();
      expect(s.hasEffect(0, PowerUpKind.cheese), isFalse);
    });
  });

  group('square turns (red): a held button turns exactly 90 degrees once', () {
    CurveSim squareSim() {
      final s = _sim(effectSeconds: 2);
      s.place(0, 800, 450, 0);
      s.place(1, 400, 450, 0);
      s.place(2, 400, 800, 0);
      return s;
    }

    void giveSquare(CurveSim s) => _pickUp(s, PowerUpKind.squareOthers);

    test('only the others are hit', () {
      final s = squareSim();
      giveSquare(s);
      expect(s.hasEffect(0, PowerUpKind.squareOthers), isFalse);
      expect(s.hasEffect(1, PowerUpKind.squareOthers), isTrue);
      expect(s.hasEffect(2, PowerUpKind.squareOthers), isTrue);
    });

    test('a held right turns +90 degrees once, then goes straight', () {
      final s = squareSim();
      giveSquare(s);
      final h0 = _head(s, 1).heading;
      s.setInput(1, left: false, right: true);
      s.tick();
      expect(_head(s, 1).heading, closeTo(h0 + pi / 2, 1e-9));
      _ticks(s, 30);
      expect(_head(s, 1).heading, closeTo(h0 + pi / 2, 1e-9), reason: 'still held, still straight');
    });

    test('a held left turns -90 degrees once', () {
      final s = squareSim();
      giveSquare(s);
      final h0 = _head(s, 1).heading;
      s.setInput(1, left: true, right: false);
      s.tick();
      _ticks(s, 10);
      expect(_head(s, 1).heading, closeTo(h0 - pi / 2, 1e-9));
    });

    test('release and press again turns another 90 degrees', () {
      final s = squareSim();
      giveSquare(s);
      final h0 = _head(s, 1).heading;
      s.setInput(1, left: false, right: true);
      _ticks(s, 5);
      s.setInput(1, left: false, right: false);
      _ticks(s, 3);
      expect(_head(s, 1).heading, closeTo(h0 + pi / 2, 1e-9));
      s.setInput(1, left: false, right: true);
      _ticks(s, 5);
      expect(_head(s, 1).heading, closeTo(h0 + pi, 1e-9));
    });

    test('switching straight from one button to the other turns the other way', () {
      final s = squareSim();
      giveSquare(s);
      final h0 = _head(s, 1).heading;
      s.setInput(1, left: false, right: true);
      s.tick();
      s.setInput(1, left: true, right: false);
      s.tick();
      expect(_head(s, 1).heading, closeTo(h0, 1e-9), reason: '+90 then -90');
    });

    test('a button already held when it is picked up does not turn until pressed again', () {
      final s = squareSim();
      s.setInput(1, left: false, right: true);
      _ticks(s, 3);
      giveSquare(s);
      final h1 = _head(s, 1).heading;
      _ticks(s, 10);
      expect(_head(s, 1).heading, closeTo(h1, 1e-9), reason: 'held, so no new press: straight, no snap');
      s.setInput(1, left: false, right: false);
      s.tick();
      s.setInput(1, left: false, right: true);
      s.tick();
      expect(_head(s, 1).heading, closeTo(h1 + pi / 2, 1e-9));
    });

    test('a tap whose press and release both land between two ticks still turns 90 degrees', () {
      final s = squareSim();
      giveSquare(s);
      final h0 = _head(s, 1).heading;
      s.setInput(1, left: false, right: true);
      s.setInput(1, left: false, right: false); // released before the next tick
      s.tick();
      expect(_head(s, 1).heading, closeTo(h0 + pi / 2, 1e-9));
      s.tick();
      expect(_head(s, 1).heading, closeTo(h0 + pi / 2, 1e-9), reason: 'once only');
      s.setInput(1, left: true, right: false);
      s.setInput(1, left: false, right: false);
      s.tick();
      expect(_head(s, 1).heading, closeTo(h0, 1e-9), reason: 'and the left tap turns back');
    });

    test('a tap is not remembered across ticks, and a press-and-hold turns once, not twice', () {
      final s = squareSim();
      giveSquare(s);
      final h0 = _head(s, 1).heading;
      s.setInput(1, left: false, right: true);
      s.tick(); // turns
      _ticks(s, 20);
      expect(_head(s, 1).heading, closeTo(h0 + pi / 2, 1e-9));
      s.setInput(1, left: false, right: false);
      _ticks(s, 20);
      expect(_head(s, 1).heading, closeTo(h0 + pi / 2, 1e-9), reason: 'the old press is gone');
    });

    test('without square turns a tap between ticks changes nothing, and held steering is as before', () {
      final s = squareSim();
      final h0 = _head(s, 1).heading;
      s.setInput(1, left: false, right: true);
      s.setInput(1, left: false, right: false);
      s.tick();
      expect(_head(s, 1).heading, closeTo(h0, 1e-9));
      s.setInput(1, left: false, right: true);
      _ticks(s, 10);
      expect(_head(s, 1).heading - h0, closeTo(pi * 10 / 60, 1e-6));
    });

    test('the picker keeps steering smoothly', () {
      final s = squareSim();
      giveSquare(s);
      final h0 = _head(s, 0).heading;
      s.setInput(0, left: false, right: true);
      _ticks(s, 10);
      expect(_head(s, 0).heading - h0, closeTo(pi * 10 / 60, 1e-6));
    });

    test('after it ends steering is smooth again', () {
      final s = squareSim();
      giveSquare(s);
      _ticks(s, 125); // 2 s = 120 ticks
      expect(s.hasEffect(1, PowerUpKind.squareOthers), isFalse);
      s.setInput(1, left: false, right: true);
      final h0 = _head(s, 1).heading;
      _ticks(s, 10);
      expect(_head(s, 1).heading - h0, closeTo(pi * 10 / 60, 1e-6));
    });

    test('with reverse on top, the 90 degrees go the other way', () {
      final s = squareSim();
      _pickUp(s, PowerUpKind.reverseOthers);
      s.place(0, 800, 450, 0);
      giveSquare(s);
      final h0 = _head(s, 1).heading;
      s.setInput(1, left: false, right: true);
      s.tick();
      expect(_head(s, 1).heading, closeTo(h0 - pi / 2, 1e-9));
    });
  });

  group('speed and slow exist both ways', () {
    test('speed up: the picker 1.6 x (green)', () {
      final s = _sim();
      final base = _travel(s, 1, 10);
      _pickUp(s, PowerUpKind.speed);
      expect(s.hasEffect(0, PowerUpKind.speed), isTrue);
      expect(s.hasEffect(1, PowerUpKind.speed), isFalse);
      expect(_travel(s, 0, 10) / base, closeTo(1.6, 0.02));
      expect(_travel(s, 1, 10), closeTo(base, 0.01));
    });

    test('slow down others: everyone but the picker 0.6 x (red)', () {
      final s = _sim();
      final base = _travel(s, 1, 10);
      _pickUp(s, PowerUpKind.slowOthers);
      expect(s.hasEffect(0, PowerUpKind.slowOthers), isFalse);
      expect(s.hasEffect(1, PowerUpKind.slowOthers), isTrue);
      expect(s.hasEffect(2, PowerUpKind.slowOthers), isTrue);
      expect(_travel(s, 1, 10) / base, closeTo(0.6, 0.02));
      expect(_travel(s, 0, 10), closeTo(base, 0.01));
    });

    test('all four exist, plus cheese and square turns', () {
      expect(PowerUpKind.values.map((k) => k.name),
          containsAll(['speed', 'slow', 'speedOthers', 'slowOthers', 'ghost', 'cheese', 'fatOthers', 'reverseOthers', 'squareOthers', 'clear', 'wrap']));
    });

    test('a fast head does not die on its own fresh trail while turning (grace scales with speed)', () {
      expect(circle(0, false, true), -1);
      expect(circle(3, false, true), -1);
    });
  });
}
