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

    testWidgets('the host not guessing sees Waiting and keeps the bar', (
      t,
    ) async {
      final c = await _app(t, 0);
      await _send(t, c, const Waiting('Pogađa riječ'));
      expect(find.byKey(_bar), findsNothing, reason: 'no Uljez yet');
      await _send(t, c, const UljezWord('Pikachu'));
      await _send(t, c, const VotePrompt(day: 1, seconds: 0, ids: [1, 2, 3]));
      await _send(t, c, const Waiting('Pogađa riječ'));
      expect(find.text('Pogađa riječ'), findsOneWidget);
      expect(find.byKey(_bar), findsOneWidget);
      await _send(t, c, _lobby());
      await _send(t, c, const Waiting('Čekaj'));
      expect(find.byKey(_bar), findsNothing, reason: 'another game');
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

    testWidgets('GamePlayers: kicked and dead are gone, a return is seen', (
      t,
    ) async {
      final c = await _app(t, 0);
      await _send(t, c, const UljezWord('Pikachu'));
      PlayerInfo p(int i, bool on) => PlayerInfo(i, 'P$i', i, on, 0);
      // P3 was kicked; P2 is still away, P1 has just dropped.
      await _send(t, c, GamePlayers([p(0, true), p(1, false), p(2, false)]));
      expect(find.text(Strings.removeAway(2)), findsOneWidget);
      await t.tap(find.byKey(_bar));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('kick-3')), findsNothing);
      expect(find.byKey(const ValueKey('kick-1')), findsOneWidget);
      expect(find.text(Strings.noConnection), findsNWidgets(2));
      // P2 comes back.
      await _send(t, c, GamePlayers([p(0, true), p(1, false), p(2, true)]));
      await t.pumpAndSettle();
      expect(find.text(Strings.noConnection), findsOneWidget);
      await t.tapAt(const Offset(10, 10)); // the barrier closes the list
      await t.pumpAndSettle();
      // The next lobby state is the truth again.
      await _send(t, c, _lobby());
      await _send(t, c, const UljezWord('Pikachu'));
      await t.tap(find.byKey(_bar));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('kick-3')), findsOneWidget);
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

    testWidgets('on the Spreman screen the host has the kick bar, a guest not', (
      t,
    ) async {
      final host = await _app(t, 0);
      await _send(t, host, _role);
      await _send(t, host, const PlayWait(ready: false, count: 1, total: 4));
      expect(find.byKey(_bar), findsOneWidget);
      final guest = await _app(t, 1);
      await _send(t, guest, _role);
      await _send(t, guest, const PlayWait(ready: false, count: 1, total: 4));
      expect(find.byKey(_bar), findsNothing);
    });

    testWidgets('a GamePlayers at night changes nothing on the phone', (
      t,
    ) async {
      final c = await _app(t, 0);
      await _send(t, c, _role);
      await _send(t, c, _night());
      final before = look(t, {});
      await _send(
        t,
        c,
        GamePlayers([PlayerInfo(0, 'P0', 0, true, 0), PlayerInfo(1, 'P1', 1, false, 0)]),
      );
      expect(look(t, {}), before);
      expect(find.byKey(_bar), findsNothing);
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

    testWidgets('after a host kick the new host has the strip, the old not', (
      t,
    ) async {
      final n = await _app(t, 1);
      await _send(t, n, _role);
      await _send(t, n, const Morning(1, 'Nitko nije umro.'));
      expect(find.byKey(_bar), findsNothing);
      await _send(t, n, const HostIs(1));
      expect(find.byKey(_bar), findsOneWidget);
      final o = await _app(t, 0);
      await _send(t, o, _role);
      await _send(t, o, const Morning(1, 'Nitko nije umro.'));
      expect(find.byKey(_bar), findsOneWidget);
      await _send(t, o, const HostIs(1));
      expect(find.byKey(_bar), findsNothing);
    });
  });
}
