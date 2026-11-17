import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/uljez_match.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/tv_theme.dart';
import 'package:tv/ui/uljez/uljez_screen.dart';
import 'package:tv/ui/uljez/uljez_view.dart';

const _pack = UljezPack('p', 'Probni', [
  WordPair('Lubenica', 'Dinja'),
  WordPair('Pas', 'Vuk'),
  WordPair('Kava', 'Čaj'),
  WordPair('Zagreb', 'Split'),
  WordPair('Nogomet', 'Rukomet'),
]);

class _Game {
  _Game({int n = 4, int impostors = 1}) {
    match = UljezMatch(
      ids: [for (var i = 1; i <= n; i++) i],
      pack: _pack,
      settings: GameSettings(uljezDiscussion: 30, uljezImpostors: impostors),
      send: (_, _) {},
      clock: () => at,
      random: Random(2),
    )..start();
    players = [for (var i = 1; i <= n; i++) PlayerInfo(i, 'Ime$i', i - 1, true, 0, character: characterIds[i - 1])];
  }
  late final UljezMatch match;
  late final List<PlayerInfo> players;
  Duration at = Duration.zero;

  // The test knows the secret; the view must not.
  // ignore: invalid_use_of_visible_for_testing_member
  int get impostor => match.ids.firstWhere((i) => match.game.isImpostor(i));

  Future<void> wait(WidgetTester t, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await t.pump(const Duration(seconds: 1));
      at += const Duration(seconds: 1);
    }
  }

  Widget view() => MaterialApp(theme: tvTheme(), home: UljezView(match: match, players: players));
}

void _big(WidgetTester t) {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Iterable<String> _wordsOnScreen(WidgetTester t) sync* {
  for (final w in t.widgetList<Text>(find.byType(Text))) {
    final s = w.data ?? w.textSpan?.toPlainText() ?? '';
    for (final p in _pack.pairs) {
      for (final word in [p.a, p.b]) {
        if (s.contains(word)) yield '$word in "$s"';
      }
    }
  }
}

Future<void> _close(WidgetTester t, _Game g) async {
  await t.pumpWidget(const SizedBox());
  g.match.dispose();
  await t.pump();
}

void main() {
  testWidgets('clues: a seat for each player, the speaker is up, and no word is on screen', (t) async {
    _big(t);
    final g = _Game();
    await t.pumpWidget(g.view());
    final speaker = g.match.speaker!;
    expect(find.byType(UljezScreen), findsOneWidget);
    expect(find.text(Strings.uljezClueFor('Ime$speaker')), findsOneWidget);
    expect(find.text(Strings.uljezRoundClues(1)), findsOneWidget);
    expect(find.text('0:20'), findsOneWidget);
    expect(find.byKey(const ValueKey('turn-ring')), findsOneWidget);
    for (var i = 1; i <= 4; i++) {
      expect(find.byKey(ValueKey('seat-$i')), findsOneWidget);
    }
    expect(_wordsOnScreen(t), isEmpty);
    await _close(t, g);
  });

  testWidgets('the turn moves on after 20 s: the next speaker is up and the one before is ticked; still no word', (t) async {
    _big(t);
    final g = _Game();
    final first = g.match.speaker!;
    await g.wait(t, 21);
    await t.pumpWidget(g.view());
    final second = g.match.speaker!;
    expect(second, isNot(first));
    expect(find.text(Strings.uljezClueFor('Ime$second')), findsOneWidget);
    expect(find.descendant(of: find.byKey(ValueKey('seat-$first')), matching: find.text(Strings.uljezSaidClue)), findsOneWidget);
    expect(_wordsOnScreen(t), isEmpty);
    await _close(t, g);
  });

  testWidgets('discussion and vote screens show no word either, and how many have voted', (t) async {
    _big(t);
    final g = _Game();
    await g.wait(t, 4 * 2 * 20 + 1); // two rounds of four 20 s turns
    await t.pumpWidget(g.view());
    expect(g.match.phase, UljezPhase.discussion);
    expect(find.text(Strings.uljezWho), findsOneWidget);
    expect(_wordsOnScreen(t), isEmpty);
    await g.wait(t, 31);
    expect(g.match.phase, UljezPhase.vote);
    g.match.onVote(1, const Vote(2));
    await t.pumpWidget(g.view());
    expect(find.text(Strings.uljezVoted(1, 4)), findsOneWidget);
    expect(_wordsOnScreen(t), isEmpty);
    await _close(t, g);
  });

  testWidgets('a caught impostor: the table shows the votes and who is being asked to guess, still no word', (t) async {
    _big(t);
    final g = _Game();
    await g.wait(t, 4 * 2 * 20 + 1 + 31);
    final imp = g.impostor;
    for (final id in g.match.alive) {
      g.match.onVote(id, Vote(id == imp ? (imp % 4) + 1 : imp));
    }
    await t.pumpWidget(g.view());
    expect(g.match.phase, UljezPhase.guess);
    expect(find.text(Strings.uljezCaught('Ime$imp')), findsOneWidget);
    expect(find.text(Strings.uljezGuesses('Ime$imp')), findsOneWidget);
    expect(find.byKey(const ValueKey('impostor-ring')), findsOneWidget);
    expect(find.text(Strings.uljezVotes(3)), findsOneWidget, reason: 'the three others voted for them');
    expect(_wordsOnScreen(t), isEmpty, reason: 'the words wait for the end');
    await _close(t, g);
  });

  testWidgets('the end: both words, the impostor marked, who won', (t) async {
    _big(t);
    final g = _Game();
    await g.wait(t, 4 * 2 * 20 + 1 + 31);
    final imp = g.impostor;
    for (final id in g.match.alive) {
      g.match.onVote(id, Vote(id == imp ? (imp % 4) + 1 : imp));
    }
    // ignore: invalid_use_of_visible_for_testing_member
    final wrong = g.match.game.guessOptions.indexWhere((w) => w != g.match.game.villageWord);
    g.match.onGuess(imp, Guess(wrong));
    await t.pumpWidget(g.view());
    expect(g.match.phase, UljezPhase.over);
    expect(find.text(Strings.uljezVillageWins), findsOneWidget);
    expect(find.byKey(const ValueKey('words')), findsOneWidget);
    expect(find.text(g.match.villageWord!), findsOneWidget);
    expect(find.text(g.match.impostorWord!), findsOneWidget);
    expect(find.descendant(of: find.byKey(ValueKey('seat-$imp')), matching: find.text(Strings.uljezTag)), findsOneWidget);
    await _close(t, g);
  });

  testWidgets('two impostors: a villager is voted out; the votes stay up a few seconds, then the next vote starts', (t) async {
    _big(t);
    final g = _Game(n: 7, impostors: 2);
    await g.wait(t, 7 * 2 * 20 + 1 + 31);
    expect(g.match.phase, UljezPhase.vote);
    await t.pumpWidget(g.view()); // the TV is already showing the vote
    // ignore: invalid_use_of_visible_for_testing_member
    final villager = g.match.ids.firstWhere((i) => !g.match.game.isImpostor(i));
    for (final id in g.match.alive) {
      g.match.onVote(id, Vote(id == villager ? g.match.ids.firstWhere((i) => i != villager) : villager));
    }
    await t.pumpWidget(g.view());
    expect(g.match.phase, UljezPhase.vote, reason: 'the second vote');
    expect(find.text(Strings.uljezNotImpostor('Ime$villager')), findsOneWidget);
    expect(find.text(Strings.uljezVotes(6)), findsOneWidget, reason: 'six voted for them');
    await g.wait(t, 8);
    await t.pumpWidget(g.view());
    expect(find.text(Strings.uljezNotImpostor('Ime$villager')), findsNothing);
    expect(find.text(Strings.uljezWho), findsOneWidget);
    await _close(t, g);
  });
}
