import 'package:controller/app.dart';
import 'package:controller/screens/blef_field.dart';
import 'package:controller/screens/blef_screens.dart';
import 'package:controller/strings.dart';
import 'package:controller/theme.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

Future<void> _show(
  WidgetTester t,
  Widget w, {
  double width = 390,
  double h = 1600,
}) async {
  t.view.physicalSize = Size(width, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(theme: theme, home: w));
}

void main() {
  group('the field', () {
    testWidgets('sends the trimmed text; an empty one is not sent', (t) async {
      final sent = <String>[];
      await _show(t, Scaffold(body: BlefField(onSend: sent.add)));
      await t.tap(find.byKey(const ValueKey('blef-send')));
      await t.enterText(find.byKey(const ValueKey('blef-field')), '   ');
      await t.tap(find.byKey(const ValueKey('blef-send')));
      expect(sent, isEmpty);
      await t.enterText(
        find.byKey(const ValueKey('blef-field')),
        '  Čačkalica ćevapi  ',
      );
      await t.tap(find.byKey(const ValueKey('blef-send')));
      expect(sent, ['Čačkalica ćevapi']);
    });

    testWidgets('stops at 40 characters; č ć š ž đ count as one each', (
      t,
    ) async {
      final sent = <String>[];
      await _show(t, Scaffold(body: BlefField(onSend: sent.add)));
      await t.enterText(find.byKey(const ValueKey('blef-field')), 'č' * 55);
      await t.tap(find.byKey(const ValueKey('blef-send')));
      expect(sent.single.length, 40);
    });

    testWidgets('the keyboard send key sends too', (t) async {
      final sent = <String>[];
      await _show(t, Scaffold(body: BlefField(onSend: sent.add)));
      await t.enterText(find.byKey(const ValueKey('blef-field')), 'đak');
      await t.testTextInput.receiveAction(TextInputAction.send);
      expect(sent, ['đak']);
    });

    testWidgets('a disabled field sends nothing; an error shows under it', (
      t,
    ) async {
      final sent = <String>[];
      await _show(
        t,
        Scaffold(
          body: BlefField(enabled: false, error: 'Nešto', onSend: sent.add),
        ),
      );
      await t.tap(find.byKey(const ValueKey('blef-send')), warnIfMissed: false);
      expect(sent, isEmpty);
      expect(find.byKey(const ValueKey('blef-error')), findsOneWidget);
    });

    testWidgets('the button is at least 56 px and the page fits 360 px', (
      t,
    ) async {
      await _show(t, const BlefSpikeScreen(), width: 360, h: 640);
      expect(
        t.getSize(find.byKey(const ValueKey('blef-send'))).height,
        greaterThanOrEqualTo(56),
      );
      expect(t.takeException(), isNull);
    });
  });

  group('the screens', () {
    Widget write({
      String? sent,
      String? error,
      int seconds = 60,
      void Function(String)? onSend,
    }) => BlefWriteScreen(
      number: 3,
      total: 7,
      seconds: seconds,
      question: 'Koliko je trajao najkraći rat?',
      sent: sent,
      error: error,
      onSend: onSend ?? (_) {},
    );

    testWidgets('writing: the question, the clock, the field', (t) async {
      await _show(t, write());
      expect(find.text('Pitanje 3 od 7'), findsOneWidget);
      expect(find.text('Koliko je trajao najkraći rat?'), findsOneWidget);
      expect(find.text('1:00'), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
      expect(find.text('0:56'), findsOneWidget);
    });

    testWidgets(
      'an accepted fake locks the screen and shows only your own text',
      (t) async {
        await _show(t, write(sent: '38 minuta'));
        expect(find.byKey(const ValueKey('blef-field')), findsNothing);
        expect(find.byKey(const ValueKey('blef-send')), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('blef-sent')),
            matching: find.text('38 minuta'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a refusal shows under the field', (t) async {
      await _show(t, write(error: 'To je točan odgovor! Smisli laž.'));
      expect(find.text('To je točan odgovor! Smisli laž.'), findsOneWidget);
      expect(find.byKey(const ValueKey('blef-field')), findsOneWidget);
    });

    testWidgets('picking: one tap sends the id and locks the list', (t) async {
      final picks = <int>[];
      await _show(
        t,
        BlefListScreen(
          seconds: 20,
          options: const ['38 minuta', '2 sata', '45 dana'],
          ids: const [4, 9, 2],
          onPick: picks.add,
        ),
      );
      for (final o in ['38 minuta', '2 sata', '45 dana']) {
        expect(find.text(o), findsOneWidget);
      }
      expect(
        t.getSize(find.byKey(const ValueKey('option-9'))).height,
        greaterThanOrEqualTo(56),
      );
      await t.tap(find.byKey(const ValueKey('option-9')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('option-4')));
      expect(picks, [9], reason: 'the first tap is final');
      expect(find.byKey(const ValueKey('blef-picked')), findsOneWidget);
    });

    testWidgets('two quick taps send one pick', (t) async {
      final picks = <int>[];
      await _show(
        t,
        BlefListScreen(
          seconds: 20,
          options: const ['a', 'b'],
          ids: const [1, 2],
          onPick: picks.add,
        ),
      );
      await t.tap(find.byKey(const ValueKey('option-1')));
      await t.tap(find.byKey(const ValueKey('option-2')));
      expect(picks, [1]);
    });

    testWidgets('after a reload the pick is shown and the list is shut', (
      t,
    ) async {
      final picks = <int>[];
      await _show(
        t,
        BlefListScreen(
          seconds: 10,
          options: const ['a', 'b'],
          ids: const [1, 2],
          picked: 2,
          onPick: picks.add,
        ),
      );
      await t.tap(find.byKey(const ValueKey('option-1')));
      expect(picks, isEmpty);
      expect(find.byKey(const ValueKey('blef-picked')), findsOneWidget);
    });

    testWidgets('the result: points, the truth, the fooled, the total', (
      t,
    ) async {
      await _show(
        t,
        const BlefResultScreen(
          points: 1500,
          total: 3000,
          foundTruth: true,
          fooled: 1,
        ),
      );
      expect(find.byKey(const ValueKey('blef-points')), findsOneWidget);
      expect(find.text(Strings.truthFound), findsOneWidget);
      expect(find.text(Strings.fooledN(1)), findsOneWidget);
      expect(find.text(Strings.totalScore(3000)), findsOneWidget);
      await _show(
        t,
        const BlefResultScreen(
          points: 0,
          total: 0,
          foundTruth: false,
          fooled: 0,
        ),
      );
      expect(find.text(Strings.truthMissed), findsOneWidget);
    });
  });

  group('through the app', () {
    LobbyState lobby({GameKind? sel, GameSettings s = const GameSettings()}) =>
        LobbyState(
          hostId: 0,
          selected: sel,
          settings: s,
          packs: const [],
          blefPacks: const [
            PackInfo('b', 'Čudno ali istinito', 40),
            PackInfo('c', 'Životinje', 30),
          ],
          players: [
            for (var i = 0; i < 3; i++)
              PlayerInfo(
                i,
                ['Luka', 'Ana', 'Marko'][i],
                i,
                true,
                0,
                character: characterIds[i],
              ),
          ],
        );

    Future<FakeConnection> app(WidgetTester t) async {
      t.view.physicalSize = const Size(390, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final c = FakeConnection();
      await t.pumpWidget(App(c));
      for (final m in <Message>[const Welcome(0, 0, 'tok'), lobby()]) {
        c.inbox.add(m);
        await t.pump();
        await t.pump();
      }
      return c;
    }

    Future<void> send(WidgetTester t, FakeConnection c, Message m) async {
      c.inbox.add(m);
      await t.pump();
      await t.pump();
    }

    const write = BlefWrite(
      number: 1,
      total: 7,
      seconds: 60,
      q: 'Pitanje?',
      sent: null,
    );

    testWidgets(
      'a fake goes out as BlefFake; a refusal shows inline, not as the red banner',
      (t) async {
        final c = await app(t);
        await send(t, c, write);
        await t.enterText(
          find.byKey(const ValueKey('blef-field')),
          '38 minuta',
        );
        await t.tap(find.byKey(const ValueKey('blef-send')));
        expect(c.sent.last, const BlefFake('38 minuta'));
        await send(t, c, const ErrorMsg('To je točan odgovor! Smisli laž.'));
        expect(find.byKey(const ValueKey('blef-error')), findsOneWidget);
        expect(find.text(Strings.ok), findsNothing, reason: 'no red banner');
        await t.enterText(
          find.byKey(const ValueKey('blef-field')),
          '39 minuta',
        );
        await t.tap(find.byKey(const ValueKey('blef-send')));
        await t.pump();
        expect(c.sent.last, const BlefFake('39 minuta'));
        expect(
          find.byKey(const ValueKey('blef-error')),
          findsNothing,
          reason: 'cleared by the next try',
        );
      },
    );

    testWidgets('the ack locks it; the list, the pick and the result follow', (
      t,
    ) async {
      final c = await app(t);
      await send(t, c, write);
      await send(
        t,
        c,
        const BlefWrite(
          number: 1,
          total: 7,
          seconds: 40,
          q: 'Pitanje?',
          sent: '38 minuta',
        ),
      );
      expect(find.byKey(const ValueKey('blef-sent')), findsOneWidget);
      await send(
        t,
        c,
        const BlefList(
          seconds: 20,
          options: ['2 sata', '45 dana'],
          ids: [5, 8],
        ),
      );
      await t.tap(find.byKey(const ValueKey('option-8')));
      expect(c.sent.last, const BlefPick(8));
      await send(
        t,
        c,
        const BlefResult(points: 500, total: 500, foundTruth: false, fooled: 1),
      );
      expect(find.text(Strings.truthMissed), findsOneWidget);
      await send(
        t,
        c,
        const BlefWrite(
          number: 2,
          total: 7,
          seconds: 60,
          q: 'Drugo?',
          sent: null,
        ),
      );
      expect(find.text('Drugo?'), findsOneWidget);
      expect(find.byKey(const ValueKey('blef-field')), findsOneWidget);
    });

    testWidgets('a reload into the list restores the pick', (t) async {
      final c = await app(t);
      await send(
        t,
        c,
        const BlefList(
          seconds: 12,
          options: ['a', 'b'],
          ids: [1, 2],
          picked: 1,
        ),
      );
      expect(find.byKey(const ValueKey('blef-picked')), findsOneWidget);
    });

    testWidgets('host settings: card line, rows, the whole settings sent', (
      t,
    ) async {
      final c = await app(t);
      for (var i = 0; i < 6; i++) {
        await t.drag(find.byType(PageView), const Offset(-320, 0));
        await t.pumpAndSettle();
      }
      expect(
        t.widget<Text>(find.byKey(const ValueKey('line-blef'))).data,
        'Čudno ali istinito · 7 pitanja',
      );
      await send(
        t,
        c,
        lobby(
          sel: GameKind.blef,
          s: const GameSettings(quizSeconds: 25, kolikoSeconds: 45),
        ),
      );
      await t.tap(find.byKey(const ValueKey('blef-questions-10')));
      var s = (c.sent.last as SetSettings).settings;
      expect((s.blefQuestions, s.quizSeconds, s.kolikoSeconds), (10, 25, 45));
      await t.tap(find.byKey(const ValueKey('blef-pack')));
      await t.pumpAndSettle();
      await t.tap(find.text('Životinje').last);
      await t.pumpAndSettle();
      expect((c.sent.last as SetSettings).settings.blefPackId, 'c');
      await t.tap(find.text(Strings.play));
      expect(c.sent.last, const StartGame(GameKind.blef, null));
    });
  });
}
