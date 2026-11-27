import 'package:controller/app.dart';
import 'package:controller/strings.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

LobbyState _lobby() => LobbyState(
  hostId: 0,
  packs: const [],
  players: [
    PlayerInfo(0, 'Petra', 0, true, 0, character: characterIds[3]),
    PlayerInfo(1, 'Luka', 1, true, 0, character: characterIds[4]),
  ],
);

Future<void> _send(WidgetTester t, FakeConnection c, Message m) async {
  c.inbox.add(m);
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('a phone that reloads in the middle of Sumo gets its header (name and face) back', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = FakeConnection();
    await t.pumpWidget(App(c, saved: SavedJoin('Petra', characterIds[3]), onSave: (_) {}));
    // What the TV sends a phone that comes back mid-round: Welcome, the lobby, then the status.
    await _send(t, c, Welcome(0, 0, 'test', character: characterIds[3]));
    await _send(t, c, _lobby());
    await _send(t, c, const CurveStatus(alive: true, score: 26, target: 70, round: 12, sumo: true));
    expect(find.text('Petra'), findsOneWidget);
    expect(find.byType(CharacterFace), findsOneWidget);
    expect(find.text(Strings.curveRoundScore(12, 26)), findsOneWidget);
    await t.pumpWidget(const SizedBox()); // the ping timer
  });

  testWidgets('with a stored name, Join goes out at once and no join screen', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = FakeConnection();
    await t.pumpWidget(
      App(c, saved: SavedJoin('Petra', characterIds[3]), onSave: (_) {}),
    );
    expect(c.sent, [Join('Petra', 'test', character: characterIds[3])]);
    expect(find.text(Strings.join), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _send(t, c, Welcome(0, 0, 'test', character: characterIds[3]));
    await _send(t, c, _lobby());
    expect(find.text(Strings.join), findsNothing);
    expect(find.text(Strings.others(1)), findsOneWidget);
  });

  testWidgets(
    'without a stored name the join screen shows and nothing is sent',
    (t) async {
      final c = FakeConnection();
      await t.pumpWidget(App(c, onSave: (_) {}));
      expect(find.text(Strings.join), findsOneWidget);
      expect(c.sent, isEmpty);
    },
  );

  testWidgets('a joined player is remembered with the name and character', (
    t,
  ) async {
    final saved = <SavedJoin?>[];
    final c = FakeConnection();
    await t.pumpWidget(App(c, onSave: saved.add));
    await _send(t, c, const Welcome(1, 1, 'test'));
    await _send(t, c, _lobby());
    expect(saved.last?.name, 'Luka');
    expect(saved.last?.character, characterIds[4]);
  });

  testWidgets('being kicked forgets the name', (t) async {
    final saved = <SavedJoin?>[];
    final c = FakeConnection();
    await t.pumpWidget(
      App(c, saved: SavedJoin('Petra', ''), onSave: saved.add),
    );
    await _send(t, c, const Welcome(0, 0, 'test'));
    await _send(t, c, const Kicked());
    expect(saved.last, isNull);
    expect(find.text(Strings.removed), findsOneWidget);
  });

  testWidgets('a refused automatic rejoin forgets the name and asks again', (
    t,
  ) async {
    final saved = <SavedJoin?>[];
    final c = FakeConnection();
    await t.pumpWidget(
      App(c, saved: SavedJoin('Petra', ''), onSave: saved.add),
    );
    await _send(t, c, const ErrorMsg('Igra je već počela.'));
    expect(saved, [null]);
    expect(find.text(Strings.join), findsOneWidget);
  });

  testWidgets('an error after a successful rejoin is only shown', (t) async {
    final saved = <SavedJoin?>[];
    final c = FakeConnection();
    await t.pumpWidget(
      App(c, saved: SavedJoin('Petra', ''), onSave: saved.add),
    );
    await _send(t, c, const Welcome(0, 0, 'test'));
    await _send(t, c, _lobby());
    saved.clear();
    await _send(t, c, const ErrorMsg('Nešto nije u redu.'));
    expect(saved, isEmpty);
    expect(find.text('Nešto nije u redu.'), findsOneWidget);
  });
}
