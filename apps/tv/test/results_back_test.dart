import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/main.dart';
import 'package:tv/session/session.dart';
import 'package:tv/ui/home_screen.dart';
import 'package:tv/ui/results_screen.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 38: Back on the results screen closes it and moves on at once (to the
/// home screen), instead of waiting out the 8 s timer or exiting the app.
void main() {
  late Session s;
  late FakePeer a;
  var exits = 0;

  Future<void> resultsUp(WidgetTester t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    exits = 0;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'SystemNavigator.pop') exits++;
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    s = Session(random: Random(1));
    await t.pumpWidget(TvApp(session: s, serve: false));
    a = join(s, 'Ana', token: 'ta');
    final b = join(s, 'Ben', token: 'tb');
    s.finishGame({a.sent.whereType<Welcome>().first.playerId: 5, b.sent.whereType<Welcome>().first.playerId: 3});
    await t.pump();
  }

  testWidgets('Back on the results moves on to the home at once, and the app does not exit', (t) async {
    await resultsUp(t);
    expect(find.byType(ResultsScreen), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.byType(ResultsScreen), findsOneWidget, reason: 'still within the 8 s hold');
    await t.binding.handlePopRoute();
    await t.pump();
    expect(s.phase, Phase.lobby);
    expect(find.byType(ResultsScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(exits, 0, reason: 'Back was handled, the app did not exit');
    // the old 8 s timer must not fire into the next thing
    await t.pump(const Duration(seconds: 10));
    expect(s.phase, Phase.lobby);
    s.dispose();
  });

  testWidgets('Escape does the same (macOS)', (t) async {
    await resultsUp(t);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(s.phase, Phase.lobby);
    expect(find.byType(HomeScreen), findsOneWidget);
    s.dispose();
  });

  testWidgets('a second Back on the home is left to the system (exits)', (t) async {
    await resultsUp(t);
    await t.binding.handlePopRoute();
    await t.pump();
    await t.binding.handlePopRoute();
    await t.pump();
    expect(exits, 1);
    s.dispose();
  });

  testWidgets('without Back the results still go home by themselves after the hold', (t) async {
    await resultsUp(t);
    await t.pump(const Duration(seconds: 9));
    expect(s.phase, Phase.lobby);
    s.dispose();
  });
}
