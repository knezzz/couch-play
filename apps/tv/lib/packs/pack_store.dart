import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The pack files under assets/packs/, General Knowledge first so it is the
/// default when the host picks no pack.
Future<List<Uint8List>> loadBundledPacks(AssetBundle bundle) async {
  final keys = (await AssetManifest.loadFromAssetBundle(bundle))
      .listAssets()
      .where((k) => k.startsWith('assets/packs/'))
      .toList()
    ..sort((a, b) => a.endsWith('/general.json') ? -1 : b.endsWith('/general.json') ? 1 : a.compareTo(b));
  return [for (final k in keys) (await bundle.load(k)).buffer.asUint8List()];
}

/// Built-in packs plus the ones the host uploaded. User packs live in
/// [userDir] as `<id>.pack` (the uploaded bytes: a zip or a bare json).
class PackStore {
  PackStore._(this._dir, this._bundled, this._user);

  final Directory _dir;
  final Map<String, QuizPack> _bundled;
  final Map<String, QuizPack> _user;
  Future<void> _tail = Future.value(); // adds run one at a time, in call order

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
    try {
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
    } catch (e) {
      debugPrint('PackStore: could not list ${userDir.path}, using built-in packs only: $e');
    }
    return PackStore._(userDir, b, u);
  }

  List<PackInfo> get infos => [
        for (final p in [..._bundled.values, ..._user.values])
          PackInfo(p.id, p.title, p.questions.length),
      ];

  QuizPack? get(String id) => _bundled[id] ?? _user[id];

  QuizPack? get firstBundled => _bundled.values.firstOrNull;

  /// Null on success, else the message to show the host. Validates before
  /// touching the disk; the file is written aside and renamed so a crash never
  /// leaves a half file. The file name comes from the parsed id, never from
  /// anything the uploader sent.
  Future<String?> add(Uint8List bytes) {
    // GameServer doesn't serialize requests; two uploads of one id would
    // otherwise interleave writes into the same .tmp.
    final run = _tail.then((_) => _add(bytes));
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<String?> _add(Uint8List bytes) async {
    final r = parsePack(bytes);
    if (r is PackError) return r.message;
    final pack = (r as PackOk).pack;
    if (_bundled.containsKey(pack.id)) {
      return "A built-in pack already uses the id '${pack.id}'. Pick another id.";
    }
    final tmp = File('${_dir.path}/${pack.id}.pack.tmp');
    try {
      await _dir.create(recursive: true);
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename('${_dir.path}/${pack.id}.pack');
    } on FileSystemException catch (e) {
      debugPrint('PackStore: could not save ${pack.id}: $e');
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      return "The TV couldn't save the pack. Free some space on the TV, then try again.";
    }
    _user[pack.id] = pack;
    return null;
  }
}
