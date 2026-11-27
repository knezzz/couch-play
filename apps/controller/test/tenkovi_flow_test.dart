import 'package:controller/app.dart';
import 'package:controller/screens/tenkovi_text.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';
import 'hold.dart';

LobbyState _lobby() => LobbyState(
  hostId: 0,
  packs: const [],
  players: [
    for (var i = 0; i < 4; i++)
      PlayerInfo(i, 'P$i', i, true, 0, character: characterIds[i]),
  ],
);

TenkoviTurn _turn({
  String stage = 'aim',
  int round = 1,
  int wind = 4,
  bool alive = true,
  int hp = 100,
  bool heavy = true,
  bool cluster = true,
  int ready = 0,
  List<int>? sent,
  List<int>? last,
  int? winner,
  int points = 0,
  int score = 0,
}) => TenkoviTurn(
  stage: stage,
  round: round,
  rounds: 3,
  map: TenkoviMap.earth,
  wind: wind,
  alive: alive,
  hp: hp,
  heavy: heavy,
  cluster: cluster,
  ready: ready,
  total: 4,
  sent: sent,
  last: last,
  winner: winner,
  points: points,
  score: score,
);

Future<void> _send(WidgetTester t, FakeConnection c, Message m) async {
  c.inbox.add(m);
  await t.pump();
  await t.pump();
}

Future<FakeConnection> _app(WidgetTester t, {Size size = const Size(360, 640)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = FakeConnection();
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(App(c));
  await _send(t, c, const Welcome(1, 1, 'tok'));
  await _send(t, c, _lobby());
  return c;
}

void main() {
  testWidgets('the aim screen: angle, power, projectile, wind, life; starts at 45 and 50', (t) async {
    final c = await _app(t);
    await _send(t, c, _turn());
    expect(find.text('Runda 1 od 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('tenkovi-wind')), findsOneWidget);
    expect(find.textContaining('→ 4'), findsOneWidget);
    expect(find.text('Život 100'), findsOneWidget);
    expect(find.byKey(const ValueKey('angle-value')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('angle-value'))).data, '45°');
    expect(t.widget<Text>(find.byKey(const ValueKey('power-value'))).data, '50');
    expect(find.byKey(const ValueKey('tenkovi-last')), findsNothing, reason: 'the first turn has no last one');
    for (final s in [TenkoviShell.grenade, TenkoviShell.heavy, TenkoviShell.cluster]) {
      expect(find.byKey(ValueKey('shell-${s.name}')), findsOneWidget);
    }
  });

  testWidgets('the screen fits a 360x640 phone with no overflow', (t) async {
    final c = await _app(t);
    await _send(t, c, _turn(last: [120, 70]));
    expect(t.takeException(), isNull);
    final fire = t.getRect(find.byKey(const ValueKey('tenkovi-fire')));
    expect(fire.bottom, lessThanOrEqualTo(640));
    expect(fire.height, greaterThanOrEqualTo(48));
  });

  testWidgets('a new turn starts from last turn\'s values, with "Prošli put"', (t) async {
    final c = await _app(t);
    await _send(t, c, _turn(last: [120, 70]));
    expect(t.widget<Text>(find.byKey(const ValueKey('angle-value'))).data, '120°');
    expect(t.widget<Text>(find.byKey(const ValueKey('power-value'))).data, '70');
    expect(find.text('Prošli put: 120°, 70'), findsOneWidget);
    // Fine steps, then back to last time.
    await t.tap(find.byKey(const ValueKey('angle-plus')));
    await t.tap(find.byKey(const ValueKey('power-minus')));
    await t.pump();
    expect(t.widget<Text>(find.byKey(const ValueKey('angle-value'))).data, '121°');
    expect(t.widget<Text>(find.byKey(const ValueKey('power-value'))).data, '69');
    await t.tap(find.byKey(const ValueKey('tenkovi-last-button')));
    await t.pump();
    expect(t.widget<Text>(find.byKey(const ValueKey('angle-value'))).data, '120°');
    expect(t.widget<Text>(find.byKey(const ValueKey('power-value'))).data, '70');
  });

  testWidgets('the steppers stop at 0 and at the top', (t) async {
    final c = await _app(t);
    await _send(t, c, _turn(last: [0, 100]));
    expect(t.widget<FilledButton>(find.byKey(const ValueKey('angle-minus'))).onPressed, isNull);
    expect(t.widget<FilledButton>(find.byKey(const ValueKey('power-plus'))).onPressed, isNull);
    expect(t.widget<FilledButton>(find.byKey(const ValueKey('angle-plus'))).onPressed, isNotNull);
  });

  testWidgets('Pucaj sends the aim once, then the phone shows the hold card, hidden until held', (t) async {
    final c = await _app(t);
    await _send(t, c, _turn(last: [120, 70]));
    await t.tap(find.byKey(const ValueKey('shell-cluster')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('tenkovi-fire')));
    await t.pump();
    expect(c.sent.whereType<TenkoviFire>().single, const TenkoviFire(120, 70, TenkoviShell.cluster));
    // A second tap does nothing.
    await t.tap(find.byKey(const ValueKey('tenkovi-fire')), warnIfMissed: false);
    expect(c.sent.whereType<TenkoviFire>().length, 1);
    // The TV answers with the phone's own aim: the card hides it.
    await _send(t, c, _turn(ready: 1, sent: [120, 70, TenkoviShell.cluster.index], last: [120, 70]));
    expect(find.byKey(const ValueKey('tenkovi-fire')), findsNothing);
    await expectHiddenUntilHeld(t, '120°, snaga 70\nKasetna');
    expect(find.textContaining('Spremno 1 od 4'), findsNothing, reason: 'only while held, like the rest of the card');
  });

  testWidgets('the hidden card looks the same on every phone: no aim, no shell, no count of rounds of anything private', (t) async {
    final c = await _app(t);
    await _send(t, c, _turn(sent: [10, 20, 0]));
    expect(find.textContaining('10°'), findsNothing);
    expect(find.textContaining('20'), findsNothing);
    expect(find.textContaining('Granata'), findsNothing);
    expect(find.byKey(const ValueKey('role-card')), findsOneWidget);
  });

  testWidgets('during the volley the card still hides the aim; a reload shows only last angle and power', (t) async {
    final c = await _app(t);
    await _send(t, c, _turn());
    await t.tap(find.byKey(const ValueKey('tenkovi-fire')));
    await t.pump();
    await _send(t, c, _turn(stage: 'fly', last: [45, 50]));
    await expectHiddenUntilHeld(t, '45°, snaga 50\nGranata');
  });

  testWidgets('a used-up special shell cannot be picked and Pucaj falls back to the Granata', (t) async {
    final c = await _app(t);
    await _send(t, c, _turn(heavy: false));
    await t.tap(find.byKey(const ValueKey('shell-heavy')), warnIfMissed: false);
    await t.pump();
    await t.tap(find.byKey(const ValueKey('tenkovi-fire')));
    await t.pump();
    expect(c.sent.whereType<TenkoviFire>().single.shell, TenkoviShell.grenade);
    expect(find.text('iskorišteno'), findsOneWidget);
  });

  testWidgets('a tank that is out sees a quiet screen, no aim controls', (t) async {
    final c = await _app(t);
    await _send(t, c, _turn(alive: false, hp: 0));
    expect(find.byKey(const ValueKey('tenkovi-fire')), findsNothing);
    expect(find.byKey(const ValueKey('tenkovi-quiet')), findsOneWidget);
  });

  testWidgets('the round over: winner, draw, points', (t) async {
    final c = await _app(t);
    await _send(t, c, _turn(stage: 'end', winner: 1, points: 3, score: 5));
    expect(find.text(TenkoviStrings.youWon), findsOneWidget);
    expect(find.text('Bodovi u rundi: +3 · Ukupno: 5'), findsOneWidget);
    await _send(t, c, _turn(stage: 'end', winner: null));
    expect(find.text(TenkoviStrings.draw), findsOneWidget);
    await _send(t, c, _turn(stage: 'end', winner: 2));
    expect(find.text(TenkoviStrings.roundOver), findsOneWidget);
  });

  testWidgets('a reload mid-turn gets the aim screen again; back in the lobby the game is forgotten', (t) async {
    final c = await _app(t);
    await _send(t, c, _turn());
    expect(find.byKey(const ValueKey('tenkovi-fire')), findsOneWidget);
    await _send(t, c, _lobby());
    expect(find.byKey(const ValueKey('tenkovi-fire')), findsNothing);
  });

  testWidgets('390x844 works too', (t) async {
    final c = await _app(t, size: const Size(390, 844));
    await _send(t, c, _turn(last: [90, 90]));
    expect(t.takeException(), isNull);
  });
}
