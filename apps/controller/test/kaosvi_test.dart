import 'package:controller/app.dart';
import 'package:controller/screens/kaosvi_screens.dart';
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

const _groups = [
  MergeGroup(1, 'jabuka'),
  MergeGroup(2, 'jabuke'),
  MergeGroup(3, 'kruška'),
];

void main() {
  group('the merge screen (host)', () {
    Widget merge({
      void Function(int, int)? onMerge,
      VoidCallback? onDone,
      List<MergeGroup> groups = _groups,
      int seconds = 15,
    }) => KaosviMergeScreen(
      seconds: seconds,
      groups: groups,
      onMerge: onMerge ?? (_, _) {},
      onDone: onDone ?? () {},
    );

    testWidgets('the groups as answers, a clock, 56 px targets', (t) async {
      await _show(t, merge());
      for (final g in _groups) {
        expect(find.text(g.text), findsOneWidget);
        expect(
          t.getSize(find.byKey(ValueKey('group-${g.id}'))).height,
          greaterThanOrEqualTo(56),
        );
      }
      expect(find.text('0:15'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      expect(find.text('0:12'), findsOneWidget);
    });

    testWidgets('tap two groups: they are asked to merge, in that order', (
      t,
    ) async {
      final merged = <(int, int)>[];
      await _show(t, merge(onMerge: (a, b) => merged.add((a, b))));
      await t.tap(find.byKey(const ValueKey('group-2')));
      await t.pump();
      expect(merged, isEmpty, reason: 'one tap only picks');
      await t.tap(find.byKey(const ValueKey('group-1')));
      await t.pump();
      expect(merged, [(2, 1)]);
    });

    testWidgets('tapping the same group twice un-picks it', (t) async {
      final merged = <(int, int)>[];
      await _show(t, merge(onMerge: (a, b) => merged.add((a, b))));
      await t.tap(find.byKey(const ValueKey('group-1')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('group-1')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('group-3')));
      await t.pump();
      expect(merged, isEmpty);
    });

    testWidgets('a pick of a group that the TV has merged away is dropped', (
      t,
    ) async {
      final merged = <(int, int)>[];
      Widget screen(List<MergeGroup> g) => MaterialApp(
        theme: theme,
        home: KaosviMergeScreen(
          key: const ValueKey('m'),
          seconds: 15,
          groups: g,
          onMerge: (a, b) => merged.add((a, b)),
          onDone: () {},
        ),
      );
      t.view.physicalSize = const Size(390, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(screen(_groups));
      await t.tap(find.byKey(const ValueKey('group-2')));
      await t.pump();
      await t.pumpWidget(
        screen(const [MergeGroup(1, 'jabuka'), MergeGroup(3, 'kruška')]),
      );
      await t.tap(find.byKey(const ValueKey('group-1')));
      await t.pump();
      expect(merged, isEmpty, reason: 'group 2 is gone; this tap only picks');
    });

    testWidgets('Gotovo ends the merge', (t) async {
      var done = 0;
      await _show(t, merge(onDone: () => done++));
      expect(
        t.getSize(find.byKey(const ValueKey('merge-done'))).height,
        greaterThanOrEqualTo(56),
      );
      await t.tap(find.byKey(const ValueKey('merge-done')));
      expect(done, 1);
    });

    testWidgets('fits 360 px with eight long answers', (t) async {
      await _show(
        t,
        merge(
          groups: [
            for (var i = 0; i < 8; i++) MergeGroup(i, 'odgovor broj $i dug'),
          ],
        ),
        width: 360,
        h: 640,
      );
      expect(t.takeException(), isNull);
    });
  });

  group('the result', () {
    Widget result({
      String? answer = 'jabuka',
      int size = 3,
      int points = 1,
      bool largest = true,
      bool lone = false,
    }) => KaosviResultScreen(
      answer: answer,
      size: size,
      points: points,
      total: 5,
      largest: largest,
      lone: lone,
    );

    testWidgets('your group, your points, your total', (t) async {
      await _show(t, result());
      expect(find.text('jabuka'), findsOneWidget);
      expect(find.text(Strings.groupSize(3)), findsOneWidget);
      expect(find.text(Strings.largestGroup), findsOneWidget);
      expect(find.text('+1 bod'), findsOneWidget);
      expect(find.text(Strings.totalScore(5)), findsOneWidget);
    });

    testWidgets('the lone answer and the -1', (t) async {
      await _show(
        t,
        result(
          answer: 'ananas',
          size: 1,
          points: -1,
          largest: false,
          lone: true,
        ),
      );
      expect(find.text(Strings.loneAnswer), findsOneWidget);
      expect(find.text('−1 bod'), findsOneWidget);
      expect(find.text(Strings.groupSize(1)), findsOneWidget);
    });

    testWidgets('a tie or a small group: no headline, 0 points; no answer', (
      t,
    ) async {
      await _show(t, result(points: 0, largest: false, size: 2));
      expect(find.byKey(const ValueKey('headline')), findsNothing);
      expect(find.text('0 bodova'), findsOneWidget);
      await _show(t, result(answer: null, size: 0, points: 0, largest: false));
      expect(find.text(Strings.noAnswer), findsOneWidget);
      expect(find.byKey(const ValueKey('group-size')), findsNothing);
    });
  });

  group('through the app', () {
    LobbyState lobby({GameKind? sel, GameSettings s = const GameSettings()}) =>
        LobbyState(
          hostId: 0,
          selected: sel,
          settings: s,
          packs: const [],
          kaosviPacks: const [
            PackInfo('o', 'Općenito', 66),
            PackInfo('h', 'Hrana', 65),
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

    Future<FakeConnection> app(WidgetTester t, int me) async {
      t.view.physicalSize = const Size(390, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final c = FakeConnection();
      await t.pumpWidget(App(c));
      for (final m in <Message>[Welcome(me, me, 'tok'), lobby()]) {
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

    const ask = KaosviAsk(
      number: 1,
      total: 12,
      seconds: 30,
      q: 'Navedi voće.',
      sent: null,
    );

    testWidgets('an answer goes out as KaosviAnswer, 30 characters at most', (
      t,
    ) async {
      final c = await app(t, 1);
      await send(t, c, ask);
      await t.enterText(find.byKey(const ValueKey('blef-field')), 'č' * 40);
      await t.tap(find.byKey(const ValueKey('blef-send')));
      expect((c.sent.last as KaosviAnswer).text.length, 30);
    });

    testWidgets(
      'a refusal shows under the field; the ack locks and keeps the answer',
      (t) async {
        final c = await app(t, 1);
        await send(t, c, ask);
        await send(t, c, const ErrorMsg('Upiši svoj odgovor.'));
        expect(find.byKey(const ValueKey('blef-error')), findsOneWidget);
        expect(find.text(Strings.ok), findsNothing, reason: 'no red banner');
        await send(
          t,
          c,
          const KaosviAsk(
            number: 1,
            total: 12,
            seconds: 22,
            q: 'Navedi voće.',
            sent: 'Jabuka',
          ),
        );
        expect(find.byKey(const ValueKey('blef-field')), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('blef-sent')),
            matching: find.text('Jabuka'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a reload into an answered question shows the kept answer', (
      t,
    ) async {
      final c = await app(t, 1);
      await send(
        t,
        c,
        const KaosviAsk(
          number: 3,
          total: 12,
          seconds: 9,
          q: 'Q',
          sent: 'kruška',
        ),
      );
      expect(find.text('kruška'), findsOneWidget);
      expect(find.byKey(const ValueKey('blef-send')), findsNothing);
    });

    testWidgets('the host merges: groups, a merge, Gotovo', (t) async {
      final c = await app(t, 0);
      await send(t, c, ask);
      await send(
        t,
        c,
        const KaosviMerging(
          seconds: 15,
          host: true,
          groups: [KaosviMergeItem(1, 'jabuka'), KaosviMergeItem(2, 'jabuke')],
        ),
      );
      await t.tap(find.byKey(const ValueKey('group-1')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('group-2')));
      expect(c.sent.last, const KaosviMerge(1, 2));
      await send(
        t,
        c,
        const KaosviMerging(
          seconds: 11,
          host: true,
          groups: [KaosviMergeItem(1, 'jabuka')],
        ),
      );
      expect(find.byKey(const ValueKey('group-2')), findsNothing);
      await t.tap(find.byKey(const ValueKey('merge-done')));
      expect(c.sent.last, const KaosviDone());
    });

    testWidgets('everyone else waits and sees no answer text', (t) async {
      final c = await app(t, 1);
      await send(t, c, ask);
      // even if groups were sent by mistake, a non-host shows none of them
      await send(
        t,
        c,
        const KaosviMerging(
          seconds: 15,
          host: false,
          groups: [KaosviMergeItem(1, 'tajna')],
        ),
      );
      expect(find.byKey(const ValueKey('merge-wait')), findsOneWidget);
      expect(find.text('tajna'), findsNothing);
      expect(find.byKey(const ValueKey('merge-done')), findsNothing);
    });

    testWidgets('the result, then the next question is a fresh field', (
      t,
    ) async {
      final c = await app(t, 1);
      await send(t, c, ask);
      await send(
        t,
        c,
        const KaosviResult(
          answer: 'jabuka',
          size: 2,
          points: 1,
          total: 1,
          largest: true,
          lone: false,
        ),
      );
      expect(find.text(Strings.largestGroup), findsOneWidget);
      await send(
        t,
        c,
        const KaosviAsk(
          number: 2,
          total: 12,
          seconds: 30,
          q: 'Drugo?',
          sent: null,
        ),
      );
      expect(find.text('Drugo?'), findsOneWidget);
      expect(find.byKey(const ValueKey('blef-field')), findsOneWidget);
    });

    testWidgets('host settings: card, rows, the whole settings sent', (
      t,
    ) async {
      final c = await app(t, 0);
      for (var i = 0; i < 8; i++) {
        await t.drag(find.byType(PageView), const Offset(-320, 0));
        await t.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('card-kaosvi')), findsOneWidget);
      await send(
        t,
        c,
        lobby(
          sel: GameKind.kaosvi,
          s: const GameSettings(quizSeconds: 25, tkobiPrompts: 15),
        ),
      );
      await t.tap(find.byKey(const ValueKey('kaosvi-questions-16')));
      var s = (c.sent.last as SetSettings).settings;
      expect((s.kaosviQuestions, s.quizSeconds, s.tkobiPrompts), (16, 25, 15));
      await t.tap(find.byKey(const ValueKey('kaosvi-target-10')));
      expect((c.sent.last as SetSettings).settings.kaosviTarget, 10);
      await t.tap(find.byKey(const ValueKey('kaosvi-pack')));
      await t.pumpAndSettle();
      await t.tap(find.text('Hrana').last);
      await t.pumpAndSettle();
      expect((c.sent.last as SetSettings).settings.kaosviPackId, 'h');
      await t.tap(find.text(Strings.play));
      expect(c.sent.last, const StartGame(GameKind.kaosvi, null));
    });

    testWidgets('a quiz stepper keeps the Kao svi settings', (t) async {
      final c = await app(t, 0);
      await send(
        t,
        c,
        lobby(
          sel: GameKind.quiz,
          s: const GameSettings(
            kaosviQuestions: 16,
            kaosviTarget: 10,
            kaosviPackId: 'h',
          ),
        ),
      );
      await t.tap(find.byTooltip(Strings.moreOf(Strings.quizSeconds)));
      final n = (c.sent.last as SetSettings).settings;
      expect(
        (n.kaosviQuestions, n.kaosviTarget, n.kaosviPackId),
        (16, 10, 'h'),
      );
    });
  });
}
