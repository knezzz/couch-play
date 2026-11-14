import 'package:controller/app.dart';
import 'package:controller/screens/lobby_screen.dart';
import 'package:controller/screens/quiz_screen.dart';
import 'package:controller/screens/results_screen.dart';
import 'package:controller/strings.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

const _wide = 'WWWWWWWWWWWWWWWW';

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(360, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

LobbyState _lobby() => const LobbyState(
  hostId: 0,
  packs: [PackInfo('g', 'Opće znanje s dugim imenom paketa pitanja', 50)],
  players: [
    PlayerInfo(0, _wide, 0, true, 0),
    PlayerInfo(1, _wide, 1, false, 0),
    PlayerInfo(2, 'Ana', 2, true, 0),
  ],
);

void main() {
  testWidgets('Croatian host lobby fits at 360 px with 16-letter names', (
    t,
  ) async {
    _phone(t);
    await t.pumpWidget(
      MaterialApp(
        home: LobbyScreen(
          FakeConnection(),
          _lobby(),
          0,
          addPack: (_) async => null,
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'Croatian guest lobby fits (long host name in the waiting line)',
    (t) async {
      _phone(t);
      await t.pumpWidget(
        MaterialApp(home: LobbyScreen(FakeConnection(), _lobby(), 2)),
      );
      expect(t.takeException(), isNull);
      expect(find.text(Strings.waitingForHost(_wide)), findsOneWidget);
    },
  );

  testWidgets('kick sheet, quiz and results fit at 360 px in Croatian', (
    t,
  ) async {
    _phone(t);
    final c = FakeConnection();
    await t.pumpWidget(MaterialApp(home: LobbyScreen(c, _lobby(), 0)));
    await t.tap(find.widgetWithText(TextButton, Strings.remove).first);
    await t.pumpAndSettle();
    expect(find.text(Strings.removeTitle(_wide)), findsOneWidget);
    expect(t.takeException(), isNull);

    const q = QuizQuestion(10, 10, [
      'Prvi odgovor',
      'Drugi odgovor',
      'Treći odgovor',
      'Četvrti odgovor',
    ], 20);
    await t.pumpWidget(MaterialApp(home: QuizScreen(c, q, null, total: 12345)));
    expect(t.takeException(), isNull);
    await t.pumpWidget(
      MaterialApp(
        home: QuizScreen(c, q, const QuizReveal(0, 0, 12345), total: 12345),
      ),
    );
    expect(find.text(Strings.notThisTime), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(
      MaterialApp(home: ResultsScreen(const [Placement(0, 8, 0, 11)], 0)),
    );
    expect(find.text(Strings.placed(8)), findsOneWidget);
    expect(find.text(Strings.sessionPoints(11)), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('join, kicked and crashed screens fit at 360 px in Croatian', (
    t,
  ) async {
    _phone(t);
    final c = FakeConnection();
    await t.pumpWidget(App(c));
    expect(t.takeException(), isNull);
    c.inbox.add(const Welcome(0, 0, 'tok'));
    await t.pump();
    await t.pump();
    c.inbox.add(const Kicked());
    await t.pump();
    await t.pump();
    expect(find.text(Strings.removed), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  test('Croatian plural of "bod"', () {
    expect(
      [1, 2, 4, 5, 11, 12, 14, 21, 22, 25, 101].map(Strings.points).toList(),
      [
        'bod',
        'boda',
        'boda',
        'bodova',
        'bodova',
        'bodova',
        'bodova',
        'bod',
        'boda',
        'bodova',
        'bod',
      ],
    );
  });
}
