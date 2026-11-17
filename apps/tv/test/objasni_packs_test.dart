import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Works from apps/tv or from the repo root.
final _dir = Directory('assets/objasni').existsSync() ? Directory('assets/objasni') : Directory('apps/tv/assets/objasni');

void main() {
  test('every_objasni_pack_parses_with_100_distinct_words', () {
    final files = _dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    expect(files, isNotEmpty);
    final ids = <String>{};
    for (final f in files) {
      final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final id = m['id'] as String;
      expect(ids.add(id), isTrue, reason: 'duplicate id $id');
      expect(f.uri.pathSegments.last, '$id.json');
      expect((m['title'] as String).trim(), isNotEmpty, reason: id);
      final words = (m['words'] as List).cast<String>();
      expect(words.length, greaterThanOrEqualTo(100), reason: id);
      final seen = <String>{};
      for (final w in words) {
        expect(w.trim(), isNotEmpty, reason: '$id: empty word');
        expect(w.length, lessThanOrEqualTo(24), reason: '$id: $w');
        expect(seen.add(w.toLowerCase()), isTrue, reason: '$id: $w twice');
      }
    }
  });
}
