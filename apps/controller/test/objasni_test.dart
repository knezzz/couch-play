import 'package:controller/app.dart';
import 'package:controller/screens/objasni_screens.dart';
import 'package:controller/strings.dart';
import 'package:controller/theme.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

const _teams = [
  [TeamMember(0, 'Luka', 'fox', 0), TeamMember(1, 'Ana', 'owl', 1)],
  [TeamMember(2, 'Marko', 'frog', 2), TeamMember(3, 'Ivana', 'bear', 3)],
];

Future<void> _show(WidgetTester t, Widget w, {double width = 390}) async {
  t.view.physicalSize = Size(width, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(theme: theme, home: w));
}

Widget _turn({
  ObjasniStage stage = ObjasniStage.play,
  ObjasniRole role = ObjasniRole.explain,
  String? word = 'Kišobran',
  int seconds = 60,
  void Function(ObjasniAct)? onAct,
  VoidCallback? onGo,
}) => ObjasniTurnScreen(
  stage: stage,
  role: role,
  team: 0,
  explainerName: 'Ana',
  word: word,
  seconds: seconds,
  scores: const [12, 9],
  onGo: onGo ?? () {},
  onAct: onAct ?? (_) {},
);

void main() {
  group('setup', () {
    Widget setup({
      bool host = true,
      void Function()? reshuffle,
      void Function()? go,
    }) => ObjasniSetupScreen(
      teams: _teams,
      myTeam: 1,
      isHost: host,
      hostName: 'Luka',
      onReshuffle: reshuffle ?? () {},
      onGo: go ?? () {},
    );

    testWidgets('both teams with their members; my team is named', (t) async {
      await _show(t, setup());
      for (final n in [
        'Luka',
        'Ana',
        'Marko',
        'Ivana',
        Strings.team1,
        Strings.team2,
      ]) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(find.text(Strings.yourTeam(1)), findsOneWidget);
    });

    testWidgets('the host can Promiješaj and Igraj', (t) async {
      var r = 0, g = 0;
      await _show(t, setup(reshuffle: () => r++, go: () => g++));
      expect(
        t.getSize(find.byKey(const ValueKey('objasni-go'))).height,
        greaterThanOrEqualTo(64),
      );
      await t.tap(find.byKey(const ValueKey('reshuffle')));
      await t.tap(find.byKey(const ValueKey('objasni-go')));
      expect((r, g), (1, 1));
    });

    testWidgets('the others only wait', (t) async {
      await _show(t, setup(host: false));
      expect(find.byKey(const ValueKey('reshuffle')), findsNothing);
      expect(find.byKey(const ValueKey('objasni-go')), findsNothing);
      expect(find.text(Strings.waitingForHost('Luka')), findsOneWidget);
    });
  });

  group('a turn', () {
    testWidgets('the explainer: the word, Točno and Preskoči (64 px+)', (
      t,
    ) async {
      final acts = <ObjasniAct>[];
      await _show(t, _turn(onAct: acts.add));
      expect(find.text('Kišobran'), findsOneWidget);
      for (final k in ['act-correct', 'act-skip']) {
        expect(
          t.getSize(find.byKey(ValueKey(k))).height,
          greaterThanOrEqualTo(64),
        );
      }
      expect(find.byKey(const ValueKey('act-foul')), findsNothing);
      await t.tap(find.byKey(const ValueKey('act-correct')));
      await t.tap(find.byKey(const ValueKey('act-skip')));
      expect(acts, [ObjasniAct.correct, ObjasniAct.skip]);
    });

    testWidgets('the button labels stay on one line, also at 360 px', (
      t,
    ) async {
      for (final w in [390.0, 360.0]) {
        await _show(t, _turn(), width: w);
        for (final label in [Strings.skip, Strings.right]) {
          final h = t.getSize(find.text(label)).height;
          expect(h, lessThan(40), reason: '$label at $w px is one line');
        }
      }
    });

    testWidgets('the other team: the same word and Prekršaj only', (t) async {
      final acts = <ObjasniAct>[];
      await _show(t, _turn(role: ObjasniRole.watch, onAct: acts.add));
      expect(find.text('Kišobran'), findsOneWidget);
      expect(find.byKey(const ValueKey('act-correct')), findsNothing);
      expect(find.byKey(const ValueKey('act-skip')), findsNothing);
      await t.tap(find.byKey(const ValueKey('act-foul')));
      expect(acts, [ObjasniAct.foul]);
    });

    testWidgets('the explainer\'s team: no word, no buttons, Pogađaj naglas!', (
      t,
    ) async {
      // even a word that should not be there is never drawn
      await _show(t, _turn(role: ObjasniRole.guess, word: 'tajna'));
      expect(find.text('tajna'), findsNothing);
      expect(find.text(Strings.guessAloud), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byKey(const ValueKey('turn-clock')), findsOneWidget);
    });

    testWidgets('ready: only the explainer has Kreni', (t) async {
      var go = 0;
      await _show(
        t,
        _turn(stage: ObjasniStage.ready, word: null, onGo: () => go++),
      );
      await t.tap(find.byKey(const ValueKey('kreni')));
      expect(go, 1);
      await _show(
        t,
        _turn(stage: ObjasniStage.ready, role: ObjasniRole.guess, word: null),
      );
      expect(find.byKey(const ValueKey('kreni')), findsNothing);
      expect(find.text(Strings.onTurn('Ana')), findsOneWidget);
    });

    testWidgets('summary shows the turn is over; scores stay on top', (
      t,
    ) async {
      await _show(t, _turn(stage: ObjasniStage.summary, word: null));
      expect(find.text(Strings.turnOver), findsOneWidget);
      expect(find.text('Tim 1 · 12'), findsOneWidget);
      expect(find.text('Tim 2 · 9'), findsOneWidget);
    });

    testWidgets('the clock counts down, and a new message restates it', (
      t,
    ) async {
      await _show(t, _turn(seconds: 60));
      expect(find.text('1:00'), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
      expect(find.text('0:55'), findsOneWidget);
      await _show(t, _turn(seconds: 40));
      expect(find.text('0:40'), findsOneWidget);
    });

    testWidgets('fits 360 px with a long word', (t) async {
      await _show(
        t,
        _turn(word: 'Prekooceanski brodovi i zrakoplovi'),
        width: 360,
      );
      expect(t.takeException(), isNull);
    });
  });

  group('through the app', () {
    LobbyState lobby(
      int host, {
      GameKind? sel,
      GameSettings s = const GameSettings(),
    }) => LobbyState(
      hostId: host,
      selected: sel,
      settings: s,
      packs: const [],
      objasniPacks: const [
        PackInfo('a', 'Općenito', 120),
        PackInfo('b', 'Hrana', 110),
      ],
      players: [
        for (var i = 0; i < 4; i++)
          PlayerInfo(
            i,
            ['Luka', 'Ana', 'Marko', 'Ivana'][i],
            i,
            true,
            0,
            character: characterIds[i],
          ),
      ],
    );

    Future<FakeConnection> app(WidgetTester t, int me, [LobbyState? l]) async {
      t.view.physicalSize = const Size(390, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final c = FakeConnection();
      await t.pumpWidget(App(c));
      for (final m in <Message>[Welcome(me, me, 'tok'), l ?? lobby(0)]) {
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

    const teams = ObjasniTeams(
      team: 0,
      teams: [
        [0, 1],
        [2, 3],
      ],
    );

    testWidgets('ObjasniTeams opens the setup; the host\'s buttons send', (
      t,
    ) async {
      final c = await app(t, 0);
      await send(t, c, teams);
      expect(find.text(Strings.teamsTitle), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('reshuffle')));
      expect(c.sent.last, const Reshuffle());
      await t.tap(find.byKey(const ValueKey('objasni-go')));
      expect(c.sent.last, const Go());
    });

    testWidgets('a guest sees the setup without buttons', (t) async {
      final c = await app(t, 2);
      await send(
        t,
        c,
        const ObjasniTeams(
          team: 1,
          teams: [
            [0, 1],
            [2, 3],
          ],
        ),
      );
      expect(find.byKey(const ValueKey('reshuffle')), findsNothing);
      expect(find.text(Strings.yourTeam(1)), findsOneWidget);
    });

    testWidgets('ObjasniTurn per role, the actions go out', (t) async {
      final c = await app(t, 1);
      await send(t, c, teams);
      await send(
        t,
        c,
        const ObjasniTurn(
          stage: ObjasniStage.play,
          role: ObjasniRole.explain,
          team: 0,
          explainer: 1,
          word: 'Sir',
          seconds: 60,
          scores: [0, 0],
        ),
      );
      expect(find.text('Sir'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('act-correct')));
      expect(c.sent.last, const ObjasniAction(ObjasniAct.correct));
      await send(
        t,
        c,
        const ObjasniTurn(
          stage: ObjasniStage.play,
          role: ObjasniRole.explain,
          team: 0,
          explainer: 1,
          word: 'Med',
          seconds: 57,
          scores: [1, 0],
        ),
      );
      expect(find.text('Med'), findsOneWidget);
      expect(find.text('Sir'), findsNothing);
      expect(find.text('Tim 1 · 1'), findsOneWidget);
    });

    testWidgets('a new draw goes back to the setup', (t) async {
      final c = await app(t, 0);
      await send(t, c, teams);
      await send(
        t,
        c,
        const ObjasniTurn(
          stage: ObjasniStage.ready,
          role: ObjasniRole.explain,
          team: 0,
          explainer: 0,
          word: null,
          seconds: 60,
          scores: [0, 0],
        ),
      );
      expect(find.byKey(const ValueKey('kreni')), findsOneWidget);
      await send(
        t,
        c,
        const ObjasniTeams(
          team: 1,
          teams: [
            [2, 1],
            [0, 3],
          ],
        ),
      );
      expect(find.byKey(const ValueKey('kreni')), findsNothing);
      expect(find.text(Strings.teamsTitle), findsOneWidget);
    });

    testWidgets('host settings: card line, three rows, whole settings sent', (
      t,
    ) async {
      final c = await app(
        t,
        0,
        lobby(0, s: const GameSettings(quizSeconds: 25, wolfDiscussion: 60)),
      );
      for (var i = 0; i < 4; i++) {
        await t.drag(find.byType(PageView), const Offset(-320, 0));
        await t.pumpAndSettle();
      }
      expect(
        t.widget<Text>(find.byKey(const ValueKey('line-objasni'))).data,
        'Općenito · 60 s · 30 bodova',
      );
      await send(
        t,
        c,
        lobby(
          0,
          sel: GameKind.objasni,
          s: const GameSettings(quizSeconds: 25, wolfDiscussion: 60),
        ),
      );
      await t.tap(find.byKey(const ValueKey('objasni-seconds-90')));
      var s = (c.sent.last as SetSettings).settings;
      expect((s.objasniSeconds, s.quizSeconds, s.wolfDiscussion), (90, 25, 60));
      await t.tap(find.byKey(const ValueKey('objasni-target-50')));
      s = (c.sent.last as SetSettings).settings;
      expect(s.objasniTarget, 50);
      await t.tap(find.byKey(const ValueKey('objasni-pack')));
      await t.pumpAndSettle();
      await t.tap(find.text('Hrana').last);
      await t.pumpAndSettle();
      expect((c.sent.last as SetSettings).settings.objasniPackId, 'b');
      await t.tap(find.text(Strings.play));
      expect(c.sent.last, const StartGame(GameKind.objasni, null));
    });
  });
}
