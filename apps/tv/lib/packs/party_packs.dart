import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/services.dart';

/// Loads the bundled packs of a party game from assets/<dir>/*.json with
/// [parse]. A file that does not parse is skipped, so one bad pack cannot
/// stop the game.
Future<List<T>> _load<T>(AssetBundle bundle, String dir, T Function(Map<String, dynamic>) parse) async {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final paths = manifest.listAssets().where((p) => p.startsWith('assets/$dir/') && p.endsWith('.json')).toList()..sort();
  final out = <T>[];
  for (final path in paths) {
    try {
      out.add(parse(jsonDecode(await bundle.loadString(path)) as Map<String, dynamic>));
    } catch (_) {}
  }
  return out;
}

Future<List<ObjasniPack>> loadObjasniPacks(AssetBundle bundle) => _load(bundle, 'objasni', ObjasniPack.fromJson);

Future<List<KolikoPack>> loadKolikoPacks(AssetBundle bundle) => _load(bundle, 'koliko', KolikoPack.fromJson);

Future<List<BlefPack>> loadBlefPacks(AssetBundle bundle) => _load(bundle, 'blef', BlefPack.fromJson);

Future<List<TkobiPack>> loadTkobiPacks(AssetBundle bundle) => _load(bundle, 'tkobi', TkobiPack.fromJson);

Future<List<KaosviPack>> loadKaosviPacks(AssetBundle bundle) => _load(bundle, 'kaosvi', KaosviPack.fromJson);
