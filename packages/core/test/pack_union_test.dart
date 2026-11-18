import 'dart:math';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one pack comes back unchanged; several merge in order without repeats (case and spacing ignored)', () {
    final a = ObjasniPack('a', 'A', ['Pas', 'Mačka', 'Kuća']);
    final b = ObjasniPack('b', 'B', ['pas ', 'Auto', 'MAČKA', 'Ptica']);
    expect(identical(unionObjasni('x', 'X', [a]), a), isTrue);
    final u = unionObjasni('all', 'Svi', [a, b]);
    expect([u.id, u.title], ['all', 'Svi']);
    expect(u.words, ['Pas', 'Mačka', 'Kuća', 'Auto', 'Ptica']);
    expect(unionObjasni('x', 'X', [b, a]).words, ['pas ', 'Auto', 'MAČKA', 'Ptica', 'Kuća'], reason: 'the first copy wins');
  });

  test('uljez: a pair is the same pair in either order', () {
    final a = UljezPack('a', 'A', [const WordPair('Pas', 'Mačka'), const WordPair('x1', 'y1')]);
    final b = UljezPack('b', 'B', [const WordPair('mačka', 'pas'), const WordPair('x2', 'y2')]);
    final u = unionUljez('all', 'Svi', [a, b]);
    expect(u.pairs.length, 3);
    expect(u.pairs.first.a, 'Pas');
  });

  test('koliko, blef, tko bi, kao svi: the same question in two packs is drawn once', () {
    KolikoQuestion k(String q) => KolikoQuestion(q, 1, '', null, 's');
    expect(
        unionKoliko('u', 'U', [
          KolikoPack('a', 'A', [k('Koliko?'), k('Drugo')]),
          KolikoPack('b', 'B', [k('koliko?'), k('Treće')])
        ]).questions.map((q) => q.q),
        ['Koliko?', 'Drugo', 'Treće']);
    BlefQuestion bq(String q) => BlefQuestion(q, 'a', 's');
    expect(
        unionBlef('u', 'U', [
          BlefPack('a', 'A', [bq('Q1'), bq('Q2')]),
          BlefPack('b', 'B', [bq('q2 '), bq('Q3')])
        ]).questions.length,
        3);
    expect(unionTkobi('u', 'U', [TkobiPack('a', 'A', ['p', 'q']), TkobiPack('b', 'B', ['Q', 'r'])]).prompts, ['p', 'q', 'r']);
    expect(unionKaosvi('u', 'U', [KaosviPack('a', 'A', ['p', 'q']), KaosviPack('b', 'B', ['P', 'r'])]).questions, ['p', 'q', 'r']);
  });

  test('quiz: pictures are renamed per pack so two packs may use the same file name; unused pictures are not carried', () {
    PackQuestion q(String t, String? img) => PackQuestion(t, img, const ['1', '2'], 0);
    final a = QuizPack('a', 'A', [q('Q1', 'img/x.svg'), q('Q2', null)], {'img/x.svg': Uint8List.fromList([1])});
    final b = QuizPack('b', 'B', [q('Q3', 'img/x.svg'), q('q1', 'img/dup.svg')], {
      'img/x.svg': Uint8List.fromList([2]),
      'img/dup.svg': Uint8List.fromList([1]), // the same picture as a's Q1: a true repeat
    });
    final u = unionQuiz('all', 'Svi', [a, b]);
    expect(u.questions.map((e) => e.q), ['Q1', 'Q2', 'Q3']);
    expect(u.questions[0].image, 'a/img/x.svg');
    expect(u.questions[2].image, 'b/img/x.svg');
    expect(u.images['a/img/x.svg'], [1]);
    expect(u.images['b/img/x.svg'], [2]);
    expect(u.images.containsKey('b/img/dup.svg'), isFalse, reason: 'its question was a repeat');
  });

  test('quiz: picture questions that share a text are different questions (11 "Koji je ovo grad?" survive)', () {
    PackQuestion city(int i, {int answer = 0}) =>
        PackQuestion('Koji je ovo grad?', 'g$i.svg', ['Grad $i', 'Drugi'], answer);
    final a = QuizPack('geo', 'Geo', [for (var i = 0; i < 11; i++) city(i)], {
      for (var i = 0; i < 11; i++) 'g$i.svg': Uint8List.fromList([i, i + 1])
    });
    final b = QuizPack('other', 'Other', [const PackQuestion('Nešto?', null, ['x', 'y'], 0)], {});
    final u = unionQuiz('all', 'Svi', [a, b]);
    expect(u.questions.where((e) => e.q == 'Koji je ovo grad?').length, 11);
    expect(u.questions.length, 12);
    // the same text with another right answer is another question too, without pictures
    final c = QuizPack('c', 'C', [const PackQuestion('Isto?', null, ['a', 'b'], 0)], {});
    final d = QuizPack('d', 'D', [const PackQuestion('Isto?', null, ['a', 'b'], 1), const PackQuestion('isto? ', null, ['a', 'b'], 0)], {});
    expect(unionQuiz('all', 'Svi', [c, d]).questions.length, 2, reason: 'the true repeat (same answer) is dropped, the other answer stays');
  });

  test('uljez: in a union the guess decoys come from the word\'s own pack', () {
    UljezPack themed(String id) => UljezPack(id, id, [for (var i = 0; i < 6; i++) WordPair('$id-a$i', '$id-b$i')]);
    final union = unionUljez('all', 'Svi', [themed('hrana'), themed('zivotinje'), themed('gradovi')]);
    expect(union.pairs.length, 18);
    for (var seed = 0; seed < 60; seed++) {
      final g = UljezGame([1, 2, 3, 4], union, random: Random(seed));
      for (var i = 0; i < g.order.length; i++) {
        g.nextTurn();
      }
      g.startVote();
      final imp = [for (final i in g.ids) if (g.isImpostor(i)) i].single;
      for (final i in g.ids) {
        g.vote(i, i == imp ? null : imp);
      }
      g.resolveVote();
      expect(g.phase, UljezPhase.guess);
      final theme = g.villageWord.split('-').first;
      for (final w in g.guessOptions) {
        expect(w.split('-').first, theme, reason: 'seed $seed: $w is off the theme of ${g.villageWord}');
      }
      expect(g.guessOptions.toSet().length, 4);
    }
  });

  test('uljez: a source with too few distinct words tops the decoys up from the others; a plain pack is unchanged', () {
    final small = UljezPack('s', 's', [const WordPair('s-a0', 's-b0'), const WordPair('s-a1', 's-b0b')]);
    final big = UljezPack('b', 'b', [for (var i = 0; i < 6; i++) WordPair('b-a$i', 'b-b$i')]);
    final union = UljezPack('u', 'u', [
      for (final p in small.pairs) WordPair(p.a, p.b, source: 's'),
      for (final p in big.pairs) WordPair(p.a, p.b, source: 'b'),
    ]);
    final g = UljezGame([1, 2, 3], union, random: Random(3));
    for (var i = 0; i < g.order.length; i++) {
      g.nextTurn();
    }
    g.startVote();
    final imp = [for (final i in g.ids) if (g.isImpostor(i)) i].single;
    for (final i in g.ids) {
      g.vote(i, i == imp ? null : imp);
    }
    g.resolveVote();
    expect(g.guessOptions.length, 4);
    expect(g.guessOptions.toSet().length, 4);
  });
}
