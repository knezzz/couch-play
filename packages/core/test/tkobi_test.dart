import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

TkobiPack pack([int n = 40]) => TkobiPack('p', 'P', [for (var i = 0; i < n; i++) 'Tko bi $i?']);

TkobiGame game(int n, {int prompts = 3, int seed = 1, TkobiPack? p}) =>
    TkobiGame([for (var i = 1; i <= n; i++) i], p ?? pack(), prompts: prompts, random: Random(seed));

void main() {
  group('pack', () {
    List<String> many(int n) => [for (var i = 0; i < n; i++) 'p$i'];

    test('parses {"id","title","prompts"}', () {
      final p = TkobiPack.fromJson({'id': 'x', 'title': 'T', 'prompts': many(30)});
      expect([p.id, p.title, p.prompts.length], ['x', 'T', 30]);
    });

    test('rejects bad shapes, empty prompts, duplicates (any case) and fewer than 30', () {
      final bad = <Map<String, dynamic>>[
        {'id': 'x', 'prompts': many(30)},
        {'id': 'x', 'title': 'T', 'prompts': 'no'},
        {'id': 'x', 'title': 'T', 'prompts': [...many(30), '']},
        {'id': 'x', 'title': 'T', 'prompts': [...many(30), 5]},
        {'id': 'x', 'title': 'T', 'prompts': [...many(30), 'P1']},
        {'id': 'x', 'title': 'T', 'prompts': many(29)},
      ];
      for (final b in bad) {
        expect(() => TkobiPack.fromJson(b), throwsA(isA<FormatException>()), reason: '$b');
      }
    });
  });

  group('the game', () {
    test('3 to 8 players; prompts drawn without repeats; seeded', () {
      expect(() => game(2), throwsArgumentError);
      expect(() => game(9), throwsArgumentError);
      final g = game(3, prompts: 10);
      final seen = <String>{};
      while (!g.over) {
        expect(seen.add(g.current), isTrue);
        g.reveal();
        g.next();
      }
      expect(seen.length, 10);
      expect(game(3, seed: 9).current, game(3, seed: 9).current);
    });

    test('one vote each, final; anyone, yourself included; unknown players and targets are refused', () {
      final g = game(3);
      expect(g.vote(1, 1), isTrue, reason: 'for yourself');
      expect(g.vote(1, 2), isFalse, reason: 'no changing the vote');
      expect(g.vote(2, 99), isFalse);
      expect(g.vote(99, 1), isFalse);
      expect(g.voted, {1});
      expect(g.votedCount, 1);
    });

    test('no vote after the reveal; everyone present voted -> done; an away player is not waited for', () {
      final g = game(3);
      g.vote(1, 2);
      g.vote(2, 2);
      expect(g.allVoted, isFalse);
      g.setAway(3, true);
      expect(g.allVoted, isTrue);
      g.reveal();
      expect(g.vote(3, 1), isFalse);
    });

    test('the most voted is crowned; a tie crowns everyone tied; no votes crown nobody', () {
      var g = game(4);
      g.vote(1, 3);
      g.vote(2, 3);
      g.vote(4, 1);
      var r = g.reveal();
      expect(r.crowned, [3]);
      expect(r.counts, {1: 1, 2: 0, 3: 2, 4: 0});

      g = game(4);
      g.vote(1, 3);
      g.vote(2, 4);
      r = g.reveal();
      expect(r.crowned.toSet(), {3, 4});

      g = game(3);
      r = g.reveal();
      expect(r.crowned, isEmpty);
      expect(r.points.values.every((v) => v == 0), isTrue);
    });

    test('1 point if your vote went to a crowned player; being crowned scores nothing by itself', () {
      final g = game(4);
      g.vote(1, 3);
      g.vote(2, 3);
      g.vote(3, 4); // crowned 3 voted for 4 (not crowned)
      g.vote(4, 1);
      final r = g.reveal();
      expect(r.crowned, [3]);
      expect(r.points, {1: 1, 2: 1, 3: 0, 4: 0});
    });

    test('a vote for yourself scores when you are the crowned one', () {
      final g = game(4);
      g.vote(1, 3);
      g.vote(2, 4);
      g.vote(3, 3); // for yourself: crowned, so right
      final r = g.reveal();
      expect(r.crowned.toSet(), {3});
      expect(r.points[1], 1);
      expect(r.points[2], 0);
      expect(r.points[3], 1);
    });

    test('the reveal shows counts only: no voter-to-target mapping anywhere in it', () {
      final g = game(3);
      g.vote(1, 2);
      final r = g.reveal();
      expect(r.counts, {1: 0, 2: 1, 3: 0});
      expect(r.toString().contains('voter'), isFalse);
    });

    test('totals and session scores at the end', () {
      final g = game(3, prompts: 2);
      for (var i = 0; i < 2; i++) {
        g.vote(1, 3);
        g.vote(2, 3);
        g.reveal();
        g.next();
      }
      expect(g.over, isTrue);
      expect(g.sessionScores, {1: 2, 2: 2, 3: 0});
      expect(game(3).sessionScores, isEmpty);
    });

    test('a player who drops and comes back while the prompt is open can vote on it; not waited for while away', () {
      final g = game(3);
      g.vote(1, 2);
      g.vote(2, 2);
      g.setAway(3, true);
      expect(g.vote(3, 1), isFalse);
      expect(g.allVoted, isTrue);
      g.setAway(3, false);
      expect(g.allVoted, isFalse);
      expect(g.vote(3, 2), isTrue);
      expect(g.allVoted, isTrue);
      expect(g.reveal().points[3], 1);
    });

    test('an away player misses the prompt (no vote, 0) and votes again from the next', () {
      final g = game(3, prompts: 2);
      g.setAway(3, true);
      expect(g.vote(3, 1), isFalse);
      g.vote(1, 2);
      g.vote(2, 2);
      g.reveal();
      g.next();
      g.setAway(3, false);
      expect(g.vote(3, 1), isTrue);
    });
  });
}
