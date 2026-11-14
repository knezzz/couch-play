import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/strings.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join, idOf;

/// The quiz timer runs on the test binding's fake Timers; the round clock is a
/// number we move ourselves, in 100 ms steps, so both agree.
void main() {
  late Session s;
  var now = Duration.zero;

  Future<void> step(WidgetTester t, Duration d) async {
    for (var left = d; left > Duration.zero; left -= const Duration(milliseconds: 100)) {
      now += const Duration(milliseconds: 100);
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  void answerRight(FakePeer p) =>
      p.say(Answer(s.quiz!.current.correctIndex));

  Session fresh() {
    now = Duration.zero;
    final s = Session(random: Random(1), clock: () => now);
    s.quizAvailable = true;
    return s;
  }

  testWidgets('start_quiz_asks_humans_and_not_bots', (t) async {
    s = fresh();
    final a = join(s, 'Ana'), b = join(s, 'Ben');
    s.setBotCount(1);
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    expect(s.phase, Phase.quiz);
    for (final p in [a, b]) {
      final q = p.last<QuizQuestion>()!;
      expect(q.number, 1);
      expect(q.choices, hasLength(4));
      expect(q.seconds, 20);
    }
    expect(s.quiz, isNotNull);
    s.dispose();
  });

  testWidgets('quizTitle_and_lastGameLabel_name_the_pack', (t) async {
    s = fresh();
    final a = join(s, 'Ana');
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    final title = s.quizTitle;
    expect(title, isNotEmpty);
    s.finishGame({idOf(a): 1});
    expect(s.quizTitle, '', reason: 'the quiz is over');
    expect(s.lastGameLabel, Strings.gameQuiz(title));
    s.dispose();
  });

  testWidgets('endGame_stops_the_quiz_timer_and_keeps_scores', (t) async {
    s = fresh();
    final a = join(s, 'Ana'), b = join(s, 'Ben');
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    await step(t, const Duration(seconds: 2));
    answerRight(a);
    answerRight(b);
    await step(t, const Duration(milliseconds: 300));
    s.endGame();
    expect(s.phase, Phase.lobby);
    expect(s.quiz, isNull);
    expect(s.sessionScores.values.every((v) => v == 0), isTrue);
    expect(a.last<Results>(), isNull);
    expect(a.last<LobbyState>(), isNotNull);
    // A running timer would trip the pending-timer check at the test's end.
    await step(t, const Duration(seconds: 30));
    expect(s.phase, Phase.lobby);
    s.dispose();
  });

  testWidgets('unknown_pack_is_an_error_and_stays_in_lobby', (t) async {
    s = fresh();
    final a = join(s, 'Ana');
    s.packLookup = (_) => null;
    a.say(const StartGame(GameKind.quiz, 'nope'));
    await t.pump();
    expect(s.phase, Phase.lobby);
    expect(a.last<ErrorMsg>(), isNotNull);
    s.dispose();
  });

  testWidgets('reveal_comes_when_all_answer_and_points_only_then', (t) async {
    s = fresh();
    final a = join(s, 'Ana'), b = join(s, 'Ben');
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    await step(t, const Duration(seconds: 2));
    answerRight(a);
    await step(t, const Duration(milliseconds: 200));
    expect(a.last<QuizReveal>(), isNull, reason: 'Ben has not answered');
    expect(s.quizAnswered, 1);
    expect(s.quizPicks, isEmpty, reason: 'picks stay hidden while asking');
    final wrong = (s.quiz!.current.correctIndex + 1) % 4;
    b.say(Answer(wrong));
    await step(t, const Duration(milliseconds: 200));
    final ra = a.last<QuizReveal>()!, rb = b.last<QuizReveal>()!;
    expect(ra.correctIndex, s.quiz!.current.correctIndex);
    expect(ra.yourPoints, greaterThan(800));
    expect(ra.yourTotal, ra.yourPoints);
    expect(rb.yourPoints, 0);
    expect(s.quizPicks, {idOf(a): s.quiz!.current.correctIndex, idOf(b): wrong});
    s.dispose();
  });

  testWidgets('full_round_ends_in_results_with_session_scores', (t) async {
    s = fresh();
    final a = join(s, 'Ana'), b = join(s, 'Ben');
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    final numbers = <int>{};
    final total = s.quiz!.total;
    var steps = 0;
    while (s.phase == Phase.quiz) {
      if (s.quiz!.step == QuizStep.asking) {
        numbers.add(s.quiz!.number);
        answerRight(a); // only Ana answers; Ben never does
      }
      await step(t, const Duration(milliseconds: 500));
      expect(++steps, lessThan(1000), reason: 'round must end');
    }
    expect(numbers.length, total);
    expect(s.phase, Phase.results);
    final r = a.last<Results>()!;
    expect(r.placements.first.playerId, idOf(a));
    expect(r.placements.first.place, 1);
    expect(s.sessionScores[idOf(a)], greaterThan(0));
    expect(b.last<Results>(), isNotNull);
    // The timer is gone: nothing more happens.
    final sent = a.sent.length;
    await step(t, const Duration(seconds: 10));
    expect(a.sent.length, sent);
    s.dispose();
  });

  testWidgets('disconnect_does_not_block_and_rejoin_answers_again', (t) async {
    s = fresh();
    final a = join(s, 'Ana', token: 'ta'), b = join(s, 'Ben', token: 'tb');
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    answerRight(a);
    b.close();
    await t.pump();
    await step(t, const Duration(milliseconds: 300));
    expect(a.last<QuizReveal>(), isNotNull, reason: 'Ben left; the round goes on');
    // Ben comes back during the reveal: he gets the reveal, then the next question.
    final b2 = FakePeer();
    s.attach(b2);
    b2.say(const Join('Ben', 'tb'));
    await t.pump();
    expect(b2.last<QuizReveal>(), isNotNull);
    await step(t, const Duration(seconds: 4));
    expect(b2.last<QuizQuestion>()!.number, 2);
    b2.say(Answer(s.quiz!.current.correctIndex));
    await step(t, const Duration(milliseconds: 100));
    expect(s.quizAnswered, 1);
    s.dispose();
  });

  testWidgets('everyone_leaves_ends_the_game', (t) async {
    s = fresh();
    final a = join(s, 'Ana');
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    a.close();
    await t.pump();
    await step(t, const Duration(milliseconds: 200));
    expect(s.phase, Phase.results);
    s.dispose();
  });

  testWidgets('rejoin_after_answering_is_told_it_is_locked_in', (t) async {
    s = fresh();
    final a = join(s, 'Ana', token: 'ta'), b = join(s, 'Ben', token: 'tb');
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    b.say(const Answer(0));
    await t.pump();
    final b2 = FakePeer();
    s.attach(b2);
    b2.say(const Join('Ben', 'tb')); // a Wi-Fi blip: same token, new socket
    await t.pump();
    expect(b2.last<QuizQuestion>(), isNull);
    expect(b2.last<Waiting>(), const Waiting(Strings.lockedIn));
    s.dispose();
  });

  testWidgets('answered_count_ignores_players_who_left', (t) async {
    s = fresh();
    final a = join(s, 'Ana'), b = join(s, 'Ben');
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    a.say(const Answer(0));
    b.say(const Answer(0));
    await t.pump();
    b.close();
    await t.pump();
    expect(s.quizAnswered, lessThanOrEqualTo(s.quizExpected));
    expect(s.quizAnswered, 1);
    s.dispose();
  });

  testWidgets('late_joiner_waits', (t) async {
    s = fresh();
    final a = join(s, 'Ana');
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    final c = join(s, 'Cy');
    await t.pump();
    expect(c.last<Waiting>(), isNotNull);
    expect(c.last<QuizQuestion>(), isNull);
    c.say(const Answer(0));
    await step(t, const Duration(milliseconds: 200));
    expect(s.quizAnswered, 0);
    s.dispose();
  });

  testWidgets('returning_to_lobby_stops_the_timer', (t) async {
    s = fresh();
    final a = join(s, 'Ana');
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    s.returnToLobby();
    expect(s.quiz, isNull);
    await step(t, const Duration(seconds: 1));
    expect(t.binding.transientCallbackCount, 0);
    s.dispose();
  });

  testWidgets('a_correct_answer_gets_a_score_pop_at_the_reveal_only', (t) async {
    s = fresh();
    final a = join(s, 'Ana'), b = join(s, 'Ben');
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    await step(t, const Duration(seconds: 2));
    answerRight(a);
    await step(t, const Duration(milliseconds: 200));
    expect(a.all<Effect>(), isEmpty, reason: 'nothing before the reveal');
    b.say(Answer((s.quiz!.current.correctIndex + 1) % 4));
    await step(t, const Duration(milliseconds: 200));
    expect(a.all<Effect>(), [const Effect('scorePop')]);
    expect(b.all<Effect>(), isEmpty, reason: 'wrong answers get no pop');
    expect(a.sent.indexOf(a.last<QuizReveal>()!), lessThan(a.sent.indexOf(const Effect('scorePop'))),
        reason: 'the phone knows its points when the pop arrives');
    s.dispose();
  });

  testWidgets('a_quiz_winner_gets_confetti', (t) async {
    s = fresh();
    final a = join(s, 'Ana'), b = join(s, 'Ben');
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    var steps = 0;
    while (s.phase == Phase.quiz) {
      if (s.quiz!.step == QuizStep.asking) answerRight(a);
      await step(t, const Duration(milliseconds: 500));
      expect(++steps, lessThan(1000), reason: 'round must end');
    }
    expect(a.all<Effect>().where((e) => e.name == 'confetti'), hasLength(1));
    expect(b.all<Effect>().where((e) => e.name == 'confetti'), isEmpty);
    s.dispose();
  });
}
