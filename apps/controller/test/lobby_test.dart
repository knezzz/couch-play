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
  await t.pumpWidget(
    MaterialApp(home: LobbyScreen(c, l, me, addPack: addPack)),
  );
  return c;
}

void main() {
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
    expect(find.text(Strings.hostBadge), findsOneWidget);

    await _pump(t, _lobby(), 1);
    expect(find.text(Strings.curve), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.widgetWithText(TextButton, Strings.remove), findsNothing);
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

  testWidgets('Curve button sends StartGame(curve)', (t) async {
    final c = await _pump(t, _lobby(), 0);
    await t.tap(find.text(Strings.curve));
    expect(c.sent.last, const StartGame(GameKind.curve, null));
  });

  testWidgets(
    'Remove and BOT are 18 px and a row fits at 360 px with a 16-letter name',
    (t) async {
      t.view.physicalSize = const Size(360, 640);
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
    expect(find.text('◀'), findsOneWidget);
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
      expect(find.text('◀'), findsOneWidget);
      await _send(
        t,
        c,
        const Results([Placement(0, 1, 20, 3), Placement(1, 2, 14, 2)]),
      );
      expect(find.text('◀'), findsNothing);
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
    await _pump(t, _lobby(), 0, addPack: pick);
    expect(find.text(Strings.addPack), findsOneWidget);
    await _pump(t, _lobby(), 1, addPack: pick);
    expect(find.text(Strings.addPack), findsNothing);
  });

  testWidgets('Add quiz pack passes the token and shows the TV message', (
    t,
  ) async {
    String? token;
    await _pump(
      t,
      _lobby(),
      0,
      addPack: (tok) async {
        token = tok;
        return 'Added World Flags (40 questions).';
      },
    );
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
      await _pump(t, _lobby(), 0, addPack: (_) async => next());
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
