import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Works from apps/tv or from the repo root.
final _dir = Directory('assets/uljez').existsSync() ? Directory('assets/uljez') : Directory('apps/tv/assets/uljez');

void main() {
  test('every_uljez_pack_parses_with_40_pairs_of_short_distinct_words', () {
    final files = _dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    expect(files.length, greaterThanOrEqualTo(6));
    final ids = <String>{};
    for (final f in files) {
      final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final id = m['id'] as String;
      expect(ids.add(id), isTrue, reason: 'duplicate id $id');
      expect(f.uri.pathSegments.last, '$id.json');
      expect((m['title'] as String).trim(), isNotEmpty, reason: id);
      final pairs = (m['pairs'] as List).cast<List<dynamic>>();
      expect(pairs.length, greaterThanOrEqualTo(40), reason: id);
      final words = <String>{};
      for (final p in pairs) {
        expect(p.length, 2, reason: '$id: $p');
        for (final w in p.cast<String>()) {
          expect(w.trim(), isNotEmpty, reason: '$id: empty word');
          expect(w.length, lessThanOrEqualTo(24), reason: '$id: $w');
          expect(words.add(w), isTrue, reason: '$id: $w twice');
        }
      }
    }
  });
}
