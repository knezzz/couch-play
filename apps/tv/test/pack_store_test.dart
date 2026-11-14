import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/packs/pack_store.dart';

Uint8List pack(String id, {String title = 'T', int n = 2}) => Uint8List.fromList(utf8.encode(jsonEncode({
      'format': 1,
      'id': id,
      'title': title,
      'questions': [
        for (var i = 0; i < n; i++) {'q': 'q$i', 'choices': ['a', 'b', 'c', 'd'], 'answer': 0},
      ],
    })));

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('packs'));
  tearDown(() => dir.deleteSync(recursive: true));

  List<String> files() => dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  test('add_valid_pack_persists_and_reloads', () async {
    final s = await PackStore.load(bundled: [], userDir: dir);
    expect(await s.add(pack('flags', title: 'Flags', n: 3)), isNull);
    expect(files(), ['flags.pack']); // no .tmp left behind
    expect(s.infos, [const PackInfo('flags', 'Flags', 3)]);
    expect(s.get('flags')!.title, 'Flags');

    final again = await PackStore.load(bundled: [], userDir: dir);
    expect(again.infos, [const PackInfo('flags', 'Flags', 3)]);
    expect(again.get('flags')!.questions.length, 3);
    expect(again.get('nope'), isNull);
  });

  test('replacing a user pack with the same id is allowed', () async {
    final s = await PackStore.load(bundled: [], userDir: dir);
    expect(await s.add(pack('flags', title: 'Old')), isNull);
    expect(await s.add(pack('flags', title: 'New')), isNull);
    expect(s.infos.map((i) => i.title), ['New']);
    expect(files(), ['flags.pack']);
  });

  test('invalid_pack_rejected_nothing_written', () async {
    final s = await PackStore.load(bundled: [], userDir: dir);
    expect(await s.add(Uint8List.fromList(utf8.encode('nope'))), "The pack isn't valid JSON.");
    expect(files(), isEmpty);
    expect(s.infos, isEmpty);
  });

  test('cannot_shadow_bundled_id', () async {
    final s = await PackStore.load(bundled: [pack('x', title: 'Built-in')], userDir: dir);
    expect(await s.add(pack('x')), "A built-in pack already uses the id 'x'. Pick another id.");
    expect(files(), isEmpty);
    expect(s.get('x')!.title, 'Built-in');
    expect(s.infos.length, 1);
  });

  test('corrupt_file_on_disk_skipped_on_load', () async {
    File('${dir.path}/good.pack').writeAsBytesSync(pack('good'));
    File('${dir.path}/junk.pack').writeAsBytesSync([1, 2, 3]);
    File('${dir.path}/half.pack.tmp').writeAsBytesSync([9]); // a crashed write is not a pack
    final s = await PackStore.load(bundled: [Uint8List(0)], userDir: dir);
    expect(s.infos.map((i) => i.id), ['good']);
  });

  test('a missing user dir is created on first add', () async {
    final sub = Directory('${dir.path}/packs');
    final s = await PackStore.load(bundled: [], userDir: sub);
    expect(s.infos, isEmpty);
    expect(await s.add(pack('a')), isNull);
    expect(File('${sub.path}/a.pack').existsSync(), isTrue);
  });

  test('a file on disk cannot shadow a bundled id', () async {
    File('${dir.path}/x.pack').writeAsBytesSync(pack('x', title: 'Sneaky'));
    final s = await PackStore.load(bundled: [pack('x', title: 'Built-in')], userDir: dir);
    expect(s.get('x')!.title, 'Built-in');
    expect(s.infos.length, 1);
  });
}
