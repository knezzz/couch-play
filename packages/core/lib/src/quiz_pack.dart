import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const _maxPack = 5 * 1024 * 1024;
const _maxUnzipped = 20 * 1024 * 1024;

class PackQuestion {
  const PackQuestion(this.q, this.image, this.choices, this.answer);
  final String q;
  final String? image;
  final List<String> choices;
  final int answer;
}

class QuizPack {
  const QuizPack(this.id, this.title, this.questions, this.images);
  final String id;
  final String title;
  final List<PackQuestion> questions;

  /// Only the SVGs a question refers to, by their path in the zip.
  final Map<String, Uint8List> images;
}

sealed class PackResult {
  const PackResult();
}

class PackOk extends PackResult {
  const PackOk(this.pack);
  final QuizPack pack;
}

class PackError extends PackResult {
  const PackError(this.message);
  final String message;
}

/// Validates an uploaded pack (a bare .json or a .zip). Never throws.
PackResult parsePack(Uint8List bytes) {
  try {
    return _parse(bytes);
  } catch (_) {
    return const PackError("The pack couldn't be read.");
  }
}

const _tooBig = PackError('The pack is too large when unzipped.');

PackResult _parse(Uint8List bytes) {
  if (bytes.length > _maxPack) return const PackError('The pack is larger than 5 MB.');

  final isZip = bytes.length >= 4 &&
      bytes[0] == 0x50 && bytes[1] == 0x4b && bytes[2] == 3 && bytes[3] == 4;
  Map<String, ArchiveFile> files = {};
  Uint8List jsonBytes = bytes;
  var unzipped = 0;

  if (isZip) {
    final entries = ZipDecoder().decodeBytes(bytes).files.where((f) => f.isFile).toList();
    // A zip64 size of 0xFFFF...F reads as -1, which turns the decoder's cap off,
    // so a negative or oversized entry is refused before anything is summed.
    if (entries.any((f) => f.size < 0 || f.size > _maxUnzipped)) return _tooBig;
    // Declared sizes first: nothing is inflated until their sum is in bounds.
    // The decoder stops each entry at its declared size, so a lying header
    // can't expand past it; a size mismatch is checked in _read.
    if (entries.fold<int>(0, (s, f) => s + f.size) > _maxUnzipped) return _tooBig;
    files = {for (final f in entries) f.name: f};
    final jsons = entries.where((f) => !f.name.contains('/') && f.name.endsWith('.json')).toList();
    if (jsons.length != 1) return const PackError('The zip must contain one .json pack file.');
    jsonBytes = _read(jsons.single) ?? Uint8List(0);
    unzipped = jsonBytes.length;
  }

  final Object? root;
  try {
    root = jsonDecode(utf8.decode(jsonBytes));
  } catch (_) {
    return const PackError("The pack isn't valid JSON.");
  }
  if (root is! Map) return const PackError("The pack isn't valid JSON.");

  if (root['format'] != 1) return const PackError('Unsupported pack format. Use "format": 1.');
  final id = root['id'];
  if (id is! String || !RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(id)) {
    return const PackError('The pack id must be lowercase letters, digits or dashes.');
  }
  final title = root['title'];
  if (title is! String || title.trim().isEmpty) return const PackError('The pack needs a title.');
  if (title.runes.length > 60) return const PackError('The pack title must be 60 characters or fewer.');
  final raw = root['questions'];
  if (raw is! List || raw.isEmpty) return const PackError('The pack needs at least one question.');

  final questions = <PackQuestion>[];
  final images = <String, Uint8List>{};
  for (var i = 0; i < raw.length; i++) {
    final n = i + 1;
    final m = raw[i];
    if (m is! Map) return PackError('Question $n: must be an object with q, choices and answer.');
    final text = m['q'];
    if (text is! String || text.trim().isEmpty) {
      return PackError('Question $n: the question text is empty.');
    }
    final choices = m['choices'];
    if (choices is! List ||
        choices.length != 4 ||
        choices.any((c) => c is! String || c.trim().isEmpty)) {
      return PackError('Question $n: needs exactly 4 non-empty choices.');
    }
    final answer = m['answer'];
    if (answer is! int || answer < 0 || answer > 3) {
      return PackError('Question $n: answer must be 0, 1, 2 or 3.');
    }
    final image = m['image'];
    if (image != null) {
      if (image is! String ||
          !image.endsWith('.svg') ||
          image.startsWith('/') ||
          image.contains('\\') ||
          image.split('/').contains('..')) {
        return PackError('Question $n: image $image must be a relative .svg path.');
      }
      final f = files[image];
      if (f == null) return PackError('Question $n: image $image is missing from the zip.');
      if (!images.containsKey(image)) {
        final b = _read(f);
        if (b == null) return PackError('Question $n: image $image is missing from the zip.');
        unzipped += b.length;
        if (unzipped > _maxUnzipped) return _tooBig;
        images[image] = b;
      }
    }
    questions.add(PackQuestion(text, image as String?, [for (final c in choices) c as String], answer));
  }
  return PackOk(QuizPack(id, title, questions, images));
}

/// Null when the entry doesn't inflate to the size it declares.
Uint8List? _read(ArchiveFile f) {
  final b = f.readBytes();
  return b != null && b.length == f.size ? b : null;
}
