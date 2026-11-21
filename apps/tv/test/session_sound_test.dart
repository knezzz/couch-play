import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/sound/sfx.dart';

import 'session_test.dart' show FakePeer, join;

class FakeSfx implements Sfx {
  final played = <Sound>[];
  @override
  void play(Sound s) => played.add(s);
}

/// Task 26: the session asks for the right sound at each event.
void main() {
  late Session s;
  late FakeSfx sfx;
  late FakePeer a, b;
  var now = Duration.zero;

  void setUpSession() {
    now = Duration.zero;
    sfx = FakeSfx();
    s = Session(random: Random(1), clock: () => now)..sfx = sfx;
    a = join(s, 'Ana', token: 'ta');
    b = join(s, 'Ben', token: 'tb');
  }

  Future<void> step(WidgetTester t, Duration d) async {
    for (var left = d; left > Duration.zero; left -= const Duration(milliseconds: 100)) {
      now += const Duration(milliseconds: 100);
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  test('a_new_player_in_the_lobby_blips_and_a_rejoin_does_not', () {
    setUpSession();
    expect(sfx.played, [Sound.join, Sound.join]);
    a.close();
    sfx.played.clear();
    final a2 = FakePeer();
    s.attach(a2);
    a2.say(const Join('Ana', 'ta'));
    expect(sfx.played, isEmpty);
    s.dispose();
  });

  group('curve', () {
    Future<void> start(WidgetTester t, {int countdown = 2}) async {
      setUpSession();
      a.say(SetSettings(GameSettings(curveCountdown: countdown)));
      a.say(const StartGame(GameKind.curve, null));
      await t.pump();
      sfx.played.clear();
    }

    /// What the TV does every tick.
    void ticks(int n) {
      for (var i = 0; i < n; i++) {
        s.beforeTick();
        s.sim!.tick();
      }
    }

    testWidgets('countdown_beeps_once_a_second_then_go', (t) async {
      await start(t, countdown: 3);
      ticks(3 * 60 - 1);
      expect(sfx.played, [Sound.countdownBeep, Sound.countdownBeep, Sound.countdownBeep]);
      ticks(2);
      expect(sfx.played.last, Sound.countdownGo);
      expect(sfx.played, hasLength(4));
      ticks(300);
      expect(sfx.played.where((x) => x == Sound.countdownGo), hasLength(1));
      s.dispose();
    });

    testWidgets('every_round_counts_down_again', (t) async {
      await start(t);
      ticks(130);
      sfx.played.clear();
      s.sim!.startRound();
      ticks(130);
      expect(sfx.played, [Sound.countdownBeep, Sound.countdownBeep, Sound.countdownGo]);
      s.dispose();
    });

    testWidgets('a_match_that_ended_mid_countdown_does_not_spoil_the_next_ones_beeps', (t) async {
      await start(t, countdown: 3);
      ticks(70); // one beep, then the host ends the game mid-countdown
      s.endGame();
      s.returnToLobby();
      a.say(const StartGame(GameKind.curve, null));
      await t.pump();
      sfx.played.clear();
      ticks(1);
      expect(sfx.played, [Sound.countdownBeep], reason: 'the new countdown starts with its own beep');
      ticks(3 * 60 - 1);
      expect(sfx.played, [Sound.countdownBeep, Sound.countdownBeep, Sound.countdownBeep]);
      ticks(2);
      expect(sfx.played.last, Sound.countdownGo);
      s.dispose();
    });

    testWidgets('pickup_crash_round_and_match_events', (t) async {
      // (the winner moment's timer is cancelled by dispose)
      await start(t);
      s.curveEvents([PickedUp(0, PowerUpKind.values.first)]);
      s.curveEvents([PickedUp(1, PowerUpKind.values.last)]);
      expect(sfx.played, [Sound.pickup, Sound.pickup]);
      sfx.played.clear();
      s.curveEvents([Died(0)]);
      expect(sfx.played, [Sound.crash]);
      sfx.played.clear();
      s.curveEvents([Died(0), RoundOver(1)]);
      expect(sfx.played, [Sound.crash, Sound.roundWin]);
      sfx.played.clear();
      s.curveEvents([Died(0), RoundOver(1), MatchOver(1)]);
      expect(sfx.played, [Sound.crash, Sound.matchWin], reason: 'the match win replaces the round win');
      s.dispose();
    });
  });

  group('quiz', () {
    GameSettings fast() => const GameSettings(quizSeconds: 10, quizQuestions: 5);

    Future<void> start(WidgetTester t) async {
      setUpSession();
      a.say(SetSettings(fast()));
      sfx.played.clear();
      a.say(const StartGame(GameKind.quiz, null));
      await t.pump();
    }

    testWidgets('a_question_starts_with_a_sound', (t) async {
      await start(t);
      expect(sfx.played, [Sound.quizStart]);
      s.dispose();
    });

    int count(Sound x) => sfx.played.where((p) => p == x).length;

    // A 10 s question, nobody answering; the session polls every 100 ms.
    testWidgets('a_10_s_question_ticks_each_second_then_speeds_up_with_a_heartbeat_in_the_last_5', (t) async {
      await start(t);
      sfx.played.clear();
      await step(t, const Duration(milliseconds: 900));
      expect(sfx.played, isEmpty, reason: 'the first second is quiet');
      await step(t, const Duration(milliseconds: 4000)); // 4.9 s: ticks at 1, 2, 3, 4 s
      expect(sfx.played, List.filled(4, Sound.quizTick));
      // Urgent ticks and heartbeats, counted at the end of each of the last 5 seconds:
      // 2 a second to the last 3 s, then 4 a second; a heartbeat each second.
      final urgent = <int>[], beats = <int>[];
      for (var i = 0; i < 5; i++) {
        await step(t, const Duration(seconds: 1));
        urgent.add(count(Sound.tickUrgent));
        beats.add(count(Sound.heartbeat));
      }
      expect(urgent, [2, 4, 8, 12, 16]);
      expect(beats, [1, 2, 3, 4, 5]);
      expect(count(Sound.quizTick), 4, reason: 'the slow tock stops in the last 5 s');
      expect(count(Sound.timeUp), 0, reason: 'not before the time is up');
      s.dispose();
    });

    testWidgets('a_60_s_question_ticks_all_the_way_and_ends_the_same_way', (t) async {
      setUpSession();
      a.say(const SetSettings(GameSettings(quizSeconds: 60, quizQuestions: 5)));
      a.say(const StartGame(GameKind.quiz, null));
      await t.pump();
      sfx.played.clear();
      await step(t, const Duration(milliseconds: 59900));
      expect(count(Sound.quizTick), 54, reason: 'one a second from 1 s to 54 s');
      expect(count(Sound.tickUrgent), 16);
      expect(count(Sound.heartbeat), 5);
      s.dispose();
    });

    testWidgets('time_up_plays_once_when_the_time_runs_out', (t) async {
      await start(t);
      sfx.played.clear();
      await step(t, const Duration(milliseconds: 10300));
      expect(count(Sound.timeUp), 1);
      expect(sfx.played.last, Sound.wrong, reason: 'then the reveal, as before');
      await step(t, const Duration(seconds: 3));
      expect(count(Sound.timeUp), 1, reason: 'once');
      s.dispose();
    });

    testWidgets('everyone_answering_early_reveals_without_time_up_and_the_ticking_stops', (t) async {
      await start(t);
      sfx.played.clear();
      await step(t, const Duration(milliseconds: 2500));
      a.say(Answer(s.quiz!.current.correctIndex));
      b.say(Answer((s.quiz!.current.correctIndex + 1) % 4));
      await step(t, const Duration(milliseconds: 300));
      expect(s.quiz!.step, QuizStep.revealing);
      sfx.played.clear();
      await step(t, const Duration(seconds: 3));
      expect(count(Sound.timeUp), 0);
      expect(count(Sound.tickUrgent), 0);
      expect(count(Sound.heartbeat), 0);
      expect(count(Sound.quizTick), 0);
      s.dispose();
    });

    testWidgets('reveal_is_right_when_someone_scored_and_wrong_when_nobody_did', (t) async {
      await start(t);
      sfx.played.clear();
      a.say(Answer(s.quiz!.current.correctIndex));
      b.say(Answer(s.quiz!.current.correctIndex));
      await step(t, const Duration(milliseconds: 300));
      expect(sfx.played, [Sound.right]);
      await step(t, const Duration(seconds: 4)); // next question, nobody answers
      sfx.played.clear();
      await step(t, const Duration(seconds: 11));
      expect(sfx.played.where((x) => x == Sound.wrong), hasLength(1));
      expect(sfx.played.where((x) => x == Sound.right), isEmpty);
      s.dispose();
    });

    testWidgets('the_end_of_the_quiz_plays_the_fanfare', (t) async {
      await start(t);
      for (var i = 0; i < 5; i++) {
        a.say(Answer(s.quiz!.current.correctIndex));
        b.say(Answer(s.quiz!.current.correctIndex));
        await step(t, const Duration(seconds: 6));
        if (s.phase == Phase.results) break;
      }
      expect(s.phase, Phase.results);
      expect(sfx.played.where((x) => x == Sound.fanfare), hasLength(1));
      s.dispose();
    });
  });
}
