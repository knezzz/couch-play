import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/src/blef.dart';
import 'package:core/src/koliko.dart';
import 'package:core/src/objasni.dart';
import 'package:core/src/quiz_pack.dart';
import 'package:core/src/tkobi.dart';
import 'package:core/src/uljez.dart';

enum Game { kviz, objasni, koliko, blef, tkobi, uljez }

const staleMessage = 'Paket se promijenio, učitaj ponovno.';
const _minQuiz = 30; // same floor as apps/tv/test/bundled_packs_test.dart

class PackRef {
  PackRef(this.game, this.id, this.title, this.path, this.count);
  final Game game;
  final String id;
  final String title;
  final String path;
  final int count;
}

class LoadedPack {
  LoadedPack(this.ref, this.json, this.stamp);
  final PackRef ref;
  final Map<String, dynamic> json;
  final String stamp;
}

sealed class SaveResult {
  const SaveResult();
}

const sourcesNote = 'izvori nisu prenumerirani';

class SaveOk extends SaveResult {
  const SaveOk(this.stamp, {this.note});
  final String stamp;

  /// Something the page should show next to "saved"; null when all is as expected.
  final String? note;
}

class SaveError extends SaveResult {
  const SaveError(this.message);
  final String message;
}

class SaveStale extends SaveError {
  const SaveStale() : super(staleMessage);
}

String _stamp(File f) => '${f.lastModifiedSync().millisecondsSinceEpoch}-${f.lengthSync()}';

String _listKey(Game g) => switch (g) {
      Game.objasni => 'words',
      Game.tkobi => 'prompts',
      Game.uljez => 'pairs',
      _ => 'questions',
    };

String _base(String path) => path.split('/').last;

PackRef _ref(Game game, File f) {
  final id = _base(f.path).replaceFirst(RegExp(r'\.json$'), '');
  final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final list = j[_listKey(game)];
  return PackRef(game, id, '${j['title'] ?? id}', f.path, list is List ? list.length : 0);
}

List<PackRef> listPacks(String repoRoot) {
  final refs = <PackRef>[];
  final quiz = Directory('$repoRoot/tool/packs');
  if (quiz.existsSync()) {
    for (final e in quiz.listSync()) {
      final name = _base(e.path);
      if (!name.startsWith('hr-')) continue;
      if (e is File && name.endsWith('.json')) refs.add(_ref(Game.kviz, e));
      if (e is Directory && File('${e.path}/$name.json').existsSync()) {
        refs.add(_ref(Game.kviz, File('${e.path}/$name.json')));
      }
    }
  }
  for (final g in Game.values.skip(1)) {
    final dir = Directory('$repoRoot/apps/tv/assets/${g.name}');
    if (!dir.existsSync()) continue;
    for (final e in dir.listSync()) {
      if (e is File && e.path.endsWith('.json')) refs.add(_ref(g, e));
    }
  }
  refs.sort((a, b) {
    final c = a.game.index.compareTo(b.game.index);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return refs;
}

/// The pack's JSON file. A quiz pack with a folder keeps it as <id>/<id>.json.
String _path(String root, Game game, String id) {
  // The id comes from a URL later; keep it a plain file name.
  if (!RegExp(r'^[a-z0-9-]{1,60}$').hasMatch(id)) throw ArgumentError('bad pack id: $id');
  if (game != Game.kviz) return '$root/apps/tv/assets/${game.name}/$id.json';
  return Directory('$root/tool/packs/$id').existsSync()
      ? '$root/tool/packs/$id/$id.json'
      : '$root/tool/packs/$id.json';
}

LoadedPack loadPack(String repoRoot, Game game, String id) {
  final f = File(_path(repoRoot, game, id));
  // Stamp first: a write between the two reads then shows up as stale, not as lost.
  final stamp = _stamp(f);
  final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  return LoadedPack(_ref(game, f), json, stamp);
}

/// JSON with ", " and ": " separators on one line.
String _compact(Object? v) => switch (v) {
      Map() => '{${v.entries.map((e) => '${jsonEncode(e.key)}: ${_compact(e.value)}').join(', ')}}',
      List() => '[${v.map(_compact).join(', ')}]',
      _ => jsonEncode(v),
    };

/// The files' own layout: top-level keys at 2 spaces, the list's items one per line at 4,
/// each item compact, so an edit changes only the lines it touches.
String encodePack(Game game, Map<String, dynamic> json, {bool trailingNewline = true}) {
  final key = _listKey(game);
  final lines = [
    for (final e in json.entries)
      if (e.key == key && e.value is List && (e.value as List).isNotEmpty)
        '  ${jsonEncode(e.key)}: [\n${(e.value as List).map((i) => '    ${_compact(i)}').join(',\n')}\n  ]'
      else
        '  ${jsonEncode(e.key)}: ${_compact(e.value)}',
  ];
  return '{\n${lines.join(',\n')}\n}${trailingNewline ? '\n' : ''}';
}

void _copyDir(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final e in from.listSync()) {
    final name = _base(e.path);
    if (e is Directory) {
      _copyDir(e, Directory('${to.path}/$name'));
    } else if (e is File) {
      e.copySync('${to.path}/$name');
    }
  }
}

/// Writes next to the target, then renames; the tmp file never outlives a failure.
/// [still] runs right before the rename and can veto it (false is returned).
bool _atomicWrite(String path, List<int> bytes, {bool Function()? still}) {
  final tmp = File('$path.tmp');
  try {
    tmp.writeAsBytesSync(bytes);
    if (still != null && !still()) return false;
    tmp.renameSync(path);
    return true;
  } finally {
    if (tmp.existsSync()) tmp.deleteSync();
  }
}

String _few(String name, int min, int n, String unit) => '$name treba barem $min $unit (sada $n)';
String _again(String name, String text) => '$name: ponavlja se „$text“ (u ovom ili drugom paketu).';

// The rules below mirror the TV pack tests, so a saved pack keeps them green:
// party_packs_test _norm (Koliko, Blef), pack_duplicates_test _normal.
String _normParty(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim();
String _normQuiz(String q) =>
    q.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim().replaceAll(RegExp(r'[\s.,;:!?…]+$'), '');

/// The list items of the other packs of the same game, as the files have them.
Iterable<Object?> _others(String root, Game game, String id) sync* {
  for (final r in listPacks(root)) {
    if (r.game == game && r.id != id) yield* (jsonDecode(File(r.path).readAsStringSync())[_listKey(game)] as List);
  }
}

String _qkey(QuizPack p, PackQuestion q) {
  final img = q.image;
  return '${_normQuiz(q.q)}|${img == null ? '' : base64.encode(p.images[img] ?? utf8.encode(img))}';
}

/// pack_duplicates_test: a question repeats another (picture questions: with the same picture)
/// in this pack or in the other bundled packs in apps/tv/assets/packs.
String? _quizRepeat(String root, QuizPack mine) {
  final seen = <String>{};
  final dir = Directory('$root/apps/tv/assets/packs');
  if (dir.existsSync()) {
    for (final f in dir.listSync().whereType<File>()) {
      if (_base(f.path).split('.').first == mine.id) continue;
      final r = parsePack(f.readAsBytesSync());
      if (r is PackOk) seen.addAll(r.pack.questions.map((q) => _qkey(r.pack, q)));
    }
  }
  for (final q in mine.questions) {
    if (!seen.add(_qkey(mine, q))) return _again('Kviz', q.q);
  }
  return null;
}

/// What party_packs_test and uljez_packs_test ask beyond the parsers.
String? _rules(String root, Game game, String id, Map<String, dynamic> j) {
  switch (game) {
    case Game.koliko:
    case Game.blef:
      final blef = game == Game.blef;
      final name = blef ? 'Blef' : 'Koliko?';
      final qs = (j['questions'] as List).cast<Map>();
      if (qs.length < 30) return _few(name, 30, qs.length, 'pitanja');
      final seen = {for (final o in _others(root, game, id)) _normParty((o as Map)['q'] as String)};
      for (final q in qs) {
        final source = q['source'] as String;
        if (blef && !source.startsWith('http')) {
          return 'Blef: izvor mora počinjati s http (sada „$source“) – pitanje „${q['q']}“.';
        }
        if (!seen.add(_normParty(q['q'] as String))) return _again(name, q['q'] as String);
      }
    case Game.uljez:
      final pairs = (j['pairs'] as List).cast<List>();
      if (pairs.length < 40) return _few('Uljez', 40, pairs.length, 'parova');
      final words = <String>{};
      for (final w in [for (final p in pairs) ...p.cast<String>()]) {
        if (w.length > 24) return 'Uljez: riječ „$w“ smije imati najviše 24 znaka (sada ${w.length}).';
        if (!words.add(w)) return 'Uljez: ponavlja se riječ „$w“.';
      }
    case Game.objasni:
      for (final w in (j['words'] as List).cast<String>()) {
        if (w.length > 24) return 'Objasni: riječ „$w“ smije imati najviše 24 znaka (sada ${w.length}).'; // objasni_packs_test
      }
    case Game.kviz:
    case Game.tkobi:
      break; // quiz is checked on its bytes; Tko bi: tkobi_packs_test is covered by the parser (30+, no repeats)
  }
  return null;
}

String? _checkOther(String root, Game game, String id, Map<String, dynamic> json) {
  try {
    // Before the parser, which refuses this too but without the count.
    if (game == Game.blef && json['questions'] is List) {
      for (final q in json['questions'] as List) {
        final a = q is Map ? q['answer'] : null;
        if (a is String && a.length > 40) return 'Blef: odgovor smije imati najviše 40 znakova (sada ${a.length}) – pitanje „${q['q']}“.';
      }
    }
    switch (game) {
      case Game.objasni:
        ObjasniPack.fromJson(json);
      case Game.koliko:
        KolikoPack.fromJson(json);
      case Game.blef:
        BlefPack.fromJson(json);
      case Game.tkobi:
        TkobiPack.fromJson(json);
      case Game.uljez:
        UljezPack.fromJson(json);
      case Game.kviz:
        break;
    }
    return _rules(root, game, id, json);
  } catch (e) {
    return e is FormatException ? e.message : '$e';
  }
}

/// Checks and writes one pack; a failed check or a changed file writes nothing.
/// [deleted] (1-based, original order) and [added] only touch the sources file.
SaveResult savePack(String repoRoot, Game game, String id, Map<String, dynamic> json, String stamp,
    {List<int> deleted = const [], int added = 0}) {
  final path = _path(repoRoot, game, id);
  final file = File(path);
  if (!file.existsSync() || _stamp(file) != stamp) return const SaveStale();
  if (json['id'] != id) return const SaveError('Oznaka paketa se ne smije mijenjati.');

  final original = file.readAsStringSync();
  final text = encodePack(game, json, trailingNewline: original.endsWith('\n'));
  final folder = path.endsWith('/$id/$id.json');
  final tmp = Directory.systemTemp.createTempSync('pack_editor');
  try {
    Uint8List? zip;
    if (game == Game.kviz) {
      var bytes = Uint8List.fromList(utf8.encode(text));
      if (folder) {
        final stage = Directory('${tmp.path}/stage');
        _copyDir(file.parent, stage);
        File('${stage.path}/$id.json').writeAsStringSync(text);
        final z = Process.runSync('zip', ['-qrX', '${tmp.path}/$id.zip', '.'], workingDirectory: stage.path);
        if (z.exitCode != 0) return SaveError('zip nije uspio: ${z.stderr}');
        zip = bytes = File('${tmp.path}/$id.zip').readAsBytesSync();
      }
      final r = parsePack(bytes);
      if (r is PackError) return SaveError(r.message);
      final pack = (r as PackOk).pack;
      if (pack.questions.length < _minQuiz) return SaveError(_few('Kviz', _minQuiz, pack.questions.length, 'pitanja'));
      final again = _quizRepeat(repoRoot, pack);
      if (again != null) return SaveError(again);
    } else {
      final err = _checkOther(repoRoot, game, id, json);
      if (err != null) return SaveError(err);
    }

    // The stamp is checked again right before the rename: a seat writing during the check wins.
    if (!_atomicWrite(path, utf8.encode(text), still: () => _stamp(file) == stamp)) return const SaveStale();
    String? note;
    if (game == Game.kviz) {
      final out = Directory('$repoRoot/apps/tv/assets/packs')..createSync(recursive: true);
      _atomicWrite('${out.path}/$id.${folder ? 'zip' : 'json'}', zip ?? utf8.encode(text));
      final src = File('$repoRoot/tool/packs/$id.sources.md');
      final originalCount = ((jsonDecode(original) as Map)['questions'] as List).length;
      if (src.existsSync() && (deleted.isNotEmpty || added > 0)) {
        final s = src.readAsStringSync();
        // Only when the numbered lines still match the pack one to one.
        if (RegExp(r'^\d+\. ', multiLine: true).allMatches(s).length == originalCount) {
          _atomicWrite(src.path, utf8.encode(renumberSources(s, deleted, added)));
        } else {
          note = sourcesNote;
        }
      }
    }
    return SaveOk(_stamp(file), note: note);
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

/// Drops the numbered lines of the deleted questions (1-based, by position among the numbered
/// lines), renumbers the rest and appends [added] placeholder lines after the last numbered line.
/// Everything else (header, blank lines, notes) stays as it is.
String renumberSources(String text, List<int> deleted, int added) {
  final numbered = RegExp(r'^\d+\. (.*)$');
  final out = <String>[];
  var pos = 0, kept = 0, lastNumbered = -1;
  for (final line in text.split('\n')) {
    final m = numbered.firstMatch(line);
    if (m == null) {
      out.add(line);
      continue;
    }
    pos++;
    if (deleted.contains(pos)) continue;
    out.add('${++kept}. ${m[1]}');
    lastNumbered = out.length - 1;
  }
  final extra = [for (var i = 0; i < added; i++) '${kept + i + 1}. (added in the editor, no source yet)'];
  out.insertAll(lastNumbered < 0 ? out.length : lastNumbered + 1, extra);
  return out.join('\n');
}
