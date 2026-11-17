import 'dart:convert';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/uljez_match.dart';
import 'package:tv/sound/sfx.dart';

UljezPack pack() => UljezPack('p', 'Paket', [for (var i = 0; i < 12; i++) WordPair('a$i', 'b$i')]);

class Rig {
  Rig({int n = 5, int impostors = 1, int seed = 1, int discussion = 60}) {
    match = UljezMatch(
      ids: [for (var i = 1; i <= n; i++) i],
      pack: pack(),
      settings: GameSettings(uljezDiscussion: discussion, uljezImpostors: impostors),
      send: (id, m) => (sent[id] ??= []).add((at, m)),
      clock: () => at,
      random: Random(seed),
      sfx: _Sfx(played),
      onOver: (s) => scores = s,
    )..start();
  }
  late final UljezMatch match;
  final sent = <int, List<(Duration, Message)>>{};
  final played = <Sound>[];
  Map<int, int>? scores;
  Duration at = Duration.zero;

  Future<void> wait(WidgetTester t, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await t.pump(const Duration(seconds: 1));
      at += const Duration(seconds: 1);
    }
  }

  List<Message> to(int id) => [for (final e in sent[id] ?? const <(Duration, Message)>[]) e.$2];
  int get impostor => match.game.impostors.first;
  Future<void> toVote(WidgetTester t) async {
    await wait(t, 20 * 2 * match.ids.length);
    await wait(t, 60);
  }
}

extension on UljezGame {
  List<int> get impostors => [for (final i in ids) if (isImpostor(i)) i];
}

class _Sfx implements Sfx {
  _Sfx(this.log);
  final List<Sound> log;
  @override
  void play(Sound s) => log.add(s);
}

Map<String, Object?> shape(Message m) => {'type': m.type, 'keys': m.toJson().keys.toList()..sort()};

void main() {
  testWidgets('every phone gets one word: the impostor\'s is the pair\'s other word, and nothing else differs', (t) async {
    final r = Rig();
    final words = {for (final id in r.match.ids) id: r.to(id).whereType<UljezWord>().single.word};
    expect(words[r.impostor], r.match.game.impostorWord);
    expect(words.values.toSet().length, 2);
    expect(words.values.where((w) => w == r.match.game.villageWord).length, 4);
    // the full message streams of the impostor and a villager have the same shape and timing
    final villager = r.match.ids.firstWhere((i) => i != r.impostor);
    await r.toVote(t);
    expect([for (final e in r.sent[r.impostor]!) '${e.$1}${shape(e.$2)}'], [for (final e in r.sent[villager]!) '${e.$1}${shape(e.$2)}']);
    r.match.dispose();
  });

  testWidgets('no message but the word carries a word, and nobody is told who the impostor is before the vote', (t) async {
    final r = Rig();
    await r.toVote(t);
    for (final id in r.match.ids) {
      for (final m in r.to(id)) {
        if (m is UljezWord) continue;
        final j = jsonEncode(m.toJson());
        expect(j.contains(r.match.game.villageWord), isFalse, reason: j);
        expect(j.contains(r.match.game.impostorWord), isFalse, reason: j);
        expect(m is UljezEnd, isFalse);
      }
    }
    expect(r.match.villageWord, isNull, reason: 'the TV does not know the words until the end');
    expect(r.match.impostors, isEmpty);
    r.match.dispose();
  });

  testWidgets('clue turns: the speaker changes every 20 s, two rounds, then the discussion', (t) async {
    final r = Rig(n: 3);
    final order = r.match.order;
    expect(r.match.speaker, order[0]);
    await r.wait(t, 19);
    expect(r.match.speaker, order[0]);
    await r.wait(t, 1);
    expect(r.match.speaker, order[1]);
    await r.wait(t, 20 * 5);
    expect(r.match.phase, UljezPhase.discussion);
    final turns = r.to(1).whereType<UljezTurn>().toList();
    expect([for (final x in turns) x.stage], ['clues', 'clues', 'clues', 'clues', 'clues', 'clues', 'discussion']);
    expect([for (final x in turns.take(6)) x.round], [1, 1, 1, 2, 2, 2]);
    expect(turns.last.seconds, 60);
    r.match.dispose();
  });

  testWidgets('the vote opens for everyone after the discussion', (t) async {
    final r = Rig();
    await r.toVote(t);
    expect(r.match.phase, UljezPhase.vote);
    for (final id in r.match.ids) {
      final p = r.to(id).whereType<VotePrompt>().single;
      expect(p.ids, r.match.ids);
    }
    expect(r.played, contains(Sound.voteBell));
    r.match.dispose();
  });

  testWidgets('catch the impostor: only they get the guess; others wait; a wrong guess means the village wins', (t) async {
    final r = Rig();
    await r.toVote(t);
    for (final id in r.match.ids) {
      if (id != r.impostor) r.match.onVote(id, Vote(r.impostor));
    }
    r.match.onVote(r.impostor, const Vote(null));
    expect(r.match.phase, UljezPhase.guess);
    for (final id in r.match.ids) {
      expect(r.to(id).whereType<UljezGuess>().length, id == r.impostor ? 1 : 0);
    }
    expect(r.to(r.match.ids.firstWhere((i) => i != r.impostor)).last, isA<Waiting>());
    final g = r.to(r.impostor).whereType<UljezGuess>().single;
    expect(g.options.length, 4);
    r.match.onGuess(r.impostor, Guess((r.match.game.rightGuess + 1) % 4));
    expect(r.match.winner, UljezWinner.village);
    final end = r.to(2).whereType<UljezEnd>().single;
    expect(end.villageWord, r.match.game.villageWord);
    expect(end.impostors, [r.impostor]);
    expect(r.scores![r.impostor], 0);
    expect(r.scores!.values.where((v) => v == 1).length, 4);
    r.match.dispose();
  });

  testWidgets('a right guess wins for the impostor', (t) async {
    final r = Rig();
    await r.toVote(t);
    for (final id in r.match.ids) {
      if (id != r.impostor) r.match.onVote(id, Vote(r.impostor));
    }
    r.match.onVote(r.impostor, const Vote(null));
    r.match.onGuess(r.impostor, Guess(r.match.game.rightGuess));
    expect(r.match.winner, UljezWinner.impostors);
    expect(r.scores![r.impostor], 1);
    r.match.dispose();
  });

  testWidgets('no guess in 15 s is a wrong guess; only the guesser counts', (t) async {
    final r = Rig();
    await r.toVote(t);
    for (final id in r.match.ids) {
      if (id != r.impostor) r.match.onVote(id, Vote(r.impostor));
    }
    r.match.onVote(r.impostor, const Vote(null));
    final other = r.match.ids.firstWhere((i) => i != r.impostor);
    r.match.onGuess(other, Guess(r.match.game.rightGuess));
    expect(r.match.phase, UljezPhase.guess);
    await r.wait(t, 14);
    expect(r.match.phase, UljezPhase.guess);
    await r.wait(t, 1);
    expect(r.match.winner, UljezWinner.village);
    r.match.dispose();
  });

  testWidgets('voting out an innocent, or nobody (30 s up), lets the impostor win', (t) async {
    final r = Rig();
    await r.toVote(t);
    await r.wait(t, 30);
    expect(r.match.winner, UljezWinner.impostors);
    expect(r.match.lastOut, isNull);
    final s = Rig(seed: 3);
    await s.toVote(t);
    final innocent = s.match.ids.firstWhere((i) => i != s.impostor);
    for (final id in s.match.ids) {
      if (id != innocent) s.match.onVote(id, Vote(innocent));
    }
    s.match.onVote(innocent, const Vote(null));
    expect(s.match.winner, UljezWinner.impostors);
    expect(s.match.lastOut, innocent);
    r.match.dispose();
    s.match.dispose();
  });

  testWidgets('two impostors: a second vote follows each result, same prompt for everyone alive', (t) async {
    final r = Rig(n: 7, impostors: 2);
    await r.toVote(t);
    final imps = r.match.game.impostors;
    for (final id in r.match.ids) {
      if (id != imps[0]) r.match.onVote(id, Vote(imps[0]));
    }
    r.match.onVote(imps[0], const Vote(null));
    r.match.onGuess(imps[0], Guess((r.match.game.rightGuess + 1) % 4));
    expect(r.match.phase, UljezPhase.vote);
    expect(r.match.alive.contains(imps[0]), isFalse);
    expect(r.to(3).whereType<VotePrompt>().map((p) => p.day), [1, 2]);
    expect(r.to(imps[0]).whereType<VotePrompt>().length, 1, reason: 'the caught one is out and gets no second vote');
    for (final id in r.match.alive) {
      if (id != imps[1]) r.match.onVote(id, Vote(imps[1]));
    }
    r.match.onVote(imps[1], const Vote(null));
    r.match.onGuess(imps[1], Guess((r.match.game.rightGuess + 1) % 4));
    expect(r.match.winner, UljezWinner.village);
    r.match.dispose();
  });

  testWidgets('reconnect: own word and own state only', (t) async {
    final r = Rig();
    final villager = r.match.ids.firstWhere((i) => i != r.impostor);
    final before = r.to(villager).length;
    r.match.rejoin(villager);
    final again = r.to(villager).skip(before).toList();
    expect(again.whereType<UljezWord>().single.word, r.match.game.villageWord);
    expect(again.whereType<UljezTurn>().length, 1);
    expect(again.length, 2);
    final ib = r.to(r.impostor).length;
    r.match.rejoin(r.impostor);
    expect(r.to(r.impostor).skip(ib).whereType<UljezWord>().single.word, r.match.game.impostorWord);
    r.match.dispose();
  });

  testWidgets('votes and guesses at the wrong time do nothing', (t) async {
    final r = Rig();
    r.match.onVote(1, const Vote(2));
    r.match.onGuess(1, const Guess(0));
    expect(r.match.votedCount, 0);
    expect(r.match.phase, UljezPhase.clues);
    r.match.dispose();
  });

  testWidgets('a kicked speaker is skipped; their turn is not waited for', (t) async {
    // a seed where the impostor is neither of the two kicked speakers
    var seed = 1;
    Rig r = Rig(n: 4, seed: seed);
    while ([r.match.order[1], r.match.order[2]].contains(r.impostor)) {
      r.match.dispose();
      r = Rig(n: 4, seed: ++seed);
    }
    final order = r.match.order;
    r.match.expel(order[1]);
    await r.wait(t, 20); // the first speaker's turn ends
    expect(r.match.speaker, order[2], reason: 'the kicked one is skipped');
    r.match.expel(order[2]);
    expect(r.match.speaker, order[3], reason: 'a kick during their own turn ends it');
    r.match.dispose();
  });

  testWidgets('a kicked player does not hold the vote up', (t) async {
    final r = Rig();
    await r.toVote(t);
    final imp = r.impostor;
    final kicked = r.match.ids.firstWhere((i) => i != imp);
    for (final id in r.match.alive) {
      if (id != kicked && id != imp) r.match.onVote(id, const Vote(null));
    }
    r.match.onVote(imp, const Vote(null));
    expect(r.match.phase, UljezPhase.vote, reason: 'waiting for the kicked one');
    r.match.expel(kicked);
    expect(r.match.winner, UljezWinner.impostors, reason: 'nobody was voted out');
    r.match.dispose();
  });

  testWidgets('a kicked impostor: the village wins at once and everyone gets the end', (t) async {
    final r = Rig();
    r.match.expel(r.impostor);
    expect(r.match.winner, UljezWinner.village);
    for (final id in r.match.ids) {
      expect(r.to(id).last, isA<UljezEnd>());
    }
    expect(r.scores![r.impostor], 0);
    r.match.dispose();
  });

  testWidgets('a kicked guesser: the guess ends at once as a wrong guess', (t) async {
    final r = Rig();
    await r.toVote(t);
    for (final id in r.match.ids) {
      if (id != r.impostor) r.match.onVote(id, Vote(r.impostor));
    }
    r.match.onVote(r.impostor, const Vote(null));
    expect(r.match.phase, UljezPhase.guess);
    r.match.expel(r.impostor);
    expect(r.match.winner, UljezWinner.village);
    r.match.dispose();
  });
}
