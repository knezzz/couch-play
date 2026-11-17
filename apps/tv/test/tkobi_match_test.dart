import 'dart:convert';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/tkobi_match.dart';
import 'package:tv/sound/sfx.dart';

TkobiPack pack() => TkobiPack('p', 'P', [for (var i = 0; i < 40; i++) 'Tko bi $i?']);

class _Sfx implements Sfx {
  _Sfx(this.log);
  final List<Sound> log;
  @override
  void play(Sound s) => log.add(s);
}

class Rig {
  Rig({int n = 4, int prompts = 2, int seed = 1}) {
    match = TkobiMatch(
      ids: [for (var i = 1; i <= n; i++) i],
      pack: pack(),
      settings: GameSettings(tkobiPrompts: prompts),
      send: (id, m) => (sent[id] ??= []).add(m),
      clock: () => at,
      random: Random(seed),
      sfx: _Sfx(played),
      onOver: (s) => result = s,
    )..start();
  }
  late final TkobiMatch match;
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

  List<Message> to(int id) => sent[id] ?? [];
}

void main() {
  testWidgets('every phone gets the prompt and everybody to vote for, itself included', (t) async {
    final r = Rig();
    for (final id in r.match.ids) {
      final a = r.to(id).whereType<TkobiAsk>().single;
      expect([a.number, a.total, a.seconds, a.text, a.ids], [1, 2, 15, r.match.text, r.match.ids]);
      expect(a.picked, isNull);
    }
    r.match.dispose();
  });

  testWidgets('the TV learns only how many have voted; nobody learns who voted for whom', (t) async {
    final r = Rig();
    r.match.onVote(1, const Vote(3));
    r.match.onVote(2, const Vote(3));
    expect(r.match.votedCount, 2);
    expect(r.match.reveal, isNull);
    for (final id in r.match.ids) {
      for (final m in r.to(id)) {
        expect(m is TkobiResult, isFalse);
      }
    }
    // after the reveal the counts are public but never the voters
    r.match.onVote(3, const Vote(1));
    r.match.onVote(4, const Vote(3));
    expect(r.match.stage, TkobiStageTv.reveal);
    final rv = r.match.reveal!;
    expect(rv.counts, {1: 1, 2: 0, 3: 3, 4: 0});
    expect(rv.crowned, [3]);
    for (final id in r.match.ids) {
      final j = jsonEncode(r.to(id).whereType<TkobiResult>().single.toJson());
      expect(j.contains('voter'), isFalse);
    }
    r.match.dispose();
  });

  testWidgets('each phone is told only whether ITS vote was right; the crowned one gets the confetti', (t) async {
    final r = Rig();
    r.match.onVote(1, const Vote(3));
    r.match.onVote(2, const Vote(3));
    r.match.onVote(3, const Vote(4));
    r.match.onVote(4, const Vote(1));
    final res = {for (final id in r.match.ids) id: r.to(id).whereType<TkobiResult>().single};
    expect(res[1]!.votedRight, isTrue);
    expect(res[2]!.votedRight, isTrue);
    expect(res[3]!.votedRight, isFalse);
    expect(res[4]!.votedRight, isFalse);
    expect([res[1]!.points, res[1]!.total], [1, 1]);
    expect(res.values.every((x) => x.crowned.length == 1 && x.counts[3] == 2), isTrue, reason: 'the counts and the crown are public');
    expect(r.to(3).whereType<Effect>().length, 1);
    expect(r.to(1).whereType<Effect>(), isEmpty);
    r.match.dispose();
  });

  testWidgets('a vote is one tap and final; a skip, a stranger, or a stranger target is ignored', (t) async {
    final r = Rig();
    r.match.onVote(1, const Vote(2));
    r.match.onVote(1, const Vote(3));
    r.match.onVote(2, const Vote(null));
    r.match.onVote(99, const Vote(1));
    r.match.onVote(3, const Vote(99));
    expect(r.match.votedCount, 1);
    r.match.dispose();
  });

  testWidgets('15 s to vote with a tick; the reveal at 0; 7 s of bars; then the next prompt; the last ends the game', (t) async {
    final r = Rig(prompts: 2);
    r.match.onVote(1, const Vote(2));
    await r.wait(t, 14);
    expect(r.match.stage, TkobiStageTv.ask);
    expect(r.match.secondsLeft, 1);
    await r.wait(t, 1);
    expect(r.match.stage, TkobiStageTv.reveal);
    expect(r.played.where((s) => s == Sound.quizTick).length, 9);
    expect(r.played.where((s) => s == Sound.tick).length, 5);
    await r.wait(t, 6);
    expect(r.match.stage, TkobiStageTv.reveal);
    await r.wait(t, 1);
    expect(r.match.stage, TkobiStageTv.ask);
    expect(r.match.number, 2);
    await r.wait(t, 15 + 7);
    expect(r.match.stage, TkobiStageTv.over);
    expect(r.result, isNotNull);
    r.match.dispose();
  });

  testWidgets('a player who drops out is not waited for and scores 0 for that prompt', (t) async {
    final r = Rig(n: 3);
    r.match.onVote(1, const Vote(2));
    r.match.onVote(2, const Vote(2));
    r.match.setAway(3, true);
    expect(r.match.stage, TkobiStageTv.reveal);
    expect(r.to(3).whereType<TkobiResult>().single.points, 0);
    r.match.dispose();
  });

  testWidgets('a reload restores the phone\'s own vote and nobody else\'s', (t) async {
    final r = Rig();
    r.match.onVote(1, const Vote(4));
    r.match.rejoin(1);
    expect(r.to(1).whereType<TkobiAsk>().last.picked, 4);
    r.match.rejoin(2);
    expect(r.to(2).whereType<TkobiAsk>().last.picked, isNull);
    r.match.dispose();
  });

  testWidgets('a screen lock: drop mid-prompt, rejoin, and the vote counts', (t) async {
    final r = Rig(n: 3);
    r.match.onVote(1, const Vote(2));
    r.match.setAway(3, true);
    r.match.setAway(3, false);
    r.match.rejoin(3);
    expect(r.to(3).whereType<TkobiAsk>().length, 2);
    r.match.onVote(3, const Vote(2));
    expect(r.match.votedCount, 2);
    r.match.onVote(2, const Vote(2));
    expect(r.match.stage, TkobiStageTv.reveal);
    expect(r.to(3).whereType<TkobiResult>().single.votedRight, isTrue);
    r.match.dispose();
  });
}
