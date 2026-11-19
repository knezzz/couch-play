import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 20: with nobody connected, Quiz and Curve wait 30 s instead of ending.
void main() {
  late Session s;
  late FakePeer a, b;
  var now = Duration.zero;

  Future<void> step(WidgetTester t, Duration d) async {
    for (var left = d; left > Duration.zero; left -= const Duration(milliseconds: 100)) {
      now += const Duration(milliseconds: 100);
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> start(WidgetTester t, GameKind kind) async {
    now = Duration.zero;
    s = Session(random: Random(1), clock: () => now);
    a = join(s, 'Ana', token: 'ta');
    b = join(s, 'Ben', token: 'tb');
    a.say(StartGame(kind, null));
    await t.pump();
  }

  FakePeer back(String name, String token) {
    final p = FakePeer();
    s.attach(p);
    p.say(Join(name, token));
    return p;
  }

  Future<void> bothLeave(WidgetTester t) async {
    a.close();
    b.close();
    await t.pump();
  }

  group('quiz', () {
    testWidgets('both_leaving_pauses_instead_of_ending', (t) async {
      await start(t, GameKind.quiz);
      await bothLeave(t);
      expect(s.phase, Phase.quiz);
      expect(s.paused, isTrue);
      expect(s.pauseText, Strings.waitingForPlayers);
      s.dispose();
    });

    testWidgets('the_question_clock_stands_still_and_resumes', (t) async {
      await start(t, GameKind.quiz);
      await step(t, const Duration(seconds: 5));
      final left = s.quizRemaining;
      await bothLeave(t);
      await step(t, const Duration(seconds: 20));
      expect(s.quizRemaining, left);
      expect(s.quiz!.number, 1);
      final a2 = back('Ana', 'ta');
      await t.pump();
      expect(s.paused, isFalse);
      expect(s.quizRemaining, left);
      expect(a2.last<QuizQuestion>()!.seconds, 15);
      await step(t, const Duration(seconds: 2));
      expect(s.quizRemaining, lessThan(left));
      await step(t, const Duration(seconds: 40)); // the 30 s timer is gone
      expect(s.phase, anyOf(Phase.quiz, Phase.results));
      expect(s.quiz?.number, isNot(1));
      s.dispose();
    });

    testWidgets('nobody_back_in_30_seconds_ends_it_with_the_scores', (t) async {
      await start(t, GameKind.quiz);
      await bothLeave(t);
      await step(t, const Duration(seconds: 29));
      expect(s.phase, Phase.quiz);
      await step(t, const Duration(seconds: 2));
      expect(s.phase, Phase.results);
      expect(s.paused, isFalse);
      s.dispose();
    });

    testWidgets('one_person_left_keeps_playing_without_a_pause', (t) async {
      await start(t, GameKind.quiz);
      b.close();
      await t.pump();
      expect(s.paused, isFalse);
      expect(s.phase, Phase.quiz);
      s.dispose();
    });

    testWidgets('back_to_the_lobby_ends_the_pause', (t) async {
      await start(t, GameKind.quiz);
      await bothLeave(t);
      s.endGame();
      expect(s.paused, isFalse);
      await step(t, const Duration(seconds: 40));
      expect(s.phase, Phase.lobby);
      s.dispose();
    });
  });

  group('curve', () {
    testWidgets('both_leaving_pauses_instead_of_ending', (t) async {
      await start(t, GameKind.curve);
      await bothLeave(t);
      expect(s.phase, Phase.curve);
      expect(s.paused, isTrue);
      expect(s.pauseText, Strings.waitingForPlayers);
      expect(s.sim!.heads.every((h) => h.alive), isTrue);
      s.dispose();
    });

    testWidgets('b_dropping_while_waiting_for_a_makes_one_wait_for_everyone', (t) async {
      await start(t, GameKind.curve);
      a.close();
      await t.pump();
      expect(s.pauseText, Strings.waitingForReturn('Ana'));
      await t.pump(const Duration(seconds: 20));
      b.close();
      await t.pump();
      expect(s.pauseText, Strings.waitingForPlayers);
      await t.pump(const Duration(seconds: 29)); // 49 s after A left: B's drop restarted it
      expect(s.phase, Phase.curve);
      await t.pump(const Duration(seconds: 2));
      expect(s.phase, Phase.results);
      s.dispose();
    });

    testWidgets('two_back_carry_on_from_a_fresh_round', (t) async {
      await start(t, GameKind.curve);
      final round = s.curveRound;
      await bothLeave(t);
      await t.pump(const Duration(seconds: 10));
      final a2 = back('Ana', 'ta');
      await t.pump();
      back('Ben', 'tb');
      await t.pump();
      expect(s.paused, isFalse);
      expect(s.curveRound, round + 1);
      expect(s.sim!.heads.every((h) => h.alive), isTrue);
      expect(a2.last<CurveStatus>()!.alive, isTrue);
      await t.pump(const Duration(seconds: 40));
      expect(s.phase, Phase.curve);
      s.dispose();
    });

    testWidgets('only_one_back_waits_for_the_other_for_another_30_seconds', (t) async {
      await start(t, GameKind.curve);
      await bothLeave(t);
      await t.pump(const Duration(seconds: 10));
      back('Ana', 'ta');
      await t.pump();
      expect(s.paused, isTrue);
      expect(s.pauseText, Strings.waitingForReturn('Ben'));
      await t.pump(const Duration(seconds: 31));
      expect(s.phase, Phase.results);
      s.dispose();
    });

    testWidgets('nobody_back_ends_it_after_30_seconds', (t) async {
      await start(t, GameKind.curve);
      await bothLeave(t);
      await t.pump(const Duration(seconds: 29));
      expect(s.phase, Phase.curve);
      await t.pump(const Duration(seconds: 2));
      expect(s.phase, Phase.results);
      expect(s.paused, isFalse);
      s.dispose();
    });

    testWidgets('a_human_leaving_a_match_with_bots_pauses', (t) async {
      now = Duration.zero;
      s = Session(random: Random(1), clock: () => now);
      a = join(s, 'Ana', token: 'ta');
      s.setBotCount(2);
      a.say(const StartGame(GameKind.curve, null));
      await t.pump();
      a.close();
      await t.pump();
      expect(s.phase, Phase.curve);
      expect(s.pauseText, Strings.waitingForPlayers);
      final a2 = back('Ana', 'ta');
      await t.pump();
      expect(s.paused, isFalse);
      expect(a2.last<CurveStatus>(), isNotNull);
      s.dispose();
    });

    testWidgets('back_to_the_lobby_ends_the_pause', (t) async {
      await start(t, GameKind.curve);
      await bothLeave(t);
      s.endGame();
      expect(s.paused, isFalse);
      await t.pump(const Duration(seconds: 40));
      expect(s.phase, Phase.lobby);
      s.dispose();
    });
  });

  group('outsiders and the returner', () {
    // Cy is a lobby player who was offline when the game started.
    Future<FakePeer> startWithOfflineCy(WidgetTester t, GameKind kind) async {
      now = Duration.zero;
      s = Session(random: Random(1), clock: () => now);
      a = join(s, 'Ana', token: 'ta');
      b = join(s, 'Ben', token: 'tb');
      final cy = join(s, 'Cy', token: 'tc');
      cy.close();
      await t.pump();
      a.say(StartGame(kind, null));
      await t.pump();
      return cy;
    }

    testWidgets('an_outsider_reattaching_does_not_resume_a_quiz', (t) async {
      await startWithOfflineCy(t, GameKind.quiz);
      await bothLeave(t);
      await step(t, const Duration(seconds: 10));
      back('Cy', 'tc');
      await t.pump();
      expect(s.paused, isTrue);
      await step(t, const Duration(seconds: 5));
      expect(s.quiz!.number, 1);
      expect(s.phase, Phase.quiz);
      s.dispose();
    });

    testWidgets('an_outsider_reattaching_does_not_change_a_curve_wait', (t) async {
      await startWithOfflineCy(t, GameKind.curve);
      await bothLeave(t);
      expect(s.pauseText, Strings.waitingForPlayers);
      await t.pump(const Duration(seconds: 20));
      back('Cy', 'tc');
      await t.pump();
      expect(s.pauseText, Strings.waitingForPlayers);
      await t.pump(const Duration(seconds: 11)); // still the first 30 s
      expect(s.phase, Phase.results);
      s.dispose();
    });

    testWidgets('the_one_who_comes_back_to_a_wait_is_told_to_wait_not_to_steer', (t) async {
      await start(t, GameKind.curve);
      await bothLeave(t);
      final a2 = back('Ana', 'ta');
      await t.pump();
      expect(s.pauseText, Strings.waitingForReturn('Ben'));
      expect(a2.last<Waiting>(), Waiting(Strings.waitingForReturn('Ben')));
      expect(a2.sent.where((m) => m is! HostIs && m is! GamePlayers).last, isA<Waiting>(), reason: 'HostIs and GamePlayers may follow it');
      s.dispose();
    });
  });
}
