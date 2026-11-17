import 'dart:convert';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

UljezPack pack([int n = 10]) => UljezPack('p', 'Paket', [for (var i = 0; i < n; i++) WordPair('a$i', 'b$i')]);

UljezGame game(int n, {int impostors = 1, int seed = 1, UljezPack? p}) =>
    UljezGame([for (var i = 1; i <= n; i++) i], p ?? pack(), impostors: impostors, random: Random(seed));

/// Plays the clues to the end.
void clues(UljezGame g) {
  while (g.phase == UljezPhase.clues) {
    g.nextTurn();
  }
}

void main() {
  group('pack', () {
    test('parses the content format', () {
      final p = UljezPack.fromJson(jsonDecode('{"id":"x","title":"T","pairs":[["a","b"],["c","d"],["e","f"],["g","h"]]}') as Map<String, dynamic>);
      expect(p.id, 'x');
      expect(p.title, 'T');
      expect(p.pairs.length, 4);
      expect(p.pairs[1].b, 'd');
    });

    test('rejects a bad shape, a pair that is not two different words, or too few pairs', () {
      for (final bad in [
        '{"id":"x","title":"T","pairs":[["a"]]}',
        '{"id":"x","title":"T","pairs":[["a","a"],["c","d"],["e","f"],["g","h"]]}',
        '{"id":"x","title":"T","pairs":"no"}',
        '{"id":"x","pairs":[["a","b"]]}',
        '{"id":"x","title":"T","pairs":[["a","b"],["c","d"]]}',
      ]) {
        expect(() => UljezPack.fromJson(jsonDecode(bad) as Map<String, dynamic>), throwsA(anything), reason: bad);
      }
    });
  });

  group('the draw', () {
    test('3 to 8 players only', () {
      expect(() => game(2), throwsArgumentError);
      expect(() => game(9), throwsArgumentError);
      for (var n = 3; n <= 8; n++) {
        game(n);
      }
    });

    test('one impostor for 3-6 even if two are asked, two at 7-8 when asked', () {
      for (var n = 3; n <= 6; n++) {
        expect(game(n, impostors: 2).impostorCount, 1);
      }
      expect(game(7).impostorCount, 1);
      expect(game(7, impostors: 2).impostorCount, 2);
      expect(game(8, impostors: 2).impostorCount, 2);
      expect([for (var i = 1; i <= 8; i++) game(8, impostors: 2).isImpostor(i)].where((x) => x).length, 2);
    });

    test('everyone has the village word but the impostors, who get the pair\'s other word', () {
      final g = game(6);
      final words = {for (var i = 1; i <= 6; i++) i: g.wordOf(i)};
      final imp = [for (var i = 1; i <= 6; i++) if (g.isImpostor(i)) i].single;
      expect(words[imp], g.impostorWord);
      expect(g.villageWord, isNot(g.impostorWord));
      for (var i = 1; i <= 6; i++) {
        if (i != imp) expect(words[i], g.villageWord);
      }
      expect({g.villageWord, g.impostorWord}, {g.pair.a, g.pair.b});
    });

    test('either side of the pair can be the village word, and anyone can be the impostor', () {
      final sides = <String>{};
      final imps = <int>{};
      for (var seed = 0; seed < 80; seed++) {
        final g = game(5, seed: seed);
        sides.add(g.villageWord == g.pair.a ? 'a' : 'b');
        imps.add([for (var i = 1; i <= 5; i++) if (g.isImpostor(i)) i].single);
      }
      expect(sides, {'a', 'b'});
      expect(imps, {1, 2, 3, 4, 5});
    });

    test('the pair is drawn from the pack, and the same seed gives the same draw', () {
      final a = game(5, seed: 9), b = game(5, seed: 9);
      expect([a.villageWord, a.impostorWord, a.order], [b.villageWord, b.impostorWord, b.order]);
      final pairs = {for (var seed = 0; seed < 100; seed++) game(5, seed: seed).pair.a};
      expect(pairs.length, greaterThan(5));
    });
  });

  group('clue turns', () {
    test('everyone speaks once per round, twice in all, in the same order', () {
      final g = game(5);
      expect(g.order.toSet(), {1, 2, 3, 4, 5});
      final spoke = <int>[];
      while (g.phase == UljezPhase.clues) {
        spoke.add(g.speaker!);
        g.nextTurn();
      }
      expect(spoke, [...g.order, ...g.order]);
      expect(spoke.length, 10);
      expect(g.phase, UljezPhase.discussion);
      expect(g.speaker, isNull);
    });

    test('round numbers', () {
      final g = game(3);
      final rounds = <int>[];
      while (g.phase == UljezPhase.clues) {
        rounds.add(g.round);
        g.nextTurn();
      }
      expect(rounds, [1, 1, 1, 2, 2, 2]);
    });

    test('the order is shuffled by the seed', () {
      final orders = {for (var seed = 0; seed < 30; seed++) game(6, seed: seed).order.join()};
      expect(orders.length, greaterThan(5));
    });
  });

  group('the vote, one impostor', () {
    UljezGame voting({int seed = 1, int n = 5}) {
      final g = game(n, seed: seed);
      clues(g);
      g.startVote();
      return g;
    }

    int impostorOf(UljezGame g) => [for (final i in g.ids) if (g.isImpostor(i)) i].first;
    int innocentOf(UljezGame g) => [for (final i in g.ids) if (!g.isImpostor(i)) i].first;

    void everyoneVotes(UljezGame g, int target) {
      for (final i in g.ids) {
        if (i != target) g.vote(i, target);
      }
      g.vote(target, g.ids.firstWhere((x) => x != target));
    }

    test('the most voted impostor is caught and gets to guess', () {
      final g = voting();
      everyoneVotes(g, impostorOf(g));
      final r = g.resolveVote();
      expect(r.out, impostorOf(g));
      expect(r.caught, isTrue);
      expect(g.phase, UljezPhase.guess);
      expect(g.guesser, impostorOf(g));
    });

    test('an innocent voted out means the impostor survived and wins', () {
      final g = voting();
      everyoneVotes(g, innocentOf(g));
      g.resolveVote();
      expect(g.phase, UljezPhase.over);
      expect(g.winner, UljezWinner.impostors);
    });

    test('a tie puts nobody out, and the impostor survives', () {
      final g = voting(n: 4);
      g.vote(1, 3);
      g.vote(2, 3);
      g.vote(3, 4);
      g.vote(4, 3);
      g.vote(3, 1); // 3 moves: now 1 has 1, 3 has 2... make it a clean tie
      g.vote(4, 1);
      final r = g.resolveVote();
      expect(r.tie, isTrue);
      expect(r.out, isNull);
      expect(g.winner, UljezWinner.impostors);
    });

    test('nobody voting is the same as a tie', () {
      final g = voting();
      expect(g.resolveVote().out, isNull);
      expect(g.winner, UljezWinner.impostors);
    });

    test('you cannot vote for yourself or a stranger; a second vote replaces the first; only in the vote phase', () {
      final g = voting();
      expect(g.vote(1, 1), isFalse);
      expect(g.vote(1, 99), isFalse);
      expect(g.vote(99, 1), isFalse);
      expect(g.vote(1, 2), isTrue);
      expect(g.vote(1, 3), isTrue);
      expect(g.votes[1], 3);
      final h = game(4);
      expect(h.vote(1, 2), isFalse, reason: 'clues are on');
    });

    test('the vote is complete when everyone has voted (a skip counts)', () {
      final g = voting(n: 3);
      g.vote(1, 2);
      g.vote(2, 3);
      expect(g.voteComplete, isFalse);
      g.vote(3, null);
      expect(g.voteComplete, isTrue);
    });
  });

  group('the guess', () {
    UljezGame caught({int seed = 1, int n = 5, UljezPack? p}) {
      final g = game(n, seed: seed, p: p);
      clues(g);
      g.startVote();
      final imp = [for (final i in g.ids) if (g.isImpostor(i)) i].first;
      for (final i in g.ids) {
        if (i != imp) g.vote(i, imp);
      }
      g.resolveVote();
      return g;
    }

    test('four options: the right word and three decoys from other pairs, shuffled', () {
      for (var seed = 0; seed < 30; seed++) {
        final g = caught(seed: seed);
        expect(g.guessOptions.length, 4);
        expect(g.guessOptions.toSet().length, 4);
        expect(g.guessOptions[g.rightGuess], g.villageWord);
        for (var i = 0; i < 4; i++) {
          if (i == g.rightGuess) continue;
          expect(g.guessOptions[i], isNot(g.pair.a));
          expect(g.guessOptions[i], isNot(g.pair.b));
        }
      }
    });

    test('the right place of the answer moves around', () {
      expect({for (var seed = 0; seed < 40; seed++) caught(seed: seed).rightGuess}.length, greaterThan(1));
    });

    test('a right guess wins for the impostors', () {
      final g = caught();
      expect(g.guess(g.guesser!, g.rightGuess), isTrue);
      g.resolveGuess();
      expect(g.winner, UljezWinner.impostors);
      expect(g.guessedRight, isTrue);
    });

    test('a wrong or missing guess means the village wins', () {
      final g = caught();
      g.guess(g.guesser!, (g.rightGuess + 1) % 4);
      g.resolveGuess();
      expect(g.winner, UljezWinner.village);
      final h = caught();
      h.resolveGuess();
      expect(h.winner, UljezWinner.village);
    });

    test('only the caught impostor can guess, once the guess phase is on', () {
      final g = caught();
      final who = g.guesser!;
      final other = g.ids.firstWhere((i) => i != who);
      expect(g.guess(other, g.rightGuess), isFalse);
      expect(g.guess(who, 7), isFalse);
      g.resolveGuess();
      expect(g.guess(who, 0), isFalse, reason: 'it is over');
    });

    test('words shared between pairs never put the right word or a duplicate among the decoys', () {
      final shared = UljezPack('s', 'S', const [
        WordPair('x', 'y'), WordPair('x', 'z'), WordPair('y', 'z'), WordPair('z', 'x'),
        WordPair('x', 'w'), WordPair('y', 'w'), WordPair('p', 'x'), WordPair('q', 'y'), WordPair('r', 'z'),
      ]);
      for (var seed = 0; seed < 60; seed++) {
        final g = caught(seed: seed, p: shared);
        expect(g.guessOptions.where((o) => o == g.villageWord).length, 1, reason: '$seed ${g.guessOptions}');
        expect(g.guessOptions.toSet().length, g.guessOptions.length);
        expect(g.guessOptions.contains(g.impostorWord), isFalse);
      }
    });

    test('a small pack still gives four options', () {
      final g = caught(p: pack(4));
      expect(g.guessOptions.toSet().length, 4);
    });
  });

  group('two impostors', () {
    UljezGame two({int seed = 1}) {
      final g = game(7, impostors: 2, seed: seed);
      clues(g);
      g.startVote();
      return g;
    }

    List<int> imps(UljezGame g) => [for (final i in g.ids) if (g.isImpostor(i)) i];
    int innocent(UljezGame g) => g.alive.firstWhere((i) => !g.isImpostor(i));

    void voteOut(UljezGame g, int target) {
      for (final i in g.alive) {
        if (i != target) g.vote(i, target);
      }
      g.resolveVote();
    }

    test('the village gets two votes, one per impostor; catching both with wrong guesses wins', () {
      final g = two();
      expect(g.votesLeft, 2);
      voteOut(g, imps(g)[0]);
      expect(g.phase, UljezPhase.guess);
      g.resolveGuess();
      expect(g.phase, UljezPhase.vote, reason: 'the second vote follows');
      expect(g.votesLeft, 1);
      expect(g.alive.contains(imps(g)[0]), isFalse);
      voteOut(g, imps(g)[1]);
      g.resolveGuess();
      expect(g.winner, UljezWinner.village);
    });

    test('missing the second impostor means the impostors win', () {
      final g = two();
      voteOut(g, imps(g)[0]);
      g.resolveGuess();
      voteOut(g, innocent(g));
      expect(g.phase, UljezPhase.over);
      expect(g.winner, UljezWinner.impostors);
    });

    test('a first vote that hits an innocent still leaves a second vote', () {
      final g = two();
      voteOut(g, innocent(g));
      expect(g.phase, UljezPhase.vote);
      expect(g.votesLeft, 1);
      voteOut(g, imps(g)[0]);
      g.resolveGuess();
      expect(g.winner, UljezWinner.impostors, reason: 'only one of two caught');
    });

    test('a right guess by either caught impostor ends it for the impostors at once', () {
      final g = two();
      voteOut(g, imps(g)[0]);
      g.guess(g.guesser!, g.rightGuess);
      g.resolveGuess();
      expect(g.winner, UljezWinner.impostors);
    });

    test('a tie uses a vote up', () {
      final g = two();
      g.resolveVote();
      expect(g.votesLeft, 1);
      expect(g.phase, UljezPhase.vote);
    });

    test('out players cannot vote or be voted for in the second vote', () {
      final g = two();
      final first = imps(g)[0];
      voteOut(g, first);
      g.resolveGuess();
      expect(g.vote(first, innocent(g)), isFalse);
      expect(g.vote(innocent(g), first), isFalse);
    });
  });

  group('scoring', () {
    test('winners get 1, the others 0, and it feeds placementPoints', () {
      final g = game(4);
      clues(g);
      g.startVote();
      g.resolveVote();
      expect(g.winner, UljezWinner.impostors);
      final scores = g.scores;
      final imp = [for (final i in g.ids) if (g.isImpostor(i)) i].single;
      expect(scores[imp], 1);
      expect(scores.values.where((v) => v == 0).length, 3);
      final places = placementPoints(scores);
      expect(places.firstWhere((p) => p.playerId == imp).place, 1);
    });

    test('a village win scores the village', () {
      final g = game(4);
      clues(g);
      g.startVote();
      final imp = [for (final i in g.ids) if (g.isImpostor(i)) i].single;
      for (final i in g.ids) {
        if (i != imp) g.vote(i, imp);
      }
      g.resolveVote();
      g.resolveGuess();
      expect(g.winner, UljezWinner.village);
      expect(g.scores[imp], 0);
      expect(g.scores.values.where((v) => v == 1).length, 3);
    });

    test('no scores before the game is over', () {
      expect(game(4).scores, isEmpty);
    });
  });
}
