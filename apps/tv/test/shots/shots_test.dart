// Writes PNGs of the TV home (idle, settings panel, pack grid) at 1272x715 and 960x540 with the
// real Roboto, from a real Session driven like the host's phone drives it (Task 48). Not part of the
// normal run (skipped without SHOTS_DIR):
//   SHOTS_DIR=/some/dir fvm flutter test test/shots/shots_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/main.dart';
import 'package:tv/packs/pack_store.dart';
import 'package:tv/session/session.dart';

import '../session_test.dart' show FakePeer, join;

final _dir = Platform.environment['SHOTS_DIR'];

// Works from apps/tv or from the repo root.
String _assets(String sub) => Directory('assets/$sub').existsSync() ? 'assets/$sub' : 'apps/tv/assets/$sub';

Future<void> _fonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/Users/llama/fvm/versions/3.47.7';
  Future<ByteData> read(String f) async => ByteData.view(File('$root/bin/cache/artifacts/material_fonts/$f').readAsBytesSync().buffer);
  for (final name in ['Roboto', 'FlutterTest', 'sans-serif', 'Arial', 'Helvetica', 'system-ui', '.SF Pro Text', 'Noto Sans']) {
    final l = FontLoader(name);
    for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
      l.addFont(read('Roboto-$f.ttf'));
    }
    await l.load();
  }
  await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
}

List<T> _json<T>(String dir, T Function(Map<String, dynamic>) parse) => [
      for (final f in (Directory(_assets(dir)).listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()..sort((a, b) => a.path.compareTo(b.path))))
        parse(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>),
    ];

const _sizes = [Size(1272, 715), Size(960, 540)];

void main() {
  setUpAll(() async {
    if (_dir != null) {
      Directory(_dir!).createSync(recursive: true);
      await _fonts();
    }
  });

  Future<Session> start(WidgetTester t, Size size, GlobalKey key) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final dir = Directory.systemTemp.createTempSync('shots');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = await t.runAsync(() => PackStore.load(
          bundled: [for (final f in Directory(_assets('packs')).listSync().whereType<File>()) f.readAsBytesSync()],
          userDir: dir,
        ));
    final s = Session(random: Random(1))
      ..joinUrl = 'http://192.168.1.5:8080/'
      ..packStore = store
      ..uljezPacks = _json('uljez', UljezPack.fromJson)
      ..objasniPacks = _json('objasni', ObjasniPack.fromJson);
    await t.pumpWidget(RepaintBoundary(key: key, child: TvApp(session: s, serve: false)));
    return s;
  }

  FakePeer players(Session s) {
    final host = join(s, 'Ana', token: 't0');
    for (final n in ['Marko', 'Iva', 'Luka']) {
      join(s, n, token: n);
    }
    return host;
  }

  Future<void> shot(WidgetTester t, GlobalKey key, String name) async {
    await t.pump(const Duration(seconds: 2));
    await t.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$_dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  for (final size in _sizes) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    final skip = _dir == null ? 'set SHOTS_DIR to write the TV shots' : null;

    testWidgets('1 home on Kviz, idle $tag', skip: skip != null, (t) async {
      final key = GlobalKey();
      final s = await start(t, size, key);
      players(s);
      await t.pump();
      await shot(t, key, '1-home-kviz-$tag');
    });

    testWidgets('2 Kviz panel after a host change of Broj pitanja $tag', skip: skip != null, (t) async {
      final key = GlobalKey();
      final s = await start(t, size, key);
      final host = players(s);
      host.say(const SelectGame(GameKind.quiz));
      host.say(SetSettings(const GameSettings(quizQuestions: 15)));
      await t.pump();
      await shot(t, key, '2-panel-kviz-$tag');
    });

    testWidgets('3 Objasni panel $tag', skip: skip != null, (t) async {
      final key = GlobalKey();
      final s = await start(t, size, key);
      final host = players(s);
      host.say(const SelectGame(GameKind.objasni));
      host.say(SetSettings(s.settings.withOffPacks({GameKind.objasni: {s.objasniPacks.first.id}})));
      await t.pump();
      await shot(t, key, '3-panel-objasni-$tag');
    });

    testWidgets('4 Kviz pack grid, a few packs off $tag', skip: skip != null, (t) async {
      final key = GlobalKey();
      final s = await start(t, size, key);
      final host = players(s);
      host.say(const SelectGame(GameKind.quiz));
      final ids = s.packStore!.infos.map((i) => i.id).toList();
      host.say(SetSettings(s.settings.withOffPacks({GameKind.quiz: {ids[1], ids[4], ids[7], ids[8]}})));
      host.say(const PackScreen(true));
      await t.pump();
      await shot(t, key, '4-packs-kviz-$tag');
    });

    testWidgets('5 Uljez pack grid $tag', skip: skip != null, (t) async {
      final key = GlobalKey();
      final s = await start(t, size, key);
      final host = players(s);
      host.say(const SelectGame(GameKind.uljez));
      host.say(SetSettings(s.settings.withOffPacks({GameKind.uljez: {s.uljezPacks[2].id}})));
      host.say(const PackScreen(true));
      await t.pump();
      await shot(t, key, '5-packs-uljez-$tag');
    });

    testWidgets('6 Curve home, panel opened by the down key $tag', skip: skip != null, (t) async {
      final key = GlobalKey();
      final s = await start(t, size, key);
      final host = players(s);
      host.say(const SelectGame(GameKind.curve));
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      await shot(t, key, '6-panel-curve-$tag');
    });
  }
}
