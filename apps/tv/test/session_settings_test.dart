import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 23: the host's game settings.
void main() {
  late Session s;
  late FakePeer a, b;
  var now = Duration.zero;

  QuizPack pack(int n) => QuizPack('big', 'Big', [
        for (var i = 0; i < n; i++) PackQuestion('Q$i?', null, const ['a', 'b', 'c', 'd'], 0),
      ], const {});

  void setUpSession() {
    now = Duration.zero;
    s = Session(random: Random(1), clock: () => now);
    s.packLookup = (_) => pack(30);
    a = join(s, 'Ana', token: 'ta');
    b = join(s, 'Ben', token: 'tb');
  }

  Future<void> step(WidgetTester t, Duration d) async {
    for (var left = d; left > Duration.zero; left -= const Duration(milliseconds: 100)) {
      now += const Duration(milliseconds: 100);
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  const custom = GameSettings(quizSeconds: 40, quizQuestions: 15, revealSeconds: 7, curveCountdown: 5);

  test('defaults_are_20_10_4_2_and_lobby_state_carries_them', () {
    setUpSession();
    expect(s.settings, const GameSettings());
    expect(a.last<LobbyState>()!.settings, const GameSettings());
    s.dispose();
  });

  test('the_host_sets_them_clamped_and_every_phone_is_told', () {
    setUpSession();
    a.say(const SetSettings(GameSettings(quizSeconds: 999, quizQuestions: 12, revealSeconds: 0, curveCountdown: 3)));
    const want = GameSettings(quizSeconds: 60, quizQuestions: 10, revealSeconds: 2, curveCountdown: 3);
    expect(s.settings, want);
    expect(a.last<LobbyState>()!.settings, want);
    expect(b.last<LobbyState>()!.settings, want);
    s.dispose();
  });

  test('a_non_host_is_ignored', () {
    setUpSession();
    b.say(const SetSettings(custom));
    expect(s.settings, const GameSettings());
    s.dispose();
  });

  testWidgets('a_message_outside_the_lobby_is_ignored_and_the_next_game_uses_new_values', (t) async {
    setUpSession();
    a.say(const SetSettings(custom));
    a.say(const StartGame(GameKind.quiz, 'big'));
    await t.pump();
    a.say(const SetSettings(GameSettings())); // stale
    expect(s.settings, custom);
    expect(s.quiz!.total, 15);
    s.endGame();
    a.say(const SetSettings(GameSettings(quizSeconds: 10, quizQuestions: 5, revealSeconds: 2, curveCountdown: 1)));
    a.say(const StartGame(GameKind.quiz, 'big'));
    await t.pump();
    expect(s.quiz!.total, 5);
    s.dispose();
  });

  group('quiz', () {
    testWidgets('uses_the_set_count_and_time', (t) async {
      setUpSession();
      a.say(const SetSettings(custom));
      a.say(const StartGame(GameKind.quiz, 'big'));
      await t.pump();
      expect(s.quiz!.total, 15);
      expect(a.last<QuizQuestion>()!.seconds, 40);
      expect(a.last<QuizQuestion>()!.total, 15);
      await step(t, const Duration(seconds: 20));
      expect(s.quizRemaining, closeTo(0.5, 0.02), reason: 'the bar runs over the set 40 s');
      await step(t, const Duration(seconds: 19));
      expect(s.quiz!.step, QuizStep.asking);
      await step(t, const Duration(seconds: 2));
      expect(s.quiz!.step, QuizStep.revealing, reason: 'time is up after 40 s');
      s.dispose();
    });

    testWidgets('the_reveal_lasts_the_set_time', (t) async {
      setUpSession();
      a.say(const SetSettings(GameSettings(quizSeconds: 10, quizQuestions: 5, revealSeconds: 7, curveCountdown: 2)));
      a.say(const StartGame(GameKind.quiz, 'big'));
      await t.pump();
      await step(t, const Duration(seconds: 11));
      expect(s.quiz!.step, QuizStep.revealing);
      await step(t, const Duration(seconds: 5));
      expect(s.quiz!.step, QuizStep.revealing);
      await step(t, const Duration(seconds: 3));
      expect(s.quiz!.step, QuizStep.asking);
      expect(s.quiz!.number, 2);
      s.dispose();
    });

    testWidgets('speed_points_scale_to_the_set_limit', (t) async {
      setUpSession();
      a.say(const SetSettings(GameSettings(quizSeconds: 60, quizQuestions: 5, revealSeconds: 4, curveCountdown: 2)));
      a.say(const StartGame(GameKind.quiz, 'big'));
      await t.pump();
      await step(t, const Duration(seconds: 30)); // half of 60 s: ~750
      a.say(Answer(s.quiz!.current.correctIndex));
      await step(t, const Duration(seconds: 31));
      final pts = s.quiz!.lastPoints[s.players.first.id]!;
      expect(pts, inInclusiveRange(740, 760), reason: 'with a 20 s limit this would be 500');
      s.dispose();
    });
  });

  testWidgets('curve_countdown_is_the_set_pause', (t) async {
    setUpSession();
    a.say(const SetSettings(GameSettings(quizSeconds: 20, quizQuestions: 10, revealSeconds: 4, curveCountdown: 6)));
    a.say(const StartGame(GameKind.curve, null));
    await t.pump();
    for (var i = 0; i < 6 * 60 - 1; i++) {
      s.sim!.tick();
    }
    expect(s.sim!.countingDown, isTrue);
    s.sim!.tick();
    s.sim!.tick();
    expect(s.sim!.countingDown, isFalse);
    s.dispose();
  });

  group('curve mode', () {
    Future<CurveConfig> matchWith(WidgetTester t, CurveMode m) async {
      setUpSession();
      a.say(SetSettings(GameSettings(curveMode: m, curveCountdown: 4)));
      a.say(const StartGame(GameKind.curve, null));
      await t.pump();
      final c = s.sim!.config;
      s.dispose();
      return c;
    }

    testWidgets('the_match_gets_the_hosts_mode_and_countdown', (t) async {
      final peaceful = await matchWith(t, CurveMode.peaceful);
      expect(peaceful.powerUps, isFalse);
      expect(peaceful.countdown, 4);
      expect((await matchWith(t, CurveMode.chaos)).powerUpMax, greaterThan(3));
      expect((await matchWith(t, CurveMode.onlyYou)).powerUpKinds,
          [PowerUpKind.slow, PowerUpKind.thin, PowerUpKind.ghost]);
      expect((await matchWith(t, CurveMode.balanced)).powerUpKinds, isNull);
    });

    test('default_is_balanced_and_a_non_host_cannot_change_it', () {
      setUpSession();
      expect(s.settings.curveMode, CurveMode.balanced);
      b.say(const SetSettings(GameSettings(curveMode: CurveMode.chaos)));
      expect(s.settings.curveMode, CurveMode.balanced);
      a.say(const SetSettings(GameSettings(curveMode: CurveMode.chaos)));
      expect(s.settings.curveMode, CurveMode.chaos);
      expect(b.last<LobbyState>()!.settings.curveMode, CurveMode.chaos);
      s.dispose();
    });

    testWidgets('a_mode_set_mid_match_waits_for_the_next_match', (t) async {
      setUpSession();
      a.say(const SetSettings(GameSettings(curveMode: CurveMode.peaceful)));
      a.say(const StartGame(GameKind.curve, null));
      await t.pump();
      a.say(const SetSettings(GameSettings(curveMode: CurveMode.chaos))); // stale
      expect(s.settings.curveMode, CurveMode.peaceful);
      expect(s.sim!.config.powerUps, isFalse);
      s.dispose();
    });
  });
}
