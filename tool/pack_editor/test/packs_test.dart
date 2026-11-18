import 'dart:convert';
import 'dart:io';

import 'package:core/src/quiz_pack.dart';
import 'package:core/strings.dart';
import 'package:pack_editor/packs.dart';
import 'package:test/test.dart';

const _real = '../..'; // the repo root, seen from tool/pack_editor

void _copy(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final e in from.listSync()) {
    final name = e.path.split('/').last;
    if (e is Directory) {
      _copy(e, Directory('${to.path}/$name'));
    } else if (e is File) {
      e.copySync('${to.path}/$name');
    }
  }
}

/// A scratch repo with only the pack folders; the real files are never written.
late String root;

setUp_() {
  final d = Directory.systemTemp.createTempSync('pack_editor_test');
  root = d.path;
  _copy(Directory('$_real/tool/packs'), Directory('$root/tool/packs'));
  for (final g in ['packs', 'objasni', 'koliko', 'blef', 'tkobi', 'kaosvi', 'uljez']) {
    _copy(Directory('$_real/apps/tv/assets/$g'), Directory('$root/apps/tv/assets/$g'));
  }
}

bool _same(List<int> a, List<int> b) => a.length == b.length && Iterable.generate(a.length).every((i) => a[i] == b[i]);

void main() {
  setUp(setUp_);
  tearDown(() => Directory(root).deleteSync(recursive: true));

  String read(String rel) => File('$root/$rel').readAsStringSync();

  test('lists_every_game', () {
    final refs = listPacks(root);
    expect(refs.where((r) => r.game == Game.kviz), hasLength(16));
    for (final g in Game.values.skip(1)) {
      expect(refs.where((r) => r.game == g), isNotEmpty, reason: g.name);
    }
    expect(refs.firstWhere((r) => r.id == 'hr-oblici').count, 50);
  });

  test('unedited_save_keeps_every_file_byte_identical', () {
    final changed = <String>[];
    for (final r in listPacks(root)) {
      final p = loadPack(root, r.game, r.id);
      final before = File(r.path).readAsBytesSync();
      final res = savePack(root, r.game, r.id, p.json, p.stamp);
      if (res is! SaveOk) {
        changed.add('${r.game.name}/${r.id}: ${(res as SaveError).message}');
      } else if (!_same(File(r.path).readAsBytesSync(), before)) {
        changed.add('${r.game.name}/${r.id}');
      }
    }
    expect(changed, isEmpty);
  });

  test('editing_one_question_changes_one_line', () {
    final p = loadPack(root, Game.kviz, 'hr-oblici');
    final before = read('tool/packs/hr-oblici/hr-oblici.json').split('\n');
    (p.json['questions'] as List)[3]['answer'] = 0;
    expect(savePack(root, Game.kviz, 'hr-oblici', p.json, p.stamp), isA<SaveOk>());
    final after = read('tool/packs/hr-oblici/hr-oblici.json').split('\n');
    expect(after, hasLength(before.length));
    expect([for (var i = 0; i < after.length; i++) if (after[i] != before[i]) i], hasLength(1));
  });

  test('sources_skip_is_reported', () {
    final p = loadPack(root, Game.kviz, 'hr-fizika');
    final f = File('$root/tool/packs/hr-fizika.sources.md');
    f.writeAsStringSync('${f.readAsStringSync()}\n999. extra\n');
    (p.json['questions'] as List).removeAt(0);
    final r = savePack(root, Game.kviz, 'hr-fizika', p.json, p.stamp, deleted: [1]);
    expect((r as SaveOk).note, sourcesNote);
  });

  test('save_roundtrip_unchanged', () {
    final p = loadPack(root, Game.kviz, 'hr-oblici');
    expect(savePack(root, Game.kviz, 'hr-oblici', p.json, p.stamp), isA<SaveOk>());
    final after = jsonDecode(read('tool/packs/hr-oblici/hr-oblici.json'));
    expect(after, p.json);
  });

  test('croatian_text_survives_as_utf8', () {
    const text = 'Što je „čćđšž“?';
    final p = loadPack(root, Game.kviz, 'hr-oblici');
    (p.json['questions'] as List)[0]['q'] = text;
    expect(savePack(root, Game.kviz, 'hr-oblici', p.json, p.stamp), isA<SaveOk>());
    final raw = read('tool/packs/hr-oblici/hr-oblici.json');
    expect(raw, contains(text));
    expect(raw, isNot(contains(r'\u')));
    expect(loadPack(root, Game.kviz, 'hr-oblici').json['questions'][0]['q'], text);
  });

  test('save_rejects_invalid', () {
    final p = loadPack(root, Game.kviz, 'hr-oblici');
    final before = File(p.ref.path).readAsBytesSync();
    (p.json['questions'] as List)[0]['answer'] = 4;
    final r = savePack(root, Game.kviz, 'hr-oblici', p.json, p.stamp);
    expect(r, isA<SaveError>());
    expect((r as SaveError).message, PackStrings.badAnswer(1));
    expect(File(p.ref.path).readAsBytesSync(), before);
  });

  test('save_rejects_too_few_koliko', () {
    final p = loadPack(root, Game.koliko, 'hr-koliko-godine');
    final before = File(p.ref.path).readAsBytesSync();
    (p.json['questions'] as List).removeRange(14, (p.json['questions'] as List).length);
    expect(savePack(root, Game.koliko, 'hr-koliko-godine', p.json, p.stamp), isA<SaveError>());
    expect(File(p.ref.path).readAsBytesSync(), before);
  });

  test('save_rejects_quiz_below_30', () {
    final p = loadPack(root, Game.kviz, 'hr-oblici');
    final before = File(p.ref.path).readAsBytesSync();
    (p.json['questions'] as List).removeRange(29, 50);
    final r = savePack(root, Game.kviz, 'hr-oblici', p.json, p.stamp);
    expect(r, isA<SaveError>());
    expect(File(p.ref.path).readAsBytesSync(), before);
  });

  test('save_stale', () {
    final p = loadPack(root, Game.blef, 'hr-blef-priroda');
    final f = File(p.ref.path)..writeAsStringSync('{"someone":"else"}');
    expect(savePack(root, Game.blef, 'hr-blef-priroda', p.json, p.stamp), isA<SaveStale>());
    expect(f.readAsStringSync(), '{"someone":"else"}');
  });

  test('save_stale_same_length_new_mtime', () {
    final p = loadPack(root, Game.uljez, 'uljez-hrana');
    final f = File(p.ref.path);
    f.writeAsBytesSync(f.readAsBytesSync());
    f.setLastModifiedSync(DateTime(2001));
    expect(savePack(root, Game.uljez, 'uljez-hrana', p.json, p.stamp), isA<SaveStale>());
  });

  test('save_rebuilds_one_zip_and_keeps_pictures', () {
    final zip = File('$root/apps/tv/assets/packs/hr-fizika.zip');
    final other = File('$root/apps/tv/assets/packs/hr-oblici.zip');
    zip.setLastModifiedSync(DateTime(2001));
    other.setLastModifiedSync(DateTime(2001));
    final p = loadPack(root, Game.kviz, 'hr-fizika');
    final withImage = (p.json['questions'] as List).where((q) => q['image'] != null).length;
    expect(withImage, greaterThan(0));
    expect(savePack(root, Game.kviz, 'hr-fizika', p.json, p.stamp), isA<SaveOk>());
    expect(zip.lastModifiedSync().isAfter(DateTime(2002)), isTrue);
    expect(other.lastModifiedSync(), DateTime(2001));
    final r = parsePack(zip.readAsBytesSync());
    expect(r, isA<PackOk>());
    expect((r as PackOk).pack.images, isNotEmpty);
    expect(r.pack.questions.where((q) => q.image != null), hasLength(withImage));
  });

  test('text_pack_is_copied', () {
    final p = loadPack(root, Game.kviz, 'hr-opce-znanje');
    (p.json['questions'] as List)[0]['q'] = 'Izmijenjeno?';
    expect(savePack(root, Game.kviz, 'hr-opce-znanje', p.json, p.stamp), isA<SaveOk>());
    expect(read('apps/tv/assets/packs/hr-opce-znanje.json'), read('tool/packs/hr-opce-znanje.json'));
  });

  test('sources_follow_a_delete', () {
    final p = loadPack(root, Game.kviz, 'hr-fizika');
    final qs = p.json['questions'] as List;
    qs.removeAt(1);
    expect(savePack(root, Game.kviz, 'hr-fizika', p.json, p.stamp, deleted: [2]), isA<SaveOk>());
    final lines = read('tool/packs/hr-fizika.sources.md').split('\n');
    expect(lines.where((l) => RegExp(r'^\d+\. ').hasMatch(l)), hasLength(qs.length));
    expect(lines.any((l) => l.startsWith('2. standard gravity')), isTrue);
  });

  test('renumber_sources', () {
    const text = '# x: sources\n\nSome header text.\n- a bullet\n\n1. a\n2. b\n3. c\n4. d\n\nend note\n';
    expect(renumberSources(text, [2], 1),
        '# x: sources\n\nSome header text.\n- a bullet\n\n1. a\n2. c\n3. d\n4. (added in the editor, no source yet)\n\nend note\n');
  });
}
