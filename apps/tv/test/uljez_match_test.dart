import 'dart:convert';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/uljez_match.dart';
import 'package:tv/sound/sfx.dart';

UljezPack pack() => UljezPack('p', 'Paket', [for (var i = 0; i < 12; i++) WordPair('a$i', 'b$i')]);

class Rig {
  Rig({int n = 5, int impostors = 1, int seed = 1}) {
    match = UljezMatch(
      ids: [for (var i = 1; i <= n; i++) i],
      pack: pack(),
      settings: GameSettings(uljezImpostors: impostors),
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

  /// Round 1 passes turn by turn, then everyone says "Idemo glasati".
  Future<void> toVote(WidgetTester t) async {
    for (var i = 0; i < match.ids.length; i++) {
      match.onDone(match.speaker!);
    }
    for (final id in match.ids) {
      match.onReady(id, const ReadyToVote(true));
    }
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

  testWidgets('clue turns: only the speaker\'s "Dao sam trag" passes the turn; rounds repeat; no clock', (t) async {
    final r = Rig(n: 3);
    final order = r.match.order;
    expect(r.match.speaker, order[0]);
    await r.wait(t, 3600);
    expect(r.match.speaker, order[0], reason: 'an hour passes and nothing moves');
    r.match.onDone(order[1]);
    r.match.onDone(order[2]);
    expect(r.match.speaker, order[0], reason: 'not their turn');
    r.match.onDone(order[0]);
    expect(r.match.speaker, order[1]);
    r.match.onDone(order[0]); // a double send from the one who just spoke
    expect(r.match.speaker, order[1]);
    for (var i = 0; i < 7; i++) {
      r.match.onDone(r.match.speaker!);
    }
    expect(r.match.round, 3, reason: 'round after round, no end of their own');
    expect(r.match.phase, UljezPhase.clues);
    final turns = r.to(1).whereType<UljezTurn>().toList();
    expect({for (final x in turns) x.stage}, {'clues'});
    expect({for (final x in turns) x.seconds}, {0});
    r.match.dispose();
  });

  testWidgets('a speaker who drops is skipped, a returning one just waits for their next turn', (t) async {
    final r = Rig(n: 4);
    final order = r.match.order;
    r.match.setAway(order[0], true); // the one speaking now
    expect(r.match.speaker, order[1]);
    r.match.setAway(order[2], true); // the next but one
    r.match.onDone(order[1]);
    expect(r.match.speaker, order[3]);
    r.match.setAway(order[0], false);
    expect(r.match.speaker, order[3], reason: 'coming back does not take the turn');
    r.match.onDone(order[3]);
    expect(r.match.speaker, order[0]);
    r.match.dispose();
  });

  testWidgets('"Idemo glasati" is closed in round 1, then a majority of the connected starts the vote', (t) async {
    final r = Rig(n: 5);
    r.match.onReady(1, const ReadyToVote(true));
    expect(r.match.wishCount, 0);
    expect(r.to(1).whereType<VoteWish>().last.open, isFalse);
    for (var i = 0; i < 5; i++) {
      r.match.onDone(r.match.speaker!);
    }
    expect(r.match.wishOpen, isTrue);
    expect(r.to(2).whereType<VoteWish>().last, const VoteWish(open: true, ready: false, want: 0, needed: 3));
    r.match.onReady(1, const ReadyToVote(true));
    r.match.onReady(1, const ReadyToVote(true)); // a double send changes nothing
    r.match.onReady(2, const ReadyToVote(true));
    expect(r.match.wishCount, 2);
    expect(r.match.phase, UljezPhase.clues, reason: '2 of 5 is not more than half');
    expect(r.to(1).whereType<VoteWish>().last, const VoteWish(open: true, ready: true, want: 2, needed: 3));
    expect(r.to(3).whereType<VoteWish>().last, const VoteWish(open: true, ready: false, want: 2, needed: 3));
    r.match.onReady(2, const ReadyToVote(false)); // undo
    expect(r.match.wishCount, 1);
    r.match.onReady(2, const ReadyToVote(true));
    r.match.onReady(3, const ReadyToVote(true));
    expect(r.match.phase, UljezPhase.vote, reason: '3 of 5');
    r.match.dispose();
  });

  testWidgets('a drop-out lowers the bar, their wish stops counting, and counts again when they return', (t) async {
    final r = Rig(n: 5);
    for (var i = 0; i < 5; i++) {
      r.match.onDone(r.match.speaker!);
    }
    r.match.onReady(1, const ReadyToVote(true));
    r.match.onReady(2, const ReadyToVote(true));
    r.match.setAway(1, true);
    expect(r.match.wishCount, 1, reason: 'the wish of the one away does not count');
    expect(r.match.wishNeeded, 3, reason: '4 connected: more than half is 3');
    r.match.setAway(5, true);
    expect(r.match.wishNeeded, 2, reason: '3 connected');
    expect(r.match.phase, UljezPhase.clues);
    r.match.onReady(3, const ReadyToVote(true));
    expect(r.match.phase, UljezPhase.vote, reason: '2 and 3 are 2 of the 3 connected');
    r.match.dispose();
    final q = Rig(n: 5);
    for (var i = 0; i < 5; i++) {
      q.match.onDone(q.match.speaker!);
    }
    q.match.onReady(1, const ReadyToVote(true));
    q.match.onReady(2, const ReadyToVote(true));
    q.match.setAway(1, true);
    q.match.setAway(4, true);
    q.match.setAway(5, true);
    expect(q.match.phase, UljezPhase.clues, reason: 'only 2 is connected and on: 1 of 2 is not more than half');
    q.match.dispose();
  });

  testWidgets('a drop-out can tip the majority; the wish of a returner counts again at once', (t) async {
    final r = Rig(n: 5);
    for (var i = 0; i < 5; i++) {
      r.match.onDone(r.match.speaker!);
    }
    r.match.onReady(1, const ReadyToVote(true));
    r.match.onReady(2, const ReadyToVote(true));
    r.match.setAway(4, true);
    expect(r.match.phase, UljezPhase.clues, reason: '2 of 4');
    r.match.setAway(5, true);
    expect(r.match.phase, UljezPhase.vote, reason: '2 of 3 now');
    r.match.dispose();
    final q = Rig(n: 5);
    for (var i = 0; i < 5; i++) {
      q.match.onDone(q.match.speaker!);
    }
    q.match.onReady(1, const ReadyToVote(true));
    q.match.setAway(1, true);
    q.match.onReady(2, const ReadyToVote(true));
    q.match.onReady(3, const ReadyToVote(true));
    q.match.setAway(4, true);
    q.match.setAway(5, true);
    expect(q.match.phase, UljezPhase.vote, reason: '2 and 3 are 2 of 3 connected');
    q.match.dispose();
    final u = Rig(n: 5);
    for (var i = 0; i < 5; i++) {
      u.match.onDone(u.match.speaker!);
    }
    u.match.onReady(1, const ReadyToVote(true));
    u.match.onReady(2, const ReadyToVote(true));
    u.match.setAway(1, true);
    u.match.setAway(2, true);
    u.match.setAway(3, true);
    expect(u.match.wishCount, 0);
    u.match.setAway(1, false);
    u.match.setAway(2, false);
    expect(u.match.wishCount, 2, reason: 'their wishes were kept');
    u.match.dispose();
  });

  testWidgets('a wish from someone who is out is ignored, and the wishes go when the vote starts', (t) async {
    final r = Rig(n: 5);
    for (var i = 0; i < 5; i++) {
      r.match.onDone(r.match.speaker!);
    }
    final imp = r.impostor;
    final kicked = r.match.ids.firstWhere((i) => i != imp);
    r.match.expel(kicked);
    r.match.onReady(kicked, const ReadyToVote(true));
    expect(r.match.wishCount, 0);
    expect(r.match.wishNeeded, 3, reason: '4 left');
    r.match.dispose();
  });

  testWidgets('the vote opens for everyone when the majority wants it', (t) async {
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
    expect(r.scores, isNull, reason: 'the end screen is up first');
    await r.wait(t, 10);
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
    await r.wait(t, 10);
    expect(r.scores![r.impostor], 1);
    r.match.dispose();
  });

  testWidgets('the impostor\'s guess has no timer; only the guesser counts', (t) async {
    final r = Rig();
    await r.toVote(t);
    for (final id in r.match.ids) {
      if (id != r.impostor) r.match.onVote(id, Vote(r.impostor));
    }
    r.match.onVote(r.impostor, const Vote(null));
    final other = r.match.ids.firstWhere((i) => i != r.impostor);
    r.match.onGuess(other, Guess(r.match.game.rightGuess));
    expect(r.match.phase, UljezPhase.guess);
    await r.wait(t, 3600);
    expect(r.match.phase, UljezPhase.guess, reason: 'the guess has no clock');
    expect(r.to(r.impostor).whereType<UljezGuess>().single.seconds, 0);
    r.match.onGuess(r.impostor, Guess((r.match.game.rightGuess + 1) % 4));
    expect(r.match.winner, UljezWinner.village);
    r.match.dispose();
  });

  testWidgets('voting out an innocent, or nobody (all skip), lets the impostor win; the vote has no clock', (t) async {
    final r = Rig();
    await r.toVote(t);
    await r.wait(t, 3600);
    expect(r.match.phase, UljezPhase.vote);
    for (final id in r.match.ids) {
      r.match.onVote(id, const Vote(null));
    }
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
    expect(again.whereType<VoteWish>().length, 1);
    expect(again.length, 3);
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
    r.match.onDone(order[0]); // the first speaker's turn ends
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
    await r.wait(t, 10);
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

  testWidgets('a kick during the vote: votes for the kicked player stay counted as voted (a skip)', (t) async {
    final r = Rig();
    await r.toVote(t);
    final imp = r.impostor;
    final kicked = r.match.ids.firstWhere((i) => i != imp);
    final others = r.match.ids.where((i) => i != kicked).toList();
    for (final id in others.take(2)) {
      r.match.onVote(id, Vote(kicked));
    }
    expect(r.match.votedCount, 2);
    r.match.expel(kicked);
    expect(r.match.votedCount, 2, reason: 'the voters still count');
    r.match.onVote(others[2], Vote(kicked)); // late vote for the kicked one: a skip
    expect(r.match.votedCount, 3);
    r.match.dispose();
  });

  testWidgets('two impostors: a voted-out innocent and a caught impostor leave the vote screen; a reload keeps them out', (t) async {
    final r = Rig(n: 7, impostors: 2);
    await r.toVote(t);
    final imps = r.match.game.impostors;
    final innocent = r.match.ids.firstWhere((i) => !imps.contains(i));
    for (final id in r.match.ids) {
      if (id != innocent) r.match.onVote(id, Vote(innocent));
    }
    r.match.onVote(innocent, const Vote(null));
    expect(r.match.phase, UljezPhase.vote, reason: 'the second vote follows');
    expect(r.to(innocent).last, isA<Waiting>(), reason: 'out: not left on the old vote screen');
    r.match.rejoin(innocent);
    expect(r.to(innocent).last, isA<Waiting>());
    r.match.dispose();
  });

  testWidgets('a caught impostor who guessed wrong leaves the guess screen when the game goes on', (t) async {
    final r = Rig(n: 7, impostors: 2);
    await r.toVote(t);
    final imps = r.match.game.impostors;
    for (final id in r.match.alive) {
      if (id != imps[0]) r.match.onVote(id, Vote(imps[0]));
    }
    r.match.onVote(imps[0], const Vote(null));
    r.match.onGuess(imps[0], Guess((r.match.game.rightGuess + 1) % 4));
    expect(r.match.winner, isNull);
    expect(r.to(imps[0]).last, isA<Waiting>());
    r.match.dispose();
  });

  testWidgets('the second impostor kicked while the first guesses: the game waits for the guess', (t) async {
    final r = Rig(n: 7, impostors: 2);
    await r.toVote(t);
    final imps = r.match.game.impostors;
    for (final id in r.match.alive) {
      if (id != imps[0]) r.match.onVote(id, Vote(imps[0]));
    }
    r.match.onVote(imps[0], const Vote(null));
    r.match.expel(imps[1]);
    expect(r.match.winner, isNull);
    r.match.onGuess(imps[0], Guess(r.match.game.rightGuess));
    expect(r.match.winner, UljezWinner.impostors);
    r.match.dispose();
  });

  testWidgets('the end screen with both words stays up for 10 s before the results; a rejoin in it gets the end', (t) async {
    final r = Rig();
    r.match.expel(r.impostor); // the village wins at once
    expect(r.match.phase, UljezPhase.over);
    expect(r.match.villageWord, isNotNull);
    expect(r.match.impostors, [r.impostor]);
    await r.wait(t, 9);
    expect(r.scores, isNull, reason: 'results only after the hold');
    final v = r.match.ids.firstWhere((i) => i != r.impostor);
    r.match.rejoin(v);
    expect(r.to(v).last, isA<UljezEnd>());
    await r.wait(t, 1);
    expect(r.scores, isNotNull);
    r.match.dispose();
  });

  testWidgets('the vote ends when every connected player has voted; the away are not waited for', (t) async {
    final r = Rig();
    await r.toVote(t);
    r.match.setAway(5, true);
    for (final id in [1, 2, 3]) {
      r.match.onVote(id, const Vote(null));
    }
    expect(r.match.phase, UljezPhase.vote);
    r.match.onVote(4, const Vote(null));
    expect(r.match.phase, UljezPhase.over, reason: 'all four connected voted; 5 is away');
    r.match.dispose();
    final q = Rig();
    await q.toVote(t);
    for (final id in [1, 2, 3, 4]) {
      q.match.onVote(id, const Vote(null));
    }
    expect(q.match.phase, UljezPhase.vote);
    q.match.setAway(5, true);
    expect(q.match.phase, UljezPhase.over, reason: 'the last one dropping ends the wait');
    q.match.dispose();
    final u = Rig();
    await u.toVote(t);
    u.match.setAway(5, true);
    u.match.setAway(5, false);
    for (final id in [1, 2, 3, 4]) {
      u.match.onVote(id, const Vote(null));
    }
    expect(u.match.phase, UljezPhase.vote, reason: 'back in: waited for again');
    u.match.dispose();
  });

  testWidgets('a guesser who is away has no guess: not waited for', (t) async {
    final r = Rig();
    await r.toVote(t);
    r.match.setAway(r.impostor, true);
    for (final id in r.match.ids) {
      if (id != r.impostor) r.match.onVote(id, Vote(r.impostor));
    }
    expect(r.match.phase, UljezPhase.over);
    expect(r.match.winner, UljezWinner.village);
    r.match.dispose();
  });

  testWidgets('nobody connected: nothing moves, and after 2 minutes the match is given up once', (t) async {
    final r = Rig(n: 3);
    var gaveUp = 0;
    r.match.onAbandon = () => gaveUp++;
    for (final id in r.match.ids) {
      r.match.setAway(id, true);
    }
    await r.wait(t, 119);
    expect(gaveUp, 0);
    expect(r.match.phase, UljezPhase.clues);
    await r.wait(t, 1);
    expect(gaveUp, 1);
    await r.wait(t, 600);
    expect(gaveUp, 1);
    r.match.dispose();
    final q = Rig(n: 3);
    var again = 0;
    q.match.onAbandon = () => again++;
    for (final id in q.match.ids) {
      q.match.setAway(id, true);
    }
    await q.wait(t, 100);
    q.match.setAway(2, false);
    await q.wait(t, 600);
    expect(again, 0, reason: 'someone came back');
    q.match.dispose();
  });

  testWidgets('nothing ends on a timer: clues, the wishes, the vote and the guess wait for an hour', (t) async {
    final r = Rig();
    await r.wait(t, 3600);
    expect(r.match.phase, UljezPhase.clues);
    await r.toVote(t);
    await r.wait(t, 3600);
    expect(r.match.phase, UljezPhase.vote);
    for (final id in r.match.ids) {
      if (id != r.impostor) r.match.onVote(id, Vote(r.impostor));
    }
    r.match.onVote(r.impostor, const Vote(null));
    await r.wait(t, 3600);
    expect(r.match.phase, UljezPhase.guess);
    r.match.dispose();
  });
}
