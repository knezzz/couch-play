import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/packs/party_packs.dart';

/// The bundled Kao svi packs go through the real parser.
void main() {
  test('every file in assets/kaosvi parses with KaosviPack.fromJson (60+ questions, no repeats across packs)', () {
    final dir = Directory('assets/kaosvi').existsSync() ? Directory('assets/kaosvi') : Directory('apps/tv/assets/kaosvi');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    expect(files.length, 5);
    final seen = <String>{};
    for (final f in files) {
      final p = KaosviPack.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
      expect(p.questions.length, greaterThanOrEqualTo(60), reason: p.id);
      for (final q in p.questions) {
        expect(seen.add(kaosviFold(q)), isTrue, reason: 'repeated across packs: $q');
      }
    }
  });

  testWidgets('the loader finds the five bundled packs', (t) async {
    final packs = await loadKaosviPacks(rootBundle);
    expect(packs.map((p) => p.id).toSet(), {'kaosvi-opcenito', 'kaosvi-hrana', 'kaosvi-hrvatska', 'kaosvi-medimurje', 'kaosvi-pop'});
  });
}
