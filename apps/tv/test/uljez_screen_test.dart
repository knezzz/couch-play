import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/tv_theme.dart';
import 'package:tv/ui/uljez/uljez_screen.dart';

List<UljezSeat> _seats(int n, {int? turn, Set<int> done = const {}, Set<int> impostors = const {}, Map<int, List<int>> voters = const {}, Set<int> out = const {}}) => [
      for (var i = 0; i < n; i++)
        UljezSeat(
          id: i + 1,
          name: 'Ime${i + 1}',
          colorIndex: i,
          character: characterIds[i],
          turn: turn == i + 1,
          done: done.contains(i + 1),
          impostor: impostors.contains(i + 1),
          out: out.contains(i + 1),
          voters: voters[i + 1] ?? const [],
        ),
    ];

Future<void> _pump(
  WidgetTester t,
  List<UljezSeat> seats, {
  String kicker = 'RUNDA 2 · TRAGOVI',
  String headline = 'Ime3, reci trag.',
  String clockLabel = 'Za trag',
  String clock = '0:12',
  String? hint,
  String? villageWord,
  String? impostorWord,
  bool showVotes = false,
  bool reduceMotion = false,
}) async {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await t.pumpWidget(MaterialApp(
    theme: tvTheme(),
    home: UljezScreen(
      seats: seats,
      kicker: kicker,
      headline: headline,
      clockLabel: clockLabel,
      clock: clock,
      hint: hint,
      villageWord: villageWord,
      impostorWord: impostorWord,
      showVotes: showVotes,
    ),
  ));
  await t.pump();
}

Finder _face(String id) => find.byWidgetPredicate((w) => w is CharacterFace && w.id == id);

void main() {
  for (final n in [3, 5, 8]) {
    testWidgets('$n players round the table with their character and name, all on screen', (t) async {
      await _pump(t, _seats(n));
      expect(t.takeException(), isNull);
      for (var i = 0; i < n; i++) {
        final seat = find.byKey(ValueKey('seat-${i + 1}'));
        expect(find.descendant(of: seat, matching: find.text('Ime${i + 1}')), findsOneWidget);
        expect(find.descendant(of: seat, matching: _face(characterIds[i])), findsOneWidget);
        final r = t.getRect(seat);
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(1920));
        expect(r.top, greaterThanOrEqualTo(0));
        expect(r.bottom, lessThanOrEqualTo(1080));
      }
    });
  }

  testWidgets('a clue turn: the speaker is marked and told, earlier speakers are ticked, the header and clock show', (t) async {
    await _pump(t, _seats(6, turn: 3, done: {1, 2}), hint: Strings.uljezClueHint);
    expect(find.text('RUNDA 2 · TRAGOVI'), findsOneWidget);
    expect(find.text('Ime3, reci trag.'), findsOneWidget);
    expect(find.text('Za trag'), findsOneWidget);
    expect(find.text('0:12'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('seat-3')), matching: find.byKey(const ValueKey('turn-ring'))), findsOneWidget);
    expect(find.byKey(const ValueKey('turn-ring')), findsOneWidget, reason: 'only one speaker');
    expect(find.descendant(of: find.byKey(const ValueKey('seat-3')), matching: find.text(Strings.uljezNow)), findsOneWidget);
    for (final id in [1, 2]) {
      expect(find.descendant(of: find.byKey(ValueKey('seat-$id')), matching: find.text(Strings.uljezSaidClue)), findsOneWidget);
    }
    expect(find.descendant(of: find.byKey(const ValueKey('seat-4')), matching: find.text(Strings.uljezSaidClue)), findsNothing);
    expect(find.textContaining('Ne reci riječ'), findsOneWidget);
  });

  testWidgets('no word before the end: the words are only drawn when the screen is given them', (t) async {
    await _pump(t, _seats(4, turn: 1));
    expect(find.byKey(const ValueKey('words')), findsNothing);
    await _pump(t, _seats(4), villageWord: 'Spužva Bob', impostorWord: 'Pikachu');
    expect(find.byKey(const ValueKey('words')), findsOneWidget);
    expect(find.text('Spužva Bob'), findsOneWidget);
    expect(find.text('Pikachu'), findsOneWidget);
    expect(find.text(Strings.uljezVillageWord), findsOneWidget);
    expect(find.text(Strings.uljezImpostorWord), findsOneWidget);
  });

  testWidgets('the end marks the impostor on the table', (t) async {
    await _pump(t, _seats(5, impostors: {4}), villageWord: 'A', impostorWord: 'B');
    expect(find.descendant(of: find.byKey(const ValueKey('seat-4')), matching: find.text(Strings.uljezTag)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('seat-4')), matching: find.byKey(const ValueKey('impostor-ring'))), findsOneWidget);
    expect(find.text(Strings.uljezTag), findsOneWidget, reason: 'only the impostor');
  });

  testWidgets('the vote result: who voted for whom (their faces under the one they voted for) and the tally', (t) async {
    await _pump(t, _seats(5, impostors: {4}, voters: {4: [1, 2, 3, 5], 1: []}), showVotes: true, headline: Strings.uljezCaught('Ime4'));
    final seat4 = find.byKey(const ValueKey('seat-4'));
    for (final voter in [1, 2, 3, 5]) {
      expect(find.descendant(of: seat4, matching: _face(characterIds[voter - 1])), findsOneWidget, reason: 'voter $voter under seat 4');
    }
    expect(find.descendant(of: seat4, matching: find.text(Strings.uljezVotes(4))), findsOneWidget);
    // Seat 1's own face is its seat's face only: it voted for 4 and is shown there.
    expect(find.descendant(of: find.byKey(const ValueKey('seat-1')), matching: _face(characterIds[0])), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('seat-2')), matching: find.textContaining('glas')), findsNothing, reason: 'no votes, no line');
  });

  testWidgets('without showVotes there are no votes on the table', (t) async {
    await _pump(t, _seats(5, voters: {4: [1, 2]}));
    expect(find.textContaining('glas'), findsNothing);
  });

  test('vote words: 1 glas, 2-4 glasa, 5+ glasova', () {
    expect(Strings.uljezVotes(1), '1 glas');
    expect(Strings.uljezVotes(2), '2 glasa');
    expect(Strings.uljezVotes(4), '4 glasa');
    expect(Strings.uljezVotes(5), '5 glasova');
  });

  testWidgets('an out player is greyed and struck through', (t) async {
    await _pump(t, _seats(5, out: {2}));
    expect(t.widget<Text>(find.text('Ime2')).style!.decoration, TextDecoration.lineThrough);
    expect(t.widget<Text>(find.text('Ime1')).style!.decoration, isNot(TextDecoration.lineThrough));
  });

  testWidgets('the speaker pulses; reduced motion keeps still', (t) async {
    await _pump(t, _seats(4, turn: 2));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await _pump(t, _seats(4, turn: 2), reduceMotion: true);
    await t.pump(const Duration(milliseconds: 100));
    expect(t.binding.transientCallbackCount, 0);
  });

  testWidgets('8 players with all the votes and the words: nothing overflows, nothing off screen', (t) async {
    await _pump(
      t,
      _seats(8, impostors: {3}, voters: {3: [1, 2, 4, 5, 6, 7, 8]}),
      showVotes: true,
      villageWord: 'Spužva Bob i drugovi',
      impostorWord: 'Pikachu iz Pokemona',
      headline: Strings.uljezCaught('Ime3'),
    );
    expect(t.takeException(), isNull);
    for (var i = 1; i <= 8; i++) {
      final r = t.getRect(find.byKey(ValueKey('seat-$i')));
      expect(r.bottom, lessThanOrEqualTo(1060), reason: 'seat $i: the votes under the bottom seat stay on screen');
      expect(r.right, lessThanOrEqualTo(1920));
    }
  });
}
