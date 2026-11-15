import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> q({String? image, Object? choices, Object? answer = 0, Object? text = 'Which?'}) => {
      'q': text,
      if (image != null) 'image': image,
      'choices': choices ?? ['a', 'b', 'c', 'd'],
      'answer': answer,
    };

Map<String, Object?> pack({Object? format = 1, Object? id = 'world-flags', Object? title = 'T', Object? questions}) => {
      'format': format,
      'id': id,
      'title': title,
      'questions': questions ?? [q()],
    };

Uint8List json(Object o) => Uint8List.fromList(utf8.encode(jsonEncode(o)));

Uint8List zip(Map<String, List<int>> files) {
  final a = Archive();
  files.forEach((n, b) => a.addFile(ArchiveFile(n, b.length, b)));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

String err(Uint8List b) => (parsePack(b) as PackError).message;

void main() {
  test('valid zip with an svg gives PackOk', () {
    final svg = utf8.encode('<svg/>');
    final r = parsePack(zip({
      'pack.json': json(pack(questions: [q(image: 'flags/japan.svg')])),
      'flags/japan.svg': svg,
    }));
    final p = (r as PackOk).pack;
    expect(p.id, 'world-flags');
    expect(p.questions.single.image, 'flags/japan.svg');
    expect(p.images['flags/japan.svg'], svg);
  });

  test('a bare json pack is fine', () {
    expect(parsePack(json(pack())), isA<PackOk>());
  });

  test('over 5 MB', () {
    expect(err(Uint8List(5 * 1024 * 1024 + 1)), PackStrings.tooBig);
  });

  test('garbage never throws', () {
    for (final b in [
      Uint8List(0),
      Uint8List.fromList([0xff, 0xfe, 0x00]),
      Uint8List.fromList([0x50, 0x4b, 0x03, 0x04, 1, 2, 3]),
      json([1, 2]),
      json('x'),
    ]) {
      expect(parsePack(b), isA<PackError>());
    }
  });

  test('not json', () {
    expect(err(Uint8List.fromList(utf8.encode('nope'))), PackStrings.notJson);
    expect(err(Uint8List.fromList([0xff, 0xfe])), PackStrings.notJson);
  });

  test('format', () {
    expect(err(json(pack(format: 2))), PackStrings.badFormat);
  });

  test('id', () {
    for (final id in ['Upper', 'has space', '', 'a' * 41, 7]) {
      expect(err(json(pack(id: id))), PackStrings.badId);
    }
  });

  test('title and questions', () {
    expect(err(json(pack(title: ''))), PackStrings.needTitle);
    expect(err(json(pack(questions: []))), PackStrings.needQuestion);
  });

  test('question errors are numbered', () {
    expect(err(json(pack(questions: [q(), q(text: '')]))), PackStrings.emptyQuestion(2));
    expect(err(json(pack(questions: [q(choices: ['a', 'b', 'c'])]))),
        PackStrings.badChoices(1));
    expect(err(json(pack(questions: [q(choices: ['a', 'b', 'c', ''])]))),
        PackStrings.badChoices(1));
    expect(err(json(pack(questions: [q(answer: 4)]))), PackStrings.badAnswer(1));
    expect(err(json(pack(questions: [q(answer: 'x')]))), PackStrings.badAnswer(1));
  });

  test('photos load: jpg, jpeg, png, webp, any case, bytes kept', () {
    final bytes = [for (final n in ['a.jpg', 'b.JPEG', 'c/d.png', 'e.WebP']) n];
    final r = parsePack(zip({
      'p.json': json(pack(questions: [for (final n in bytes) q(image: n)])),
      for (final n in bytes) n: [n.length],
    }));
    expect(r, isA<PackOk>(), reason: r is PackError ? r.message : '');
    expect((r as PackOk).pack.images.keys, bytes);
  });

  test('image path must be relative .svg, .jpg, .jpeg, .png or .webp without ..', () {
    for (final p in ['../x.svg', 'a/../x.svg', '/x.svg', '../x.jpg', '/x.png', 'x.gif', 'x.bmp', 'x', 'x.jpg.exe']) {
      expect(err(zip({'p.json': json(pack(questions: [q(image: p)])), 'x.svg': [1]})),
          PackStrings.badImage(1, p));
    }
  });

  test('zip-slip entry is never exposed', () {
    final r = parsePack(zip({
      'p.json': json(pack(questions: [q(image: 'ok.svg')])),
      'ok.svg': [1],
      '../evil.svg': [2],
    }));
    expect((r as PackOk).pack.images.keys, ['ok.svg']);
  });

  test('missing image', () {
    expect(err(zip({'p.json': json(pack(questions: [q(image: 'flags/x.svg')]))})),
        PackStrings.missingImage(1, 'flags/x.svg'));
  });

  test('image in a bare json is missing', () {
    expect(err(json(pack(questions: [q(image: 'flags/x.svg')]))),
        PackStrings.missingImage(1, 'flags/x.svg'));
  });

  test('zip needs exactly one root json', () {
    const m = PackStrings.zipNeedsJson;
    expect(err(zip({'a.json': json(pack()), 'b.json': json(pack())})), m);
    expect(err(zip({'x.svg': [1]})), m);
    expect(err(zip({'sub/a.json': json(pack())})), m);
  });

  test('zip bomb: unzipped over 20 MB', () {
    final big = List<int>.filled(21 * 1024 * 1024, 0);
    final z = zip({'p.json': json(pack(questions: [q(image: 'a.svg')])), 'a.svg': big});
    expect(z.length, lessThan(5 * 1024 * 1024)); // it passes the raw limit
    expect(err(z), PackStrings.unzippedTooBig);
  });

  test('many small entries add up', () {
    final f = <String, List<int>>{'p.json': json(pack())};
    for (var i = 0; i < 11; i++) {
      f['f$i.bin'] = List<int>.filled(2 * 1024 * 1024, 0);
    }
    expect(err(zip(f)), PackStrings.unzippedTooBig);
  });

  test('an entry that lies about its size is rejected', () {
    final z = zip({
      'p.json': json(pack(questions: [q(image: 'a.svg')])),
      'a.svg': List<int>.filled(3 * 1024 * 1024, 0),
    });
    // Patch the declared uncompressed size to 100 in every local and central header.
    final d = ByteData.view(z.buffer);
    for (var i = 0; i < z.length - 28; i++) {
      final sig = d.getUint32(i, Endian.little);
      if (sig == 0x04034b50) d.setUint32(i + 22, 100, Endian.little);
      if (sig == 0x02014b50) d.setUint32(i + 24, 100, Endian.little);
    }
    expect(parsePack(z), isA<PackError>());
  });

  test('zip64 size of -1 does not bypass the unzip cap', () {
    // One entry whose zip64 extra field declares 0xFFFFFFFFFFFFFFFF (read as -1)
    // over 30 MB of deflated spaces.
    final name = utf8.encode('pack.json');
    final data = ZLibCodec(raw: true, level: 9).encode(List<int>.filled(30 * 1024 * 1024, 0x20));
    final extra = ByteData(12)
      ..setUint16(0, 1, Endian.little)
      ..setUint16(2, 8, Endian.little)
      ..setUint64(4, -1, Endian.little);
    Uint8List header(bool central) {
      final h = ByteData(central ? 46 : 30);
      var o = 0;
      void u32(int v) { h.setUint32(o, v, Endian.little); o += 4; }
      void u16(int v) { h.setUint16(o, v, Endian.little); o += 2; }
      u32(central ? 0x02014b50 : 0x04034b50);
      if (central) u16(45);
      u16(45); u16(0); u16(8); u16(0); u16(0);
      u32(0); u32(data.length); u32(0xFFFFFFFF);
      u16(name.length); u16(extra.lengthInBytes);
      if (central) { u16(0); u16(0); u16(0); u32(0); u32(0); }
      return h.buffer.asUint8List();
    }
    final local = [...header(false), ...name, ...extra.buffer.asUint8List(), ...data];
    final central = [...header(true), ...name, ...extra.buffer.asUint8List()];
    final eocd = ByteData(22)
      ..setUint32(0, 0x06054b50, Endian.little)
      ..setUint16(8, 1, Endian.little)
      ..setUint16(10, 1, Endian.little)
      ..setUint32(12, central.length, Endian.little)
      ..setUint32(16, local.length, Endian.little);
    final z = Uint8List.fromList([...local, ...central, ...eocd.buffer.asUint8List()]);
    expect(err(z), PackStrings.unzippedTooBig);
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('a leading BOM is ignored', () {
    final b = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...json(pack())]);
    expect(parsePack(b), isA<PackOk>());
  });

  test('a question that is not an object', () {
    expect(err(json(pack(questions: ['x']))),
        PackStrings.notObject(1));
  });

  test('title is capped at 60 characters', () {
    expect(parsePack(json(pack(title: 'a' * 60))), isA<PackOk>());
    expect(err(json(pack(title: 'a' * 61))), PackStrings.titleTooLong);
    // Characters, not UTF-16 units: 60 emoji are fine.
    expect(parsePack(json(pack(title: '😀' * 60))), isA<PackOk>());
  });

  test('a damaged zip is unreadable', () {
    final good = zip({'p.json': json(pack())});
    final cut = Uint8List.fromList(good.sublist(0, good.length ~/ 2));
    expect(err(cut), anyOf(PackStrings.unreadable, PackStrings.zipNeedsJson));
  });
}
