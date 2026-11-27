import 'package:controller/screens/home_rows.dart';
import 'package:controller/screens/home_widgets.dart';
import 'package:controller/screens/settings_copy.dart';
import 'package:controller/strings.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Task 57: the "Bodova do pobjede" row of Curve and Sumo on the phone home.
void main() {
  LobbyState lobby(GameSettings s) => LobbyState(
        hostId: 0,
        packs: const [],
        settings: s,
        players: [for (var i = 0; i < 3; i++) PlayerInfo(i, 'P$i', i, true, 0)],
      );

  for (final (game, key) in [(GameKind.curve, 'curveTarget'), (GameKind.sumo, 'sumoTarget')]) {
    test('$game has the row, Automatski first, stepping through the choices', () {
      final row = homeRows(game, lobby(const GameSettings())).firstWhere((r) => r.key == key);
      expect(row.label, 'Bodova do pobjede');
      expect(row.display, 'Automatski');
      expect(row.values, [0, 10, 20, 30, 50, 70, 100]);
      expect(row.prev, isNull, reason: 'Automatski is the first');
      expect(row.next, 1);
      final up = row.messageFor!(row.next!) as SetSettings;
      final t = game == GameKind.curve ? up.settings.curveTarget : up.settings.sumoTarget;
      expect(t, 10);
    });

    test('$game: a change keeps every other setting, and shows the number', () {
      const s = GameSettings(curveMode: CurveMode.chaos, sumoMap: SumoMap.ice, sumoPowerUps: false, curveTarget: 30, sumoTarget: 50, tenkoviRounds: 5);
      final row = homeRows(game, lobby(s)).firstWhere((r) => r.key == key);
      expect(row.display, game == GameKind.curve ? '30' : '50');
      final sent = (row.messageFor!(row.values.indexOf(100)) as SetSettings).settings;
      expect(sent.curveMode, CurveMode.chaos);
      expect(sent.sumoMap, SumoMap.ice);
      expect(sent.sumoPowerUps, isFalse);
      expect(sent.tenkoviRounds, 5);
      expect(game == GameKind.curve ? sent.curveTarget : sent.sumoTarget, 100);
      expect(game == GameKind.curve ? sent.sumoTarget : sent.curveTarget, game == GameKind.curve ? 50 : 30, reason: 'the other game\'s number is kept');
    });
  }

  test('the line under the game name says "do N" for a fixed number and nothing for Automatski', () {
    expect(homeMeta(GameKind.curve, lobby(const GameSettings())), isNot(contains('do ')));
    expect(homeMeta(GameKind.curve, lobby(const GameSettings(curveTarget: 30))), contains(' · do 30'));
    expect(homeMeta(GameKind.sumo, lobby(const GameSettings())), isNot(contains('do ')));
    expect(homeMeta(GameKind.sumo, lobby(const GameSettings(sumoTarget: 70))), contains(' · do 70'));
    expect(homeMeta(GameKind.curve, lobby(const GameSettings(sumoTarget: 70))), isNot(contains('do ')));
  });

  test('Tenkovi and the other games have no such row', () {
    for (final g in GameKind.values.where((g) => g != GameKind.curve && g != GameKind.sumo)) {
      expect(homeRows(g, lobby(const GameSettings())).where((r) => r.key == 'curveTarget' || r.key == 'sumoTarget'), isEmpty, reason: '$g');
    }
  });

  test('a change in the log is worded with the number or Automatski', () {
    final l = lobby(const GameSettings(curveTarget: 30));
    final c = LobbyChange.setting(GameKind.curve, 'curveTarget', 0, 30, ChangeBy.phone);
    expect(changeValue(c, 0, l), 'Automatski');
    expect(changeValue(c, 30, l), '30');
    expect(copySettings(const GameSettings(), curveTarget: 20).curveTarget, 20);
    expect(Strings.targetPoints, 'Bodova do pobjede');
  });
}
