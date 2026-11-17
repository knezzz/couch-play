import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/services.dart';

/// Loads the bundled Uljez word packs (assets/uljez/*.json). A file that does
/// not parse is skipped, so one bad pack cannot stop the game.
Future<List<UljezPack>> loadUljezPacks(AssetBundle bundle) async {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final paths = manifest.listAssets().where((p) => p.startsWith('assets/uljez/') && p.endsWith('.json')).toList()..sort();
  final packs = <UljezPack>[];
  for (final path in paths) {
    try {
      packs.add(UljezPack.fromJson(jsonDecode(await bundle.loadString(path)) as Map<String, dynamic>));
    } catch (_) {}
  }
  return packs;
}
