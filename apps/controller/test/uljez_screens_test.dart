import 'package:controller/screens/uljez_screens.dart';
import 'package:controller/screens/wolf_screens.dart';
import 'package:controller/strings.dart';
import 'package:controller/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'look.dart';

Future<void> _show(WidgetTester t, Widget w, {double width = 390}) async {
  t.view.physicalSize = Size(width, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(theme: theme, home: w));
}

const _people = [
  NightItem(1, 'Ana'),
  NightItem(2, 'Ivana'),
  NightItem(3, 'Josip'),
  NightItem(4, 'Luka'),
];

void main() {
  group('the word', () {
    Widget word(String w) => UljezWordScreen(name: 'Petra', round: 2, word: w);

    testWidgets('shows only while a finger is down', (t) async {
      await _show(t, word('Pikachu'));
      expect(find.text('Pikachu'), findsNothing);
      final g = await t.startGesture(
        t.getCenter(find.byKey(const ValueKey('role-card'))),
      );
      await t.pump();
      expect(find.text('Pikachu'), findsOneWidget);
      expect(find.text(Strings.yourWord), findsOneWidget);
      await g.up();
      await t.pump();
      expect(find.text('Pikachu'), findsNothing);
      expect(find.text(Strings.uljezRound(2)), findsOneWidget);
    });

    testWidgets('the impostor phone looks like the others, hidden and held', (
      t,
    ) async {
      Future<String> phone(String w) async {
        await _show(t, word(w));
        final hidden = look(t, {w});
        final g = await t.startGesture(
          t.getCenter(find.byKey(const ValueKey('role-card'))),
        );
        await t.pump();
        final held = look(t, {w}); // words of one line, as on a real phone
        await g.up();
        await t.pump();
        return hidden + held;
      }

      await phone('x'); // leaves the test pointer in a known place
      expect(await phone('Pas'), await phone('Mačka'));
    });
  });

  group('vote and guess', () {
    testWidgets('Glasaj sends the picked player, nothing without a pick', (
      t,
    ) async {
      final sent = <int>[];
      await _show(t, UljezVoteScreen(targets: _people, onVote: sent.add));
      expect(find.text(Strings.whoIsImpostor), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('night-confirm')));
      expect(sent, isEmpty);
      await t.tap(find.byKey(const ValueKey('night-3')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('night-confirm')));
      expect(sent, [3]);
      expect(find.byKey(const ValueKey('night-special')), findsNothing);
    });

    testWidgets('the guess shows the word and sends the picked option', (
      t,
    ) async {
      final sent = <int>[];
      await _show(
        t,
        UljezGuessScreen(
          word: 'Pikachu',
          options: const [
            NightItem(0, 'Spužva Bob'),
            NightItem(1, 'Patrik'),
            NightItem(2, 'Garfield'),
            NightItem(3, 'Scooby-Doo'),
          ],
          onGuess: sent.add,
        ),
      );
      expect(find.text(Strings.caughtHint('Pikachu')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('night-2')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('night-confirm')));
      expect(sent, [2]);
      await t.tap(find.byKey(const ValueKey('night-3')));
      await t.tap(find.byKey(const ValueKey('night-confirm')));
      expect(sent, [2], reason: 'one guess only');
    });

    testWidgets('the picked row is marked, and an empty hint leaves no gap', (
      t,
    ) async {
      await _show(t, UljezVoteScreen(targets: _people, onVote: (_) {}));
      expect(find.text('●'), findsNothing);
      await t.tap(find.byKey(const ValueKey('night-2')));
      await t.pump();
      expect(find.text('●'), findsOneWidget);
      final title = t.getBottomLeft(find.text(Strings.whoIsImpostor)).dy;
      final first = t.getTopLeft(find.byKey(const ValueKey('night-1'))).dy;
      expect(first - title, lessThan(40), reason: 'no 72 px hint box');
    });

    testWidgets('vote rows are at least 56 px and fit at 360 px', (t) async {
      await _show(
        t,
        UljezVoteScreen(targets: _people, onVote: (_) {}),
        width: 360,
      );
      expect(t.takeException(), isNull);
      expect(
        t.getSize(find.byKey(const ValueKey('night-1'))).height,
        greaterThanOrEqualTo(56),
      );
    });
  });
}
