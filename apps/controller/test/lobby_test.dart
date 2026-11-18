import 'package:controller/app.dart';
import 'package:controller/screens/lobby_screen.dart';
import 'package:controller/strings.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

LobbyState _lobby({int humans = 2, int bots = 0, int host = 0}) => LobbyState(
  hostId: host,
  packs: const [],
  players: [
    for (var i = 0; i < humans; i++) PlayerInfo(i, 'P$i', i, true, 0),
    for (var i = 0; i < bots; i++)
      PlayerInfo(10 + i, 'Bot ${i + 1}', humans + i, true, 0, bot: true),
  ],
);

/// The broadcast stream delivers in a microtask, so pump twice.
Future<void> _send(WidgetTester t, FakeConnection c, Message m) async {
  c.inbox.add(m);
  await t.pump();
  await t.pump();
}

Future<FakeConnection> _pump(
  WidgetTester t,
  LobbyState l,
  int me, {
  Future<String?> Function(String token)? addPack,
}) async {
  final c = FakeConnection();
  // Tall, so the details' Igraj button is built; 360 px tests set their own size.
  if (t.view.physicalSize.width > 400)
    t.view.physicalSize = const Size(390, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(home: LobbyScreen(c, l, me, addPack: addPack)),
  );
  return c;
}

LobbyState _sel(LobbyState l, GameKind? k) => LobbyState(
  players: l.players,
  packs: l.packs,
  hostId: l.hostId,
  settings: l.settings,
  selected: k,
);

/// Taps a game card, checks the phone only asked, then plays the TV's answer
/// (a LobbyState with that game selected).
Future<void> _openGame(
  WidgetTester t,
  FakeConnection c,
  LobbyState l,
  GameKind k, {
  Future<String?> Function(String token)? addPack,
}) async {
  final card = find.text(Strings.gameName(k)).first;
  await t.ensureVisible(card);
  await t.pumpAndSettle();
  await t.tap(card);
  expect(c.sent.last, SelectGame(k));
  await t.pumpWidget(
    MaterialApp(home: LobbyScreen(c, _sel(l, k), 0, addPack: addPack)),
  );
}

void main() {
  settingsTests();
  characterTests();
  testWidgets('host sees game, bots and kick controls; others do not', (
    t,
  ) async {
    await _pump(t, _lobby(), 0);
    expect(find.text(Strings.curve), findsOneWidget);
    expect(find.text(Strings.quiz), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, Strings.remove),
      findsOneWidget,
    ); // not for yourself
    expect(find.byIcon(Icons.add), findsOneWidget);
    // Your own chip is on top and not repeated under "Others".
    expect(find.text('P0'), findsOneWidget);
    expect(find.text(Strings.others(1)), findsOneWidget);
    expect(
      find.byIcon(Icons.star),
      findsOneWidget,
    ); // the star alone marks the host

    await _pump(t, _lobby(), 1);
    expect(find.text(Strings.curve), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.widgetWithText(TextButton, Strings.remove), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.textContaining('P0'), findsWidgets); // waiting for the host
  });

  testWidgets('bots + and - send SetBots with the right count', (t) async {
    final c = await _pump(t, _lobby(bots: 2), 0);
    await t.tap(find.byIcon(Icons.add));
    expect(c.sent.last, const SetBots(3));
    await t.tap(find.byIcon(Icons.remove));
    expect(c.sent.last, const SetBots(1));
  });

  testWidgets('bots buttons are disabled at 0 bots and at 8 seats', (t) async {
    final c = await _pump(t, _lobby(), 0);
    await t.tap(find.byIcon(Icons.remove));
    expect(c.sent, isEmpty);
    await _pump(t, _lobby(humans: 2, bots: 6), 0);
    await t.tap(find.byIcon(Icons.add));
    expect(c.sent, isEmpty);
  });

  testWidgets('a card opens details; Igraj starts that game', (t) async {
    final c = await _pump(t, _lobby(), 0);
    expect(find.text(Strings.play), findsNothing); // carousel: nothing to start
    expect(find.text(Strings.back), findsNothing);
    await _openGame(t, c, _lobby(), GameKind.curve);
    expect(find.text(Strings.back), findsOneWidget);
    expect(c.sent.whereType<StartGame>(), isEmpty);
    await t.tap(find.text(Strings.play));
    expect(c.sent.last, const StartGame(GameKind.curve, null));
  });

  testWidgets('quiz pack: the pick goes in SetSettings; Igraj sends no pack', (
    t,
  ) async {
    const packs = [PackInfo('a', 'Zastave', 40), PackInfo('b', 'Sport', 30)];
    final l = LobbyState(
      hostId: 0,
      packs: packs,
      settings: const GameSettings(quizSeconds: 30),
      players: _lobby().players,
    );
    final c = await _pump(t, l, 0);
    await _openGame(t, c, l, GameKind.quiz);
    await t.tap(find.byKey(const ValueKey('open-packs')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pack-b')));
    await t.pumpAndSettle();
    final sent = (c.sent.last as SetSettings).settings;
    expect(sent.quizOffPacks, {'b'});
    expect(sent.quizSeconds, 30);
    await t.tap(find.byKey(const ValueKey('packs-back')));
    await t.pumpAndSettle();
    await t.tap(find.text(Strings.play));
    expect(c.sent.last, const StartGame(GameKind.quiz, null));
  });

  testWidgets('Back returns to the carousel without starting anything', (
    t,
  ) async {
    final c = await _pump(t, _lobby(), 0);
    await _openGame(t, c, _lobby(), GameKind.quiz);
    await t.tap(find.text(Strings.back));
    expect(c.sent.last, const SelectGame(null));
    expect(c.sent.whereType<StartGame>(), isEmpty);
    // The phone does not switch by itself: the TV's LobbyState decides.
    expect(find.text(Strings.back), findsOneWidget);
    await t.pumpWidget(MaterialApp(home: LobbyScreen(c, _lobby(), 0)));
    expect(find.text(Strings.play), findsNothing);
    expect(find.byKey(const ValueKey('card-quiz')), findsOneWidget);
  });

  testWidgets('a guest has no cards to open and cannot start a game', (
    t,
  ) async {
    final c = await _pump(t, _lobby(), 1);
    expect(find.byKey(const ValueKey('card-quiz')), findsNothing);
    expect(find.text(Strings.play), findsNothing);
    expect(c.sent, isEmpty);
  });

  testWidgets(
    'a guest sees "<host> gleda: Kviz" when the TV reports a selection',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: LobbyScreen(FakeConnection(), _sel(_lobby(), GameKind.quiz), 1),
        ),
      );
      final card = find.byKey(const ValueKey('watching-card'));
      expect(
        find.descendant(
          of: card,
          matching: find.text(Strings.watchingLabel('P0')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(Strings.quiz)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Remove and BOT are 18 px and a row fits at 360 px with a 16-letter name',
    (t) async {
      t.view.physicalSize = const Size(360, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      const wide = 'WWWWWWWWWWWWWWWW';
      final l = LobbyState(
        hostId: 0,
        packs: const [],
        players: const [
          PlayerInfo(0, 'Host', 0, true, 0),
          PlayerInfo(1, wide, 1, true, 0),
          PlayerInfo(2, wide, 2, false, 0),
          PlayerInfo(10, wide, 3, true, 0, bot: true),
        ],
      );
      await _pump(t, l, 0);
      expect(t.takeException(), isNull);
      for (final label in [Strings.remove, Strings.botTag]) {
        for (final e in find.text(label).evaluate()) {
          final fs = (e.renderObject as RenderParagraph).text.style?.fontSize;
          expect(fs, 18, reason: label);
        }
      }
      expect(find.text(Strings.botTag), findsOneWidget);
    },
  );

  testWidgets('kick asks first: Keep sends nothing, Remove sends Kick once', (
    t,
  ) async {
    final c = await _pump(t, _lobby(), 0);
    await t.tap(find.widgetWithText(TextButton, Strings.remove));
    await t.pumpAndSettle();
    expect(find.text(Strings.removeTitle('P1')), findsOneWidget);
    expect(c.sent.whereType<Kick>(), isEmpty);
    await t.tap(find.text(Strings.keep));
    await t.pumpAndSettle();
    expect(c.sent.whereType<Kick>(), isEmpty);
    await t.tap(find.widgetWithText(TextButton, Strings.remove));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, Strings.remove));
    await t.pumpAndSettle();
    expect(c.sent.whereType<Kick>().map((k) => k.playerId), [1]);
  });

  testWidgets('Join and Join again buttons are 64 px high with 24 px text', (
    t,
  ) async {
    final c = FakeConnection();
    await t.pumpWidget(App(c));
    for (final label in [Strings.join, Strings.joinAgain]) {
      if (label == Strings.joinAgain) {
        await _send(t, c, const Welcome(0, 0, 'tok'));
        await _send(t, c, const Kicked());
      }
      expect(
        t.getSize(find.widgetWithText(FilledButton, label)).height,
        greaterThanOrEqualTo(64),
      );
      expect(
        t.renderObject<RenderParagraph>(find.text(label)).text.style?.fontSize,
        24,
      );
    }
  });

  testWidgets('Welcome then Waiting then Kicked route the screens', (t) async {
    final c = FakeConnection();
    await t.pumpWidget(App(c));
    await _send(t, c, const Welcome(0, 0, 'tok'));
    await _send(t, c, _lobby());
    expect(find.byType(LobbyScreen), findsOneWidget);
    await _send(t, c, const Waiting('Next game starts soon.'));
    expect(find.text('Next game starts soon.'), findsOneWidget);
    await _send(t, c, const Kicked());
    expect(find.text(Strings.removed), findsOneWidget);
    expect(find.text(Strings.joinAgain), findsOneWidget);
  });

  testWidgets('CurveStatus opens the curve screen; ErrorMsg is shown', (
    t,
  ) async {
    final c = FakeConnection();
    await t.pumpWidget(App(c));
    await _send(t, c, const Welcome(0, 0, 'tok'));
    await _send(t, c, _lobby());
    await _send(
      t,
      c,
      const ErrorMsg(
        'Curve needs at least 2 players. Add a bot or ask a friend to join.',
      ),
    );
    expect(
      find.textContaining('Curve needs at least 2 players'),
      findsOneWidget,
    );
    await _send(t, c, const CurveStatus(alive: true, score: 0, target: 20));
    expect(find.byKey(const ValueKey('steer-left')), findsOneWidget);
    await t.pumpWidget(const SizedBox()); // stop the ping timer
  });

  testWidgets(
    'Results leaves the curve screen; LobbyState returns to the lobby',
    (t) async {
      final c = FakeConnection();
      await t.pumpWidget(App(c));
      await _send(t, c, const Welcome(1, 1, 'tok'));
      await _send(t, c, _lobby());
      await _send(t, c, const CurveStatus(alive: true, score: 0, target: 20));
      expect(find.byKey(const ValueKey('steer-left')), findsOneWidget);
      await _send(
        t,
        c,
        const Results([Placement(0, 1, 20, 3), Placement(1, 2, 14, 2)]),
      );
      expect(find.byKey(const ValueKey('steer-left')), findsNothing);
      expect(find.text(Strings.placed(2)), findsOneWidget);
      expect(find.text(Strings.sessionPoints(2)), findsOneWidget);
      await _send(t, c, _lobby());
      expect(find.byType(LobbyScreen), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'quiz question, reveal, next question reset the lock, Results leaves',
    (t) async {
      final c = FakeConnection();
      await t.pumpWidget(App(c));
      await _send(t, c, const Welcome(1, 1, 'tok'));
      await _send(t, c, _lobby());
      await _send(t, c, const QuizQuestion(1, 2, ['a', 'b', 'c', 'd'], 20));
      await t.tap(find.text('b'));
      await t.pump();
      expect(find.text(Strings.locked), findsOneWidget);
      await _send(t, c, const QuizReveal(1, 750, 750));
      expect(find.text('+750'), findsOneWidget);
      await _send(t, c, const QuizQuestion(2, 2, ['e', 'f', 'g', 'h'], 20));
      expect(find.text(Strings.locked), findsNothing);
      expect(find.text('e'), findsOneWidget);
      await _send(t, c, const Results([Placement(1, 1, 750, 3)]));
      expect(find.text('e'), findsNothing);
    },
  );

  testWidgets(
    'QuizReveal with no current question (reconnect) still shows the reveal',
    (t) async {
      final c = FakeConnection();
      await t.pumpWidget(App(c));
      await _send(t, c, const Welcome(1, 1, 'tok'));
      await _send(t, c, _lobby());
      await _send(t, c, const QuizReveal(1, 0, 900));
      expect(find.text(Strings.notThisTime), findsOneWidget);
      expect(find.textContaining('900'), findsOneWidget);
    },
  );

  testWidgets('LobbyState also leaves the curve screen directly', (t) async {
    final c = FakeConnection();
    await t.pumpWidget(App(c));
    await _send(t, c, const Welcome(0, 0, 'tok'));
    await _send(t, c, const CurveStatus(alive: true, score: 0, target: 20));
    await _send(t, c, _lobby());
    expect(find.byType(LobbyScreen), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'when you crash, a message shows and steering is inert until next round',
    (t) async {
      final c = FakeConnection();
      await t.pumpWidget(App(c));
      await _send(t, c, const Welcome(0, 0, 'tok'));
      await _send(t, c, const CurveStatus(alive: false, score: 1, target: 20));
      expect(find.text(Strings.crashed), findsOneWidget);
      c.sent.clear();
      final g = await t.startGesture(const Offset(50, 300));
      await g.up();
      expect(
        c.sent.whereType<Steer>().where((s) => s.left || s.right),
        isEmpty,
      );
      await _send(t, c, const CurveStatus(alive: true, score: 1, target: 20));
      expect(find.text(Strings.crashed), findsNothing);
      final g2 = await t.startGesture(const Offset(50, 300));
      expect(c.sent.last, const Steer(left: true, right: false));
      await g2.up();
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the crashed message has a solid backing panel', (t) async {
    final c = FakeConnection();
    await t.pumpWidget(App(c));
    await _send(t, c, const Welcome(0, 0, 'tok'));
    await _send(t, c, const CurveStatus(alive: false, score: 0, target: 20));
    final panel = find.ancestor(
      of: find.text(Strings.crashed),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox && (w.decoration as BoxDecoration).color != null,
      ),
    );
    expect(panel, findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('an Effect from the TV plays; an unknown one is ignored', (
    t,
  ) async {
    final c = FakeConnection();
    await t.pumpWidget(App(c));
    await _send(t, c, const Welcome(0, 0, 'tok'));
    await _send(t, c, _lobby());
    expect(t.binding.transientCallbackCount, 0);
    await _send(t, c, const Effect('nope'));
    expect(t.binding.transientCallbackCount, 0);
    await _send(t, c, const Effect('confetti'));
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await t.pump(const Duration(seconds: 3));
    await _send(t, c, const Effect('colorPulse'));
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('only the host gets Add quiz pack', (t) async {
    Future<String?> pick(String _) async => null;
    final c = await _pump(t, _lobby(), 0, addPack: pick);
    expect(find.text(Strings.addPack), findsNothing); // not on the carousel
    await _openGame(t, c, _lobby(), GameKind.quiz, addPack: pick);
    expect(find.text(Strings.addPack), findsNothing); // it lives in the grid
    await t.tap(find.byKey(const ValueKey('open-packs')));
    await t.pumpAndSettle();
    expect(find.text(Strings.addPack), findsOneWidget);
    await t.pumpWidget(const SizedBox()); // drops the pushed grid
    await _pump(t, _lobby(), 1, addPack: pick);
    expect(find.text(Strings.addPack), findsNothing);
  });

  testWidgets('Add quiz pack passes the token and shows the TV message', (
    t,
  ) async {
    String? token;
    Future<String?> add(String tok) async {
      token = tok;
      return 'Added World Flags (40 questions).';
    }

    final c = await _pump(t, _lobby(), 0, addPack: add);
    await _openGame(t, c, _lobby(), GameKind.quiz, addPack: add);
    await t.tap(find.byKey(const ValueKey('open-packs')));
    await t.pumpAndSettle();
    await t.tap(find.text(Strings.addPack));
    await t.pump();
    await t.pump();
    expect(token, 'test'); // FakeConnection's token
    expect(find.text('Added World Flags (40 questions).'), findsOneWidget);
  });

  testWidgets(
    'an error from the TV is shown as is; a cancelled pick shows nothing',
    (t) async {
      var reply = "The pack isn't valid JSON.";
      String? next() => reply.isEmpty ? null : reply;
      Future<String?> add(String _) async => next();
      final c = await _pump(t, _lobby(), 0, addPack: add);
      await _openGame(t, c, _lobby(), GameKind.quiz, addPack: add);
      await t.tap(find.byKey(const ValueKey('open-packs')));
      await t.pumpAndSettle();
      await t.tap(find.text(Strings.addPack));
      await t.pump();
      await t.pump();
      expect(find.text("The pack isn't valid JSON."), findsOneWidget);
      reply = '';
      await t.tap(find.text(Strings.addPack));
      await t.pump();
      await t.pump();
      expect(
        find.text("The pack isn't valid JSON."),
        findsNothing,
      ); // old message cleared
    },
  );

  testWidgets('a score pop plays after a reveal', (t) async {
    final c = FakeConnection();
    await t.pumpWidget(App(c));
    await _send(t, c, const Welcome(0, 0, 'tok'));
    await _send(t, c, _lobby());
    await _send(t, c, const QuizQuestion(1, 10, ['a', 'b', 'c', 'd'], 20));
    await _send(t, c, const QuizReveal(1, 750, 750));
    await _send(t, c, const Effect('scorePop'));
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'the death pulse uses the color from Welcome, even with no lobby yet',
    (t) async {
      final key = GlobalKey();
      final c = FakeConnection();
      await t.pumpWidget(RepaintBoundary(key: key, child: App(c)));
      await _send(
        t,
        c,
        const Welcome(0, 3, 'tok'),
      ); // color 3 is blue; no LobbyState follows
      await _send(t, c, const Effect('colorPulse'));
      await t.pump(const Duration(milliseconds: 300)); // the pulse at its peak
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final (r, b) = (await t.runAsync(() async {
        final img = await boundary.toImage();
        final d = (await img.toByteData())!;
        return (d.getUint8(0), d.getUint8(2)); // top-left pixel: red, blue
      }))!;
      expect(
        b,
        greaterThan(r),
        reason: 'blue-ish, not the red fallback (r=$r b=$b)',
      );
      await t.pump(const Duration(seconds: 3));
    },
  );
}

LobbyState _withSettings(GameSettings s, {int host = 0}) => LobbyState(
  hostId: host,
  packs: const [],
  settings: s,
  players: const [
    PlayerInfo(0, 'P0', 0, true, 0),
    PlayerInfo(1, 'P1', 1, true, 0),
  ],
);

void settingsTests() {
  group('game settings in the details', () {
    final quizLabels = [
      Strings.quizSeconds,
      Strings.quizQuestions,
      Strings.revealSeconds,
    ];
    Future<FakeConnection> open(
      WidgetTester t,
      GameSettings s,
      GameKind k,
    ) async {
      // Tall enough that nothing is scrolled off; the 360 px test overrides this.
      if (t.view.physicalSize.width > 400)
        t.view.physicalSize = const Size(390, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final l = _withSettings(s);
      final c = await _pump(t, l, 0);
      await _openGame(t, c, l, k);
      return c;
    }

    Future<void> tapTip(WidgetTester t, String tip) async {
      final b = find.byTooltip(tip);
      await t.ensureVisible(b);
      await t.tap(b, warnIfMissed: false);
    }

    testWidgets('each game shows only its own settings', (t) async {
      await open(t, const GameSettings(), GameKind.curve);
      expect(
        find.byTooltip(Strings.moreOf(Strings.curveCountdown)),
        findsOneWidget,
      );
      expect(find.byTooltip(Strings.moreOf(Strings.quizSeconds)), findsNothing);
      await t.pumpWidget(const SizedBox());
      await open(t, const GameSettings(), GameKind.quiz);
      expect(
        find.byTooltip(Strings.moreOf(Strings.quizSeconds)),
        findsOneWidget,
      );
      expect(find.text(Strings.curveCountdown), findsNothing);
    });

    testWidgets('a quiz tap sends the whole settings with one field changed', (
      t,
    ) async {
      const s = GameSettings(
        quizSeconds: 30,
        quizQuestions: 15,
        revealSeconds: 6,
        curveCountdown: 3,
      );
      final c = await open(t, s, GameKind.quiz);
      final taps = {
        Strings.moreOf(Strings.quizSeconds): 35,
        Strings.lessOf(Strings.quizQuestions): 10,
        Strings.moreOf(Strings.revealSeconds): 7,
      };
      final want = [
        const GameSettings(
          quizSeconds: 35,
          quizQuestions: 15,
          revealSeconds: 6,
          curveCountdown: 3,
        ),
        const GameSettings(
          quizSeconds: 30,
          quizQuestions: 10,
          revealSeconds: 6,
          curveCountdown: 3,
        ),
        const GameSettings(
          quizSeconds: 30,
          quizQuestions: 15,
          revealSeconds: 7,
          curveCountdown: 3,
        ),
      ];
      var i = 0;
      for (final tip in taps.keys) {
        await tapTip(t, tip);
        expect(
          (c.sent.last as SetSettings).settings.toJson(),
          want[i++].toJson(),
          reason: tip,
        );
      }
    });

    testWidgets('a stepper keeps the chosen quiz pack', (t) async {
      final c = await open(
        t,
        const GameSettings(quizOffPacks: {'b'}),
        GameKind.quiz,
      );
      await tapTip(t, Strings.moreOf(Strings.quizSeconds));
      expect((c.sent.last as SetSettings).settings.quizOffPacks, {'b'});
    });

    testWidgets('the Curve pause sends; a mode pick sends the rest along', (
      t,
    ) async {
      final c = await open(
        t,
        const GameSettings(quizSeconds: 30, curveMode: CurveMode.peaceful),
        GameKind.curve,
      );
      await tapTip(t, Strings.moreOf(Strings.curveCountdown));
      var sent = (c.sent.last as SetSettings).settings;
      expect(sent.curveCountdown, 3);
      expect(sent.curveMode, CurveMode.peaceful);
      for (final m in CurveMode.values) {
        final b = find.text(Strings.curveMode(m));
        await t.ensureVisible(b);
        await t.tap(b);
        sent = (c.sent.last as SetSettings).settings;
        expect(sent.curveMode, m);
        expect(sent.quizSeconds, 30);
      }
    });

    testWidgets('the shown values come from LobbyState, not a local copy', (
      t,
    ) async {
      final c = await open(t, const GameSettings(), GameKind.quiz);
      await tapTip(t, Strings.moreOf(Strings.quizSeconds));
      expect(
        find.text(Strings.seconds(20)),
        findsOneWidget,
      ); // unchanged until the TV answers
      await t.pumpWidget(
        MaterialApp(
          home: LobbyScreen(
            c,
            _sel(
              _withSettings(const GameSettings(quizSeconds: 25)),
              GameKind.quiz,
            ),
            0,
          ),
        ),
      );
      expect(find.text(Strings.seconds(25)), findsOneWidget);
    });

    testWidgets('steppers stop at min and max', (t) async {
      final lo = await open(
        t,
        const GameSettings(quizSeconds: 10, quizQuestions: 5, revealSeconds: 2),
        GameKind.quiz,
      );
      for (final l in quizLabels) {
        await tapTip(t, Strings.lessOf(l));
      }
      expect(lo.sent.whereType<SetSettings>(), isEmpty);
      await t.pumpWidget(const SizedBox());
      final hi = await open(
        t,
        const GameSettings(
          quizSeconds: 60,
          quizQuestions: 30,
          revealSeconds: 15,
        ),
        GameKind.quiz,
      );
      for (final l in quizLabels) {
        await tapTip(t, Strings.moreOf(l));
      }
      expect(hi.sent.whereType<SetSettings>(), isEmpty);
      await t.pumpWidget(const SizedBox());
      final cl = await open(
        t,
        const GameSettings(curveCountdown: 1),
        GameKind.curve,
      );
      await tapTip(t, Strings.lessOf(Strings.curveCountdown));
      expect(cl.sent.whereType<SetSettings>(), isEmpty);
      await t.pumpWidget(const SizedBox());
      final ch = await open(
        t,
        const GameSettings(curveCountdown: 10),
        GameKind.curve,
      );
      await tapTip(t, Strings.moreOf(Strings.curveCountdown));
      expect(ch.sent.whereType<SetSettings>(), isEmpty);
    });

    testWidgets('steppers and mode rows are 56 px and fit at 360 px', (
      t,
    ) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await open(t, const GameSettings(), GameKind.quiz);
      for (final l in quizLabels) {
        await t.ensureVisible(find.byTooltip(Strings.moreOf(l)));
        expect(
          t.getSize(find.byTooltip(Strings.moreOf(l))),
          const Size(56, 56),
        );
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await open(t, const GameSettings(), GameKind.curve);
      for (final m in CurveMode.values) {
        await t.ensureVisible(find.byKey(ValueKey('mode-${m.name}')));
        expect(
          t.getSize(find.byKey(ValueKey('mode-${m.name}'))).height,
          greaterThanOrEqualTo(56),
        );
      }
      expect(t.takeException(), isNull);
    });
  });
}

LobbyState _chars() => LobbyState(
  hostId: 0,
  packs: const [],
  players: const [
    PlayerInfo(0, 'P0', 0, true, 0, character: 'fox'),
    PlayerInfo(1, 'P1', 1, true, 0, character: 'owl'),
  ],
);

void characterTests() {
  group('character', () {
    testWidgets('the header shows my character next to my name', (t) async {
      await _pump(t, _chars(), 0);
      expect(find.byKey(const ValueKey('my-character-fox')), findsOneWidget);
      expect(find.byKey(const ValueKey('my-character-owl')), findsNothing);
    });

    testWidgets(
      'the face reads on all 8 player colors: ink disc, contrast >= 3',
      (t) async {
        double lum(Color c) => c.computeLuminance();
        double contrast(Color a, Color b) {
          final hi = lum(a) > lum(b) ? lum(a) : lum(b);
          final lo = lum(a) > lum(b) ? lum(b) : lum(a);
          return (hi + 0.05) / (lo + 0.05);
        }

        for (var i = 0; i < playerColors.length; i++) {
          final l = LobbyState(
            hostId: 0,
            packs: const [],
            players: [PlayerInfo(0, 'P0', i, true, 0, character: 'lion')],
          );
          await _pump(t, l, 0);
          final face = t.widget<CharacterFace>(find.byType(CharacterFace));
          final disc = t.widget<Container>(
            find
                .ancestor(
                  of: find.byType(CharacterFace),
                  matching: find.byType(Container),
                )
                .first,
          );
          final discColor = (disc.decoration as BoxDecoration).color!;
          final chip = playerColors[i];
          expect(face.color, chip, reason: 'drawn in the player color #$i');
          expect(
            contrast(face.color, discColor),
            greaterThanOrEqualTo(3),
            reason: 'face on disc #$i',
          );
          expect(
            contrast(discColor, chip),
            greaterThanOrEqualTo(3),
            reason: 'disc on chip #$i',
          );
          await t.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets(
      'Promijeni lik: a free one sends SetCharacter, taken and own send nothing',
      (t) async {
        final c = await _pump(t, _chars(), 0);
        await t.tap(find.text(Strings.changeCharacter));
        await t.pumpAndSettle();
        await t.tap(
          find.byKey(const ValueKey('char-owl')),
          warnIfMissed: false,
        ); // taken by P1
        await t.pumpAndSettle();
        expect(c.sent.whereType<SetCharacter>(), isEmpty);
        expect(
          find.text(Strings.pickCharacter),
          findsOneWidget,
        ); // sheet still open
        await t.tap(find.byKey(const ValueKey('char-fox'))); // my own
        await t.pumpAndSettle();
        expect(c.sent.whereType<SetCharacter>(), isEmpty);
        await t.tap(find.text(Strings.changeCharacter));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('char-bear')));
        await t.pumpAndSettle();
        expect(c.sent.last, const SetCharacter('bear'));
      },
    );

    testWidgets(
      'a refused pick shows the TV reason and keeps the old character',
      (t) async {
        final c = FakeConnection();
        await t.pumpWidget(App(c));
        await _send(t, c, const Welcome(0, 0, 'tok', character: 'fox'));
        await _send(t, c, _chars());
        await t.tap(find.text(Strings.changeCharacter));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('char-bear')));
        await t.pumpAndSettle();
        expect(c.sent.last, const SetCharacter('bear'));
        await _send(t, c, const ErrorMsg('Taj lik je zauzet.'));
        expect(find.text('Taj lik je zauzet.'), findsOneWidget);
        expect(find.byKey(const ValueKey('my-character-fox')), findsOneWidget);
      },
    );
  });
}
