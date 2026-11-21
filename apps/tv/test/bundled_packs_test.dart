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
        'hr-psihologija', 'hr-matematika', 'hr-memeovi', 'hr-fizika', 'hr-umjetnost', 'hr-ljudsko-tijelo',
        'hr-hrana-pice', 'hr-sport-svijet', 'hr-zivotinje', 'hr-jezik',
        'hr-pop-kultura', 'hr-glazba-2000']));
    expect(total, greaterThanOrEqualTo(300));
  });

  test('the union of all bundled packs keeps the picture questions (task 46 must-fix: 226 used to become 104)', () {
    final packs = [for (final f in _files()) (parsePack(f.readAsBytesSync()) as PackOk).pack];
    final u = unionQuiz('all', 'Svi', packs);
    int pics(Iterable<PackQuestion> qs) => qs.where((q) => q.image != null).length;
    final sum = packs.fold<int>(0, (n, p) => n + pics(p.questions));
    expect(sum, greaterThan(200));
    expect(pics(u.questions), greaterThanOrEqualTo(sum - 5), reason: 'only true cross-pack repeats may drop');
    expect(u.questions.where((q) => q.q == 'Koji je ovo grad?').length,
        greaterThanOrEqualTo(packs.firstWhere((p) => p.id == 'hr-geografija').questions.where((q) => q.q == 'Koji je ovo grad?').length));
    for (final q in u.questions) {
      if (q.image != null) expect(u.images.containsKey(q.image), isTrue, reason: q.q);
    }
  });

  test('bundled packs load, are the default, and an upload cannot replace one', () async {
    final dir = Directory.systemTemp.createTempSync('packs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = await PackStore.load(bundled: [for (final f in _files()) f.readAsBytesSync()], userDir: dir);
    expect(store.infos.length, 22);

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

  test('the pack grid tags: pictures where a question has one, new for the Task 28 packs', () async {
    final store = await PackStore.load(
        bundled: [for (final f in _files()) f.readAsBytesSync()], userDir: Directory.systemTemp.createTempSync('nopacks'));
    final byId = {for (final i in store.infos) i.id: i};
    for (final id in PackStore.newBundledIds) {
      expect(byId[id]!.isNew, isTrue, reason: id);
    }
    expect(byId['hr-povijest']!.isNew, isFalse);
    expect(byId['hr-umjetnost']!.pictures, isTrue, reason: 'the art pack is all pictures');
    for (final e in byId.entries) {
      final pack = store.get(e.key)!;
      expect(e.value.pictures, pack.questions.any((q) => q.image != null), reason: e.key);
    }
    // Every bundled pack has pictures since 2026-11-20, so an upload covers the no-pictures tag.
    await store.add(Uint8List.fromList(utf8.encode(jsonEncode({
      'format': 1, 'id': 'bez-slika', 'title': 'Bez slika',
      'questions': [{'q': 'q', 'choices': ['a', 'b', 'c', 'd'], 'answer': 0}],
    }))));
    expect(store.infos.firstWhere((i) => i.id == 'bez-slika').pictures, isFalse);
  });
}
