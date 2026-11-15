import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

// Works from apps/tv or from the repo root.
final _dir = Directory('assets/packs').existsSync() ? Directory('assets/packs') : Directory('apps/tv/assets/packs');

String _normal(String q) => q
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .replaceAll(RegExp(r'[\s.,;:!?…]+$'), '');

/// One line per pair of questions that repeat, within a pack or across packs.
/// A question with a picture only repeats another with the same picture.
List<String> findRepeats(List<QuizPack> packs) {
  final seen = <String, String>{};
  final out = <String>[];
  for (final p in packs) {
    for (var i = 0; i < p.questions.length; i++) {
      final q = p.questions[i];
      final img = q.image;
      final pic = img == null ? '' : base64.encode(p.images[img] ?? utf8.encode(img));
      final key = '${_normal(q.q)}|$pic';
      final where = '${p.id} #${i + 1}';
      final first = seen[key];
      if (first == null) {
        seen[key] = where;
      } else {
        out.add('"${q.q}": $first and $where');
      }
    }
  }
  return out;
}

QuizPack _pack(String id, List<(String, String?)> qs, [Map<String, List<int>> images = const {}]) =>
    QuizPack(id, id, [for (final (q, image) in qs) PackQuestion(q, image, const ['a', 'b', 'c', 'd'], 0)],
        {for (final e in images.entries) e.key: Uint8List.fromList(e.value)});

void main() {
  test('a_repeat_is_found_within_and_across_packs_and_images_decide_for_picture_questions', () {
    final one = _pack('one', [('Koji je glavni grad?', null), ('  koji JE glavni   grad ', null), ('Čija je ovo zastava?', 'a.svg'), ('Čija je ovo zastava?', 'b.svg')],
        {'a.svg': [1], 'b.svg': [2]});
    final two = _pack('two', [('Koji je glavni grad?!', null), ('Čija je ovo zastava?', 'z.svg')], {'z.svg': [1]});
    final r = findRepeats([one, two]);
    expect(r, hasLength(3), reason: r.join('\n'));
    expect(r[0], contains('one #1 and one #2'));
    expect(r[1], contains('one #1 and two #1'));
    expect(r[2], contains('one #3 and two #2'), reason: 'same picture bytes under another name');
  });

  test('no_bundled_pack_repeats_a_question', () {
    final packs = [
      for (final f in _dir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path)))
        (parsePack(f.readAsBytesSync()) as PackOk).pack,
    ];
    final r = findRepeats(packs);
    expect(r, isEmpty, reason: '${r.length} repeated question(s):\n${r.join('\n')}');
  });
}
