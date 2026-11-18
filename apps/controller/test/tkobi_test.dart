import 'package:controller/app.dart';
import 'package:controller/screens/tkobi_screens.dart';
import 'package:controller/strings.dart';
import 'package:controller/theme.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

const _players = [
  TkobiPlayer(0, 'Luka', 'fox', 0),
  TkobiPlayer(1, 'Ana', 'owl', 1),
  TkobiPlayer(2, 'Marko', 'frog', 2),
];

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
  group('the vote', () {
    Widget ask({void Function(int)? onVote, int? picked, int seconds = 15}) =>
        TkobiAskScreen(
          number: 4,
          total: 10,
          seconds: seconds,
          text: 'Tko bi najvjerojatnije zaspao na vlastitom rođendanu?',
          players: _players,
          picked: picked,
          onVote: onVote ?? (_) {},
        );

    testWidgets('every player is a row, yourself included; rows are 64 px', (
      t,
    ) async {
      await _show(t, ask());
      for (final p in _players) {
        expect(
          t.getSize(find.byKey(ValueKey('vote-${p.id}'))).height,
          greaterThanOrEqualTo(56),
        );
        expect(find.text(p.name), findsOneWidget);
      }
      expect(find.text('Pitanje 4 od 10'), findsOneWidget);
      expect(find.text('0:15'), findsOneWidget);
    });

    testWidgets('one tap votes, and it is final', (t) async {
      final votes = <int>[];
      await _show(t, ask(onVote: votes.add));
      await t.tap(find.byKey(const ValueKey('vote-1')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('vote-2')));
      expect(votes, [1]);
      expect(find.byKey(const ValueKey('tkobi-voted')), findsOneWidget);
    });

    testWidgets('after a reload the vote is shown and the list is shut', (
      t,
    ) async {
      final votes = <int>[];
      await _show(t, ask(onVote: votes.add, picked: 2));
      await t.tap(find.byKey(const ValueKey('vote-0')));
      expect(votes, isEmpty);
      expect(find.byKey(const ValueKey('tkobi-voted')), findsOneWidget);
    });

    testWidgets('when the time is out nothing can be voted', (t) async {
      final votes = <int>[];
      await _show(t, ask(onVote: votes.add, seconds: 1));
      await t.pump(const Duration(seconds: 2));
      await t.tap(find.byKey(const ValueKey('vote-0')));
      expect(votes, isEmpty);
    });

    testWidgets('fits 360 px', (t) async {
      await _show(t, ask(), width: 360, h: 640);
      expect(t.takeException(), isNull);
    });
  });

  group('the result', () {
    Widget result({bool right = true, List<int> crowned = const [1]}) =>
        TkobiResultScreen(
          players: _players,
          counts: const {0: 1, 1: 3, 2: 0},
          crowned: crowned,
          votedRight: right,
          points: right ? 1 : 0,
          total: 4,
        );

    testWidgets('the votes each got, the crown, and nobody\'s vote', (t) async {
      await _show(t, result());
      expect(t.widget<Text>(find.byKey(const ValueKey('count-1'))).data, '3');
      expect(t.widget<Text>(find.byKey(const ValueKey('count-2'))).data, '0');
      expect(find.byKey(const ValueKey('crown')), findsOneWidget);
      expect(find.text(Strings.tkobiRight), findsOneWidget);
      expect(find.text('+1 bod · ${Strings.totalScore(4)}'), findsOneWidget);
    });

    testWidgets('a tie crowns everyone tied; a wrong vote says so', (t) async {
      await _show(t, result(right: false, crowned: const [0, 1]));
      expect(find.byKey(const ValueKey('crown')), findsNWidgets(2));
      expect(find.text(Strings.tkobiWrong), findsOneWidget);
    });
  });

  group('through the app', () {
    LobbyState lobby({GameKind? sel, GameSettings s = const GameSettings()}) =>
        LobbyState(
          hostId: 0,
          selected: sel,
          settings: s,
          packs: const [],
          tkobiPacks: const [
            PackInfo('b', 'Blago', 40),
            PackInfo('l', 'Ljuto', 35),
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

    const ask = TkobiAsk(
      number: 1,
      total: 10,
      seconds: 15,
      text: 'Tko bi?',
      ids: [0, 1, 2],
    );

    testWidgets('a tap sends Vote(target), yourself included, once', (t) async {
      final c = await app(t);
      await send(t, c, ask);
      await t.tap(find.byKey(const ValueKey('vote-0')));
      expect(c.sent.last, const Vote(0));
      await t.tap(find.byKey(const ValueKey('vote-1')));
      expect(c.sent.whereType<Vote>().length, 1);
    });

    testWidgets(
      'the result follows the vote; the next prompt is a fresh vote',
      (t) async {
        final c = await app(t);
        await send(t, c, ask);
        await t.tap(find.byKey(const ValueKey('vote-1')));
        await send(
          t,
          c,
          const TkobiResult(
            counts: {0: 0, 1: 2, 2: 1},
            crowned: [1],
            votedRight: true,
            points: 1,
            total: 1,
          ),
        );
        expect(find.text(Strings.tkobiRight), findsOneWidget);
        await send(
          t,
          c,
          const TkobiAsk(
            number: 2,
            total: 10,
            seconds: 15,
            text: 'Opet?',
            ids: [0, 1, 2],
          ),
        );
        expect(find.text('Opet?'), findsOneWidget);
        expect(find.byKey(const ValueKey('tkobi-voted')), findsNothing);
        await t.tap(find.byKey(const ValueKey('vote-2')));
        expect(c.sent.last, const Vote(2));
      },
    );

    testWidgets('the crowned phone plays the confetti the TV asks for', (
      t,
    ) async {
      final c = await app(t);
      await send(t, c, ask);
      await send(
        t,
        c,
        const TkobiResult(
          counts: {0: 3, 1: 0, 2: 0},
          crowned: [0],
          votedRight: false,
          points: 0,
          total: 0,
        ),
      );
      await send(t, c, const Effect('confetti'));
      expect(t.binding.transientCallbackCount, greaterThan(0));
      await t.pump(const Duration(seconds: 4));
    });

    testWidgets('host settings: card line, rows, whole settings sent', (
      t,
    ) async {
      final c = await app(t);
      for (var i = 0; i < 7; i++) {
        await t.drag(find.byType(PageView), const Offset(-320, 0));
        await t.pumpAndSettle();
      }
      expect(
        t.widget<Text>(find.byKey(const ValueKey('line-tkobi'))).data,
        'Svi paketi · 10 pitanja',
      );
      await send(
        t,
        c,
        lobby(
          sel: GameKind.tkobi,
          s: const GameSettings(quizSeconds: 25, blefQuestions: 10),
        ),
      );
      await t.tap(find.byKey(const ValueKey('tkobi-prompts-15')));
      var s = (c.sent.last as SetSettings).settings;
      expect((s.tkobiPrompts, s.quizSeconds, s.blefQuestions), (15, 25, 10));
      await t.tap(find.byKey(const ValueKey('pack-l')));
      await t.pumpAndSettle();
      s = (c.sent.last as SetSettings).settings;
      expect(s.tkobiOffPacks, {'l'});
      expect(s.tkobiPackId, isNull);
      await t.tap(find.text(Strings.play));
      expect(c.sent.last, const StartGame(GameKind.tkobi, null));
    });
  });
}
