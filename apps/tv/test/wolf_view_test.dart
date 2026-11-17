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

  testWidgets('the vote: the vote screen with how many have voted, and nothing about who voted for whom', (t) async {
    _big(t);
    final g = _Game(_roles7);
    for (final id in g.match.alive) {
      g.match.onNightPick(id, const NightPick(null));
    }
    await g.wait(t, 5); // morning, nobody died
    await g.wait(t, 125); // the day passes
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
    await g.wait(t, 130); // morning, the day, then the vote
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

  testWidgets('a held vote result shows the real x of y (someone did not vote) and no clock', (t) async {
    _big(t);
    final g = _Game(_roles7);
    for (final id in g.match.alive) {
      g.match.onNightPick(id, const NightPick(null));
    }
    await g.wait(t, 130);
    expect(g.match.stage, WolfStage.vote);
    for (final id in [1, 2, 3, 4, 5]) {
      g.match.onVote(id, const Vote(6));
    }
    await t.pumpWidget(g.view());
    await g.wait(t, 25); // 6 and 7 never vote: the vote times out (30 s after it began, ~7 s were already gone)
    expect(g.match.lastOut, 6);
    final v = t.widget<WolfVoteScreen>(find.byType(WolfVoteScreen));
    expect(v.voted, 5);
    expect(v.expected, 7);
    expect(v.clock, isEmpty);
    expect(find.text(Strings.wolfVoted(5, 7)), findsOneWidget);
    await _close(t, g);
  });
}
