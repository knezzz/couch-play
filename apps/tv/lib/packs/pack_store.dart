import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

/// Built-in packs plus the ones the host uploaded. User packs live in
/// [userDir] as `<id>.pack` (the uploaded bytes: a zip or a bare json).
class PackStore {
  PackStore._(this._dir, this._bundled, this._user);

  final Directory _dir;
  final Map<String, QuizPack> _bundled;
  final Map<String, QuizPack> _user;

  /// A bad bundled or user pack is skipped and logged, never fatal.
  static Future<PackStore> load({
    required List<Uint8List> bundled,
    required Directory userDir,
  }) async {
    final b = <String, QuizPack>{};
    for (final bytes in bundled) {
      final r = parsePack(bytes);
      if (r is PackOk) {
        b[r.pack.id] = r.pack;
      } else {
        debugPrint('PackStore: skipped a bundled pack: ${(r as PackError).message}');
      }
    }
    final u = <String, QuizPack>{};
    if (await userDir.exists()) {
      await for (final f in userDir.list()) {
        if (f is! File || !f.path.endsWith('.pack')) continue; // not a .pack.tmp
        try {
          final r = parsePack(await f.readAsBytes());
          if (r is PackError) {
            debugPrint('PackStore: skipped ${f.path}: ${r.message}');
          } else if (b.containsKey((r as PackOk).pack.id)) {
            debugPrint('PackStore: skipped ${f.path}: id is built in');
          } else {
            u[r.pack.id] = r.pack;
          }
        } catch (e) {
          debugPrint('PackStore: skipped ${f.path}: $e');
        }
      }
    }
    return PackStore._(userDir, b, u);
  }

  List<PackInfo> get infos => [
        for (final p in [..._bundled.values, ..._user.values])
          PackInfo(p.id, p.title, p.questions.length),
      ];

  QuizPack? get(String id) => _bundled[id] ?? _user[id];

  /// Null on success, else the message to show the host. Validates before
  /// touching the disk; the file is written aside and renamed so a crash never
  /// leaves a half file. The file name comes from the parsed id, never from
  /// anything the uploader sent.
  Future<String?> add(Uint8List bytes) async {
    final r = parsePack(bytes);
    if (r is PackError) return r.message;
    final pack = (r as PackOk).pack;
    if (_bundled.containsKey(pack.id)) {
      return "A built-in pack already uses the id '${pack.id}'. Pick another id.";
    }
    try {
      await _dir.create(recursive: true);
      final tmp = File('${_dir.path}/${pack.id}.pack.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename('${_dir.path}/${pack.id}.pack');
    } on FileSystemException catch (e) {
      debugPrint('PackStore: could not save ${pack.id}: $e');
      return "The pack couldn't be saved.";
    }
    _user[pack.id] = pack;
    return null;
  }
}
