import 'package:controller/app.dart';
import 'package:controller/strings.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';
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

NightPrompt _night({int night = 2, bool two = false}) => NightPrompt(
  night: night,
  text: _pad('Čiju ulogu želiš vidjeti?'),
  choices: const ['P0', 'P2', 'P3'],
  ids: const [0, 2, 3],
  choices2: two ? const ['P0', 'P2', 'P3'] : const [],
  ids2: two ? const [0, 2, 3] : const [],
  picks: two ? 2 : 1,
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
    expect((p.target, p.second, p.special), (2, null, true));
  });

  testWidgets('night 1 asks for two picks on every phone and sends both', (
    t,
  ) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(t, c, _night(night: 1, two: true));
    await t.tap(find.byKey(const ValueKey('night-0')));
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    expect(
      c.sent.whereType<NightPick>(),
      isEmpty,
      reason: 'one pick is not enough',
    );
    await t.tap(find.byKey(const ValueKey('night2-3')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('night-confirm')));
    final p = c.sent.last as NightPick;
    expect((p.target, p.second), (0, 3));
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

  testWidgets('the vote goes out as Vote; skipping sends null', (t) async {
    final c = await _app(t);
    await _send(t, c, _role);
    await _send(t, c, const VotePrompt(day: 1, seconds: 60, ids: [0, 1, 2, 3]));
    await t.tap(find.byKey(const ValueKey('vote-2')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('vote-go')));
    expect(c.sent.last, const Vote(2));
    await t.tap(find.byKey(const ValueKey('vote-skip')));
    expect(c.sent.last, const Vote(null));
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
    await t.tap(find.byKey(const ValueKey('vote-go')));
    expect(c.sent.last, const Vote(3));
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
        const GameSettings(quizSeconds: 25, wolfDiscussion: 90),
      );
      await t.ensureVisible(find.byKey(const ValueKey('hidden-roles')));
      await t.tap(find.byKey(const ValueKey('hidden-roles')));
      final s = (c.sent.last as SetSettings).settings;
      expect(s.wolfHideRoles, isFalse);
      expect((s.quizSeconds, s.wolfDiscussion), (25, 90));
    });

    testWidgets('a role switch keeps the other roles and the always-on two', (
      t,
    ) async {
      final c = await host(t, const GameSettings());
      await t.ensureVisible(find.byKey(const ValueKey('open-roles-pick')));
      await t.tap(find.byKey(const ValueKey('open-roles-pick')));
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
      await t.ensureVisible(find.text(Strings.play));
      await t.tap(find.text(Strings.play));
      expect(c.sent.last, const StartGame(GameKind.vukodlak, null));
    });

    testWidgets('a quiz stepper does not reset the Vukodlak settings', (
      t,
    ) async {
      final s = GameSettings(
        wolfRoles: {...GameSettings.defaultWolfRoles, WolfRole.mayor},
        wolfHideRoles: false,
        wolfDiscussion: 60,
      );
      final c = await _app(t, me: 0);
      await _send(t, c, _lobby(selected: GameKind.quiz, settings: s));
      await t.tap(find.byTooltip(Strings.moreOf(Strings.quizSeconds)));
      final n = (c.sent.last as SetSettings).settings;
      expect(n.wolfRoles, s.wolfRoles);
      expect((n.wolfHideRoles, n.wolfDiscussion), (false, 60));
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
}
