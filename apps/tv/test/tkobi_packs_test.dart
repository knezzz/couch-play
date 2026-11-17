import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Works from apps/tv or from the repo root.
final _dir = Directory('assets/tkobi').existsSync() ? Directory('assets/tkobi') : Directory('apps/tv/assets/tkobi');

void main() {
  test('every_tkobi_pack_parses_with_30_distinct_prompts', () {
    final files = _dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    final ids = <String>{};
    for (final f in files) {
      final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final id = m['id'] as String;
      expect(ids.add(id), isTrue, reason: 'duplicate id $id');
      expect(f.uri.pathSegments.last, '$id.json');
      expect((m['title'] as String).trim(), isNotEmpty, reason: id);
      final prompts = (m['prompts'] as List).cast<String>();
      expect(prompts.length, greaterThanOrEqualTo(30), reason: id);
      final seen = <String>{};
      for (final p in prompts) {
        expect(p.trim(), isNotEmpty, reason: '$id: empty prompt');
        expect(seen.add(p), isTrue, reason: '$id: "$p" twice');
      }
    }
    expect(ids, containsAll(['tkobi-blago', 'tkobi-ljuto']));
  });
}
