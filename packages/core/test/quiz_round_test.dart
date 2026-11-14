import 'dart:math';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

QuizPack pack(int n) => QuizPack('p', 'P', [
      for (var i = 0; i < n; i++)
        PackQuestion('q$i', null, [for (var c = 0; c < 4; c++) 'q$i-c$c'], i % 4),
    ], <String, Uint8List>{});

const s = Duration(seconds: 1);

QuizRound round(int n, List<int> players, {int length = 10}) =>
    QuizRound(pack(n), players, random: Random(1), length: length);

/// Answers the shown question right (or wrong) for [id] at [t] seconds.
void reply(QuizRound r, int id, {required bool right, int t = 0}) {
  final c = r.current.correctIndex;
  r.answer(id, right ? c : (c + 1) % 4, s * t);
}

void main() {
  test('picks_min_of_length_and_pack_size', () {
    expect(round(3, [1]).total, 3);
    expect(round(15, [1]).total, 10);
    expect(round(15, [1], length: 4).total, 4);
  });

  test('shuffle_keeps_correct_answer', () {
    final r = round(8, [1]);
    final seen = <String>{};
    var now = Duration.zero;
    while (r.step != QuizStep.done) {
      final q = r.current;
      final i = int.parse(q.q.substring(1));
      expect(q.choices[q.correctIndex], 'q$i-c${i % 4}');
      expect(q.choices.toSet(), {for (var c = 0; c < 4; c++) 'q$i-c$c'});
      expect(seen.add(q.q), isTrue); // no question twice
      r.advance(now += s * 20);
      r.advance(now += s * 4);
    }
    expect(seen.length, 8);
  });

  test('first_answer_locks', () {
    final r = round(3, [1, 2]);
    reply(r, 1, right: true);
    reply(r, 1, right: false);
    reply(r, 1, right: true, t: 15);
    expect(r.lastPoints[1], 1000);
    expect(r.totals[1], 1000);
    expect(r.step, QuizStep.asking); // player 2 has not answered
  });

  test('ends_early_when_all_answered', () {
    final r = round(3, [1, 2]);
    reply(r, 1, right: true);
    r.advance(s);
    expect(r.step, QuizStep.asking);
    reply(r, 2, right: false);
    r.advance(s);
    expect(r.step, QuizStep.revealing);
  });

  test('timeout_gives_zero', () {
    final r = round(3, [1]);
    r.advance(s * 19);
    expect(r.step, QuizStep.asking);
    r.advance(s * 20);
    expect(r.step, QuizStep.revealing);
    expect(r.lastPoints[1], 0);
    expect(r.totals[1], 0);
  });

  test('points_scale_with_speed', () {
    final r = round(3, [1, 2, 3]);
    reply(r, 1, right: true, t: 10);
    reply(r, 2, right: true, t: 0);
    reply(r, 3, right: false, t: 0);
    expect(r.lastPoints, {1: 750, 2: 1000, 3: 0});
  });

  test('disconnected_player_keeps_points_and_scores_zero_after', () {
    final r = round(3, [1, 2]);
    reply(r, 1, right: true);
    reply(r, 2, right: true);
    r.advance(s); // reveal starts at 1 s
    r.removePlayer(1);
    r.advance(s * 5); // reveal over, question 2 starts at 5 s
    expect(r.number, 2);
    reply(r, 1, right: true, t: 5); // ignored: gone
    reply(r, 2, right: true, t: 5);
    r.advance(s * 6); // only player 2 remains, and has answered
    expect(r.step, QuizStep.revealing);
    expect(r.totals[1], 1000);
    expect(r.lastPoints[1], 0);
    expect(r.totals[2], 2000);
  });

  test('rejoined_player_answers_again_and_keeps_total', () {
    final r = round(3, [1, 2]);
    reply(r, 1, right: true);
    reply(r, 2, right: false);
    r.advance(s); // reveal from 1 s
    r.removePlayer(1);
    r.advance(s * 5); // question 2 from 5 s
    r.addPlayer(1);
    reply(r, 1, right: true, t: 5);
    expect(r.totals[1], 2000);
    expect(r.lastPoints[1], 1000);
    reply(r, 2, right: true, t: 5);
    r.advance(s * 6);
    expect(r.step, QuizStep.revealing);
  });

  test('a rejoined player who missed a question scored 0 for it', () {
    final r = round(3, [1]);
    r.removePlayer(1);
    r.advance(s * 20); // question 1 times out with nobody
    r.addPlayer(1);
    r.advance(s * 24);
    reply(r, 1, right: true, t: 24);
    expect(r.totals[1], 1000);
  });

  test('answer ignores an index outside 0-3 and an unknown player', () {
    final r = round(3, [1]);
    r.answer(1, 4, Duration.zero);
    r.answer(1, -1, Duration.zero);
    r.answer(99, 0, Duration.zero);
    expect(r.totals.keys, [1]);
    expect(r.lastPoints, isEmpty);
    r.advance(s);
    expect(r.step, QuizStep.asking); // player 1 can still answer
    reply(r, 1, right: true);
    expect(r.totals[1], 1000);
  });

  test('answers are ignored while revealing', () {
    final r = round(3, [1]);
    r.advance(s * 20);
    reply(r, 1, right: true);
    expect(r.totals[1], 0);
  });

  test('runs to done and stays there', () {
    final r = round(2, [1]);
    var now = Duration.zero;
    for (var i = 0; i < 2; i++) {
      expect(r.number, i + 1);
      r.advance(now += s * 20);
      r.advance(now += s * 4);
    }
    expect(r.step, QuizStep.done);
    r.advance(s * 99);
    expect(r.step, QuizStep.done);
  });

  test('instant_answer_on_every_question_scores_1000', () {
    final r = round(5, [1]);
    var now = Duration.zero;
    for (var i = 0; i < 5; i++) {
      r.answer(1, r.current.correctIndex, now); // at the phase start
      expect(r.lastPoints[1], 1000, reason: 'question ${i + 1}');
      r.advance(now += s); // all answered: reveal
      r.advance(now += s * 4); // reveal over: next question starts at now
    }
    expect(r.step, QuizStep.done);
    expect(r.totals[1], 5000);
  });

  test('reveal_lasts_full_reveal_duration', () {
    final r = round(4, [1]); // nobody answers: every ask runs to the time limit
    const tick = Duration(milliseconds: 100);
    var now = Duration.zero;
    var phaseStart = now;
    var seen = QuizStep.asking;
    final revealed = <Duration>[], asked = <Duration>[];
    while (r.step != QuizStep.done) {
      now += tick;
      r.advance(now);
      if (r.step != seen) {
        (seen == QuizStep.asking ? asked : revealed).add(now - phaseStart);
        phaseStart = now;
        seen = r.step;
      }
    }
    expect(asked.length, 4);
    expect(revealed.length, 4);
    expect(asked.every((d) => d >= const Duration(seconds: 20)), isTrue, reason: '$asked');
    expect(revealed.every((d) => d >= const Duration(seconds: 4)), isTrue, reason: '$revealed');
  });
}
