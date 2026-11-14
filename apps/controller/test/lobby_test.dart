import 'package:controller/app.dart';
import 'package:controller/screens/lobby_screen.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

LobbyState _lobby({int humans = 2, int bots = 0, int host = 0}) => LobbyState(
  hostId: host,
  packs: const [],
  players: [
    for (var i = 0; i < humans; i++) PlayerInfo(i, 'P$i', i, true, 0),
    for (var i = 0; i < bots; i++)
      PlayerInfo(10 + i, 'Bot ${i + 1}', humans + i, true, 0, bot: true),
  ],
);

/// The broadcast stream delivers in a microtask, so pump twice.
Future<void> _send(WidgetTester t, FakeConnection c, Message m) async {
  c.inbox.add(m);
  await t.pump();
  await t.pump();
}

Future<FakeConnection> _pump(WidgetTester t, LobbyState l, int me) async {
  final c = FakeConnection();
  await t.pumpWidget(MaterialApp(home: LobbyScreen(c, l, me)));
  return c;
}

void main() {
  testWidgets('host sees game, bots and kick controls; others do not', (
    t,
  ) async {
    await _pump(t, _lobby(), 0);
    expect(find.text('Curve'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
    expect(
      find.byIcon(Icons.person_remove),
      findsOneWidget,
    ); // not for yourself
    expect(find.byIcon(Icons.add), findsOneWidget);

    await _pump(t, _lobby(), 1);
    expect(find.text('Curve'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.person_remove), findsNothing);
    expect(find.textContaining('P0'), findsWidgets); // waiting for the host
  });

  testWidgets('bots + and - send SetBots with the right count', (t) async {
    final c = await _pump(t, _lobby(bots: 2), 0);
    await t.tap(find.byIcon(Icons.add));
    expect(c.sent.last, const SetBots(3));
    await t.tap(find.byIcon(Icons.remove));
    expect(c.sent.last, const SetBots(1));
  });

  testWidgets('bots buttons are disabled at 0 bots and at 8 seats', (t) async {
    final c = await _pump(t, _lobby(), 0);
    await t.tap(find.byIcon(Icons.remove));
    expect(c.sent, isEmpty);
    await _pump(t, _lobby(humans: 2, bots: 6), 0);
    await t.tap(find.byIcon(Icons.add));
    expect(c.sent, isEmpty);
  });

  testWidgets('Curve button sends StartGame(curve)', (t) async {
    final c = await _pump(t, _lobby(), 0);
    await t.tap(find.text('Curve'));
    expect(c.sent.last, const StartGame(GameKind.curve, null));
  });

  testWidgets('Welcome then Waiting then Kicked route the screens', (t) async {
    final c = FakeConnection();
    await t.pumpWidget(App(c));
    await _send(t, c, const Welcome(0, 0, 'tok'));
    await _send(t, c, _lobby());
    expect(find.byType(LobbyScreen), findsOneWidget);
    await _send(t, c, const Waiting('Next game starts soon.'));
    expect(find.text('Next game starts soon.'), findsOneWidget);
    await _send(t, c, const Kicked());
    expect(find.text('You were removed from the game.'), findsOneWidget);
    expect(find.text('Join again'), findsOneWidget);
  });

  testWidgets('CurveStatus opens the curve screen; ErrorMsg is shown', (
    t,
  ) async {
    final c = FakeConnection();
    await t.pumpWidget(App(c));
    await _send(t, c, const Welcome(0, 0, 'tok'));
    await _send(t, c, _lobby());
    await _send(
      t,
      c,
      const ErrorMsg(
        'Curve needs at least 2 players. Add a bot or ask a friend to join.',
      ),
    );
    expect(
      find.textContaining('Curve needs at least 2 players'),
      findsOneWidget,
    );
    await _send(t, c, const CurveStatus(alive: true, score: 0, target: 20));
    expect(find.text('◀'), findsOneWidget);
    await t.pumpWidget(const SizedBox()); // stop the ping timer
  });
}
