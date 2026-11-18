import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/src/blef.dart';
import 'package:core/src/kaosvi.dart';
import 'package:core/src/koliko.dart';
import 'package:core/src/objasni.dart';
import 'package:core/src/quiz_pack.dart';
import 'package:core/src/tkobi.dart';
import 'package:core/src/uljez.dart';

enum Game { kviz, objasni, koliko, blef, tkobi, kaosvi, uljez }

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

class SaveOk extends SaveResult {
  const SaveOk(this.stamp);
  final String stamp;
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

void _atomicWrite(String path, List<int> bytes) {
  final tmp = File('$path.tmp')..writeAsBytesSync(bytes);
  tmp.renameSync(path);
}

String? _checkOther(Game game, Map<String, dynamic> json) {
  try {
    switch (game) {
      case Game.objasni:
        ObjasniPack.fromJson(json);
      case Game.koliko:
        KolikoPack.fromJson(json);
      case Game.blef:
        BlefPack.fromJson(json);
      case Game.tkobi:
        TkobiPack.fromJson(json);
      case Game.kaosvi:
        KaosviPack.fromJson(json);
      case Game.uljez:
        UljezPack.fromJson(json);
      case Game.kviz:
        break;
    }
    return null;
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
  final text = '${const JsonEncoder.withIndent('  ').convert(json)}${original.endsWith('\n') ? '\n' : ''}';
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
      if (r is PackOk && r.pack.questions.length < _minQuiz) {
        return const SaveError('Kviz paket mora imati barem $_minQuiz pitanja.');
      }
    } else {
      final err = _checkOther(game, json);
      if (err != null) return SaveError(err);
    }

    _atomicWrite(path, utf8.encode(text));
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
        }
      }
    }
    return SaveOk(_stamp(file));
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
