import 'package:controller/screens/wolf_screens.dart';
import 'package:controller/strings.dart';
import 'package:controller/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hold.dart';
import 'look.dart';

Future<void> _show(WidgetTester t, Widget w, {double width = 390}) async {
  t.view.physicalSize = Size(width, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  // A fresh tree, so a screen's sent state never carries into the next one.
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(MaterialApp(theme: theme, home: w));
}

const _night = [
  NightItem(1, 'Ana'),
  NightItem(2, 'Ivana'),
  NightItem(3, 'Josip'),
  NightItem(4, 'Luka'),
];

const _fiveWolf = [..._night, NightItem(5, 'Maja')];

/// A sum, like 7 x 8: five answers, no faces.
const _sum = [
  NightItem(1, '54'),
  NightItem(2, '56'),
  NightItem(3, '58'),
  NightItem(4, '63'),
  NightItem(5, '49'),
];

const _people = [
  WolfTarget(1, 'Ana', 'owl', 0),
  WolfTarget(2, 'Ivana', 'rabbit', 1),
  WolfTarget(3, 'Josip', 'bear', 2),
  WolfTarget(4, 'Luka', 'fox', 3),
];

void main() {
  group('hold to see', () {
    Widget screen() => const RoleHoldScreen(
      name: 'Petra',
      night: 1,
      role: 'Vidovnjakinja',
      description: 'Svake noći saznaš ulogu jednog igrača.',
    );

    testWidgets('hidden until a finger is down, hidden again on release', (
      t,
    ) async {
      await _show(t, screen());
      expect(find.text('Vidovnjakinja'), findsNothing);
      expect(find.text(Strings.holdHere), findsOneWidget);
      final g = await t.startGesture(
        t.getCenter(find.byKey(const ValueKey('role-card'))),
      );
      await t.pump();
      expect(find.text('Vidovnjakinja'), findsOneWidget);
      expect(find.text(Strings.holdHere), findsNothing);
      await g.up();
      await t.pump();
      expect(find.text('Vidovnjakinja'), findsNothing);
    });

    testWidgets('a cancelled touch hides it too', (t) async {
      await _show(t, screen());
      final g = await t.startGesture(
        t.getCenter(find.byKey(const ValueKey('role-card'))),
      );
      await t.pump();
      await g.cancel();
      await t.pump();
      expect(find.text('Vidovnjakinja'), findsNothing);
    });

    testWidgets('stays shown while any of two fingers is down', (t) async {
      await _show(t, screen());
      final c = t.getCenter(find.byKey(const ValueKey('role-card')));
      final a = await t.startGesture(c, pointer: 1);
      final b = await t.startGesture(c + const Offset(20, 0), pointer: 2);
      await a.up();
      await t.pump();
      expect(find.text('Vidovnjakinja'), findsOneWidget);
      await b.up();
      await t.pump();
      expect(find.text('Vidovnjakinja'), findsNothing);
    });
  });

  group('night: one screen for every role', () {
    final hints = [
      for (final r in Strings.wolfRoles)
        // a different length per role, on purpose
        '${r.$2}: ${'x' * (r.$2.length * 3)}',
    ];

    testWidgets('all 14 roles render identically but for the hint', (t) async {
      expect(hints.length, 14);
      String? first;
      for (final h in hints) {
        await _show(
          t,
          NightScreen(
            night: 2,
            hint: h,
            targets: _night,
            onConfirm: (_, _, _) {},
          ),
        );
        final got = look(t, {h});
        first ??= got;
        expect(got, first, reason: h);
        expect(find.text(h), findsOneWidget);
      }
    });

    testWidgets('the comparison can fail: a role-specific colour is caught', (
      t,
    ) async {
      await _show(
        t,
        NightScreen(
          night: 2,
          hint: 'a',
          targets: _night,
          onConfirm: (_, _, _) {},
        ),
      );
      final plain = look(t, {'a'});
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: ColoredBox(
            color: Colors.red,
            child: NightScreen(
              night: 2,
              hint: 'a',
              targets: _night,
              onConfirm: (_, _, _) {},
            ),
          ),
        ),
      );
      expect(look(t, {'a'}), isNot(plain));
    });

    Future<String> phone(
      WidgetTester t,
      String hint,
      List<NightItem> items, {
      bool answered = false,
    }) async {
      await _show(
        t,
        NightScreen(
          night: 2,
          hint: hint,
          targets: items,
          onConfirm: (_, _, _) {},
        ),
      );
      if (answered) {
        await t.tap(find.byKey(const ValueKey('night-2')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('night-confirm')));
        await t.pump();
      }
      return look(t, {hint, ...items.map((i) => i.label)});
    }

    testWidgets('a sum phone looks like a wolf phone, picking and answered', (
      t,
    ) async {
      for (final answered in [false, true]) {
        final wolf = await phone(
          t,
          'Koga posjećujete? Luka je odabrao Ivanu.',
          _night + [const NightItem(5, 'Maja')],
          answered: answered,
        );
        final sum = await phone(
          t,
          'Koliko je 7 × 8?',
          _sum,
          answered: answered,
        );
        final a = sum.split('\n'), c = wolf.split('\n');
        for (var i = 0; i < a.length && i < c.length; i++) {
          expect(a[i], c[i], reason: 'line $i, answered: $answered');
        }
        expect(a.length, c.length);
      }
    });

    testWidgets('the sent card looks the same for a sum and a player, held too', (
      t,
    ) async {
      Future<String> held(String hint, List<NightItem> items) async {
        await _show(
          t,
          NightScreen(
            night: 2,
            hint: hint,
            targets: items,
            onConfirm: (_, _, _) {},
          ),
        );
        await t.tap(find.byKey(const ValueKey('night-2')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('night-confirm')));
        await t.pump();
        final g = await holdCard(t);
        final l = look(t, {items[1].label});
        await g.up();
        await t.pump();
        return l;
      }

      await held('x', _night);
      expect(
        await held('Koliko je 7 × 8?', _sum),
        await held('Koga posjećujete?', _night),
      );
    });

    testWidgets('two sent picks both hide behind the card', (t) async {
      await _show(
        t,
        NightScreen(
          night: 1,
          hint: 'h',
          targets: _night,
          targets2: _sum,
          onConfirm: (_, _, _) {},
        ),
      );
      await t.tap(find.byKey(const ValueKey('night-1')));
      await t.tap(find.byKey(const ValueKey('night2-3')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('night-confirm')));
      await t.pump();
      expect(find.text('Ana'), findsNothing);
      expect(find.text('58'), findsNothing);
      final g = await holdCard(t);
      expect(find.text('Ana\n58'), findsOneWidget);
      await g.up();
    });

    testWidgets('night 1 with two picks looks the same for a wolf and a sum', (
      t,
    ) async {
      Future<String> two(String hint, List<NightItem> items) async {
        await _show(
          t,
          NightScreen(
            night: 1,
            hint: hint,
            targets: items,
            targets2: items,
            onConfirm: (_, _, _) {},
          ),
        );
        await t.tap(find.byKey(const ValueKey('night-1')));
        await t.tap(find.byKey(const ValueKey('night2-3')));
        await t.pump();
        final before = look(t, {hint, ...items.map((i) => i.label)});
        await t.tap(find.byKey(const ValueKey('night-confirm')));
        await t.pump();
        return before + look(t, {hint, ...items.map((i) => i.label)});
      }

      await two('x', _night); // leaves the test pointer in a known place
      final wolf = await two('Koga posjećujete?', _fiveWolf);
      final sum = await two('Koliko je 7 × 8?', _sum);
      expect(sum, wolf);
    });

    testWidgets('a 5-row list and a 7-row list are told apart by the check', (
      t,
    ) async {
      Future<String> phone(List<NightItem> items) async {
        await _show(
          t,
          NightScreen(
            night: 2,
            hint: 'h',
            targets: items,
            onConfirm: (_, _, _) {},
          ),
        );
        return look(t, {'h', ...items.map((i) => i.label)});
      }

      final seven = [for (var i = 0; i < 7; i++) NightItem(i, 'P$i')];
      expect(await phone(seven), isNot(await phone(_sum)));
      expect(await phone(seven), await phone(seven.reversed.toList()));
    });

    testWidgets('after Potvrdi every role shows Poslano and locks the list', (
      t,
    ) async {
      final sent = <int>[];
      await _show(
        t,
        NightScreen(
          night: 1,
          hint: 'h',
          targets: _sum,
          onConfirm: (t, _, _) => sent.add(t),
        ),
      );
      await t.tap(find.byKey(const ValueKey('night-2')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('night-confirm')));
      await t.pump();
      expect(find.byKey(const ValueKey('night-3')), findsNothing);
      expect(find.byKey(const ValueKey('night-confirm')), findsNothing);
      expect(find.text(Strings.sentHint), findsOneWidget);
      expect(sent, [2]);
      await expectHiddenUntilHeld(t, '56');
    });

    bool marked(WidgetTester t, String key) {
      final box = t.widget<Container>(
        find
            .descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Container),
            )
            .first,
      );
      final d = box.decoration! as BoxDecoration;
      return (d.border! as Border).top.color != Colors.transparent;
    }

    testWidgets(
      'a sum answer has the same grey disc, and locks after sending',
      (t) async {
        await _show(
          t,
          NightScreen(
            night: 1,
            hint: 'h',
            targets: _sum,
            onConfirm: (_, _, _) {},
          ),
        );
        final disc = t.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(const ValueKey('night-1')),
                matching: find.byType(DecoratedBox),
              )
              .last,
        );
        expect(
          (disc.decoration as BoxDecoration).color,
          const Color(0xFF9A9AA6),
        );
        await t.tap(find.byKey(const ValueKey('night-2')));
        await t.pump();
        expect(marked(t, 'night-2'), isTrue);
        await t.tap(find.byKey(const ValueKey('night-confirm')));
        await t.pump();
        // Sent: no list is left on screen to read or change.
        expect(find.byKey(const ValueKey('night-2')), findsNothing);
        expect(find.byKey(const ValueKey('night-3')), findsNothing);
      },
    );

    testWidgets('the special switch goes out with the pick and locks after', (
      t,
    ) async {
      final sent = <(int, bool)>[];
      await _show(
        t,
        NightScreen(
          night: 1,
          hint: 'h',
          targets: _night,
          onConfirm: (t, _, s) => sent.add((t, s)),
        ),
      );
      await t.tap(find.byKey(const ValueKey('night-3')));
      await t.tap(find.byKey(const ValueKey('night-special')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('night-confirm')));
      await t.pump();
      expect(find.byKey(const ValueKey('night-special')), findsNothing);
      expect(sent, [(3, true)]);
    });

    testWidgets('Potvrdi sends the picked player; nothing without a pick', (
      t,
    ) async {
      final sent = <int>[];
      await _show(
        t,
        NightScreen(
          night: 1,
          hint: 'h',
          targets: _night,
          onConfirm: (t, _, _) => sent.add(t),
        ),
      );
      await t.tap(find.byKey(const ValueKey('night-confirm')));
      expect(sent, isEmpty);
      await t.tap(find.byKey(const ValueKey('night-2')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('night-confirm')));
      expect(sent, [2]);
    });

    testWidgets('targets and button are at least 56 px', (t) async {
      await _show(
        t,
        NightScreen(
          night: 1,
          hint: 'h',
          targets: _night,
          onConfirm: (_, _, _) {},
        ),
      );
      for (final k in ['night-1', 'night-confirm']) {
        expect(
          t.getSize(find.byKey(ValueKey(k))).height,
          greaterThanOrEqualTo(56),
        );
      }
    });
  });

  group('day vote', () {
    testWidgets('Glasaj is off until a pick, then sends that player', (
      t,
    ) async {
      final sent = <int>[];
      await _show(
        t,
        VoteScreen(
          day: 3,
          targets: _people,
          selfId: 1,
          onVote: sent.add,
          onSkip: () {},
        ),
      );
      expect(find.byKey(const ValueKey('vote-clock')), findsNothing);
      await t.tap(find.byKey(const ValueKey('vote-go')), warnIfMissed: false);
      expect(sent, isEmpty);
      await t.tap(find.byKey(const ValueKey('vote-3')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('vote-go')));
      expect(sent, [3]);
    });

    testWidgets('you cannot vote for yourself', (t) async {
      final sent = <int>[];
      await _show(
        t,
        VoteScreen(
          day: 1,
          targets: _people,
          selfId: 1,
          onVote: sent.add,
          onSkip: () {},
        ),
      );
      await t.tap(find.byKey(const ValueKey('vote-1')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('vote-go')), warnIfMissed: false);
      expect(sent, isEmpty);
    });

    testWidgets('Preskoči glasanje calls onSkip', (t) async {
      var skipped = 0;
      await _show(
        t,
        VoteScreen(
          day: 1,
          targets: _people,
          selfId: 1,
          onVote: (_) {},
          onSkip: () => skipped++,
        ),
      );
      await t.tap(find.byKey(const ValueKey('vote-skip')));
      expect(skipped, 1);
    });
  });

  group('host settings and roles', () {
    testWidgets('the pick screen toggles a role, never Vukodlak or Seljanin', (
      t,
    ) async {
      final sent = <String>[];
      await _show(
        t,
        WolfRolesPickScreen(
          players: 7,
          enabled: const {'seer'},
          onToggle: sent.add,
          onBack: () {},
        ),
      );
      await t.ensureVisible(find.byKey(const ValueKey('role-wolf')));
      await t.tap(find.byKey(const ValueKey('role-wolf')));
      await t.tap(find.byKey(const ValueKey('role-villager')));
      expect(sent, isEmpty);
      await t.ensureVisible(find.byKey(const ValueKey('role-hunter')));
      await t.tap(find.byKey(const ValueKey('role-hunter')));
      expect(sent, ['hunter']);
    });

    test('the mix does not throw with few players', () {
      for (var n = 0; n <= 4; n++) {
        expect(
          () => WolfRolesPickScreen.mix(n, {'seer', 'doc', 'hunter'}),
          returnsNormally,
          reason: '$n players',
        );
      }
      expect(WolfRolesPickScreen.mix(2, {'seer'}).$2, 0);
    });

    testWidgets('the roles pick screen opens with two players', (t) async {
      await _show(
        t,
        WolfRolesPickScreen(
          players: 2,
          enabled: const {'seer', 'doc'},
          onToggle: (_) {},
          onBack: () {},
        ),
      );
      expect(t.takeException(), isNull);
    });

    test('the plurals of the intros', () {
      expect(Strings.wolvesN(1), '1 vukodlak');
      expect(Strings.wolvesN(2), '2 vukodlaka');
      expect(Strings.specialsN(1), '1 posebna uloga');
      expect(Strings.specialsN(3), '3 posebne uloge');
      expect(Strings.specialsN(5), '5 posebnih uloga');
      expect(Strings.specialsUpTo(3), 'do 3 posebne uloge');
      expect(Strings.villagersN(1), '1 seljanin');
      expect(Strings.villagersN(2), '2 seljana');
    });

    testWidgets('the pick screen: the lead sentence and the mix in bold', (
      t,
    ) async {
      await _show(
        t,
        WolfRolesPickScreen(
          players: 7,
          enabled: const {'seer', 'doc', 'hunter', 'herb'},
          onToggle: (_) {},
          onBack: () {},
        ),
      );
      final box = find.byKey(const ValueKey('mix'));
      final text = t
          .widget<Text>(find.descendant(of: box, matching: find.byType(Text)))
          .textSpan!
          .toPlainText();
      expect(text, contains(Strings.rolesPickIntroLead));
      expect(
        text,
        contains(
          'Za 7 igrača: 2 vukodlaka, 3 posebne uloge od uključenih, 2 seljana.',
        ),
      );
    });

    testWidgets('the info screen explains the mix for this game', (t) async {
      await _show(
        t,
        WolfRolesInfoScreen(
          players: 7,
          enabled: const {'seer', 'hunter', 'doc', 'herb'},
          onBack: () {},
        ),
      );
      expect(
        find.text(
          '2 vukodlaka i do 3 posebne uloge s ovog popisa. Ne mora svaka biti u igri. Ostali su Seljani. Svi vide isti popis.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      await _show(
        t,
        WolfRolesInfoScreen(players: 5, enabled: const {}, onBack: () {}),
      );
      expect(
        find.text(
          '1 vukodlak. Ostali su Seljani. Svi vide isti popis.',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    test('the mix: 1 wolf up to 6 players, 2 from 7, specials capped', () {
      expect(WolfRolesPickScreen.mix(5, {'seer', 'doc', 'hunter'}), (1, 2, 2));
      expect(WolfRolesPickScreen.mix(6, {'seer'}), (1, 1, 4));
      expect(WolfRolesPickScreen.mix(7, {'seer', 'doc', 'hunter', 'herb'}), (
        2,
        3,
        2,
      ));
      expect(WolfRolesPickScreen.mix(8, {}), (2, 0, 6));
      // werewolf variants are not special slots
      expect(WolfRolesPickScreen.mix(7, {'alpha', 'lone'}), (2, 0, 5));
    });

    testWidgets(
      'players see only the roles switched on, plus the two always on',
      (t) async {
        await _show(
          t,
          WolfRolesInfoScreen(enabled: const {'seer', 'hunter'}, onBack: () {}),
        );
        for (final id in ['wolf', 'villager', 'seer', 'hunter']) {
          expect(find.byKey(ValueKey('role-$id')), findsOneWidget, reason: id);
        }
        for (final id in ['doc', 'herb', 'alpha', 'tramp']) {
          expect(find.byKey(ValueKey('role-$id')), findsNothing, reason: id);
        }
        expect(find.byType(Switch), findsNothing);
      },
    );

    testWidgets('every screen fits 360 px without overflow', (t) async {
      await _show(
        t,
        WolfRolesPickScreen(
          players: 8,
          enabled: {for (final r in Strings.wolfRoles) r.$1},
          onToggle: (_) {},
          onBack: () {},
        ),
        width: 360,
      );
      expect(t.takeException(), isNull);
      await _show(
        t,
        NightScreen(
          night: 2,
          hint: 'Koga posjećujete? Luka je odabrao Ivanu.',
          targets: _night,
          onConfirm: (_, _, _) {},
        ),
        width: 360,
      );
      expect(t.takeException(), isNull);
    });
  });
}
