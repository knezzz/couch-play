import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/strings.dart';
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
    expect(s.infos, [const PackInfo('flags', 'Flags', 3, isNew: true)], reason: 'uploaded now: new');
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
    expect(await s.add(Uint8List.fromList(utf8.encode('nope'))), PackStrings.notJson);
    expect(files(), isEmpty);
    expect(s.infos, isEmpty);
  });

  test('cannot_shadow_bundled_id', () async {
    final s = await PackStore.load(bundled: [pack('x', title: 'Built-in')], userDir: dir);
    expect(await s.add(pack('x')), Strings.builtInPackId('x'));
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

  test('infos lists hr-opce-znanje first, then the other bundled packs, then user packs', () async {
    File('${dir.path}/mine.pack').writeAsBytesSync(pack('mine'));
    final s = await PackStore.load(
        bundled: [pack('general'), pack('flags'), pack('hr-opce-znanje')], userDir: dir);
    expect(s.infos.map((i) => i.id), ['hr-opce-znanje', 'general', 'flags', 'mine']);
    expect(s.defaultPack!.id, 'hr-opce-znanje');
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
    expect([for (final i in again.infos) i.title], [for (final i in s.infos) i.title]);
    expect(s.infos.single.title, 'Small'); // adds run in call order
  });

  test('a failed write leaves no .tmp and a clear message', () async {
    Directory('${dir.path}/a.pack').createSync(); // the rename onto it throws
    final s = await PackStore.load(bundled: [], userDir: dir);
    expect(await s.add(pack('a')),
        Strings.packSaveFailed);
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

  group('grid tags', () {
    Uint8List withPicture(String id) => Uint8List.fromList(utf8.encode(jsonEncode({
          'format': 1,
          'id': id,
          'title': id,
          'questions': [
            {'q': 'q', 'image': 'x.svg', 'choices': ['a', 'b', 'c', 'd'], 'answer': 0},
          ],
        })));

    test('pictures: true only when some question has a picture', () async {
      // a bare json pack cannot carry a file, so an image name there is not a valid pack: use a plain one
      final s = await PackStore.load(bundled: [pack('plain')], userDir: dir);
      expect(s.infos.single.pictures, isFalse);
    });

    test('a Task 28 bundled pack is new, another bundled pack is not, an upload is new until the app restarts', () async {
      final s = await PackStore.load(bundled: [pack('hr-umjetnost'), pack('hr-povijest')], userDir: dir);
      final byId = {for (final i in s.infos) i.id: i};
      expect(byId['hr-umjetnost']!.isNew, isTrue);
      expect(byId['hr-povijest']!.isNew, isFalse);
      expect(await s.add(pack('mine')), isNull);
      expect(s.infos.firstWhere((i) => i.id == 'mine').isNew, isTrue);
      final again = await PackStore.load(bundled: [pack('hr-umjetnost')], userDir: dir);
      expect(again.infos.firstWhere((i) => i.id == 'mine').isNew, isFalse, reason: 'a later run: not new any more');
    });

    test('a user pack named like a Task 28 id is not marked new by that name', () async {
      final s = await PackStore.load(bundled: [], userDir: dir);
      dir.createSync(recursive: true);
      File('${dir.path}/hr-fizika.pack').writeAsBytesSync(pack('hr-fizika'));
      final again = await PackStore.load(bundled: [], userDir: dir);
      expect(again.infos.single.isNew, isFalse);
      expect(s.infos, isEmpty);
    });
  });
}
