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
      'img/dup.svg': Uint8List.fromList([3]),
    });
    final u = unionQuiz('all', 'Svi', [a, b]);
    expect(u.questions.map((e) => e.q), ['Q1', 'Q2', 'Q3']);
    expect(u.questions[0].image, 'a/img/x.svg');
    expect(u.questions[2].image, 'b/img/x.svg');
    expect(u.images['a/img/x.svg'], [1]);
    expect(u.images['b/img/x.svg'], [2]);
    expect(u.images.containsKey('b/img/dup.svg'), isFalse, reason: 'its question was a repeat');
  });
}
