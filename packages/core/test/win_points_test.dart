import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Task 57: "Bodova do pobjede", a setting for Curve and for Sumo. 0 is Automatski, today's 10 x (players - 1).
void main() {
  group('the setting', () {
    test('the default is Automatski for both games', () {
      const s = GameSettings();
      expect(s.curveTarget, 0);
      expect(s.sumoTarget, 0);
      expect(winPointsChoices, [0, 10, 20, 30, 50, 70, 100]);
    });

    test('it round-trips, per game', () {
      const s = GameSettings(curveTarget: 30, sumoTarget: 100);
      final back = (Message.decode(const SetSettings(GameSettings(curveTarget: 30, sumoTarget: 100)).encode()) as SetSettings).settings;
      expect(back.curveTarget, 30);
      expect(back.sumoTarget, 100);
      expect(s.clamped().curveTarget, 30);
      expect(s.withOffPacks({}).sumoTarget, 100);
    });

    test('an older settings message or file without the field reads as Automatski', () {
      final old = GameSettings.fromJson({'quizSeconds': 20, 'quizQuestions': 10, 'revealSeconds': 4, 'curveCountdown': 2});
      expect(old.curveTarget, 0);
      expect(old.sumoTarget, 0);
    });

    test('a bad value (not one of the choices, or not a number) falls back to Automatski', () {
      for (final bad in [7, -5, 1000, 'x', 3.5, null, true]) {
        final s = GameSettings.fromJson({'quizSeconds': 20, 'quizQuestions': 10, 'revealSeconds': 4, 'curveCountdown': 2, 'curveTarget': bad, 'sumoTarget': bad});
        expect(s.curveTarget, 0, reason: '$bad');
        expect(s.sumoTarget, 0, reason: '$bad');
      }
      expect(const GameSettings(curveTarget: 33, sumoTarget: -1).clamped().curveTarget, 0);
      expect(const GameSettings(curveTarget: 33, sumoTarget: -1).clamped().sumoTarget, 0);
    });
  });

  group('the sims', () {
    test('Automatski gives exactly today\'s target: 10 x (players - 1)', () {
      for (var n = 2; n <= 8; n++) {
        final ids = [for (var i = 0; i < n; i++) i];
        expect(CurveSim(ids, random: Random(1)).target, 10 * (n - 1));
        expect(SumoSim(ids, random: Random(1)).target, 10 * (n - 1));
      }
    });

    test('a fixed number is the target, whatever the number of players', () {
      for (final n in [2, 5, 8]) {
        final ids = [for (var i = 0; i < n; i++) i];
        expect(CurveSim(ids, target: 30, random: Random(1)).target, 30);
        expect(SumoSim(ids, target: 100, random: Random(1)).target, 100);
      }
    });

    test('the match ends at the chosen target (Sumo: a clear leader past it)', () {
      final s = SumoSim([0, 1], target: 20, config: const SumoConfig(countdown: 0, powerUps: false), random: Random(1));
      for (var round = 0; round < 25 && !s.matchOver; round++) {
        s.place(1, 500, 0); // out: 0 outlives 1, one point a round
        s.tick();
        if (!s.matchOver) s.startRound();
      }
      expect(s.scores[0], 20);
      expect(s.matchOver, isTrue);
      expect(s.winner, 0);
    });

    test('play still goes on while two share the top past a fixed target', () {
      final s = SumoSim([0, 1], target: 10, config: const SumoConfig(countdown: 0, powerUps: false), random: Random(1));
      s.scores[0] = 10;
      s.scores[1] = 9;
      s.place(0, 500, 0); // 1 outlives 0: 10 and 10
      s.tick();
      expect(s.roundOver, isTrue);
      expect(s.matchOver, isFalse);
    });
  });
}
