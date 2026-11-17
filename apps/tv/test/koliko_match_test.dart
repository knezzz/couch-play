import 'dart:convert';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/koliko_match.dart';
import 'package:tv/sound/sfx.dart';

KolikoPack pack() => KolikoPack('p', 'P', [for (var i = 0; i < 20; i++) KolikoQuestion('q$i?', 100.0 + i, 'm', null, 's')]);

class _Sfx implements Sfx {
  _Sfx(this.log);
  final List<Sound> log;
  @override
  void play(Sound s) => log.add(s);
}

class Rig {
  Rig({int n = 3, int seconds = 30, int questions = 3, int seed = 1}) {
    match = KolikoMatch(
      ids: [for (var i = 1; i <= n; i++) i],
      pack: pack(),
      settings: GameSettings(kolikoSeconds: seconds, kolikoQuestions: questions),
      send: (id, m) => (sent[id] ??= []).add(m),
      clock: () => at,
      random: Random(seed),
      sfx: _Sfx(played),
      onOver: (s) => result = s,
    )..start();
  }
  late final KolikoMatch match;
  final sent = <int, List<Message>>{};
  final played = <Sound>[];
  Map<int, int>? result;
  Duration at = Duration.zero;

  Future<void> wait(WidgetTester t, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await t.pump(const Duration(seconds: 1));
      at += const Duration(seconds: 1);
    }
  }

  double get truth => match.game.current.answer;
}

void main() {
  testWidgets('every phone gets the question; the TV knows who answered, never what', (t) async {
    final r = Rig();
    for (final id in r.match.ids) {
      final a = r.sent[id]!.whereType<KolikoAsk>().single;
      expect([a.number, a.total, a.seconds, a.unit], [1, 3, 30, 'm']);
      expect(a.q, r.match.q);
      expect(a.sent, isNull);
    }
    r.match.onNumber(1, const NumberAnswer(123));
    expect(r.match.answered, {1});
    // nobody gets another player's number during the question
    for (final id in r.match.ids) {
      for (final m in r.sent[id]!) {
        expect(jsonEncode(m.toJson()).contains('123'), isFalse, reason: 'player $id: ${m.encode()}');
      }
    }
    r.match.dispose();
  });

  testWidgets('everybody answered: the reveal comes at once; each phone gets only its own number, rank and points', (t) async {
    final r = Rig();
    final tr = r.truth;
    r.match.onNumber(1, NumberAnswer(tr + 10));
    r.match.onNumber(2, NumberAnswer(tr));
    expect(r.match.stage, KolikoStageTv.ask);
    r.match.onNumber(3, NumberAnswer(tr + 50));
    expect(r.match.stage, KolikoStageTv.reveal);
    final r2 = r.sent[2]!.whereType<KolikoResult>().single;
    expect([r2.answer, r2.value, r2.rank, r2.points, r2.total], [tr, tr, 1, 1500, 1500]);
    final r1 = r.sent[1]!.whereType<KolikoResult>().single;
    expect([r1.value, r1.rank, r1.points], [tr + 10, 2, 750]);
    // the TV, though, can draw them all
    expect([for (final e in r.match.reveal!.entries) e.id], [2, 1, 3]);
    r.match.dispose();
  });

  testWidgets('the clock: a tick per second, sharper in the last 5, the reveal at 0; no early reveal while someone is missing', (t) async {
    final r = Rig(questions: 2);
    r.match.onNumber(1, const NumberAnswer(5));
    await r.wait(t, 29);
    expect(r.match.stage, KolikoStageTv.ask);
    expect(r.match.secondsLeft, 1);
    await r.wait(t, 1);
    expect(r.match.stage, KolikoStageTv.reveal);
    expect(r.played.where((s) => s == Sound.quizTick).length, 24, reason: '29 down to 6');
    expect(r.played.where((s) => s == Sound.tick).length, 5);
    r.match.dispose();
  });

  testWidgets('the reveal shows for 8 s, then the next question; the last one ends the game with session points', (t) async {
    final r = Rig(questions: 2);
    for (var q = 1; q <= 2; q++) {
      expect(r.match.number, q);
      r.match.onNumber(1, NumberAnswer(r.truth));
      r.match.onNumber(2, NumberAnswer(r.truth + 1));
      r.match.onNumber(3, NumberAnswer(r.truth + 2));
      expect(r.match.stage, KolikoStageTv.reveal);
      await r.wait(t, 7);
      expect(r.match.stage, KolikoStageTv.reveal);
      await r.wait(t, 1);
    }
    expect(r.match.stage, KolikoStageTv.over);
    expect(r.result, {1: 3000, 2: 1500, 3: 1000});
    expect(r.played, contains(Sound.fanfare));
    r.match.dispose();
  });

  testWidgets('a number after the time, or twice, or from a stranger, is ignored', (t) async {
    final r = Rig();
    r.match.onNumber(1, const NumberAnswer(5));
    r.match.onNumber(1, const NumberAnswer(6));
    r.match.onNumber(99, const NumberAnswer(6));
    r.match.onNumber(2, const NumberAnswer(-3));
    expect(r.match.answered, {1});
    await r.wait(t, 30);
    r.match.onNumber(2, const NumberAnswer(7));
    expect(r.match.reveal!.entries.firstWhere((e) => e.id == 2).value, isNull);
    r.match.dispose();
  });

  testWidgets('a player who drops out is not waited for and scores 0 for that question', (t) async {
    final r = Rig();
    r.match.onNumber(1, NumberAnswer(r.truth));
    r.match.onNumber(2, NumberAnswer(r.truth + 1));
    r.match.setAway(3, true);
    expect(r.match.stage, KolikoStageTv.reveal, reason: 'the only one missing is away');
    expect(r.sent[3]!.whereType<KolikoResult>().single.points, 0);
    await r.wait(t, 8);
    r.match.setAway(3, false);
    r.match.rejoin(3);
    expect(r.sent[3]!.whereType<KolikoAsk>().last.number, 2, reason: 'back in at the next question');
    r.match.dispose();
  });

  testWidgets('a reload during the question restores the phone\'s own number, and nobody else\'s', (t) async {
    final r = Rig();
    r.match.onNumber(1, const NumberAnswer(4242));
    r.match.rejoin(1);
    expect(r.sent[1]!.whereType<KolikoAsk>().last.sent, 4242);
    r.match.rejoin(2);
    expect(r.sent[2]!.whereType<KolikoAsk>().last.sent, isNull);
    expect(jsonEncode(r.sent[2]!.map((m) => m.toJson()).toList()).contains('4242'), isFalse);
    r.match.dispose();
  });

  testWidgets('a reload after the reveal restores the phone\'s own result', (t) async {
    final r = Rig();
    r.match.onNumber(1, NumberAnswer(r.truth));
    r.match.onNumber(2, NumberAnswer(r.truth + 3));
    r.match.onNumber(3, NumberAnswer(r.truth + 4));
    r.match.rejoin(2);
    final res = r.sent[2]!.whereType<KolikoResult>().toList();
    expect(res.length, 2);
    expect(res.last, res.first);
    r.match.dispose();
  });

  testWidgets('a screen lock: drop mid-question, rejoin, and the answer counts', (t) async {
    final r = Rig();
    r.match.onNumber(1, NumberAnswer(r.truth + 9));
    r.match.setAway(3, true);
    r.match.setAway(3, false); // the phone is back
    r.match.rejoin(3);
    expect(r.sent[3]!.whereType<KolikoAsk>().length, 2, reason: 'the open question again');
    r.match.onNumber(3, NumberAnswer(r.truth));
    expect(r.match.answered, {1, 3});
    r.match.onNumber(2, NumberAnswer(r.truth + 1));
    expect(r.match.stage, KolikoStageTv.reveal);
    expect(r.sent[3]!.whereType<KolikoResult>().single.rank, 1);
    r.match.dispose();
  });
}
