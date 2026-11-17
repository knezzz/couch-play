import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

BlefPack pack([int n = 12]) => BlefPack('p', 'P', [for (var i = 0; i < n; i++) BlefQuestion('q$i?', 'Istina $i', 'https://example.org')]);

BlefGame game(int n, {int questions = 3, int seed = 1, BlefPack? p}) =>
    BlefGame([for (var i = 1; i <= n; i++) i], p ?? pack(), questions: questions, random: Random(seed));

String truthOf(BlefGame g) => g.current.answer;

/// Everybody sends a different fake.
void allFake(BlefGame g) {
  for (final id in g.ids) {
    expect(g.submitFake(id, 'laž $id'), FakeResult.ok);
  }
}

void main() {
  group('folding', () {
    test('case, spaces and Croatian diacritics are ignored', () {
      expect(blefFold('  Čćšžđ ŠĐ '), 'ccszdsd');
      expect(blefFold('Manje od sat  vremena'), blefFold('manje od satvremena'));
      expect(blefFold('Đurđevac'), blefFold('durdevac'));
    });
  });

  group('pack', () {
    Map<String, dynamic> q(String a) => {'q': 'Koliko?', 'answer': a, 'source': 'https://example.org'};
    Map<String, dynamic> p(List<Map<String, dynamic>> qs) => {'id': 'x', 'title': 'T', 'questions': qs};
    List<Map<String, dynamic>> many([Map<String, dynamic>? extra]) => [for (var i = 0; i < 10; i++) q('a$i'), ?extra];

    test('parses the content format', () {
      final k = BlefPack.fromJson(p(many(q('x' * 40))));
      expect([k.id, k.title, k.questions.length], ['x', 'T', 11]);
      expect(k.questions.last.answer.length, 40);
    });

    test('rejects bad shapes, an answer over 40 characters, empty parts and fewer than 10 questions', () {
      final bad = <Map<String, dynamic>>[
        {'id': 'x', 'questions': many()},
        p(many(q('x' * 41))),
        p(many(q(''))),
        p(many({...q('a'), 'q': ''})),
        p(many({...q('a'), 'source': ''})),
        p(many({...q('a'), 'answer': 5})),
        p(many().take(9).toList()),
      ];
      for (final b in bad) {
        expect(() => BlefPack.fromJson(b), throwsA(isA<FormatException>()), reason: '$b');
      }
    });
  });

  group('writing', () {
    test('3 to 8 players; no question twice; seeded', () {
      expect(() => game(2), throwsArgumentError);
      expect(() => game(9), throwsArgumentError);
      final g = game(3, questions: 10);
      final seen = <String>{};
      while (g.phase != BlefPhase.over) {
        expect(seen.add(g.current.q), isTrue);
        allFake(g);
        g.closeWriting();
        g.reveal();
        g.next();
      }
      expect(seen.length, 10);
    });

    test('a fake is accepted once, trimmed, at most 40 characters, not empty', () {
      final g = game(3);
      expect(g.submitFake(1, '   '), FakeResult.empty);
      expect(g.submitFake(1, 'x' * 41), FakeResult.tooLong);
      expect(g.submitFake(1, '  Mjesec dana  '), FakeResult.ok);
      expect(g.submitFake(1, 'drugo'), FakeResult.alreadySent);
      expect(g.sent, {1});
      expect(g.submitFake(99, 'x'), FakeResult.closed);
    });

    test('the true answer is refused, whatever the case, spaces or diacritics', () {
      final g = game(3, p: BlefPack('p', 'P', [for (var i = 0; i < 12; i++) BlefQuestion('q$i', 'Đurđevac Čaj', 's')]));
      expect(g.submitFake(1, 'durdevac caj'), FakeResult.truth);
      expect(g.submitFake(1, '  ĐURĐEVAC  ČAJ'), FakeResult.truth);
      expect(g.sent, isEmpty, reason: 'a refused fake must be replaced');
      expect(g.submitFake(1, 'Đurđevac Čaj 2'), FakeResult.ok);
    });

    test('writing ends early when everyone present has sent; an away player is not waited for', () {
      final g = game(3);
      g.submitFake(1, 'a');
      g.submitFake(2, 'b');
      expect(g.allSent, isFalse);
      g.setAway(3, true);
      expect(g.allSent, isTrue);
    });

    test('nothing can be sent once picking has begun', () {
      final g = game(3);
      allFake(g);
      g.closeWriting();
      expect(g.submitFake(1, 'zakasnilo'), FakeResult.closed);
    });
  });

  group('the list', () {
    test('every fake plus the true answer, shuffled; identical fakes merge into one entry with all their writers', () {
      final g = game(4);
      g.submitFake(1, 'Dva sata');
      g.submitFake(2, 'dva  SATA'); // the same fake
      g.submitFake(3, 'Tri sata');
      g.closeWriting();
      final texts = [for (final e in g.entries) e.text];
      expect(texts.length, 3 + 0, reason: '2 fakes + the truth');
      expect(g.entries.where((e) => e.isTruth).length, 1);
      final merged = g.entries.firstWhere((e) => e.writers.length == 2);
      expect(merged.writers.toSet(), {1, 2});
      expect(g.entries.firstWhere((e) => e.isTruth).text, truthOf(g));
    });

    test('the list is shuffled: the truth is not always last', () {
      final pos = <int>{};
      for (var seed = 0; seed < 40; seed++) {
        final g = game(3, seed: seed);
        allFake(g);
        g.closeWriting();
        pos.add(g.entries.indexWhere((e) => e.isTruth));
      }
      expect(pos.length, greaterThan(1));
    });

    test('a phone sees the list without its own fake (and without a merged fake it wrote)', () {
      final g = game(4);
      g.submitFake(1, 'Dva sata');
      g.submitFake(2, 'dva sata');
      g.submitFake(3, 'Tri sata');
      g.closeWriting();
      final mine1 = g.optionsFor(1).map((i) => g.entries[i].text.toLowerCase()).toList();
      expect(mine1, isNot(contains('dva sata')));
      expect(mine1.length, 2);
      expect(g.optionsFor(2).length, 2);
      expect(g.optionsFor(3).map((i) => g.entries[i].text), isNot(contains('Tri sata')));
      // someone who sent nothing sees everything
      expect(g.optionsFor(4).length, 3);
    });

    test('nobody wrote a fake: the list is only the truth, so picking is skipped', () {
      final g = game(3);
      g.closeWriting();
      expect(g.phase, BlefPhase.reveal);
      expect(g.entries.single.isTruth, isTrue);
    });
  });

  group('picking and points', () {
    BlefGame picking({int n = 4}) {
      final g = game(n);
      for (final id in g.ids) {
        g.submitFake(id, 'laž $id');
      }
      g.closeWriting();
      return g;
    }

    int idxOfTruth(BlefGame g) => g.entries.indexWhere((e) => e.isTruth);
    int idxOfFake(BlefGame g, int writer) => g.entries.indexWhere((e) => e.writers.contains(writer));

    test('you cannot pick your own fake, an unknown entry, or twice; only in the picking phase', () {
      final g = picking();
      expect(g.pick(1, idxOfFake(g, 1)), isFalse);
      expect(g.pick(1, 99), isFalse);
      expect(g.pick(1, -1), isFalse);
      expect(g.pick(1, idxOfTruth(g)), isTrue);
      expect(g.pick(1, idxOfFake(g, 2)), isFalse, reason: 'the first pick stays');
      expect(g.pick(99, 0), isFalse);
      final h = game(3);
      expect(h.pick(1, 0), isFalse, reason: 'still writing');
    });

    test('the true answer is +1000 for each who found it; each fooled player is +500 for the writer', () {
      final g = picking();
      g.pick(1, idxOfTruth(g));
      g.pick(2, idxOfFake(g, 3)); // fooled by 3
      g.pick(3, idxOfFake(g, 4)); // fooled by 4
      g.pick(4, idxOfFake(g, 3)); // fooled by 3
      final r = g.reveal();
      expect(r.points, {1: 1000, 2: 0, 3: 1000, 4: 500});
      expect(g.totals, {1: 1000, 2: 0, 3: 1000, 4: 500});
    });

    test('an identical fake pays each of its writers for each player it fooled', () {
      final g = game(5);
      g.submitFake(1, 'Isto');
      g.submitFake(2, 'isto');
      g.submitFake(3, 'Nešto drugo');
      g.closeWriting();
      final same = g.entries.indexWhere((e) => e.writers.length == 2);
      g.pick(3, same);
      g.pick(4, same);
      g.pick(5, g.entries.indexWhere((e) => e.isTruth));
      final r = g.reveal();
      expect(r.points[1], 1000, reason: '2 fooled x 500');
      expect(r.points[2], 1000);
      expect(r.points[5], 1000);
      expect(r.points[3], 0);
    });

    test('not sending a fake, or picking nothing, scores 0 for that part', () {
      final g = game(3);
      g.submitFake(1, 'a');
      g.submitFake(2, 'b');
      g.closeWriting(); // 3 sent nothing
      g.pick(3, g.entries.indexWhere((e) => e.isTruth));
      final r = g.reveal();
      expect(r.points[3], 1000, reason: 'found the truth without a fake of their own');
      expect(r.points[1], 0);
      expect(r.points[2], 0);
    });

    test('picking ends early when everyone present has picked', () {
      final g = picking(n: 3);
      g.pick(1, idxOfTruth(g));
      g.pick(2, idxOfTruth(g));
      expect(g.allPicked, isFalse);
      g.setAway(3, true);
      expect(g.allPicked, isTrue);
    });

    test('the reveal goes through the fakes first and the true answer last, with who picked what', () {
      final g = picking();
      g.pick(1, idxOfTruth(g));
      g.pick(2, idxOfFake(g, 3));
      final r = g.reveal();
      expect(g.entries[r.order.last].isTruth, isTrue);
      expect(r.order.length, g.entries.length);
      expect(g.entries[idxOfFake(g, 3)].pickers, [2]);
      expect(g.entries[idxOfTruth(g)].pickers, [1]);
    });

    test('the totals become the game scores at the end', () {
      final g = game(3, questions: 2);
      for (var i = 0; i < 2; i++) {
        allFake(g);
        g.closeWriting();
        g.pick(1, g.entries.indexWhere((e) => e.isTruth));
        g.reveal();
        g.next();
      }
      expect(g.phase, BlefPhase.over);
      expect(g.sessionScores[1], 2000);
      expect(g.sessionScores[2], 0);
      expect(game(3).sessionScores, isEmpty);
    });
  });

  group('away', () {
    test('an away player misses the question: no fake, no pick, 0 points, back in the next', () {
      final g = game(3, questions: 2);
      g.setAway(3, true);
      expect(g.submitFake(3, 'x'), FakeResult.closed);
      g.submitFake(1, 'a');
      g.submitFake(2, 'b');
      g.closeWriting();
      expect(g.pick(3, 0), isFalse);
      g.pick(1, g.entries.indexWhere((e) => e.isTruth));
      g.reveal();
      expect(g.totals[3], 0);
      g.next();
      g.setAway(3, false);
      expect(g.submitFake(3, 'x'), FakeResult.ok);
    });
  });
}
