import 'package:controller/app.dart';
import 'package:controller/strings.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';
import 'look.dart';

// The host's way to remove a player during a game (Task 45 must-fix).

LobbyState _lobby() => LobbyState(
  hostId: 0,
  packs: const [],
  uljezPacks: const [PackInfo('a', 'Crtići', 40)],
  players: [
    for (var i = 0; i < 5; i++)
      PlayerInfo(
        i,
        'P$i',
        i,
        i != 2, // P2 has lost the connection
        0,
        bot: i == 4,
        character: characterIds[i],
      ),
  ],
);

Future<void> _send(WidgetTester t, FakeConnection c, Message m) async {
  c.inbox.add(m);
  await t.pump();
  await t.pump();
}

Future<FakeConnection> _app(WidgetTester t, int me) async {
  t.view.physicalSize = const Size(390, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = FakeConnection();
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(App(c));
  await _send(t, c, Welcome(me, me, 'tok'));
  await _send(t, c, _lobby());
  return c;
}

const _bar = ValueKey('kick-open');

const _role = RoleMsg(WolfRole.seer, [], [
  WolfRole.wolf,
  WolfRole.villager,
], hide: true);

NightPrompt _night() => NightPrompt(
  night: 1,
  text: ''.padRight(wolfTextWidth),
  choices: const ['P1', 'P2', 'P3'],
  ids: const [1, 2, 3],
  choices2: const [],
  ids2: const [],
  picks: 1,
);

void main() {
  group('Uljez', () {
    testWidgets('only the host has the bar, on the word, vote and guess', (
      t,
    ) async {
      final c = await _app(t, 0);
      await _send(t, c, const UljezWord('Pikachu'));
      expect(find.byKey(_bar), findsOneWidget);
      await _send(t, c, const VotePrompt(day: 1, seconds: 0, ids: [1, 2, 3]));
      expect(find.byKey(_bar), findsOneWidget);
      await _send(t, c, const UljezGuess(seconds: 0, options: ['a', 'b']));
      expect(find.byKey(_bar), findsOneWidget);
      final g = await _app(t, 1);
      await _send(t, g, const UljezWord('Pikachu'));
      expect(find.byKey(_bar), findsNothing);
    });

    testWidgets('the bar names how many are away', (t) async {
      final c = await _app(t, 0);
      await _send(t, c, const UljezWord('Pikachu'));
      expect(find.text(Strings.removeAway(1)), findsOneWidget);
    });

    testWidgets('the list has the others (no bots), the away one marked', (
      t,
    ) async {
      final c = await _app(t, 0);
      await _send(t, c, const UljezWord('Pikachu'));
      await t.tap(find.byKey(_bar));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('kick-0')), findsNothing);
      expect(find.byKey(const ValueKey('kick-4')), findsNothing);
      for (final id in [1, 2, 3]) {
        expect(find.byKey(ValueKey('kick-$id')), findsOneWidget);
      }
      expect(find.text(Strings.noConnection), findsOneWidget);
    });

    testWidgets('Ukloni after the confirm sends Kick; Zadrži sends nothing', (
      t,
    ) async {
      final c = await _app(t, 0);
      await _send(t, c, const UljezWord('Pikachu'));
      await t.tap(find.byKey(_bar));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('kick-2')));
      await t.pumpAndSettle();
      expect(find.text(Strings.removeTitle('P2')), findsOneWidget);
      expect(c.sent.whereType<Kick>(), isEmpty, reason: 'not before the yes');
      await t.tap(find.text(Strings.keep));
      await t.pumpAndSettle();
      expect(c.sent.whereType<Kick>(), isEmpty);
      await t.tap(find.byKey(_bar));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('kick-2')));
      await t.pumpAndSettle();
      await t.tap(find.text(Strings.remove));
      await t.pumpAndSettle();
      expect(c.sent.last, const Kick(2));
    });

    testWidgets('no bar once the game is over', (t) async {
      final c = await _app(t, 0);
      await _send(t, c, const UljezWord('Pikachu'));
      await _send(t, c, const UljezEnd(UljezWinner.village, 'a', 'b', [1]));
      expect(find.byKey(_bar), findsNothing);
    });
  });

  group('Vukodlak', () {
    testWidgets('by day and at the vote, not at night, not before it', (
      t,
    ) async {
      final c = await _app(t, 0);
      await _send(t, c, _role);
      expect(find.byKey(_bar), findsNothing, reason: 'game start');
      await _send(t, c, _night());
      expect(find.byKey(_bar), findsNothing, reason: 'night');
      await _send(t, c, const Morning(1, 'Nitko nije umro.'));
      expect(find.byKey(_bar), findsOneWidget, reason: 'day');
      await _send(t, c, const VotePrompt(day: 1, seconds: 0, ids: [1, 2, 3]));
      expect(find.byKey(_bar), findsOneWidget, reason: 'vote');
      await _send(t, c, _night());
      expect(find.byKey(_bar), findsNothing, reason: 'next night');
      await _send(t, c, const Farewell(seconds: 0, ids: [1, 2]));
      expect(find.byKey(_bar), findsNothing, reason: 'farewell');
    });

    testWidgets('a guest never has it', (t) async {
      final c = await _app(t, 1);
      await _send(t, c, _role);
      await _send(t, c, const Morning(1, 'Nitko nije umro.'));
      expect(find.byKey(_bar), findsNothing);
      await _send(t, c, const VotePrompt(day: 1, seconds: 0, ids: [0, 2, 3]));
      expect(find.byKey(_bar), findsNothing);
    });

    testWidgets('the night screen of the host looks like a guest\'s', (
      t,
    ) async {
      final h = await _app(t, 0);
      await _send(t, h, _role);
      await _send(t, h, _night());
      final host = look(t, {'x'});
      final g = await _app(t, 1);
      await _send(t, g, _role);
      await _send(t, g, _night());
      expect(look(t, {'x'}), host);
    });

    testWidgets('the day card says DAN, the night card NOĆ', (t) async {
      final c = await _app(t, 1);
      await _send(t, c, _role);
      expect(find.text(Strings.night(1)), findsOneWidget);
      await _send(t, c, const Morning(2, 'Nitko nije umro.'));
      expect(find.text(Strings.day(2)), findsOneWidget);
      expect(find.textContaining('NOĆ'), findsNothing);
    });

    testWidgets('a kick on the day vote sends Kick', (t) async {
      final c = await _app(t, 0);
      await _send(t, c, _role);
      await _send(t, c, const VotePrompt(day: 1, seconds: 0, ids: [1, 2, 3]));
      await t.tap(find.byKey(_bar));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('kick-2')));
      await t.pumpAndSettle();
      await t.tap(find.text(Strings.remove));
      await t.pumpAndSettle();
      expect(c.sent.last, const Kick(2));
    });

    testWidgets('night closes an open kick list and an open confirm', (
      t,
    ) async {
      final c = await _app(t, 0);
      await _send(t, c, _role);
      await _send(t, c, const Morning(1, 'Nitko nije umro.'));
      await t.tap(find.byKey(_bar));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('kick-2')), findsOneWidget);
      await _send(t, c, _night());
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('kick-2')), findsNothing);
      // The confirm too.
      await _send(t, c, const Morning(2, 'Nitko nije umro.'));
      await t.tap(find.byKey(_bar));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('kick-2')));
      await t.pumpAndSettle();
      expect(find.text(Strings.remove), findsOneWidget);
      await _send(t, c, _night());
      await t.pumpAndSettle();
      expect(find.text(Strings.remove), findsNothing);
      expect(c.sent.whereType<Kick>(), isEmpty);
    });
  });
}
