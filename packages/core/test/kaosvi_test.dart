import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

KaosviPack pack([int n = 30]) => KaosviPack('p', 'P', [for (var i = 0; i < n; i++) 'Navedi nešto $i.']);

KaosviGame game(int n, {int questions = 12, int target = 8, int seed = 1, KaosviPack? p}) =>
    KaosviGame([for (var i = 1; i <= n; i++) i], p ?? pack(), questions: questions, target: target, random: Random(seed));

/// Everyone answers [answers] (player i gets answers[i-1]); then the merge phase is closed and revealed.
KaosviReveal play(KaosviGame g, List<String> answers) {
  for (var i = 0; i < answers.length; i++) {
    g.answer(i + 1, answers[i]);
  }
  g.closeAnswering();
  g.finishMerge();
  return g.lastReveal!;
}

void main() {
  group('folding', () {
    test('case, surrounding spaces, repeated inner spaces and Croatian diacritics are ignored', () {
      expect(kaosviFold('Jabuka'), kaosviFold(' jabuka '));
      expect(kaosviFold('JABUKA'), kaosviFold('jabuka'));
      expect(kaosviFold('Šećer'), kaosviFold('secer'));
      expect(kaosviFold('Đurđevac'), kaosviFold('durdevac'));
      expect(kaosviFold('ne   znam'), kaosviFold('NE ZNAM'));
      expect(kaosviFold('ne znam'), isNot(kaosviFold('neznam')), reason: 'inner words are not glued');
      expect(kaosviFold('jabuka'), isNot(kaosviFold('jabuke')));
    });
  });

  group('pack', () {
    List<String> many(int n) => [for (var i = 0; i < n; i++) 'p$i'];
    test('parses {"id","title","questions"}', () {
      final p = KaosviPack.fromJson({'id': 'x', 'title': 'T', 'questions': many(20)});
      expect([p.id, p.title, p.questions.length], ['x', 'T', 20]);
    });

    test('rejects bad shapes, empty questions, duplicates (any case) and fewer than 20', () {
      final bad = <Map<String, dynamic>>[
        {'id': 'x', 'questions': many(20)},
        {'id': 'x', 'title': 'T', 'questions': 'no'},
        {'id': 'x', 'title': 'T', 'questions': [...many(20), ' ']},
        {'id': 'x', 'title': 'T', 'questions': [...many(20), 4]},
        {'id': 'x', 'title': 'T', 'questions': [...many(20), 'P1']},
        {'id': 'x', 'title': 'T', 'questions': many(19)},
      ];
      for (final b in bad) {
        expect(() => KaosviPack.fromJson(b), throwsA(isA<FormatException>()), reason: '$b');
      }
    });
  });

  group('answers', () {
    test('3 to 8 players; no question twice; never more than the pack', () {
      expect(() => game(2), throwsArgumentError);
      expect(() => game(9), throwsArgumentError);
      final g = game(3, questions: 30, target: 1000);
      final seen = <String>{};
      while (g.phase != KaosviPhase.over) {
        expect(seen.add(g.current), isTrue);
        play(g, ['a', 'b', 'c']);
        g.next();
      }
      expect(seen.length, 30);
      expect(game(3, questions: 99).total, 30);
    });

    test('one answer each, trimmed, 1 to 30 characters (characters, not UTF-16 units)', () {
      final g = game(3);
      expect(g.answer(1, '   '), KaosviAnswerResult.empty);
      expect(g.answer(1, 'x' * 31), KaosviAnswerResult.tooLong);
      expect(g.answer(1, '😀' * 30), KaosviAnswerResult.ok);
      expect(g.answer(1, 'drugo'), KaosviAnswerResult.alreadySent);
      expect(g.answer(2, '😀' * 31), KaosviAnswerResult.tooLong);
      expect(g.answer(99, 'x'), KaosviAnswerResult.closed);
      expect(g.sent, {1});
    });

    test('everybody present answered ends the answering early; an away player is not waited for', () {
      final g = game(3);
      g.answer(1, 'a');
      g.answer(2, 'b');
      expect(g.allSent, isFalse);
      g.setAway(3, true);
      expect(g.allSent, isTrue);
      g.setAway(3, false);
      expect(g.allSent, isFalse, reason: 'back while open: expected again');
      expect(g.answer(3, 'c'), KaosviAnswerResult.ok);
    });

    test('nothing after the answering is closed', () {
      final g = game(3);
      g.closeAnswering();
      expect(g.answer(1, 'a'), KaosviAnswerResult.closed);
    });
  });

  group('groups and merging', () {
    test('equal answers after folding are one group, largest first, with the first writer\'s spelling', () {
      final g = game(5);
      for (final e in {1: 'Jabuka', 2: ' jabuka ', 3: 'Kruška', 4: 'JABUKA', 5: 'Šljiva'}.entries) {
        g.answer(e.key, e.value);
      }
      g.closeAnswering();
      expect(g.phase, KaosviPhase.merging);
      final gs = g.groups;
      expect(gs.length, 3);
      expect(gs.first.members.toSet(), {1, 2, 4});
      expect(gs.first.text, 'Jabuka');
      expect(gs.map((x) => x.members.length), [3, 1, 1]);
    });

    test('the host merges two groups: one group with both texts\' members, the larger text', () {
      final g = game(5);
      g.answer(1, 'jabuka');
      g.answer(2, 'jabuka');
      g.answer(3, 'jabuke');
      g.answer(4, 'kruška');
      g.answer(5, 'kruške');
      g.closeAnswering();
      final a = g.groups.firstWhere((x) => x.text == 'jabuka').id;
      final b = g.groups.firstWhere((x) => x.text == 'jabuke').id;
      expect(g.merge(a, b), isTrue);
      expect(g.groups.length, 3);
      final merged = g.groups.first;
      expect(merged.members.toSet(), {1, 2, 3});
      expect(merged.text, 'jabuka');
      // merging again is possible
      final k1 = g.groups.firstWhere((x) => x.text == 'kruška').id;
      final k2 = g.groups.firstWhere((x) => x.text == 'kruške').id;
      expect(g.merge(k1, k2), isTrue);
      expect(g.groups.length, 2);
    });

    test('bad merges are refused: the same group, an unknown one, outside the merge phase', () {
      final g = game(3);
      g.answer(1, 'a');
      g.answer(2, 'b');
      expect(g.merge(0, 1), isFalse, reason: 'still answering');
      g.closeAnswering();
      final id = g.groups.first.id;
      expect(g.merge(id, id), isFalse);
      expect(g.merge(id, 999), isFalse);
      g.finishMerge();
      expect(g.merge(g.groups[0].id, g.groups[1].id), isFalse, reason: 'revealed');
    });

    test('the merge view shows answers only: the groups carry texts and ids, nothing says who wrote them', () {
      final g = game(3);
      g.answer(1, 'a');
      g.answer(2, 'b');
      g.closeAnswering();
      expect(g.mergeView.map((e) => e.text).toSet(), {'a', 'b'});
      expect(g.mergeView.first.toJson().keys.toSet(), {'id', 'text'});
    });

    test('nobody answered: no merge phase, straight to the reveal with no points', () {
      final g = game(3);
      g.closeAnswering();
      expect(g.phase, KaosviPhase.reveal);
      expect(g.lastReveal!.points.values.every((v) => v == 0), isTrue);
    });
  });

  group('points', () {
    test('every player in the single largest group scores 1', () {
      final g = game(5);
      final r = play(g, ['a', 'a', 'a', 'b', 'c']);
      expect(r.points, {1: 1, 2: 1, 3: 1, 4: 0, 5: 0});
      expect(r.largestTie, isFalse);
    });

    test('a tie for largest scores nobody', () {
      final g = game(6);
      final r = play(g, ['a', 'a', 'b', 'b', 'c', 'c']);
      expect(r.points.values.every((v) => v == 0), isTrue);
      expect(r.largestTie, isTrue);
    });

    test('a lone unique answer while everyone else is in groups of 2+ loses 1 (not below 0)', () {
      final g = game(5, target: 100);
      // first, with 0 points: stays at 0
      var r = play(g, ['a', 'a', 'b', 'b', 'z']);
      expect(r.lone, 5);
      expect(g.totals[5], 0, reason: 'not below 0');
      g.next();
      // 5 earns a point, then loses one
      r = play(g, ['a', 'a', 'z', 'a', 'a']);
      expect(g.totals[5], 1);
      g.next();
      r = play(g, ['a', 'a', 'b', 'b', 'z']);
      expect(g.totals[5], 0);
      expect(r.points[5], -1, reason: 'the question itself cost one');
    });

    test('the lone rule fires together with a largest group: a, a, a, b-lone', () {
      final g = game(4);
      final r = play(g, ['a', 'a', 'a', 'z']);
      expect(r.points, {1: 1, 2: 1, 3: 1, 4: 0}, reason: '0 now, so nothing to lose');
      expect(r.lone, 4);
    });

    test('no lone penalty when two players are alone, or when someone else is alone too', () {
      final g = game(5);
      final r = play(g, ['a', 'a', 'a', 'y', 'z']);
      expect(r.lone, isNull);
    });

    test('a single answerer is not a herd: nothing is scored, nobody loses', () {
      final g = game(4);
      final r = play(g, ['a']);
      expect(r.points.values.every((v) => v == 0), isTrue);
      expect(r.lone, isNull);
    });

    test('everybody different: a tie of singletons, nobody scores and nobody is the lone one', () {
      final g = game(4);
      final r = play(g, ['a', 'b', 'c', 'd']);
      expect(r.points.values.every((v) => v == 0), isTrue);
      expect(r.lone, isNull);
    });

    test('players who did not answer are not counted in "everyone else"', () {
      final g = game(5);
      final r = play(g, ['a', 'a', 'z']); // 4 and 5 sent nothing
      expect(r.lone, 3);
    });

    test('a merge changes the herd: jabuka + jabuke beat the rest', () {
      final g = game(5);
      g.answer(1, 'jabuka');
      g.answer(2, 'jabuke');
      g.answer(3, 'kruška');
      g.answer(4, 'kruška');
      g.answer(5, 'kruška');
      g.closeAnswering();
      expect(g.merge(g.groups.firstWhere((x) => x.text == 'jabuka').id, g.groups.firstWhere((x) => x.text == 'jabuke').id), isTrue);
      g.finishMerge();
      expect(g.lastReveal!.points, {1: 0, 2: 0, 3: 1, 4: 1, 5: 1});
      expect(g.lastReveal!.groups.map((x) => x.members.length), [3, 2]);
    });

    test('the reveal lists the groups largest first and each member\'s group', () {
      final g = game(5);
      final r = play(g, ['a', 'b', 'b', 'c', 'b']);
      expect(r.groups.first.text, 'b');
      expect(r.groupOf(2)!.members.toSet(), {2, 3, 5});
      expect(r.groupOf(1)!.text, 'a');
    });
  });

  group('the end', () {
    test('the first to the target ends the game after that question; everyone is placed', () {
      final g = game(3, target: 2, questions: 12);
      play(g, ['a', 'a', 'b']);
      g.next();
      expect(g.phase, KaosviPhase.answering);
      play(g, ['a', 'a', 'b']);
      g.next();
      expect(g.phase, KaosviPhase.over);
      expect(g.sessionScores, {1: 2, 2: 2, 3: 0});
    });

    test('or after the number of questions', () {
      final g = game(3, target: 100, questions: 3);
      for (var i = 0; i < 3; i++) {
        play(g, ['a', 'b', 'c']);
        g.next();
      }
      expect(g.phase, KaosviPhase.over);
      expect(g.sessionScores.values.every((v) => v == 0), isTrue);
    });

    test('no session scores before the end', () {
      expect(game(3).sessionScores, isEmpty);
    });
  });

  group('away', () {
    test('an away player is not in the question; keeps points; back while it is open they can answer', () {
      final g = game(4);
      g.setAway(4, true);
      expect(g.answer(4, 'x'), KaosviAnswerResult.closed);
      g.setAway(4, false);
      expect(g.answer(4, 'x'), KaosviAnswerResult.ok);
    });
  });
}
