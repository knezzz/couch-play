import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Works from apps/tv or from the repo root.
final _dir = Directory('assets/kaosvi').existsSync() ? Directory('assets/kaosvi') : Directory('apps/tv/assets/kaosvi');

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  test('Kao svi: five packs of 60+ distinct open questions', () {
    final files = _dir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
    final ids = <String>{};
    final seen = <String>{};
    for (final f in files) {
      final p = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      expect(p['id'], startsWith('kaosvi-'), reason: f.path);
      expect(f.path, endsWith('${p['id']}.json'));
      expect((p['title'] as String).isNotEmpty, isTrue);
      final qs = (p['questions'] as List).cast<String>();
      expect(qs.length, greaterThanOrEqualTo(60), reason: p['id']);
      for (final q in qs) {
        expect(q.trim().isNotEmpty && (q.endsWith('?') || q.endsWith('.')), isTrue, reason: q);
        expect(seen.add(_norm(q)), isTrue, reason: 'repeat: $q');
      }
      ids.add(p['id'] as String);
    }
    expect(ids, {'kaosvi-opcenito', 'kaosvi-hrana', 'kaosvi-hrvatska', 'kaosvi-medimurje', 'kaosvi-pop'});
  });
}
