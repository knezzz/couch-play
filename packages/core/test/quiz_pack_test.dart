import 'dart:convert';
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
    expect(err(Uint8List(5 * 1024 * 1024 + 1)), 'The pack is larger than 5 MB.');
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
    expect(err(Uint8List.fromList(utf8.encode('nope'))), "The pack isn't valid JSON.");
    expect(err(Uint8List.fromList([0xff, 0xfe])), "The pack isn't valid JSON.");
  });

  test('format', () {
    expect(err(json(pack(format: 2))), 'Unsupported pack format. Use "format": 1.');
  });

  test('id', () {
    for (final id in ['Upper', 'has space', '', 'a' * 41, 7]) {
      expect(err(json(pack(id: id))), 'The pack id must be lowercase letters, digits or dashes.');
    }
  });

  test('title and questions', () {
    expect(err(json(pack(title: ''))), 'The pack needs a title.');
    expect(err(json(pack(questions: []))), 'The pack needs at least one question.');
  });

  test('question errors are numbered', () {
    expect(err(json(pack(questions: [q(), q(text: '')]))), 'Question 2: the question text is empty.');
    expect(err(json(pack(questions: [q(choices: ['a', 'b', 'c'])]))),
        'Question 1: needs exactly 4 non-empty choices.');
    expect(err(json(pack(questions: [q(choices: ['a', 'b', 'c', ''])]))),
        'Question 1: needs exactly 4 non-empty choices.');
    expect(err(json(pack(questions: [q(answer: 4)]))), 'Question 1: answer must be 0, 1, 2 or 3.');
    expect(err(json(pack(questions: [q(answer: 'x')]))), 'Question 1: answer must be 0, 1, 2 or 3.');
  });

  test('image path must be relative .svg without ..', () {
    for (final p in ['../x.svg', 'a/../x.svg', '/x.svg', 'x.png']) {
      expect(err(zip({'p.json': json(pack(questions: [q(image: p)])), 'x.svg': [1]})),
          'Question 1: image $p must be a relative .svg path.');
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
        'Question 1: image flags/x.svg is missing from the zip.');
  });

  test('image in a bare json is missing', () {
    expect(err(json(pack(questions: [q(image: 'flags/x.svg')]))),
        'Question 1: image flags/x.svg is missing from the zip.');
  });

  test('zip needs exactly one root json', () {
    const m = 'The zip must contain one .json pack file.';
    expect(err(zip({'a.json': json(pack()), 'b.json': json(pack())})), m);
    expect(err(zip({'x.svg': [1]})), m);
    expect(err(zip({'sub/a.json': json(pack())})), m);
  });

  test('zip bomb: unzipped over 20 MB', () {
    final big = List<int>.filled(21 * 1024 * 1024, 0);
    final z = zip({'p.json': json(pack(questions: [q(image: 'a.svg')])), 'a.svg': big});
    expect(z.length, lessThan(5 * 1024 * 1024)); // it passes the raw limit
    expect(err(z), 'The pack is too large when unzipped.');
  });

  test('many small entries add up', () {
    final f = <String, List<int>>{'p.json': json(pack())};
    for (var i = 0; i < 11; i++) {
      f['f$i.bin'] = List<int>.filled(2 * 1024 * 1024, 0);
    }
    expect(err(zip(f)), 'The pack is too large when unzipped.');
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
}
