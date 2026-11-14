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

  List<String> files() => dir.listSync().map((e) => e.path.split('/').last).toList()..sort();

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

  test('infos lists general first, then the other bundled packs, then user packs', () async {
    File('${dir.path}/mine.pack').writeAsBytesSync(pack('mine'));
    final s = await PackStore.load(
        bundled: [pack('film-music'), pack('flags'), pack('general')], userDir: dir);
    expect(s.infos.map((i) => i.id), ['general', 'film-music', 'flags', 'mine']);
    expect(s.defaultPack!.id, 'general');
  });

  test('an old user pack with a bundled id is skipped at load', () async {
    File('${dir.path}/general.pack').writeAsBytesSync(pack('general', title: 'Old upload'));
    final s = await PackStore.load(bundled: [pack('general', title: 'Built-in')], userDir: dir);
    expect(s.infos.map((i) => i.title), ['Built-in']);
    expect(s.get('general')!.title, 'Built-in');
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

  test('concurrent adds of one id leave disk and memory in agreement', () async {
    final s = await PackStore.load(bundled: [], userDir: dir);
    // A big pack and a small one: unserialized writes to one .tmp can mix.
    final results = await Future.wait([
      s.add(pack('a', title: 'Big', n: 3000)),
      s.add(pack('a', title: 'Small', n: 1)),
    ]);
    expect(results, [null, null]);
    expect(files(), ['a.pack']);
    final again = await PackStore.load(bundled: [], userDir: dir);
    expect(again.infos, s.infos);
    expect(s.infos.single.title, 'Small'); // adds run in call order
  });

  test('a failed write leaves no .tmp and a clear message', () async {
    Directory('${dir.path}/a.pack').createSync(); // the rename onto it throws
    final s = await PackStore.load(bundled: [], userDir: dir);
    expect(await s.add(pack('a')),
        "The TV couldn't save the pack. Free some space on the TV, then try again.");
    expect(files(), ['a.pack']); // only the directory we made
    expect(s.infos, isEmpty);
    // and the next add still works
    expect(await s.add(pack('b')), isNull);
  });

  test('a listing error keeps the bundled packs', () async {
    final sealed = Directory('${dir.path}/sealed')..createSync();
    Process.runSync('chmod', ['000', sealed.path]);
    addTearDown(() => Process.runSync('chmod', ['755', sealed.path]));
    final s = await PackStore.load(bundled: [pack('x')], userDir: sealed);
    expect(s.infos.map((i) => i.id), ['x']);
  });
}
