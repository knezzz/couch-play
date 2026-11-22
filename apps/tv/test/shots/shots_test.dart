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
import 'package:tv/ui/curve/curve_game.dart';

import '../session_test.dart' show FakePeer, join;

final _dir = Platform.environment['SHOTS_DIR'];

// Works from apps/tv or from the repo root.
String _assets(String sub) => Directory('assets/$sub').existsSync() ? 'assets/$sub' : 'apps/tv/assets/$sub';

Future<void> _fonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/Users/llama/fvm/versions/3.47.7';
  Future<ByteData> read(String f) async => ByteData.view(File('$root/bin/cache/artifacts/material_fonts/$f').readAsBytesSync().buffer);
  for (final name in ['Roboto', 'FlutterTest', 'sans-serif', 'Ahem', '.AppleSystemUIFont', '.SF Pro Display', '.SF UI Text', '.SF UI Display', 'Arial', 'Helvetica', 'system-ui', '.SF Pro Text', 'Noto Sans']) {
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
      CurveGame.fontFamily = 'Roboto'; // canvas text would be boxes (Ahem) in the test host
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

  Future<void> shot(WidgetTester t, GlobalKey key, String name, {Duration settle = const Duration(seconds: 2)}) async {
    await t.pump(settle);
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

    testWidgets('7 Curve panel after a host change of the pause (no legend) $tag', skip: skip != null, (t) async {
      final key = GlobalKey();
      final s = await start(t, size, key);
      final host = players(s);
      host.say(const SelectGame(GameKind.curve));
      host.say(SetSettings(const GameSettings(curveCountdown: 4)));
      await t.pump();
      await shot(t, key, '7-panel-curve-host-change-$tag');
    });

    testWidgets('8 Kviz panel after the host added robots $tag', skip: skip != null, (t) async {
      final key = GlobalKey();
      final s = await start(t, size, key);
      final host = players(s);
      host.say(const SelectGame(GameKind.quiz));
      host.say(const SetBots(2));
      await t.pump();
      await shot(t, key, '8-panel-kviz-bots-$tag');
    });

    testWidgets('9 Objasni panel after the host changed the turn time $tag', skip: skip != null, (t) async {
      final key = GlobalKey();
      final s = await start(t, size, key);
      final host = players(s);
      host.say(const SelectGame(GameKind.objasni));
      host.say(SetSettings(const GameSettings(objasniSeconds: 90)));
      await t.pump();
      await shot(t, key, '9-panel-objasni-turn-$tag');
    });

    testWidgets('10 Vukodlak panel after the host hid no roles $tag', skip: skip != null, (t) async {
      final key = GlobalKey();
      final s = await start(t, size, key);
      final host = players(s);
      host.say(const SelectGame(GameKind.vukodlak));
      host.say(SetSettings(const GameSettings(wolfHideRoles: false)));
      await t.pump();
      await shot(t, key, '10-panel-vukodlak-$tag');
    });

    // Plays a real Curve round (nobody steers: heads run into walls) until [stop] holds.
    Future<Session> play(WidgetTester t, Size size, GlobalKey key, bool Function(Session) stop) async {
      final s = await start(t, size, key);
      players(s).say(const StartGame(GameKind.curve, null));
      await t.pump();
      for (var i = 0; i < 1200 && !stop(s); i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(stop(s), isTrue, reason: 'the round got there');
      return s;
    }

    testWidgets('11 Curve mid-play: the names strip, a crashed one dimmed $tag', skip: skip != null, (t) async {
      final key = GlobalKey();
      await play(t, size, key, (s) => s.sim!.heads.any((h) => !h.alive) && s.sim!.heads.any((h) => h.alive) && !s.sim!.countingDown);
      await t.pump(const Duration(milliseconds: 600)); // the dead one's trail stays, the rest run on
      await shot(t, key, '11-curve-names-strip-$tag', settle: Duration.zero);
    });

    testWidgets('12 Curve: the winner banner over the frozen field $tag', skip: skip != null, (t) async {
      final key = GlobalKey();
      final s = await play(t, size, key, (s) => s.moment != null);
      await shot(t, key, '12-curve-winner-banner-$tag', settle: const Duration(milliseconds: 300));
      await t.pumpWidget(const SizedBox());
      s.dispose(); // its moment timer
    });
  }

  // --- Task 52 follow-up: the states a live run rarely shows, at 1920x1080 (the real TV) ---
  const full = Size(1920, 1080);
  const longNames = ['Marija-Luisa', 'Ivan-Krešimir', 'Tomislava', 'Dragutin-Josip', 'Ana-Marija', 'Bartol', 'Zvonimirka', 'Krunoslav'];
  final skipFull = _dir == null ? 'set SHOTS_DIR to write the TV shots' : null;

  /// A real Curve match of [n] players on a real Session. Nobody steers; [fates] puts each head
  /// in line with a wall: a distance in px to the wall it runs into (smaller dies first; equal
  /// distances on opposite walls die on the same tick), or null to run the long way (lives).
  Future<Session> curve(WidgetTester t, GlobalKey key, int n, List<double?> fates, {Map<int, int> scores = const {}}) async {
    final s = await start(t, full, key);
    final host = join(s, longNames[0], token: 't0');
    for (var i = 1; i < n; i++) {
      join(s, longNames[i], token: 'p$i');
    }
    host.say(const StartGame(GameKind.curve, null));
    await t.pump();
    final w = s.sim!.config.arenaW.toDouble(), h = s.sim!.config.arenaH.toDouble();
    for (var i = 0; i < n; i++) {
      final y = 100 + i * (h - 200) / (n - 1);
      final d = fates[i];
      if (d == null) {
        s.sim!.place(i, 100, y, 0);
      } else if (i > 0 && fates[i - 1] == d) {
        s.sim!.place(i, d, y, pi); // the pair of the previous head: the opposite wall
      } else {
        s.sim!.place(i, w - d, y, 0);
      }
    }
    scores.forEach((id, v) => s.sim!.scores[id] = v);
    return s;
  }

  Future<void> until(WidgetTester t, Session s, bool Function() stop) async {
    for (var i = 0; i < 1200 && !stop(); i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(stop(), isTrue, reason: 'the scene got there');
  }

  Future<void> finish(WidgetTester t, Session s) async {
    await t.pumpWidget(const SizedBox());
    s.dispose();
  }

  testWidgets('13 Curve mid-play, 8 players with long names, 2 crashed 1920x1080', skip: skipFull != null, (t) async {
    final key = GlobalKey();
    final s = await curve(t, key, 8, [null, 20, 20, null, null, null, null, null]);
    await until(t, s, () => s.sim!.heads.where((h) => !h.alive).length == 2 && !s.sim!.countingDown);
    await t.pump(const Duration(milliseconds: 800));
    await shot(t, key, '13-curve-8-names-strip-1920x1080', settle: Duration.zero);
    await finish(t, s);
  });

  testWidgets('14 Curve countdown: the number, the names and the hint 1920x1080', skip: skipFull != null, (t) async {
    final key = GlobalKey();
    final s = await curve(t, key, 8, [null, null, null, null, null, null, null, null]);
    await t.pump(const Duration(milliseconds: 600));
    expect(s.sim!.countingDown, isTrue);
    await shot(t, key, '14-curve-countdown-1920x1080', settle: Duration.zero);
    await finish(t, s);
  });

  testWidgets('15 Curve tie: two crash on the same tick 1920x1080', skip: skipFull != null, (t) async {
    final key = GlobalKey();
    final s = await curve(t, key, 4, [10, 40, 90, 90]);
    await until(t, s, () => s.moment != null);
    expect(s.moment!.tie, isTrue);
    await shot(t, key, '15-curve-tie-1920x1080', settle: const Duration(milliseconds: 300));
    await finish(t, s);
  });

  testWidgets('16 Curve match won: the game goes to the last one standing 1920x1080', skip: skipFull != null, (t) async {
    final key = GlobalKey();
    final s = await curve(t, key, 4, [null, 10, 40, 90], scores: {0: 29});
    await until(t, s, () => s.moment != null);
    expect(s.moment!.match, isTrue);
    await shot(t, key, '16-curve-match-won-1920x1080', settle: const Duration(milliseconds: 300));
    await finish(t, s);
  });

  testWidgets('17 Curve break card: tied at the top, play goes on 1920x1080', skip: skipFull != null, (t) async {
    final key = GlobalKey();
    // 3 players, target 20: Ana 21 already, Ivan 19 + 2 for winning the round = 21 as well.
    final s = await curve(t, key, 3, [10, null, 60], scores: {0: 21, 1: 19});
    await until(t, s, () => s.roundBreak);
    expect(s.moment, isNull);
    await shot(t, key, '17-curve-tied-at-top-1920x1080', settle: const Duration(milliseconds: 300));
    await finish(t, s);
  });

  testWidgets('18 Curve round banner, 8 players: equal points share a place 1920x1080', skip: skipFull != null, (t) async {
    final key = GlobalKey();
    final s = await curve(t, key, 8, [null, 10, 10, 40, 40, 90, 90, 150]);
    await until(t, s, () => s.moment != null);
    await shot(t, key, '18-curve-round-8-places-1920x1080', settle: const Duration(milliseconds: 300));
    await finish(t, s);
  });
}
