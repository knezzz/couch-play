import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/wolf_match.dart';
import 'package:tv/strings.dart';
import 'package:tv/session/wolf_text.dart';
import 'package:tv/ui/tv_theme.dart';
import 'package:tv/ui/wolf/end_screen.dart';
import 'package:tv/ui/wolf/village_screen.dart';
import 'package:tv/ui/wolf/vote_screen.dart';
import 'package:tv/ui/wolf/wolf_view.dart';

/// Seven players, ids 1..7: 1 wolf, 2 wolf, 3 seer, 4 doctor, 5 hunter, 6 herbalist, 7 villager.
const _roles7 = {
  1: WolfRole.wolf,
  2: WolfRole.wolf,
  3: WolfRole.seer,
  4: WolfRole.doc,
  5: WolfRole.hunter,
  6: WolfRole.herb,
  7: WolfRole.villager,
};

class _Game {
  _Game(Map<int, WolfRole> roles, {bool hide = true}) {
    match = WolfMatch(
      ids: roles.keys.toList(),
      nameOf: (id) => 'P$id',
      settings: GameSettings(wolfHideRoles: hide),
      send: (_, _) {},
      clock: () => at,
      random: Random(1),
      fixedRoles: roles,
    )..start();
    players = [for (final id in roles.keys) PlayerInfo(id, 'P$id', id - 1, true, 0, character: characterIds[id - 1])];
  }
  late final WolfMatch match;
  late final List<PlayerInfo> players;
  Duration at = Duration.zero;

  Future<void> wait(WidgetTester t, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await t.pump(const Duration(seconds: 1));
      at += const Duration(seconds: 1);
    }
  }

  /// The morning passes, then everyone taps "Idemo glasati": the vote begins.
  Future<void> toVote(WidgetTester t, {int morning = 10}) async {
    await wait(t, morning);
    for (final id in match.alive) {
      match.onReady(id, const ReadyToVote(true));
    }
  }

  Widget view() => MaterialApp(theme: tvTheme(), home: WolfView(match: match, players: players));
}

void _big(WidgetTester t) {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Iterable<String> _roleWordsOnScreen(WidgetTester t) sync* {
  for (final w in t.widgetList<Text>(find.byType(Text))) {
    final s = w.data ?? w.textSpan?.toPlainText() ?? '';
    for (final role in WolfText.roleNames.values) {
      if (s.contains(role)) yield '$role in "$s"';
    }
  }
}

Future<void> _close(WidgetTester t, _Game g) async {
  await t.pumpWidget(const SizedBox());
  g.match.dispose();
  await t.pump();
}

void main() {
  testWidgets('night: the village with every house lit and no role on screen', (t) async {
    _big(t);
    final g = _Game(_roles7);
    await t.pumpWidget(g.view());
    expect(find.byType(VillageScreen), findsOneWidget);
    expect(t.widget<VillageScreen>(find.byType(VillageScreen)).night, isTrue);
    expect(t.widget<VillageScreen>(find.byType(VillageScreen)).players.every((p) => p.lit), isTrue);
    expect(_roleWordsOnScreen(t), isEmpty);
    expect(find.text('P1'), findsOneWidget);
    await _close(t, g);
  });

  testWidgets('a light goes out when that player is done, after the first 15 s; the TV only reads the public getters', (t) async {
    _big(t);
    final g = _Game(_roles7);
    g.match.onNightPick(7, const NightPick(null));
    await g.wait(t, 5);
    await t.pumpWidget(g.view());
    expect(t.widget<VillageScreen>(find.byType(VillageScreen)).players.every((p) => p.lit), isTrue, reason: 'held for 15 s');
    await g.wait(t, 12);
    await t.pumpWidget(g.view());
    final lit = {for (final p in t.widget<VillageScreen>(find.byType(VillageScreen)).players) p.id: p.lit};
    expect(lit[7], isFalse, reason: 'player 7 is done');
    expect(lit[1], isTrue);
    await _close(t, g);
  });

  testWidgets('hidden roles: after a death the house is closed and no role is named anywhere', (t) async {
    _big(t);
    final g = _Game(_roles7);
    for (final id in g.match.alive) {
      g.match.onNightPick(id, id <= 2 ? const NightPick(7) : const NightPick(null));
    }
    await g.wait(t, 5);
    await t.pumpWidget(g.view());
    final v = t.widget<VillageScreen>(find.byType(VillageScreen));
    expect(v.players.firstWhere((p) => p.id == 7).out, isTrue, reason: 'player 7 was killed');
    expect(v.night, isFalse, reason: 'morning');
    expect(_roleWordsOnScreen(t), isEmpty, reason: 'roles are hidden');
    expect(find.textContaining('P7'), findsWidgets, reason: 'the story names who is out');
    await _close(t, g);
  });

  testWidgets('roles shown: the same death names the role in the story', (t) async {
    _big(t);
    final g = _Game(_roles7, hide: false);
    for (final id in g.match.alive) {
      g.match.onNightPick(id, id <= 2 ? const NightPick(7) : const NightPick(null));
    }
    await g.wait(t, 5);
    await t.pumpWidget(g.view());
    expect(find.textContaining(WolfText.roleNames[WolfRole.villager]!), findsWidgets);
    await _close(t, g);
  });

  testWidgets('game over: every role is shown and the winner\'s line', (t) async {
    _big(t);
    final g = _Game({1: WolfRole.wolf, 2: WolfRole.villager, 3: WolfRole.villager});
    g.match.onNightPick(1, const NightPick(2));
    g.match.onNightPick(2, const NightPick(null));
    g.match.onNightPick(3, const NightPick(null));
    await g.wait(t, 25); // the morning, then the farewell window of whoever went out
    await t.pumpWidget(g.view());
    expect(g.match.stage, WolfStage.over);
    expect(find.byType(WolfEndScreen), findsOneWidget);
    expect(find.text(WolfText.roleNames[WolfRole.wolf]!), findsOneWidget);
    expect(find.text(WolfText.roleNames[WolfRole.villager]!), findsNWidgets(2));
    await _close(t, g);
  });

  testWidgets('by day: how many want to vote, as a count only, and no clock anywhere; at night nothing', (t) async {
    _big(t);
    final g = _Game(_roles7);
    await t.pumpWidget(g.view());
    expect(find.textContaining('Idemo glasati'), findsNothing, reason: 'night');
    for (final id in g.match.alive) {
      g.match.onNightPick(id, const NightPick(null));
    }
    await g.wait(t, 10);
    await t.pumpWidget(g.view());
    expect(find.text('Idemo glasati 0 od 7'), findsOneWidget);
    g.match.onReady(2, const ReadyToVote(true));
    g.match.onReady(5, const ReadyToVote(true));
    await t.pumpWidget(g.view());
    expect(find.text('Idemo glasati 2 od 7'), findsOneWidget);
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      expect(w.data ?? w.textSpan?.toPlainText() ?? '', isNot(matches(RegExp(r'\d:\d\d'))));
    }
    expect(t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? ''), isNot(contains('2')), reason: 'no name of who wants');
    await _close(t, g);
  });

  for (final size in const [Size(1272, 715), Size(960, 540)]) {
    testWidgets('the day count fits at ${size.width.toInt()}x${size.height.toInt()}', (t) async {
      t.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final g = _Game(_roles7);
      for (final id in g.match.alive) {
        g.match.onNightPick(id, const NightPick(null));
      }
      await g.wait(t, 10);
      await t.pumpWidget(g.view());
      expect(find.text('Idemo glasati 0 od 7'), findsOneWidget);
      expect(t.takeException(), isNull);
      await _close(t, g);
    });
  }

  testWidgets('locked phones still count: the day N is every living player', (t) async {
    _big(t);
    final g = _Game(_roles7);
    for (final id in g.match.alive) {
      g.match.onNightPick(id, const NightPick(null));
    }
    await g.wait(t, 10);
    for (final id in [5, 6, 7]) {
      g.match.setAway(id, true);
    }
    g.match.onReady(1, const ReadyToVote(true));
    await t.pumpWidget(g.view());
    expect(find.text('Idemo glasati 1 od 7'), findsOneWidget);
    await _close(t, g);
  });

  testWidgets('the vote: the vote screen with how many have voted, and nothing about who voted for whom', (t) async {
    _big(t);
    final g = _Game(_roles7);
    for (final id in g.match.alive) {
      g.match.onNightPick(id, const NightPick(null));
    }
    await g.toVote(t, morning: 5); // morning, nobody died, then the wish
    await t.pumpWidget(g.view());
    expect(g.match.stage, WolfStage.vote);
    expect(find.byType(WolfVoteScreen), findsOneWidget);
    g.match.onVote(1, const Vote(3));
    g.match.onVote(2, const Vote(3));
    await t.pumpWidget(g.view());
    expect(t.widget<WolfVoteScreen>(find.byType(WolfVoteScreen)).voted, 2);
    expect(t.widget<WolfVoteScreen>(find.byType(WolfVoteScreen)).expected, 7);
    expect(_roleWordsOnScreen(t), isEmpty);
    await _close(t, g);
  });

  testWidgets('the vote ends: the result stays on the vote screen for a few seconds with only who is out, then the village', (t) async {
    _big(t);
    final g = _Game(_roles7);
    for (final id in g.match.alive) {
      g.match.onNightPick(id, const NightPick(null));
    }
    await g.toVote(t);
    expect(g.match.stage, WolfStage.vote);
    for (final id in g.match.alive) {
      g.match.onVote(id, Vote(id == 6 ? 1 : 6)); // everyone votes for player 6 (who votes for 1)
    }
    await t.pumpWidget(g.view());
    expect(g.match.lastOut, 6);
    var v = t.widget<WolfVoteScreen>(find.byType(WolfVoteScreen));
    expect(v.outId, 6);
    expect(v.result, contains('P6'));
    expect(find.byKey(const ValueKey('out-card')), findsOneWidget);
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      final d = w.data ?? w.textSpan?.toPlainText() ?? '';
      expect(d, isNot(contains('→')));
      expect(d.toLowerCase(), isNot(contains('glasova')));
    }
    await g.wait(t, 9);
    await t.pumpWidget(g.view());
    expect(find.byType(WolfVoteScreen), findsNothing, reason: 'the result is not held for ever');
    expect(find.byType(VillageScreen), findsOneWidget);
    await _close(t, g);
  });

  testWidgets('a held vote result shows the real x of y (someone did not vote)', (t) async {
    _big(t);
    final g = _Game(_roles7);
    for (final id in g.match.alive) {
      g.match.onNightPick(id, const NightPick(null));
    }
    await g.toVote(t);
    expect(g.match.stage, WolfStage.vote);
    for (final id in [1, 2, 3, 4, 5]) {
      g.match.onVote(id, const Vote(6));
    }
    await t.pumpWidget(g.view());
    g.match.onVote(6, const Vote(null));
    g.match.expel(7); // 7 never votes: a sleeping phone is waited for, the host's kick completes the vote
    expect(g.match.lastOut, 6);
    final v = t.widget<WolfVoteScreen>(find.byType(WolfVoteScreen));
    expect(v.voted, 5);
    expect(v.expected, 7);
    expect(find.text(Strings.wolfVoted(5, 7)), findsOneWidget);
    await _close(t, g);
  });

  testWidgets('the vote screen lists only the players still in the game; the one just voted out stays for the result', (t) async {
    _big(t);
    final g = _Game(_roles7, hide: false);
    for (final id in g.match.alive) {
      g.match.onNightPick(id, id <= 2 ? const NightPick(7) : const NightPick(null));
    }
    await g.wait(t, 30); // morning: 7 is out; farewell
    await g.toVote(t, morning: 0);
    await t.pumpWidget(g.view());
    expect(g.match.stage, WolfStage.vote);
    var v = t.widget<WolfVoteScreen>(find.byType(WolfVoteScreen));
    expect(v.players.map((p) => p.id), isNot(contains(7)), reason: 'player 7 went out in the night');
    expect(v.players.length, 6);
    for (final id in g.match.alive) {
      g.match.onVote(id, Vote(id == 6 ? 1 : 6));
    }
    await t.pumpWidget(g.view());
    v = t.widget<WolfVoteScreen>(find.byType(WolfVoteScreen));
    expect(v.players.map((p) => p.id), contains(6), reason: 'the one voted out is still on the result');
    expect(v.role, WolfText.roleNames[WolfRole.herb], reason: 'roles are shown in this game');
    await _close(t, g);
  });

  testWidgets('hidden roles: the vote result has no role part', (t) async {
    _big(t);
    final g = _Game(_roles7);
    for (final id in g.match.alive) {
      g.match.onNightPick(id, const NightPick(null));
    }
    await g.toVote(t);
    for (final id in g.match.alive) {
      g.match.onVote(id, Vote(id == 6 ? 1 : 6));
    }
    await t.pumpWidget(g.view());
    expect(t.widget<WolfVoteScreen>(find.byType(WolfVoteScreen)).role, isNull);
    await _close(t, g);
  });

  testWidgets('the night line counts the lit houses: they go out as players finish (V2WolfNight)', (t) async {
    _big(t);
    final g = _Game(_roles7);
    await t.pumpWidget(g.view());
    expect(find.textContaining(Strings.wolfLightsLeft(7)), findsOneWidget, reason: 'seven houses are lit at the start');
    g.match.onNightPick(7, const NightPick(null));
    g.match.onNightPick(6, const NightPick(null));
    await g.wait(t, 17); // the first 15 s nobody's light goes out
    await t.pumpWidget(g.view());
    expect(find.textContaining(Strings.wolfLightsLeft(5)), findsOneWidget, reason: 'two are done, five still decide');
    expect(find.textContaining(Strings.wolfLightsLeft(7)), findsNothing);
    await _close(t, g);
  });

  testWidgets('by day there is no lights line', (t) async {
    _big(t);
    final g = _Game(_roles7);
    for (final id in g.match.alive) {
      g.match.onNightPick(id, const NightPick(null));
    }
    await g.wait(t, 8);
    await t.pumpWidget(g.view());
    expect(g.match.stage, isNot(WolfStage.night));
    expect(find.textContaining('Svjetlo gori'), findsNothing);
    await _close(t, g);
  });
}
