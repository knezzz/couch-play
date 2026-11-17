import 'package:controller/app.dart';
import 'package:controller/strings.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';
import 'look.dart';

LobbyState _lobby({
  GameKind? selected,
  GameSettings settings = const GameSettings(),
  int players = 6,
}) => LobbyState(
  hostId: 0,
  packs: const [],
  uljezPacks: const [PackInfo('a', 'Crtići', 40), PackInfo('b', 'Hrana', 30)],
  settings: settings,
  selected: selected,
  players: [
    for (var i = 0; i < players; i++)
      PlayerInfo(i, 'P$i', i, true, 0, character: characterIds[i]),
  ],
);

Future<void> _send(WidgetTester t, FakeConnection c, Message m) async {
  c.inbox.add(m);
  await t.pump();
  await t.pump();
}

Future<FakeConnection> _app(
  WidgetTester t, {
  int me = 1,
  LobbyState? lobby,
}) async {
  t.view.physicalSize = const Size(390, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = FakeConnection();
  await t.pumpWidget(const SizedBox()); // a fresh App state per phone
  await t.pumpWidget(App(c));
  await _send(t, c, Welcome(me, me, 'tok'));
  await _send(t, c, lobby ?? _lobby());
  return c;
}

Future<void> _hold(WidgetTester t) async {
  final g = await t.startGesture(
    t.getCenter(find.byKey(const ValueKey('role-card'))),
  );
  await t.pump();
  addTearDown(() => g.up());
}

void main() {
  testWidgets('UljezWord shows the card; the word only while held', (t) async {
    final c = await _app(t);
    await _send(t, c, const UljezWord('Pikachu'));
    expect(find.text(Strings.holdHere), findsOneWidget);
    expect(find.text('Pikachu'), findsNothing);
    await _hold(t);
    expect(find.text('Pikachu'), findsOneWidget);
  });

  testWidgets('an impostor phone and a village phone look the same', (t) async {
    Future<String> phone(String word) async {
      final c = await _app(t);
      await _send(
        t,
        c,
        const UljezTurn(round: 1, speaker: 2, seconds: 20, stage: 'clues'),
      );
      await _send(t, c, UljezWord(word));
      return look(t, {word});
    }

    await phone('x');
    expect(await phone('Pas'), await phone('Mačka'));
  });

  testWidgets('the vote goes out as Vote, once', (t) async {
    final c = await _app(t);
    await _send(t, c, const UljezWord('Pikachu'));
    await _send(t, c, const VotePrompt(day: 1, seconds: 20, ids: [0, 2, 3]));
    expect(find.text(Strings.whoIsImpostor), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('night-2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    expect(c.sent.last, const Vote(2));
    await t.tap(find.byKey(const ValueKey('night-3')));
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    expect(c.sent.whereType<Vote>().length, 1);
  });

  testWidgets('after a reload the vote shows the pick the TV already has', (
    t,
  ) async {
    final c = await _app(t);
    await _send(t, c, const UljezWord('Pikachu'));
    await _send(
      t,
      c,
      const VotePrompt(day: 1, seconds: 20, ids: [0, 2, 3], picked: 3),
    );
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    expect(c.sent.last, const Vote(3));
  });

  testWidgets('you cannot vote for yourself: the row is greyed and refuses', (
    t,
  ) async {
    final c = await _app(t, me: 1);
    await _send(t, c, const UljezWord('Pikachu'));
    await _send(t, c, const VotePrompt(day: 1, seconds: 20, ids: [0, 1, 2]));
    expect(find.text(Strings.you), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('night-1')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    expect(c.sent.whereType<Vote>(), isEmpty, reason: 'nothing picked');
    final dim = t.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('night-1')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(dim.opacity, lessThan(1));
    await t.tap(find.byKey(const ValueKey('night-2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    expect(c.sent.last, const Vote(2));
  });

  testWidgets('you cannot vote for yourself: the row is greyed and refuses', (
    t,
  ) async {
    final c = await _app(t, me: 1);
    await _send(t, c, const UljezWord('Pikachu'));
    await _send(t, c, const VotePrompt(day: 1, seconds: 20, ids: [0, 1, 2]));
    expect(find.text(Strings.you), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('night-1')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    expect(c.sent.whereType<Vote>(), isEmpty, reason: 'nothing picked');
    final dim = t.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('night-1')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(dim.opacity, lessThan(1));
    await t.tap(find.byKey(const ValueKey('night-2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    expect(c.sent.last, const Vote(2));
  });

  testWidgets('the vote and the guess show a clock that counts down', (
    t,
  ) async {
    final c = await _app(t);
    await _send(t, c, const UljezWord('Pikachu'));
    await _send(t, c, const VotePrompt(day: 1, seconds: 20, ids: [0, 2]));
    expect(find.text('GLASANJE · 0:20'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(find.text('GLASANJE · 0:17'), findsOneWidget);
    await _send(
      t,
      c,
      const UljezGuess(seconds: 15, options: ['a', 'b', 'c', 'd']),
    );
    expect(find.text('POGAĐANJE · 0:15'), findsOneWidget);
  });

  testWidgets('the word card shows the stage: Tragovi, then Rasprava', (
    t,
  ) async {
    final c = await _app(t);
    await _send(t, c, const UljezWord('Pikachu'));
    await _send(
      t,
      c,
      const UljezTurn(round: 2, speaker: 0, seconds: 20, stage: 'clues'),
    );
    expect(find.text('Tragovi'), findsOneWidget);
    expect(find.text(Strings.uljezRound(2)), findsOneWidget);
    await _send(
      t,
      c,
      const UljezTurn(
        round: 2,
        speaker: null,
        seconds: 90,
        stage: 'discussion',
      ),
    );
    expect(find.text('Rasprava'), findsOneWidget);
    expect(find.text('Tragovi'), findsNothing);
  });

  testWidgets('the next turn after a vote brings the word card back', (
    t,
  ) async {
    final c = await _app(t);
    await _send(t, c, const UljezWord('Pikachu'));
    await _send(t, c, const VotePrompt(day: 1, seconds: 20, ids: [0, 2]));
    await _send(
      t,
      c,
      const UljezTurn(round: 2, speaker: 0, seconds: 20, stage: 'clues'),
    );
    expect(find.text(Strings.holdHere), findsOneWidget);
    expect(find.text(Strings.uljezRound(2)), findsOneWidget);
  });

  testWidgets('the guess shows the word and goes out as Guess(index)', (
    t,
  ) async {
    final c = await _app(t);
    await _send(t, c, const UljezWord('Pikachu'));
    await _send(
      t,
      c,
      const UljezGuess(
        seconds: 15,
        options: ['Spužva Bob', 'Patrik', 'Garfield', 'Scooby-Doo'],
      ),
    );
    expect(find.text(Strings.caughtHint('Pikachu')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('night-2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    expect(c.sent.last, const Guess(2));
  });

  testWidgets('UljezEnd shows the words and who the impostors were', (t) async {
    final c = await _app(t);
    await _send(t, c, const UljezWord('Pikachu'));
    await _send(
      t,
      c,
      const UljezEnd(UljezWinner.village, 'Spužva Bob', 'Pikachu', [3]),
    );
    expect(find.text(Strings.uljezWinner(UljezWinner.village)), findsOneWidget);
    expect(find.text('Spužva Bob'), findsOneWidget);
    expect(find.text('P3'), findsOneWidget);
  });

  testWidgets('VotePrompt goes to the game that started last', (t) async {
    final c = await _app(t);
    await _send(t, c, const UljezWord('Pikachu'));
    await _send(t, c, const VotePrompt(day: 1, seconds: 20, ids: [0, 2]));
    expect(find.text(Strings.whoIsImpostor), findsOneWidget);
    await _send(
      t,
      c,
      const RoleMsg(WolfRole.seer, [], [
        WolfRole.wolf,
        WolfRole.villager,
      ], hide: true),
    );
    await _send(t, c, const VotePrompt(day: 1, seconds: 60, ids: [0, 2]));
    expect(find.text(Strings.voteTitle), findsOneWidget);
  });

  group('host settings', () {
    Future<FakeConnection> host(
      WidgetTester t,
      GameSettings s, {
      int players = 6,
    }) async {
      final c = await _app(t, me: 0, lobby: _lobby(players: players));
      await _send(
        t,
        c,
        _lobby(selected: GameKind.uljez, settings: s, players: players),
      );
      return c;
    }

    testWidgets('a pack pick sends the whole settings', (t) async {
      final c = await host(
        t,
        const GameSettings(
          quizSeconds: 25,
          wolfDiscussion: 60,
          uljezDiscussion: 120,
        ),
      );
      await t.ensureVisible(find.byKey(const ValueKey('uljez-pack')));
      await t.tap(find.byKey(const ValueKey('uljez-pack')));
      await t.pumpAndSettle();
      await t.tap(find.text('Hrana').last);
      await t.pumpAndSettle();
      final s = (c.sent.last as SetSettings).settings;
      expect(s.uljezPackId, 'b');
      expect(
        (s.quizSeconds, s.wolfDiscussion, s.uljezDiscussion),
        (25, 60, 120),
      );
    });

    testWidgets('discussion time and 2 impostors (7-8 players) go out', (
      t,
    ) async {
      final c = await host(t, const GameSettings(), players: 7);
      await t.ensureVisible(find.byKey(const ValueKey('discuss-more')));
      await t.tap(find.byKey(const ValueKey('discuss-more')));
      expect((c.sent.last as SetSettings).settings.uljezDiscussion, 120);
      await t.ensureVisible(find.byKey(const ValueKey('impostors-2')));
      await t.tap(find.byKey(const ValueKey('impostors-2')));
      expect((c.sent.last as SetSettings).settings.uljezImpostors, 2);
    });

    testWidgets('Igraj starts Uljez', (t) async {
      final c = await host(t, const GameSettings());
      await t.ensureVisible(find.text(Strings.play));
      await t.tap(find.text(Strings.play));
      expect(c.sent.last, const StartGame(GameKind.uljez, null));
    });

    testWidgets(
      'a quiz stepper and a Vukodlak switch keep the Uljez settings',
      (t) async {
        const s = GameSettings(
          uljezPackId: 'b',
          uljezDiscussion: 150,
          uljezImpostors: 2,
        );
        final c = await _app(t, me: 0);
        await _send(t, c, _lobby(selected: GameKind.quiz, settings: s));
        await t.tap(find.byTooltip(Strings.moreOf(Strings.quizSeconds)));
        var n = (c.sent.last as SetSettings).settings;
        expect(
          (n.uljezPackId, n.uljezDiscussion, n.uljezImpostors),
          ('b', 150, 2),
        );
        await _send(t, c, _lobby(selected: GameKind.vukodlak, settings: s));
        await t.ensureVisible(find.byKey(const ValueKey('hidden-roles')));
        await t.tap(find.byKey(const ValueKey('hidden-roles')));
        n = (c.sent.last as SetSettings).settings;
        expect(
          (n.uljezPackId, n.uljezDiscussion, n.uljezImpostors),
          ('b', 150, 2),
        );
      },
    );
  });
}
