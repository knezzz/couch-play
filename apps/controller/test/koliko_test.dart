import 'package:controller/app.dart';
import 'package:controller/screens/koliko_screens.dart';
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

Widget _ask({
  void Function(double)? onSend,
  double? sent,
  int seconds = 30,
  String unit = 'm',
}) => KolikoAskScreen(
  number: 2,
  total: 10,
  seconds: seconds,
  question: 'Koliko je visok Eiffelov toranj?',
  unit: unit,
  sent: sent,
  onSend: onSend ?? (_) {},
);

Future<void> _tap(WidgetTester t, String keys) async {
  for (final k in keys.split('')) {
    final id = switch (k) {
      ',' => ',',
      '<' => 'del',
      _ => k,
    };
    await t.tap(find.byKey(ValueKey('key-$id')));
    await t.pump();
  }
}

String _display(WidgetTester t) =>
    t.widget<Text>(find.byKey(const ValueKey('koliko-display'))).data!;

void main() {
  group('the pad', () {
    testWidgets('digits show grouped as typed; the unit stays beside them', (
      t,
    ) async {
      await _show(t, _ask());
      expect(_display(t), '0');
      await _tap(t, '1234567');
      expect(_display(t), '1.234.567');
      expect(find.text('m'), findsOneWidget);
      await _tap(t, '<<<<');
      expect(_display(t), '123');
      await _tap(t, ',5');
      expect(_display(t), '123,5');
    });

    testWidgets('a year stays whole while typed; the dot comes from 10 000', (
      t,
    ) async {
      await _show(t, _ask(unit: ''));
      await _tap(t, '1886');
      expect(_display(t), '1886');
      await _tap(t, '5');
      expect(_display(t), '18.865');
    });

    testWidgets('every key is at least 56 px and fits 360 px', (t) async {
      await _show(t, _ask(), width: 360, h: 640);
      for (final k in ['0', '1', '9', ',', 'del']) {
        expect(
          t.getSize(find.byKey(ValueKey('key-$k'))).height,
          greaterThanOrEqualTo(56),
        );
      }
      expect(
        t.getSize(find.byKey(const ValueKey('koliko-send'))).height,
        greaterThanOrEqualTo(56),
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('Pošalji sends the number once, then the pad is shut', (
      t,
    ) async {
      final sent = <double>[];
      await _show(t, _ask(onSend: sent.add));
      await t.tap(
        find.byKey(const ValueKey('koliko-send')),
        warnIfMissed: false,
      );
      expect(sent, isEmpty, reason: 'nothing typed');
      await _tap(t, '330');
      await t.tap(find.byKey(const ValueKey('koliko-send')));
      await t.pump();
      expect(sent, [330]);
      expect(find.byKey(const ValueKey('koliko-sent')), findsOneWidget);
      expect(find.byKey(const ValueKey('key-1')), findsNothing);
      expect(_display(t), '330');
    });

    testWidgets('a decimal comma goes out as a number', (t) async {
      final sent = <double>[];
      await _show(t, _ask(onSend: sent.add));
      await _tap(t, '3,14');
      await t.tap(find.byKey(const ValueKey('koliko-send')));
      expect(sent, [3.14]);
    });

    testWidgets(
      'after a reload the sent number is shown and nothing is sendable',
      (t) async {
        await _show(t, _ask(sent: 1234.5));
        expect(_display(t), '1234,5');
        expect(find.byKey(const ValueKey('koliko-sent')), findsOneWidget);
        expect(find.byKey(const ValueKey('koliko-send')), findsNothing);
      },
    );

    testWidgets('the clock counts down; at 0 the pad is dead', (t) async {
      final sent = <double>[];
      await _show(t, _ask(seconds: 2, onSend: sent.add));
      await _tap(t, '5');
      await t.pump(const Duration(seconds: 3));
      expect(find.text('0:00'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('key-1')), warnIfMissed: false);
      await t.tap(
        find.byKey(const ValueKey('koliko-send')),
        warnIfMissed: false,
      );
      expect(sent, isEmpty);
      expect(_display(t), '5');
    });
  });

  group('the result', () {
    Widget result({double? value, int? rank, int points = 0}) =>
        KolikoResultScreen(
          answer: 330,
          value: value,
          rank: rank,
          points: points,
          total: 1750,
          unit: 'm',
        );

    testWidgets('the answer, your number, the rank and the points', (t) async {
      await _show(t, result(value: 320, rank: 1, points: 1000));
      expect(find.text('330 m'), findsOneWidget);
      expect(find.text('320 m'), findsOneWidget);
      expect(find.text(Strings.closest), findsOneWidget);
      expect(find.text('+1.000 bodova'.replaceAll('.', '')), findsOneWidget);
      expect(find.text(Strings.totalScore(1750)), findsOneWidget);
    });

    testWidgets('the result writes a year whole and a big number with dots', (
      t,
    ) async {
      await _show(
        t,
        KolikoResultScreen(
          answer: 1886,
          value: 12500,
          rank: 2,
          points: 750,
          total: 750,
          unit: '',
        ),
      );
      expect(find.text('1886'), findsOneWidget);
      expect(find.text('12.500'), findsOneWidget);
    });

    testWidgets('an exact hit, a lower rank, no answer', (t) async {
      await _show(t, result(value: 330, rank: 1, points: 1500));
      expect(find.text(Strings.exactHit), findsOneWidget);
      await _show(t, result(value: 100, rank: 3, points: 500));
      expect(find.text(Strings.place(3)), findsOneWidget);
      await _show(t, result(value: 1, rank: 5, points: 0));
      expect(find.byKey(const ValueKey('headline')), findsNothing);
      await _show(t, result());
      expect(find.text(Strings.noNumber), findsOneWidget);
      expect(find.text('–'), findsOneWidget);
    });
  });

  group('through the app', () {
    LobbyState lobby({GameKind? sel, GameSettings s = const GameSettings()}) =>
        LobbyState(
          hostId: 0,
          selected: sel,
          settings: s,
          packs: const [],
          kolikoPacks: const [
            PackInfo('k', 'Brojevi', 80),
            PackInfo('l', 'Gradovi', 60),
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

    testWidgets(
      'KolikoAsk opens the pad; the answer goes out as NumberAnswer',
      (t) async {
        final c = await app(t);
        await send(
          t,
          c,
          const KolikoAsk(
            number: 1,
            total: 10,
            seconds: 30,
            q: 'Koliko?',
            unit: 'm',
          ),
        );
        await _tap(t, '330');
        await t.tap(find.byKey(const ValueKey('koliko-send')));
        expect(c.sent.last, const NumberAnswer(330));
      },
    );

    testWidgets(
      'the result replaces the pad; the next question is a fresh pad',
      (t) async {
        final c = await app(t);
        await send(
          t,
          c,
          const KolikoAsk(
            number: 1,
            total: 10,
            seconds: 30,
            q: 'Koliko?',
            unit: 'm',
          ),
        );
        await _tap(t, '5');
        await send(
          t,
          c,
          const KolikoResult(
            answer: 330,
            value: 5,
            rank: 2,
            points: 750,
            total: 750,
          ),
        );
        expect(find.text('330 m'), findsOneWidget);
        await send(
          t,
          c,
          const KolikoAsk(
            number: 2,
            total: 10,
            seconds: 30,
            q: 'Opet?',
            unit: '',
          ),
        );
        expect(find.text('Opet?'), findsOneWidget);
        expect(_display(t), '0', reason: 'nothing carries over');
      },
    );

    testWidgets(
      'a reload into the reveal still shows the unit (it comes with the result)',
      (t) async {
        final c = await app(t);
        await send(
          t,
          c,
          const KolikoResult(
            answer: 330,
            value: 320,
            rank: 1,
            points: 1000,
            total: 1000,
            unit: 'm',
          ),
        );
        expect(find.text('330 m'), findsOneWidget);
        expect(find.text('320 m'), findsOneWidget);
      },
    );

    testWidgets('an older TV sends no unit: the question\'s is used', (
      t,
    ) async {
      final c = await app(t);
      await send(
        t,
        c,
        const KolikoAsk(number: 1, total: 10, seconds: 30, q: 'Q', unit: 'kg'),
      );
      await send(
        t,
        c,
        const KolikoResult(
          answer: 5,
          value: 5,
          rank: 1,
          points: 1500,
          total: 1500,
        ),
      );
      expect(find.text('5 kg'), findsNWidgets(2)); // the answer and your number
    });

    testWidgets('a question that follows a question gets a fresh pad', (
      t,
    ) async {
      final c = await app(t);
      await send(
        t,
        c,
        const KolikoAsk(
          number: 1,
          total: 10,
          seconds: 30,
          q: 'Prvo?',
          unit: '',
        ),
      );
      await _tap(t, '5');
      await send(
        t,
        c,
        const KolikoAsk(
          number: 2,
          total: 10,
          seconds: 30,
          q: 'Drugo?',
          unit: '',
        ),
      );
      expect(_display(t), '0');
    });

    testWidgets('a reload after answering shows the sent number', (t) async {
      final c = await app(t);
      await send(
        t,
        c,
        const KolikoAsk(
          number: 3,
          total: 10,
          seconds: 12,
          q: 'Q',
          unit: '',
          sent: 42,
        ),
      );
      expect(_display(t), '42');
      expect(find.byKey(const ValueKey('koliko-send')), findsNothing);
    });

    testWidgets('host settings: card line, rows, whole settings sent', (
      t,
    ) async {
      final c = await app(t);
      for (var i = 0; i < 5; i++) {
        await t.drag(find.byType(PageView), const Offset(-320, 0));
        await t.pumpAndSettle();
      }
      expect(
        t.widget<Text>(find.byKey(const ValueKey('line-koliko'))).data,
        'Svi paketi · 10 pitanja · 30 s',
      );
      await send(
        t,
        c,
        lobby(
          sel: GameKind.koliko,
          s: const GameSettings(quizSeconds: 25, objasniTarget: 50),
        ),
      );
      await t.tap(find.byKey(const ValueKey('koliko-seconds-45')));
      var s = (c.sent.last as SetSettings).settings;
      expect((s.kolikoSeconds, s.quizSeconds, s.objasniTarget), (45, 25, 50));
      await t.tap(find.byKey(const ValueKey('koliko-questions-15')));
      expect((c.sent.last as SetSettings).settings.kolikoQuestions, 15);
      await t.tap(find.byKey(const ValueKey('pack-l')));
      await t.pumpAndSettle();
      s = (c.sent.last as SetSettings).settings;
      expect(s.kolikoOffPacks, {'l'});
      expect(s.kolikoPackId, isNull);
      await t.tap(find.text(Strings.play));
      expect(c.sent.last, const StartGame(GameKind.koliko, null));
    });
  });
}
