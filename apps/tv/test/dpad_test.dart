import 'dart:math';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/strings.dart';
import 'package:tv/session/session.dart';
import 'package:tv/ui/back_guard.dart';
import 'package:tv/ui/tv_theme.dart';

import 'session_test.dart' show join;

const _prompt = Strings.endGameTitle;

/// The wiring from main.dart around [home]. The remote's Back arrives as a
/// pop-route from Android, not as a key.
Widget _app(Session s, {Widget? home}) {
  final nav = GlobalKey<NavigatorState>();
  return MaterialApp(
    theme: tvTheme(),
    navigatorKey: nav,
    builder: (_, child) => BackGuard(
      navigatorKey: nav,
      active: () => s.phase == Phase.quiz || s.phase == Phase.curve,
      changes: s.changes,
      onEnd: s.endGame,
      child: child!,
    ),
    home: home ??
        ListenableBuilder(
          listenable: s.changes,
          builder: (_, _) => Scaffold(body: Center(child: Text('phase ${s.phase.name}'))),
        ),
  );
}

/// Counts the times nothing handled a pop-route (the app would exit).
int _exits = 0;
void _watchExit(WidgetTester t) {
  _exits = 0;
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
    if (c.method == 'SystemNavigator.pop') _exits++;
    return null;
  });
  addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await t.pump();
}

bool _focused(WidgetTester t, String label) =>
    Focus.of(t.element(find.text(label))).hasPrimaryFocus;

Session _quiz() {
  final s = Session(random: Random(1));
  join(s, 'Ana').say(const StartGame(GameKind.quiz, null));
  return s;
}

void main() {
  setUp(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional);
  tearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

  testWidgets('back_during_game_confirms_then_returns_to_lobby', (t) async {
    _watchExit(t);
    final s = _quiz();
    await t.pumpWidget(_app(s));
    expect(s.phase, Phase.quiz);
    expect(find.text(_prompt), findsNothing);

    await _back(t);
    expect(find.text(_prompt), findsOneWidget);
    expect(_exits, 0, reason: 'Back was handled, the app did not exit');
    expect(_focused(t, Strings.no), isTrue, reason: 'focus starts on No');

    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(_focused(t, Strings.yes), isTrue);

    await t.sendKeyEvent(LogicalKeyboardKey.select);
    await t.pumpAndSettle();
    expect(find.text(_prompt), findsNothing);
    expect(s.phase, Phase.lobby);
    expect(s.sessionScores.values.every((v) => v == 0), isTrue);
    s.dispose();
  });

  testWidgets('Escape asks too (macOS)', (t) async {
    final s = _quiz();
    await t.pumpWidget(_app(s));
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.text(_prompt), findsOneWidget);
    s.dispose();
  });

  testWidgets('Back or Escape while the dialog is open counts as No, never a second dialog', (t) async {
    _watchExit(t);
    final s = _quiz();
    await t.pumpWidget(_app(s));
    await _back(t);
    expect(find.text(_prompt), findsOneWidget);
    await _back(t); // again: closes it
    await t.pumpAndSettle();
    expect(find.text(_prompt), findsNothing);
    expect(s.phase, Phase.quiz);
    expect(_exits, 0);

    await _back(t);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.text(_prompt), findsNothing, reason: 'Escape closes it too');
    expect(s.phase, Phase.quiz);
    s.dispose();
  });

  testWidgets('choosing No keeps the game going', (t) async {
    final s = _quiz();
    await t.pumpWidget(_app(s));
    await _back(t);
    await t.sendKeyEvent(LogicalKeyboardKey.select); // focus is on No
    await t.pumpAndSettle();
    expect(find.text(_prompt), findsNothing);
    expect(s.phase, Phase.quiz);
    s.dispose();
  });

  testWidgets('back in the lobby is left to the system (exits the app)', (t) async {
    _watchExit(t);
    final s = Session(random: Random(1));
    await t.pumpWidget(_app(s));
    await _back(t);
    expect(find.text(_prompt), findsNothing);
    expect(_exits, 1);
    s.dispose();
  });

  testWidgets('the dialog closes when the game ends on its own', (t) async {
    final s = _quiz();
    await t.pumpWidget(_app(s));
    await _back(t);
    expect(find.text(_prompt), findsOneWidget);
    s.finishGame({for (final p in s.players) p.id: 5});
    await t.pumpAndSettle();
    expect(find.text(_prompt), findsNothing);
    expect(s.phase, Phase.results);
    s.dispose();
  });

  testWidgets('Back and Escape work with a Flame GameWidget on screen (Curve)', (t) async {
    // Flame takes keyboard focus by default and swallows every key.
    _watchExit(t);
    final s = _quiz();
    await t.pumpWidget(_app(s, home: Scaffold(body: GameWidget(game: FlameGame(), autofocus: false))));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.text(_prompt), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump(const Duration(seconds: 1));
    expect(find.text(_prompt), findsNothing);
    await t.pump(const Duration(seconds: 1)); // the game keeps ticking: no settle
    await _back(t);
    expect(find.text(_prompt), findsOneWidget);
    expect(_exits, 0);
    s.dispose();
  });

  testWidgets('End-game dialog fits with the Croatian question', (t) async {
    final s = _quiz();
    await t.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_app(s));
    await _back(t);
    expect(t.takeException(), isNull);
    expect(find.text(Strings.endGameTitle), findsOneWidget);
    s.dispose();
  });
}
