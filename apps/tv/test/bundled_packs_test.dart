import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all_bundled_packs_valid', () {
    final files = Directory('assets/packs').listSync().whereType<File>().toList();
    final ids = <String>{};
    var total = 0;
    for (final f in files) {
      final r = parsePack(f.readAsBytesSync());
      expect(r, isA<PackOk>(), reason: '${f.path}: ${r is PackError ? r.message : ''}');
      final p = (r as PackOk).pack;
      expect(ids.add(p.id), isTrue, reason: 'duplicate id ${p.id}');
      expect(p.questions.length, greaterThanOrEqualTo(p.id.startsWith('hr-') ? 30 : 40), reason: p.id);
      total += p.questions.length;
    }
    expect(ids, containsAll(['general', 'geography', 'science', 'film-music', 'flags', 'shapes',
        'hr-medimurje', 'hr-geografija', 'hr-povijest', 'hr-kultura-sport']));
    expect(total, greaterThanOrEqualTo(400));
  });
}
