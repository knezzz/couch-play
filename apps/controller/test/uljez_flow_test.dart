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

  testWidgets('the vote and the guess show no clock', (t) async {
    final c = await _app(t);
    await _send(t, c, const UljezWord('Pikachu'));
    await _send(t, c, const VotePrompt(day: 1, seconds: 0, ids: [0, 2]));
    expect(find.text('GLASANJE'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(find.text('GLASANJE'), findsOneWidget);
    await _send(t, c, const UljezGuess(seconds: 0, options: ['a', 'b']));
    expect(find.text('POGAĐANJE'), findsOneWidget);
  });

  testWidgets('the word card shows the stage Tragovi', (t) async {
    final c = await _app(t);
    await _send(t, c, const UljezWord('Pikachu'));
    await _send(
      t,
      c,
      const UljezTurn(round: 2, speaker: 0, seconds: 0, stage: 'clues'),
    );
    expect(find.text('Tragovi'), findsOneWidget);
    expect(find.text(Strings.uljezRound(2)), findsOneWidget);
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

    Future<void> openPacks(WidgetTester t) async {
      await t.tap(find.byKey(const ValueKey('open-uljezOffPacks')));
      await t.pumpAndSettle();
    }

    testWidgets('a pack pick sends the whole settings', (t) async {
      final c = await host(
        t,
        const GameSettings(
          quizSeconds: 25,
          curveCountdown: 60,
          kolikoSeconds: 120,
        ),
      );
      await openPacks(t);
      expect(c.sent.last, const PackScreen(true));
      await t.tap(find.byKey(const ValueKey('pack-b')));
      await t.pumpAndSettle();
      final s = (c.sent.last as SetSettings).settings;
      expect(s.uljezOffPacks, {'b'});
      expect((s.quizSeconds, s.curveCountdown, s.kolikoSeconds), (25, 60, 120));
    });

    bool ticked(WidgetTester t, String id) =>
        t
            .widget<Icon>(
              find.descendant(
                of: find.byKey(ValueKey('pack-$id')),
                matching: find.byType(Icon),
              ),
            )
            .icon ==
        Icons.check_box;

    testWidgets('every pack starts ticked, the row says Svi paketi', (t) async {
      await host(t, const GameSettings());
      expect(
        t.widget<Text>(find.byKey(const ValueKey('banner-meta'))).data,
        contains(Strings.allPacks),
      );
      await openPacks(t);
      expect([ticked(t, 'a'), ticked(t, 'b')], [true, true]);
    });

    testWidgets('one switched off: the others stay, a new pack is ticked', (
      t,
    ) async {
      // 'a' was switched off; the lobby also has 'b', which the TV added later.
      await host(t, const GameSettings(uljezOffPacks: {'a'}));
      await openPacks(t);
      expect([ticked(t, 'a'), ticked(t, 'b')], [false, true]);
    });

    testWidgets('a tick on the last ticked pack sends nothing and says why', (
      t,
    ) async {
      final c = await host(t, const GameSettings(uljezOffPacks: {'a'}));
      await openPacks(t);
      final before = c.sent.length;
      await t.tap(find.byKey(const ValueKey('pack-b')));
      await t.pump();
      expect(c.sent.length, before);
      expect(find.text(Strings.lastPackStays), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pack-a')));
      expect((c.sent.last as SetSettings).settings.uljezOffPacks, isEmpty);
    });

    testWidgets('2 impostors (7-8 players) go out; no discussion row', (
      t,
    ) async {
      final c = await host(t, const GameSettings(), players: 7);
      expect(find.byKey(const ValueKey('discuss-more')), findsNothing);
      await t.tap(find.byKey(const ValueKey('inc-uljezImpostors')));
      expect((c.sent.last as SetSettings).settings.uljezImpostors, 2);
    });

    testWidgets('with 6 players there is no second impostor to step to', (
      t,
    ) async {
      await host(t, const GameSettings(), players: 6);
      expect(
        t
            .widget<IconButton>(find.byKey(const ValueKey('inc-uljezImpostors')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('Igraj starts Uljez', (t) async {
      final c = await host(t, const GameSettings());
      await t.tap(find.byKey(const ValueKey('play')));
      expect(c.sent.last, const StartGame(GameKind.uljez, null));
    });

    testWidgets(
      'a quiz stepper and a Vukodlak switch keep the Uljez settings',
      (t) async {
        const s = GameSettings(
          uljezOffPacks: {'b'},
          kolikoSeconds: 150,
          uljezImpostors: 2,
        );
        final c = await _app(t, me: 0);
        await _send(t, c, _lobby(selected: GameKind.quiz, settings: s));
        await t.tap(find.byKey(const ValueKey('inc-quizSeconds')));
        var n = (c.sent.last as SetSettings).settings;
        expect((n.kolikoSeconds, n.uljezImpostors), (150, 2));
        expect(n.uljezOffPacks, {'b'});
        await _send(t, c, _lobby(selected: GameKind.vukodlak, settings: s));
        await t.tap(find.byKey(const ValueKey('inc-wolfHideRoles')));
        n = (c.sent.last as SetSettings).settings;
        expect((n.kolikoSeconds, n.uljezImpostors), (150, 2));
        expect(n.uljezOffPacks, {'b'});
      },
    );
  });

  group('no timers: Dao sam trag and Idemo glasati', () {
    const turn = UljezTurn(round: 1, speaker: 1, seconds: 0, stage: 'clues');

    testWidgets('only the speaker has Dao sam trag, and it sends UljezDone', (
      t,
    ) async {
      final c = await _app(t, me: 1);
      await _send(t, c, const UljezWord('Pikachu'));
      await _send(t, c, turn);
      await _send(
        t,
        c,
        const VoteWish(open: false, ready: false, want: 0, needed: 3),
      );
      // Round 1: the speaker has Dao sam trag but no Idemo glasati.
      expect(find.byKey(const ValueKey('vote-wish')), findsNothing);
      await t.tap(find.byKey(const ValueKey('clue-done')));
      expect(c.sent.last, const UljezDone());
      final o = await _app(t, me: 2);
      await _send(t, o, const UljezWord('Pikachu'));
      await _send(t, o, turn);
      await _send(
        t,
        o,
        const VoteWish(open: true, ready: false, want: 0, needed: 3),
      );
      expect(find.byKey(const ValueKey('vote-wish')), findsOneWidget);
      expect(find.byKey(const ValueKey('clue-done')), findsNothing);
    });

    testWidgets('no Idemo glasati until the TV opens it (round 1)', (t) async {
      final c = await _app(t, me: 1);
      await _send(t, c, const UljezWord('Pikachu'));
      await _send(t, c, turn);
      expect(find.byKey(const ValueKey('vote-wish')), findsNothing);
    });

    testWidgets('Idemo glasati sends the wish and shows only the TV state', (
      t,
    ) async {
      final c = await _app(t, me: 2);
      await _send(t, c, const UljezWord('Pikachu'));
      await _send(t, c, turn);
      await _send(
        t,
        c,
        const VoteWish(open: true, ready: false, want: 1, needed: 3),
      );
      expect(find.text(Strings.wishCount(1, 3)), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('vote-wish')));
      expect(c.sent.last, const ReadyToVote(true));
      // Nothing local: until the TV says so, the button is unchanged.
      expect(find.text(Strings.letsVote), findsOneWidget);
      await _send(
        t,
        c,
        const VoteWish(open: true, ready: true, want: 2, needed: 3),
      );
      expect(find.text(Strings.letsVoteOn), findsOneWidget);
      expect(find.text(Strings.wishCount(2, 3)), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('vote-wish')));
      expect(c.sent.last, const ReadyToVote(false));
    });

    testWidgets('a vote removes the button and no clock is shown', (t) async {
      final c = await _app(t, me: 2);
      await _send(t, c, const UljezWord('Pikachu'));
      await _send(
        t,
        c,
        const VoteWish(open: true, ready: true, want: 2, needed: 3),
      );
      await _send(t, c, const VotePrompt(day: 1, seconds: 0, ids: [0, 1, 3]));
      expect(find.byKey(const ValueKey('vote-wish')), findsNothing);
      // A word card after the vote must not bring the old wish back.
      await _send(
        t,
        c,
        const UljezTurn(round: 2, speaker: 0, seconds: 0, stage: 'clues'),
      );
      expect(find.byKey(const ValueKey('vote-wish')), findsNothing);
      await _send(t, c, const VotePrompt(day: 1, seconds: 0, ids: [0, 1, 3]));
      expect(find.textContaining(':'), findsNothing);
      await _send(t, c, const UljezGuess(seconds: 0, options: ['a', 'b']));
      expect(find.textContaining(':'), findsNothing);
    });
  });
}
