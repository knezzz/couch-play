import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/tenkovi_match.dart';
import 'package:tv/sound/sfx.dart';
import 'package:tv/ui/tenkovi/tenkovi_view.dart';
import 'package:tv/ui/tv_theme.dart';

/// DIFFERENTIAL privacy: two runs that differ ONLY in one player's aim must be
/// indistinguishable to everybody else, before the volley: the same bytes to
/// every other phone, the same sounds, the same pixels on the TV. This catches
/// a leak through any field (a derived one too), not just a copied value.
class _Sfx implements Sfx {
  _Sfx(this.log);
  final List<Sound> log;
  @override
  void play(Sound s) => log.add(s);
}

class _Run {
  _Run(TenkoviFire p1) {
    match = TenkoviTvMatch(
      ids: const [1, 2, 3, 4],
      settings: const GameSettings(tenkoviMap: TenkoviMapPick.mars),
      send: (id, m) => (sent[id] ??= []).add(m.encode()),
      random: Random(11),
      sfx: _Sfx(sounds),
      notify: changes.call,
      clock: () => Duration.zero,
    )..start();
    // P2 presses the same in every run; P3 and P4 are still aiming.
    match.onFire(2, const TenkoviFire(75, 40, TenkoviShell.cluster));
    match.onFire(1, p1);
  }
  late final TenkoviTvMatch match;
  final sent = <int, List<String>>{};
  final sounds = <Sound>[];
  final changes = _Notifier();
}

class _Notifier extends ChangeNotifier {
  void call() => notifyListeners();
}

const _a = TenkoviFire(137, 83, TenkoviShell.heavy);
const _b = TenkoviFire(20, 10, TenkoviShell.grenade);
const _c = TenkoviFire(180, 0, TenkoviShell.cluster);

Future<Uint8List> _pixels(WidgetTester t, _Run run) async {
  t.view.physicalSize = const Size(960, 540);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(const SizedBox());
  final key = GlobalKey();
  await t.pumpWidget(
    MaterialApp(
      theme: tvTheme(),
      home: RepaintBoundary(
        key: key,
        child: ListenableBuilder(
          listenable: run.changes,
          builder: (_, _) => TenkoviView(
            match: run.match,
            players: [
              for (var i = 1; i <= 4; i++)
                PlayerInfo(i, 'Igrač $i', i - 1, true, 0, character: characterIds[i - 1]),
            ],
          ),
        ),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
  late Uint8List bytes;
  await t.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1);
    bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  });
  return bytes;
}

void main() {
  testWidgets('every other phone gets identical bytes whatever one player aimed', (t) async {
    final x = _Run(_a), y = _Run(_b), z = _Run(_c);
    for (final id in [2, 3, 4]) {
      expect(y.sent[id], x.sent[id], reason: 'phone $id: aim A vs aim B');
      expect(z.sent[id], x.sent[id], reason: 'phone $id: aim A vs aim C');
    }
    // The test can tell: the phone that pressed gets its own aim back.
    expect(y.sent[1], isNot(x.sent[1]));
    x.match.dispose();
    y.match.dispose();
    z.match.dispose();
  });

  testWidgets('the sounds are identical whatever one player aimed', (t) async {
    final x = _Run(_a), y = _Run(_b);
    expect(y.sounds, x.sounds);
    expect(x.sounds, isNotEmpty);
    x.match.dispose();
    y.match.dispose();
  });

  testWidgets('the TV draws the same pixels whatever one player aimed (before the volley)', (t) async {
    final x = _Run(_a), y = _Run(_b);
    expect(x.match.stage, TenkoviStageTv.aim);
    final px = await _pixels(t, x);
    final py = await _pixels(t, y);
    expect(px.length, py.length);
    var diff = 0;
    for (var i = 0; i < px.length; i++) {
      if (px[i] != py[i]) diff++;
    }
    expect(diff, 0, reason: '$diff bytes differ');
    x.match.dispose();
    y.match.dispose();
  });

  testWidgets('the pixels do change with something public: who is ready', (t) async {
    final x = _Run(_a);
    final before = await _pixels(t, x);
    x.match.onFire(3, const TenkoviFire(45, 45, TenkoviShell.grenade));
    final after = await _pixels(t, x);
    var diff = 0;
    for (var i = 0; i < before.length; i++) {
      if (before[i] != after[i]) diff++;
    }
    expect(diff, greaterThan(0), reason: 'a tick appears: the comparison is sensitive');
    x.match.dispose();
  });
}
