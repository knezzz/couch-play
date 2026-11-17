import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Works from apps/tv or from the repo root.
Directory _dir(String name) =>
    Directory('assets/$name').existsSync() ? Directory('assets/$name') : Directory('apps/tv/assets/$name');

List<Map<String, dynamic>> _packs(String name) => (_dir(name).listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path)))
    .map((f) => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)
    .toList();

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim();

void main() {
  test('Koliko? packs: 30+ questions each, numeric non-negative answers, a source, no repeats', () {
    final packs = _packs('koliko');
    expect(packs.length, greaterThanOrEqualTo(2));
    final seen = <String>{};
    for (final p in packs) {
      expect(p['id'], startsWith('hr-koliko-'));
      expect(p['title'], isA<String>());
      final qs = (p['questions'] as List).cast<Map<String, dynamic>>();
      expect(qs.length, greaterThanOrEqualTo(30), reason: p['id']);
      for (final q in qs) {
        expect(q['q'], isA<String>(), reason: '$q');
        expect(q['answer'], isA<num>(), reason: q['q']);
        expect(q['answer'] as num, greaterThanOrEqualTo(0), reason: q['q']);
        expect(q['unit'], isA<String>(), reason: q['q']);
        expect((q['source'] as String).isNotEmpty, isTrue, reason: q['q']);
        expect(seen.add(_norm(q['q'])), isTrue, reason: 'repeat: ${q['q']}');
      }
    }
  });

  test('Blef packs: 30+ true facts each, answers up to 40 characters, a source, no repeats', () {
    final packs = _packs('blef');
    expect(packs.length, greaterThanOrEqualTo(2));
    final seen = <String>{};
    for (final p in packs) {
      expect(p['id'], startsWith('hr-blef-'));
      final qs = (p['questions'] as List).cast<Map<String, dynamic>>();
      expect(qs.length, greaterThanOrEqualTo(30), reason: p['id']);
      for (final q in qs) {
        final a = q['answer'] as String;
        expect(a.trim().isNotEmpty && a.length <= 40, isTrue, reason: '${q['q']}: $a');
        expect((q['source'] as String).startsWith('http'), isTrue, reason: q['q']);
        expect(seen.add(_norm(q['q'])), isTrue, reason: 'repeat: ${q['q']}');
      }
    }
  });
}
