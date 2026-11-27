import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/home_screen.dart';
import 'package:tv/ui/tv_theme.dart';

/// Task 57: "Bodovi za pobjedu" on the TV: the settings panel, and the line under the game's name.
void main() {
  Future<void> pump(WidgetTester t, GameKind game, GameSettings settings, {bool panel = true}) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: tvTheme(),
      home: HomeScreen(
        joinUrl: 'http://192.168.1.5:8080/',
        players: [for (var i = 0; i < 4; i++) PlayerInfo(i, 'P$i', i, true, 0, character: characterIds[i])],
        settings: settings,
        selected: game,
        hostView: panel ? HostView.settings : HostView.home,
        onOpenSettings: () {},
        onCloseSettings: () {},
        games: const [GameKind.curve, GameKind.sumo],
        onSelect: (_) {},
        onPlay: (_) {},
      ),
    ));
    await t.pump();
  }

  for (final game in [GameKind.curve, GameKind.sumo]) {
    testWidgets('$game: the panel shows Bodovi za pobjedu, Automatski by default', (t) async {
      await pump(t, game, const GameSettings());
      expect(find.textContaining('Bodovi za pobjedu', findRichText: true), findsOneWidget);
      expect(find.textContaining('Automatski', findRichText: true), findsOneWidget);
    });

    testWidgets('$game: the panel shows the chosen number', (t) async {
      await pump(t, game, const GameSettings(curveTarget: 30, sumoTarget: 30));
      expect(find.textContaining('30', findRichText: true), findsWidgets);
      expect(find.textContaining('Automatski', findRichText: true), findsNothing);
    });
  }

  test('the lines under the game name say "do N" only for a fixed number', () {
    expect(Strings.homeMeta(GameKind.curve, const GameSettings(), null), isNot(contains('do ')));
    expect(Strings.homeMeta(GameKind.curve, const GameSettings(curveTarget: 50), null), endsWith(' · do 50'));
    expect(Strings.homeMeta(GameKind.sumo, const GameSettings(), null), isNot(contains('do ')));
    expect(Strings.homeMeta(GameKind.sumo, const GameSettings(sumoTarget: 70), null), endsWith(' · do 70'));
    expect(Strings.settingsLine(const GameSettings(curveTarget: 20)), endsWith(' · do 20'));
    expect(Strings.settingsLine(const GameSettings()), isNot(contains(' do ')));
    expect(Strings.homeMeta(GameKind.curve, const GameSettings(sumoTarget: 70), null), isNot(contains('do ')), reason: 'each game has its own');
  });
}
