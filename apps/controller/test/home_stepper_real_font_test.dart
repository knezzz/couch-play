import 'dart:io';

import 'package:controller/screens/lobby_screen.dart';
import 'package:controller/theme.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

// The test font (Ahem) hid a real bug: with the real Roboto, "Nasumično" and
// "Automatski" were torn in the middle ("Nasumičn" / "o") in the host's stepper.
// These tests load the real Roboto the app bundles.

Future<void> _fonts() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ?? '/Users/llama/fvm/versions/3.47.7';
  Future<ByteData> read(String f) async => ByteData.view(
    File('$root/bin/cache/artifacts/material_fonts/$f').readAsBytesSync().buffer,
  );
  final roboto = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
    roboto.addFont(read('Roboto-$f.ttf'));
  }
  await roboto.load();
  // A TextPainter given no font family measures with a DIFFERENT, narrower font
  // than the Roboto bold the row renders (as in the browser): that is what
  // made a width check pass while the word was torn. Reproduce it here.
  final fallback = FontLoader('FlutterTest')..addFont(read('Roboto-Regular.ttf'));
  await fallback.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
}

LobbyState _lobby(GameKind k, GameSettings s) => LobbyState(
  hostId: 0,
  packs: const [],
  selected: k,
  settings: s,
  players: [
    for (var i = 0; i < 3; i++)
      PlayerInfo(i, 'P$i', i, true, 0, character: characterIds[i]),
  ],
);

Future<void> _show(WidgetTester t, LobbyState l, double width) async {
  t.view.physicalSize = Size(width, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(theme: theme, home: LobbyScreen(FakeConnection(), l, 0)),
  );
  await t.pump();
}

/// How many lines the value's paragraph really laid out.
int _lines(WidgetTester t, String key) {
  final p = t.renderObject<RenderParagraph>(find.byKey(ValueKey(key)));
  final h = p.size.height;
  final lineH = p.text.style?.fontSize ?? 17;
  return (h / (lineH * 1.2)).round();
}

void main() {
  setUpAll(_fonts);

  final cases = <(String, GameKind, GameSettings, String)>[
    ('Nasumično', GameKind.tenkovi, const GameSettings(tenkoviMap: TenkoviMapPick.random), 'val-tenkoviMap'),
    ('Nasumično', GameKind.sumo, const GameSettings(sumoMap: SumoMap.random), 'val-sumoMap'),
    ('Automatski', GameKind.sumo, const GameSettings(sumoTarget: 0), 'val-sumoTarget'),
    ('Automatski', GameKind.curve, const GameSettings(curveTarget: 0), 'val-curveTarget'),
    ('Uravnoteženo', GameKind.curve, const GameSettings(curveMode: CurveMode.balanced), 'val-curveMode'),
  ];
  for (final width in [360.0, 390.0]) {
    for (final (word, kind, settings, key) in cases) {
      testWidgets('"$word" is one line in the host stepper of $kind at $width', (t) async {
        await _show(t, _lobby(kind, settings), width);
        expect(find.text(word), findsWidgets);
        expect(_lines(t, key), 1, reason: 'no word torn in the middle');
        expect(t.takeException(), isNull);
      });
    }
  }

  for (final width in [360.0, 390.0]) {
    testWidgets('the word stays inside the 88 px box at $width (scaled, never torn)', (t) async {
      await _show(t, _lobby(GameKind.curve, const GameSettings(curveTarget: 0)), width);
      final v = find.byKey(const ValueKey('val-curveTarget'));
      final shown = t.getBottomRight(v) - t.getTopLeft(v);
      expect(shown.dx, lessThanOrEqualTo(88.01));
      expect(shown.dy, lessThan(26), reason: 'one line');
    });
  }

  testWidgets('several words keep their two lines, unscaled: "Samo za tebe"', (t) async {
    await _show(t, _lobby(GameKind.curve, const GameSettings(curveMode: CurveMode.onlyYou)), 390);
    final v = find.byKey(const ValueKey('val-curveMode'));
    expect(_lines(t, 'val-curveMode'), 2);
    final shown = t.getBottomRight(v) - t.getTopLeft(v);
    expect(shown.dx, closeTo(t.getSize(v).width, 0.01));
  });

  testWidgets('a number is one line at its own size', (t) async {
    await _show(t, _lobby(GameKind.tenkovi, const GameSettings()), 390);
    final v = find.byKey(const ValueKey('val-tenkoviRounds'));
    expect(_lines(t, 'val-tenkoviRounds'), 1);
    final shown = t.getBottomRight(v) - t.getTopLeft(v);
    expect(shown.dx, closeTo(t.getSize(v).width, 0.01));
  });
}
