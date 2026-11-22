import 'package:controller/app.dart';
import 'package:controller/strings.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';
import 'hold.dart';
import 'look.dart';

LobbyState _lobby({
  int me = 0,
  GameKind? selected,
  GameSettings settings = const GameSettings(),
}) => LobbyState(
  hostId: 0,
  packs: const [],
  settings: settings,
  selected: selected,
  players: [
    for (var i = 0; i < 6; i++)
      PlayerInfo(i, 'P$i', i, true, 0, character: characterIds[i]),
  ],
);

Future<void> _send(WidgetTester t, FakeConnection c, Message m) async {
  c.inbox.add(m);
  await t.pump();
  await t.pump();
}

Future<FakeConnection> _app(WidgetTester t, {int me = 1}) async {
  t.view.physicalSize = const Size(390, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = FakeConnection();
  await t.pumpWidget(const SizedBox()); // a fresh App state per phone
  await t.pumpWidget(App(c));
  await _send(t, c, Welcome(me, me, 'tok'));
  await _send(t, c, _lobby());
  return c;
}

const _role = RoleMsg(WolfRole.seer, [], [
  WolfRole.wolf,
  WolfRole.villager,
  WolfRole.seer,
], hide: true);

String _pad(String s) => s.padRight(wolfTextWidth);

NightPrompt _night({int night = 2}) => NightPrompt(
  night: night,
  text: _pad('Čiju ulogu želiš vidjeti?'),
  choices: const ['P0', 'P2', 'P3'],
  ids: const [0, 2, 3],
);

void main() {
  testWidgets('RoleMsg shows the hold screen; the role is not on it', (
    t,
  ) async {
    final c = await _app(t);
    await _send(t, c, _role);
    expect(find.text(Strings.holdHere), findsOneWidget);
    expect(find.text('Vidovnjakinja'), findsNothing);
    final g = await t.startGesture(
      t.getCenter(find.byKey(const ValueKey('role-card'))),
    );
    await t.pump();
    expect(find.text('Vidovnjakinja'), findsOneWidget);
    await g.up();
  });

  testWidgets('a night pick goes out as NightPick with the switch', (t) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(t, c, _night());
    await t.tap(find.byKey(const ValueKey('night-2')));
    await t.tap(find.byKey(const ValueKey('night-special')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    expect(c.sent.last, isA<NightPick>());
    final p = c.sent.last as NightPick;
    expect((p.target, p.special), (2, true));
  });

  const cupid = RoleMsg(WolfRole.cupid, [], [
    WolfRole.wolf,
    WolfRole.villager,
    WolfRole.cupid,
  ], hide: true);

  NightPrompt step(List<int> ids, {String hint = 'x', int? picked, int? picked2, bool done = false}) => NightPrompt(
    night: 1,
    text: _pad(hint),
    choices: [for (final i in ids) 'P$i'],
    ids: ids,
    picked: picked,
    picked2: picked2,
    done: done,
  );

  testWidgets('night 1: one list and one Potvrdi for every phone, a villager too', (t) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(t, c, _night(night: 1));
    await t.tap(find.byKey(const ValueKey('night-0')));
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    await t.pump();
    expect(find.byKey(const ValueKey('night2-0')), findsNothing);
    expect((c.sent.last as NightPick).target, 0);
    expect(find.byKey(const ValueKey('night-sent')), findsOneWidget);
  });

  testWidgets('the Provodadžija: the first Potvrdi goes straight to the second list, no sent card; the second gives the card', (t) async {
    final c = await _app(t);
    await _send(t, c, cupid);
    await _send(t, c, step([0, 1, 2, 3], hint: 'Odaberi prvog zaljubljenog.'));
    expect(
      t.widgetList<Opacity>(find.byType(Opacity)).where((o) => o.opacity < 1),
      isEmpty,
      reason: 'no row is greyed, own row included',
    );
    expect(
      t.widget<InkWell>(find.byKey(const ValueKey('night-1'))).onTap,
      isNotNull,
      reason: 'the own row looks and taps like any other; the TV refuses quietly',
    );
    await t.tap(find.byKey(const ValueKey('night-0')));
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    await t.pump();
    expect((c.sent.last as NightPick).target, 0);
    expect(find.byKey(const ValueKey('night-sent')), findsNothing, reason: 'no card in between');
    await _send(t, c, step([2, 3], hint: 'Odaberi drugog zaljubljenog.'));
    expect(find.byKey(const ValueKey('night-0')), findsNothing, reason: 'not the first pick');
    expect(find.byKey(const ValueKey('night-1')), findsNothing, reason: 'not yourself');
    await t.tap(find.byKey(const ValueKey('night-3')));
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    await t.pump();
    expect((c.sent.last as NightPick).target, 3);
    expect(c.sent.whereType<NightPick>().length, 2);
    expect(find.byKey(const ValueKey('night-sent')), findsOneWidget);
  });

  testWidgets('the Provodadžija reloads on each step', (t) async {
    var c = await _app(t);
    await _send(t, c, cupid);
    await _send(t, c, step([2, 3], hint: 'Odaberi drugog zaljubljenog.'));
    expect(find.byKey(const ValueKey('night-confirm')), findsOneWidget);
    expect(find.byKey(const ValueKey('night-sent')), findsNothing);
    expect(find.byKey(const ValueKey('night-0')), findsNothing, reason: 'second step');
    c = await _app(t);
    await _send(t, c, cupid);
    await _send(t, c, step([0, 1, 2, 3], picked: 2, picked2: 3, done: true));
    expect(find.byKey(const ValueKey('night-sent')), findsOneWidget);
    final g = await t.startGesture(t.getCenter(find.byKey(const ValueKey('night-sent'))));
    await t.pump();
    expect(find.text('P2\nP3'), findsOneWidget);
    await g.up();
  });

  testWidgets(
    '7 alive: a wolf prompt and a sum prompt (7 answers) look identical',
    (t) async {
      Future<String> phone(NightPrompt p) async {
        final c = await _app(t);
        await _send(t, c, _role);
        await _send(t, c, p);
        return look(t, {p.text.trim(), ...p.choices});
      }

      NightPrompt prompt(String text, List<String> labels) => NightPrompt(
        night: 2,
        text: _pad(text),
        choices: labels,
        ids: [for (var i = 0; i < labels.length; i++) i],
      );
      final wolf = prompt('Koga posjećujete?', [
        for (var i = 0; i < 7; i++) 'Igrač $i',
      ]);
      final sum = prompt('Koliko je 7 × 8?', [
        '54',
        '56',
        '58',
        '63',
        '49',
        '64',
        '48',
      ]);
      final five = prompt('Koliko je 7 × 8?', ['54', '56', '58', '63', '49']);
      await phone(wolf); // pointer warm-up
      expect(await phone(sum), await phone(wolf));
      expect(
        await phone(five),
        isNot(await phone(wolf)),
        reason: 'the check can fail',
      );
    },
  );

  testWidgets(
    'a reload after confirming shows Poslano with the picks, locked',
    (t) async {
      final c = await _app(t);
      await _send(t, c, _role);
      await _send(
        t,
        c,
        NightPrompt(
          night: 2,
          text: _pad('Čiju ulogu želiš vidjeti?'),
          choices: const ['P0', 'P2', 'P3'],
          ids: const [0, 2, 3],
          picked: 2,
          special: true,
          done: true,
        ),
      );
      expect(find.byKey(const ValueKey('night-confirm')), findsNothing);
      expect(find.text('●'), findsNothing);
      expect(find.byKey(const ValueKey('night-3')), findsNothing);
      expect(c.sent, isEmpty, reason: 'the first confirm is final');
      await expectHiddenUntilHeld(t, 'P2');
    },
  );

  testWidgets(
    'confirming, then the TV sending the prompt again with done, stays locked',
    (t) async {
      final c = await _app(t);
      await _send(t, c, _role);
      await _send(t, c, _night());
      await t.tap(find.byKey(const ValueKey('night-2')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('night-confirm')));
      await t.pump();
      await _send(
        t,
        c,
        NightPrompt(
          night: 2,
          text: _pad('Čiju ulogu želiš vidjeti?'),
          choices: const ['P0', 'P2', 'P3'],
          ids: const [0, 2, 3],
          picked: 2,
          done: true,
        ),
      );
      expect(find.byKey(const ValueKey('night-confirm')), findsNothing);
      expect(find.text(Strings.sentHint), findsOneWidget);
      await expectHiddenUntilHeld(t, 'P2');
    },
  );

  testWidgets('the same prompt resent with done=true locks a form left open', (
    t,
  ) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(t, c, _night());
    expect(find.text(Strings.confirm), findsOneWidget);
    await _send(
      t,
      c,
      NightPrompt(
        night: 2,
        text: _pad('Čiju ulogu želiš vidjeti?'),
        choices: const ['P0', 'P2', 'P3'],
        ids: const [0, 2, 3],
        picked: 3,
        done: true,
      ),
    );
    expect(find.byKey(const ValueKey('night-confirm')), findsNothing);
    await expectHiddenUntilHeld(t, 'P3');
  });

  testWidgets('a done wolf phone and a done sum phone look the same', (
    t,
  ) async {
    Future<String> phone(String text, List<String> labels) async {
      final c = await _app(t);
      await _send(t, c, _role);
      await _send(
        t,
        c,
        NightPrompt(
          night: 2,
          text: _pad(text),
          choices: labels,
          ids: [for (var i = 0; i < labels.length; i++) i],
          picked: 1,
          done: true,
        ),
      );
      return look(t, {text, ...labels});
    }

    final names = [for (var i = 0; i < 5; i++) 'Igrač $i'];
    await phone('x', names);
    expect(
      await phone('Koga posjećujete?', names),
      await phone('Koliko je 7 × 8?', ['54', '56', '58', '63', '49']),
    );
  });

  testWidgets('the vote goes out as Vote; skipping sends null', (t) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(t, c, const VotePrompt(day: 1, seconds: 60, ids: [0, 1, 2, 3]));
    await t.tap(find.byKey(const ValueKey('vote-2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('vote-go')));
    await t.pump();
    expect(c.sent.last, const Vote(2));
    expect(find.byKey(const ValueKey('vote-skip')), findsNothing);
    expect(find.byKey(const ValueKey('vote-3')), findsNothing);
    await expectHiddenUntilHeld(t, 'P2');
  });

  testWidgets('skipping sends null and hides behind the card too', (t) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(t, c, const VotePrompt(day: 1, seconds: 60, ids: [0, 1, 2, 3]));
    await t.tap(find.byKey(const ValueKey('vote-skip')));
    await t.pump();
    expect(c.sent.last, const Vote(null));
    expect(find.byKey(const ValueKey('vote-go')), findsNothing);
    expect(find.text(Strings.sentHint), findsOneWidget);
  });

  testWidgets('after a reload the vote shows the pick the TV already has', (
    t,
  ) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(
      t,
      c,
      const VotePrompt(day: 1, seconds: 40, ids: [0, 2, 3], picked: 3),
    );
    expect(find.byKey(const ValueKey('vote-go')), findsNothing);
    expect(c.sent.whereType<Vote>(), isEmpty);
    await expectHiddenUntilHeld(t, 'P3');
  });

  testWidgets('a spared fool cannot vote', (t) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(
      t,
      c,
      const VotePrompt(day: 1, seconds: 60, ids: [0, 2], canVote: false),
    );
    await t.tap(find.byKey(const ValueKey('vote-2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('vote-go')), warnIfMissed: false);
    await t.tap(find.byKey(const ValueKey('vote-skip')), warnIfMissed: false);
    expect(c.sent.whereType<Vote>(), isEmpty);
  });

  testWidgets('Farewell sends Shoot, with no special switch', (t) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(t, c, const Farewell(seconds: 15, ids: [0, 2]));
    expect(find.byKey(const ValueKey('night-special')), findsNothing);
    await t.tap(find.byKey(const ValueKey('night-2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    expect(c.sent.last, const Shoot(2));
  });

  testWidgets('Morning text is behind the hold, with the role', (t) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(t, c, Morning(2, _pad('P2 je vukodlak.')));
    expect(find.textContaining('vukodlak.'), findsNothing);
    final g = await t.startGesture(
      t.getCenter(find.byKey(const ValueKey('role-card'))),
    );
    await t.pump();
    expect(find.text('P2 je vukodlak.'), findsOneWidget);
    await g.up();
  });

  testWidgets('WolfEnd lists everybody\'s role and who won', (t) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(
      t,
      c,
      const WolfEnd(WolfWinner.village, {0: WolfRole.wolf, 2: WolfRole.seer}),
    );
    expect(find.text(Strings.wolfWinner(WolfWinner.village)), findsOneWidget);
    expect(find.text('Vukodlak'), findsOneWidget);
    expect(find.text('Vidovnjakinja'), findsOneWidget);
  });

  testWidgets('a second game on the same phone starts on its role card with Spreman, not on game 1\'s end screen', (
    t,
  ) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(t, c, const PlayWait(ready: false, count: 0, total: 6));
    expect(find.byKey(const ValueKey('play-ready')), findsOneWidget);
    await _send(t, c, _night(night: 1));
    await _send(
      t,
      c,
      const WolfEnd(WolfWinner.village, {0: WolfRole.wolf, 2: WolfRole.seer}),
    );
    expect(find.text(Strings.wolfWinner(WolfWinner.village)), findsOneWidget);
    // back in the lobby, then the next game
    await _send(t, c, _lobby());
    await _send(t, c, _role);
    await _send(t, c, const PlayWait(ready: false, count: 0, total: 6));
    expect(find.text(Strings.wolfWinner(WolfWinner.village)), findsNothing);
    expect(find.text(Strings.holdHere), findsOneWidget);
    expect(find.byKey(const ValueKey('play-ready')), findsOneWidget);
  });

  testWidgets('the roles list opens from the hold screen, and goes back', (
    t,
  ) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await t.tap(find.byKey(const ValueKey('open-roles')));
    await t.pumpAndSettle();
    expect(find.text(Strings.rolesInThisGame), findsWidgets);
    expect(find.byKey(const ValueKey('role-seer')), findsOneWidget);
    expect(find.byKey(const ValueKey('role-doc')), findsNothing);
    await t.tap(find.byKey(const ValueKey('wolf-back')));
    await t.pumpAndSettle();
    expect(find.text(Strings.holdHere), findsOneWidget);
  });

  group('lobby: host settings', () {
    Future<FakeConnection> host(WidgetTester t, GameSettings s) async {
      final c = await _app(t, me: 0);
      await _send(t, c, _lobby(selected: GameKind.vukodlak, settings: s));
      return c;
    }

    testWidgets('Skrivene uloge sends the whole settings with one change', (
      t,
    ) async {
      final c = await host(
        t,
        const GameSettings(quizSeconds: 25, curveCountdown: 90),
      );
      await t.tap(find.byKey(const ValueKey('inc-wolfHideRoles')));
      final s = (c.sent.last as SetSettings).settings;
      expect(s.wolfHideRoles, isFalse);
      expect((s.quizSeconds, s.curveCountdown), (25, 90));
    });

    testWidgets('a role switch keeps the other roles and the always-on two', (
      t,
    ) async {
      final c = await host(t, const GameSettings());
      await t.tap(find.byKey(const ValueKey('open-wolfRoles')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('role-mayor')));
      await t.tap(find.byKey(const ValueKey('role-mayor')));
      final s = (c.sent.last as SetSettings).settings;
      expect(s.wolfRoles, {...GameSettings.defaultWolfRoles, WolfRole.mayor});
      // the TV answers; the open screen follows it
      await _send(
        t,
        c,
        _lobby(
          me: 0,
          selected: GameKind.vukodlak,
          settings: GameSettings(wolfRoles: s.wolfRoles),
        ),
      );
      expect(
        t.widget<Switch>(find.byKey(const ValueKey('switch-mayor'))).value,
        isTrue,
      );
    });

    testWidgets('Igraj starts Vukodlak', (t) async {
      final c = await host(t, const GameSettings());
      await t.tap(find.byKey(const ValueKey('play')));
      expect(c.sent.last, const StartGame(GameKind.vukodlak, null));
    });

    testWidgets('a quiz stepper does not reset the Vukodlak settings', (
      t,
    ) async {
      final s = GameSettings(
        wolfRoles: {...GameSettings.defaultWolfRoles, WolfRole.mayor},
        wolfHideRoles: false,
        curveCountdown: 60,
      );
      final c = await _app(t, me: 0);
      await _send(t, c, _lobby(selected: GameKind.quiz, settings: s));
      await t.tap(find.byTooltip(Strings.moreOf(Strings.quizSeconds)));
      final n = (c.sent.last as SetSettings).settings;
      expect(n.wolfRoles, s.wolfRoles);
      expect((n.wolfHideRoles, n.curveCountdown), (false, 60));
    });
  });

  testWidgets('a guest sees the roles link while Vukodlak is open', (t) async {
    final c = await _app(t, me: 1);
    await _send(t, c, _lobby(selected: GameKind.vukodlak));
    expect(find.byKey(const ValueKey('guest-roles')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('guest-roles')));
    await t.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(find.byKey(const ValueKey('role-wolf')), findsOneWidget);
  });

  group('no timers: Idemo glasati by day', () {
    testWidgets('after Morning the wish shows; it sends and follows the TV', (
      t,
    ) async {
      final c = await _app(t);
      await _send(t, c, _role);
      expect(find.byKey(const ValueKey('vote-wish')), findsNothing);
      await _send(t, c, Morning(2, _pad('P2 je vukodlak.')));
      await _send(
        t,
        c,
        const VoteWish(open: true, ready: false, want: 0, needed: 3),
      );
      expect(find.text(Strings.wishCount(0, 3)), findsOneWidget);
      expect(find.byKey(const ValueKey('clue-done')), findsNothing);
      await t.tap(find.byKey(const ValueKey('vote-wish')));
      expect(c.sent.last, const ReadyToVote(true));
      expect(find.text(Strings.letsVote), findsOneWidget);
      await _send(
        t,
        c,
        const VoteWish(open: true, ready: true, want: 1, needed: 3),
      );
      await t.tap(find.byKey(const ValueKey('vote-wish')));
      expect(c.sent.last, const ReadyToVote(false));
    });

    testWidgets('a night prompt and a vote take the button away', (t) async {
      final c = await _app(t);
      await _send(t, c, _role);
      await _send(
        t,
        c,
        const VoteWish(open: true, ready: true, want: 1, needed: 3),
      );
      await _send(t, c, _night());
      expect(find.byKey(const ValueKey('vote-wish')), findsNothing);
      // Back at the card (next morning) the old wish must not reappear.
      await _send(t, c, Morning(3, _pad('Nitko nije umro.')));
      expect(find.byKey(const ValueKey('vote-wish')), findsNothing);
      await _send(t, c, const VotePrompt(day: 1, seconds: 0, ids: [0, 2, 3]));
      expect(find.byKey(const ValueKey('vote-wish')), findsNothing);
      expect(find.byKey(const ValueKey('vote-clock')), findsNothing);
    });

    testWidgets('the night screens carry no wish, even if one arrives', (
      t,
    ) async {
      final c = await _app(t);
      await _send(t, c, _role);
      await _send(t, c, _night());
      final before = look(t, {'x'});
      await _send(
        t,
        c,
        const VoteWish(open: true, ready: false, want: 0, needed: 3),
      );
      expect(find.byKey(const ValueKey('vote-wish')), findsNothing);
      expect(look(t, {'x'}), before);
    });
  });

  testWidgets(
    'before night 1: the role card with Spreman and the count; pressing sends ReadyToPlay, the night replaces it',
    (t) async {
      final c = await _app(t);
      await _send(t, c, _role);
      await _send(t, c, const PlayWait(ready: false, count: 2, total: 6));
      expect(find.text(Strings.holdHere), findsOneWidget);
      expect(find.text(Strings.readyCount(2, 6)), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('play-ready')));
      await t.pump();
      expect(c.sent.last, isA<ReadyToPlay>());
      await _send(t, c, const PlayWait(ready: true, count: 3, total: 6));
      expect(find.text(Strings.readyDone), findsOneWidget);
      expect(find.text(Strings.readyCount(3, 6)), findsOneWidget);
      await _send(t, c, _night(night: 1));
      expect(find.byKey(const ValueKey('play-ready')), findsNothing);
      expect(find.byKey(const ValueKey('night-confirm')), findsOneWidget);
    },
  );
}
