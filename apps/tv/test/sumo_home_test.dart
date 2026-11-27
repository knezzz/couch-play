import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/home_screen.dart';
import 'package:tv/ui/tv_theme.dart';

/// Task 55: Sumo's card on the TV home (board SumoTvHome) and its settings panel.
void main() {
  Future<List<GameKind>> pump(WidgetTester t, {GameSettings settings = const GameSettings(), HostView view = HostView.home, LobbyChange? changed}) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final played = <GameKind>[];
    await t.pumpWidget(MaterialApp(
      theme: tvTheme(),
      home: HomeScreen(
        joinUrl: 'http://192.168.1.5:8080/',
        players: [for (var i = 0; i < 4; i++) PlayerInfo(i, 'P$i', i, true, 0, character: characterIds[i])],
        settings: settings,
        selected: GameKind.sumo,
        hostView: view,
        changed: changed,
        onOpenSettings: () {},
        onCloseSettings: () {},
        games: const [GameKind.curve, GameKind.sumo],
        onSelect: (_) {},
        onPlay: played.add,
      ),
    ));
    await t.pump();
    return played;
  }

  test('Sumo is on the home, after the other games', () {
    expect(homeGames[homeGames.length - 2], GameKind.sumo, reason: "Tenkovi follows it");
    expect(homeGames.toSet().length, homeGames.length);
  });

  testWidgets('the card: name, line about it, and who can play with the settings', (t) async {
    await pump(t);
    expect(find.text('Sumo'), findsWidgets);
    expect(find.text('Gurni ostale s ringa.'), findsOneWidget);
    expect(find.text('2–8 igrača · Klasični · pojačanja'), findsOneWidget);
  });

  testWidgets('the settings change the line: Led and without power-ups', (t) async {
    await pump(t, settings: const GameSettings(sumoMap: SumoMap.ice, sumoPowerUps: false));
    expect(find.text('2–8 igrača · Led · bez pojačanja'), findsOneWidget);
  });

  testWidgets('the settings panel shows the map and the power-ups, and marks the one the host changed', (t) async {
    await pump(t,
        settings: const GameSettings(sumoMap: SumoMap.random),
        view: HostView.settings,
        changed: const LobbyChange.setting(GameKind.sumo, 'sumoMap', 'classic', 'random', ChangeBy.phone));
    expect(find.textContaining('Mapa', findRichText: true), findsWidgets);
    expect(find.textContaining('Nasumično', findRichText: true), findsWidgets);
    expect(find.textContaining(Strings.settingPowerUps, findRichText: true), findsWidgets);
  });

  testWidgets('OK plays it', (t) async {
    final played = await pump(t);
    await t.sendKeyEvent(LogicalKeyboardKey.select);
    await t.pump();
    expect(played, [GameKind.sumo]);
  });
}
