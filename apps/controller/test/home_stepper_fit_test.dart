import 'package:controller/screens/lobby_screen.dart';
import 'package:controller/theme.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

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
}

/// "Nasumično" must not be torn in the middle ("Nasumičn" / "o") in the host's
/// stepper: the value stays on one line (scaled down), at 360 and 390.
void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets('Tenkovi Mapa "Nasumično" is one line at $width', (t) async {
      await _show(
        t,
        _lobby(GameKind.tenkovi, const GameSettings(tenkoviMap: TenkoviMapPick.random)),
        width,
      );
      final v = find.byKey(const ValueKey('val-tenkoviMap'));
      expect(v, findsOneWidget);
      expect(t.getSize(v).height, lessThan(30), reason: 'one line of 17 px text');
      expect(t.takeException(), isNull);
    });

    testWidgets('Sumo Mapa "Nasumično" is one line at $width too (the shared stepper)', (t) async {
      await _show(
        t,
        _lobby(GameKind.sumo, const GameSettings(sumoMap: SumoMap.random)),
        width,
      );
      final v = find.byKey(const ValueKey('val-sumoMap'));
      expect(v, findsOneWidget);
      expect(t.getSize(v).height, lessThan(30));
    });
  }

  testWidgets('a short value keeps its look: a number is not scaled', (t) async {
    await _show(
      t,
      _lobby(GameKind.tenkovi, const GameSettings(tenkoviMap: TenkoviMapPick.earth)),
      390,
    );
    final v = find.byKey(const ValueKey('val-tenkoviRounds'));
    final shown = t.getBottomRight(v) - t.getTopLeft(v);
    expect(shown.dx, closeTo(t.getSize(v).width, 0.01), reason: 'scale 1: it looks as before');
  });
}
