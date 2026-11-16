import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/strings.dart';
import 'package:tv/packs/pack_store.dart';
import 'package:tv/session/session.dart';

// Works from apps/tv or from the repo root.
final _dir = Directory('assets/packs').existsSync() ? Directory('assets/packs') : Directory('apps/tv/assets/packs');
List<File> _files() => _dir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('all_bundled_packs_valid', () {
    final files = _files();
    final ids = <String>{};
    var total = 0;
    for (final f in files) {
      final r = parsePack(f.readAsBytesSync());
      expect(r, isA<PackOk>(), reason: '${f.path}: ${r is PackError ? r.message : ''}');
      final p = (r as PackOk).pack;
      expect(ids.add(p.id), isTrue, reason: 'duplicate id ${p.id}');
      expect(p.id, startsWith('hr-'), reason: 'only Croatian packs are bundled');
      expect(p.questions.length, greaterThanOrEqualTo(30), reason: p.id);
      total += p.questions.length;
    }
    expect(ids, unorderedEquals(['hr-medimurje', 'hr-geografija', 'hr-povijest', 'hr-kultura-sport',
        'hr-opce-znanje', 'hr-zemljopis-svijeta', 'hr-znanost', 'hr-film-glazba', 'hr-zastave', 'hr-oblici',
        'hr-psihologija', 'hr-matematika', 'hr-memeovi', 'hr-fizika', 'hr-umjetnost']));
    expect(total, greaterThanOrEqualTo(300));
  });

  test('bundled packs load, are the default, and an upload cannot replace one', () async {
    final dir = Directory.systemTemp.createTempSync('packs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = await PackStore.load(bundled: [for (final f in _files()) f.readAsBytesSync()], userDir: dir);
    expect(store.infos.length, 15);

    final s = Session()..packStore = store;
    expect(s.packLookup(null)!.id, 'hr-opce-znanje');
    expect(store.infos.first.id, 'hr-opce-znanje');
    expect(s.packLookup('hr-zastave')!.images, isNotEmpty);

    final upload = Uint8List.fromList(utf8.encode(jsonEncode({
      'format': 1, 'id': 'hr-opce-znanje', 'title': 'Mine',
      'questions': [{'q': 'q', 'choices': ['a', 'b', 'c', 'd'], 'answer': 0}],
    })));
    expect(await store.add(upload), Strings.builtInPackId('hr-opce-znanje'));
    expect(store.get('hr-opce-znanje')!.title, 'Opće znanje');
  });
}

