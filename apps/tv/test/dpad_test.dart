import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/ui/back_guard.dart';
import 'package:tv/ui/lobby_screen.dart';
import 'package:tv/ui/tv_theme.dart';

import 'session_test.dart' show join;

const _prompt = 'End this game and return to the lobby?';

/// The real wiring from main.dart, around a screen that reads the session.
Widget _app(Session s) {
  final nav = GlobalKey<NavigatorState>();
  return MaterialApp(
    theme: tvTheme(),
    navigatorKey: nav,
    builder: (_, child) => BackGuard(
      navigatorKey: nav,
      active: () => s.phase == Phase.quiz || s.phase == Phase.curve,
      onEnd: s.endGame,
      child: child!,
    ),
    home: ListenableBuilder(
      listenable: s.changes,
      builder: (_, _) => Scaffold(body: Center(child: Text('phase ${s.phase.name}'))),
    ),
  );
}

/// flutter_test has no physical key for the remote's Back, so give it one.
Future<void> _press(WidgetTester t, LogicalKeyboardKey key) async {
  if (key != LogicalKeyboardKey.goBack) {
    await t.sendKeyEvent(key);
    return;
  }
  await simulateKeyDownEvent(key, physicalKey: PhysicalKeyboardKey.f24);
  await simulateKeyUpEvent(key, physicalKey: PhysicalKeyboardKey.f24);
}

bool _focused(WidgetTester t, String label) =>
    Focus.of(t.element(find.text(label))).hasPrimaryFocus;

void main() {
  for (final key in [LogicalKeyboardKey.goBack, LogicalKeyboardKey.escape]) {
    testWidgets('back_during_game_confirms_then_returns_to_lobby (${key.keyLabel})', (t) async {
      final s = Session(random: Random(1))..quizAvailable = true;
      final a = join(s, 'Ana');
      a.say(const StartGame(GameKind.quiz, null));
      await t.pumpWidget(_app(s));
      expect(s.phase, Phase.quiz);
      expect(find.text(_prompt), findsNothing);

      await _press(t, key);
      await t.pump();
      expect(find.text(_prompt), findsOneWidget);
      expect(_focused(t, 'No'), isTrue, reason: 'focus starts on No');

      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(_focused(t, 'Yes'), isTrue);

      await t.sendKeyEvent(LogicalKeyboardKey.select);
      await t.pumpAndSettle();
      expect(find.text(_prompt), findsNothing);
      expect(s.phase, Phase.lobby);
      expect(s.sessionScores.values.every((v) => v == 0), isTrue);
      s.dispose();
    });
  }

  testWidgets('choosing No keeps the game going', (t) async {
    final s = Session(random: Random(1))..quizAvailable = true;
    join(s, 'Ana').say(const StartGame(GameKind.quiz, null));
    await t.pumpWidget(_app(s));
    await _press(t, LogicalKeyboardKey.goBack);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.select); // focus is on No
    await t.pumpAndSettle();
    expect(find.text(_prompt), findsNothing);
    expect(s.phase, Phase.quiz);
    s.dispose();
  });

  testWidgets('back in the lobby asks nothing', (t) async {
    final s = Session(random: Random(1));
    await t.pumpWidget(_app(s));
    await _press(t, LogicalKeyboardKey.goBack);
    await t.pump();
    expect(find.text(_prompt), findsNothing);
    expect(s.phase, Phase.lobby);
    s.dispose();
  });

  // --- the lobby's own focusable items ---

  Widget lobby({VoidCallback? onQuit}) => MaterialApp(
        theme: tvTheme(),
        home: LobbyScreen(
          joinUrl: 'http://192.168.1.5:8080/',
          players: const [],
          hostId: null,
          onQuit: onQuit ?? () {},
        ),
      );

  testWidgets('d-pad reaches How to join and Quit; focus is a 3 px accent outline', (t) async {
    await t.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(lobby());

    BorderSide side(String label) {
      final m = t.widget<Material>(find
          .descendant(of: find.widgetWithText(FilledButton, label), matching: find.byType(Material))
          .first);
      return (m.shape! as OutlinedBorder).side;
    }

    expect(side('Quit').width, isNot(3), reason: 'no ring until focused');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    final first = _focused(t, 'How to join') ? 'How to join' : 'Quit';
    for (final label in ['How to join', 'Quit']) {
      final ring = side(label);
      if (label == first) {
        expect(ring.color, tvAccent);
        expect(ring.width, 3);
      } else {
        expect(ring.width, isNot(3));
      }
    }
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(_focused(t, 'Quit') || _focused(t, 'How to join'), isTrue);
    expect(side(_focused(t, 'Quit') ? 'Quit' : 'How to join').width, 3);
  });

  testWidgets('How to join shows the steps; Quit calls onQuit', (t) async {
    await t.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => t.binding.setSurfaceSize(null));
    var quit = 0;
    await t.pumpWidget(lobby(onQuit: () => quit++));
    await t.tap(find.text('How to join'));
    await t.pumpAndSettle();
    expect(find.textContaining('same Wi-Fi'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.select); // the dialog's button has focus
    await t.pumpAndSettle();
    expect(find.textContaining('same Wi-Fi'), findsNothing);
    await t.tap(find.text('Quit'));
    expect(quit, 1);
  });
}
