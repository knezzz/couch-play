import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

KolikoPack pack([int n = 20]) => KolikoPack('p', 'Paket', [for (var i = 0; i < n; i++) KolikoQuestion('q$i?', 100.0 + i, 'm', null, 'izvor')]);

KolikoGame game(int n, {int questions = 5, int seed = 1, KolikoPack? p}) =>
    KolikoGame([for (var i = 1; i <= n; i++) i], p ?? pack(), questions: questions, random: Random(seed));

/// The true answer of the current question.
double truth(KolikoGame g) => g.current.answer;

void main() {
  group('pack', () {
    Map<String, dynamic> q(Object? answer, {Object? unit = 'm', bool image = false}) => {
          'q': 'Koliko?',
          'answer': answer,
          'unit': unit,
          'source': 'https://example.org',
          if (image) 'image': 'a.jpg',
        };
    Map<String, dynamic> p(List<Map<String, dynamic>> qs) => {'id': 'x', 'title': 'T', 'questions': qs};
    List<Map<String, dynamic>> many([Map<String, dynamic>? extra]) =>
        [for (var i = 0; i < 15; i++) q(i * 2), ?extra];

    test('parses the content format', () {
      final k = KolikoPack.fromJson(p([...many(), q(3.5, unit: ''), q(0, image: true)]));
      expect([k.id, k.title, k.questions.length], ['x', 'T', 17]);
      expect(k.questions[15].answer, 3.5);
      expect(k.questions[15].unit, '');
      expect(k.questions[16].image, 'a.jpg');
      expect(k.questions[0].source, 'https://example.org');
    });

    test('rejects bad shapes, bad numbers, an empty question or source, and fewer than 15 questions', () {
      final bad = <Map<String, dynamic>>[
        {'id': 'x', 'questions': many()},
        {'id': 'x', 'title': 'T', 'questions': 'no'},
        p(many(q(-1))), // negative
        p(many(q('5'))), // not a number
        p(many(q(double.infinity))),
        p(many(q(5, unit: null))),
        p(many({...q(5), 'q': ''})),
        p(many({...q(5), 'q': '  '})),
        p(many({...q(5), 'source': ''})),
        p(many({...q(5), 'image': 5})),
        p(many().take(14).toList()),
      ];
      for (final b in bad) {
        expect(() => KolikoPack.fromJson(b), throwsA(isA<FormatException>()), reason: '$b');
      }
    });
  });

  group('the draw', () {
    test('2 to 8 players, no question twice, seeded', () {
      expect(() => game(1), throwsArgumentError);
      expect(() => game(9), throwsArgumentError);
      final g = game(3, questions: 10);
      final seen = <String>{};
      while (!g.over) {
        expect(seen.add(g.current.q), isTrue);
        g.reveal();
        g.next();
      }
      expect(seen.length, 10);
      expect(game(3, seed: 4).current.q, game(3, seed: 4).current.q);
    });

    test('never more questions than the pack has', () {
      final g = game(2, questions: 50, p: pack(15));
      expect(g.total, 15);
    });

    test('number and total', () {
      final g = game(2, questions: 5);
      expect([g.number, g.total], [1, 5]);
      g.reveal();
      g.next();
      expect(g.number, 2);
    });
  });

  group('answers', () {
    test('a number from a player counts once; the first one stays', () {
      final g = game(3);
      expect(g.answer(1, 5), isTrue);
      expect(g.answer(1, 9), isFalse);
      expect(g.answered, {1});
      expect(g.valueOf(1), 5);
    });

    test('negative, not-a-number, infinite and unknown players are refused', () {
      final g = game(3);
      expect(g.answer(1, -1), isFalse);
      expect(g.answer(1, double.nan), isFalse);
      expect(g.answer(1, double.infinity), isFalse);
      expect(g.answer(99, 3), isFalse);
      expect(g.answered, isEmpty);
      expect(g.answer(1, 0), isTrue, reason: 'zero is a fine answer');
    });

    test('no answers after the reveal', () {
      final g = game(3);
      g.reveal();
      expect(g.answer(1, 5), isFalse);
    });

    test('everyone answered: the question can end early; an away player is not waited for', () {
      final g = game(3);
      g.answer(1, 1);
      g.answer(2, 1);
      expect(g.allAnswered, isFalse);
      g.setAway(3, true);
      expect(g.allAnswered, isTrue);
      g.setAway(3, false);
      expect(g.allAnswered, isFalse, reason: 'back while the question is open: expected again');
    });
  });

  group('points per question', () {
    KolikoGame asked(Map<int, double> guesses, {int n = 5}) {
      final g = game(n);
      guesses.forEach(g.answer);
      return g;
    }

    test('ranked by distance: 1000, 750, 500, 250, the rest 0', () {
      final g = game(6);
      final t = truth(g);
      g.answer(1, t + 50);
      g.answer(2, t + 10);
      g.answer(3, t - 30);
      g.answer(4, t + 5);
      g.answer(5, t + 200);
      g.answer(6, t - 100);
      final r = g.reveal();
      expect({for (final e in r.entries) e.id: e.points}, {4: 1000, 2: 750, 3: 500, 1: 250, 6: 0, 5: 0});
      expect([for (final e in r.entries) e.id], [4, 2, 3, 1, 6, 5], reason: 'closest first');
      expect([for (final e in r.entries) e.rank], [1, 2, 3, 4, 5, 6]);
    });

    test('equal distances share the higher rank and its points; the next rank skips', () {
      final g = game(4);
      final t = truth(g);
      g.answer(1, t + 10);
      g.answer(2, t - 10); // same distance as 1
      g.answer(3, t + 40);
      g.answer(4, t + 90);
      final r = g.reveal();
      expect({for (final e in r.entries) e.id: e.rank}, {1: 1, 2: 1, 3: 3, 4: 4});
      expect({for (final e in r.entries) e.id: e.points}, {1: 1000, 2: 1000, 3: 500, 4: 250});
    });

    test('an exact hit adds 500', () {
      final g = game(3);
      final t = truth(g);
      g.answer(1, t);
      g.answer(2, t + 1);
      final r = g.reveal();
      final first = r.entries.first;
      expect([first.id, first.exact, first.points], [1, true, 1500]);
      expect(r.entries[1].exact, isFalse);
    });

    test('two exact hits both get 1500 and share rank 1', () {
      final g = game(3);
      final t = truth(g);
      g.answer(1, t);
      g.answer(2, t);
      g.answer(3, t + 5);
      final r = g.reveal();
      expect({for (final e in r.entries) e.id: e.points}, {1: 1500, 2: 1500, 3: 500});
    });

    test('no answer scores 0 and is listed without a rank', () {
      final g = game(3);
      g.answer(1, truth(g) + 5);
      final r = g.reveal();
      expect(r.entries.length, 3);
      final none = r.entries.where((e) => e.value == null).toList();
      expect(none.map((e) => e.id).toSet(), {2, 3});
      expect(none.every((e) => e.points == 0 && e.rank == null), isTrue);
    });

    test('the totals add up over the questions and become the game scores', () {
      final g = game(2, questions: 3);
      var bonus = 0;
      for (var i = 0; i < 3; i++) {
        g.answer(1, truth(g));
        g.answer(2, truth(g) + 3);
        g.reveal();
        bonus += 1500;
        g.next();
      }
      expect(g.totals[1], bonus);
      expect(g.totals[2], 3 * 750);
      expect(g.over, isTrue);
      expect(g.sessionScores, g.totals);
    });

    test('big and decimal numbers compare exactly enough', () {
      final p = KolikoPack('p', 'P', [for (var i = 0; i < 15; i++) KolikoQuestion('q$i', 1234567.5, '', null, 's')]);
      final g = game(2, p: p);
      g.answer(1, 1234567.5);
      g.answer(2, 1234568);
      final r = g.reveal();
      expect(r.entries.first.exact, isTrue);
      expect(r.entries.first.id, 1);
    });

    test('nobody answering scores nothing for anyone', () {
      final g = game(3);
      final r = g.reveal();
      expect(r.entries.every((e) => e.points == 0), isTrue);
      expect(g.totals.values.every((v) => v == 0), isTrue);
    });
  });

  group('away and back', () {
    test('a player who drops and comes back while the question is open can answer it', () {
      final g = game(3);
      g.setAway(3, true);
      expect(g.answer(3, 5), isFalse, reason: 'away: refused');
      g.setAway(3, false);
      expect(g.answer(3, truth(g)), isTrue);
      g.answer(1, 1);
      g.answer(2, 1);
      expect(g.allAnswered, isTrue);
      final r = g.reveal();
      expect(r.entries.first.id, 3);
      expect(g.totals[3], 1500);
    });

    test('while away they are not waited for; back, they are expected again', () {
      final g = game(3);
      g.answer(1, 1);
      g.answer(2, 1);
      g.setAway(3, true);
      expect(g.allAnswered, isTrue);
      g.setAway(3, false);
      expect(g.allAnswered, isFalse);
    });

    test('back after the reveal they simply wait for the next question', () {
      final g = game(3, questions: 2);
      g.setAway(3, true);
      g.answer(1, 1);
      g.answer(2, 1);
      g.reveal();
      g.setAway(3, false);
      expect(g.answer(3, 5), isFalse, reason: 'revealed');
      g.next();
      expect(g.answer(3, 5), isTrue);
    });
  });

  group('away', () {
    test('an away player scores 0 for what they miss, keeps their points, and answers the next question', () {
      final g = game(3, questions: 3);
      g.answer(1, truth(g));
      g.answer(2, truth(g) + 1);
      g.answer(3, truth(g) + 2);
      g.reveal();
      final before = g.totals[3]!;
      g.next();
      g.setAway(3, true);
      expect(g.answer(3, truth(g)), isFalse, reason: 'away: the answer does not count');
      g.answer(1, truth(g));
      g.reveal();
      expect(g.totals[3], before);
      g.next();
      g.setAway(3, false);
      expect(g.answer(3, truth(g)), isTrue);
    });
  });
}
