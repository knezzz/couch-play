import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/main.dart';
import 'package:tv/session/session.dart';

import 'home_frames_test.dart' show framesAsked;
import 'session_test.dart' show join;

/// Task 48 on the real TvApp: a host's phone drives the TV home through the session.
void main() {
  testWidgets('the host changes a setting: the panel opens by itself, the row is outlined, and the TV is still idle', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = Session(random: Random(1));
    await t.pumpWidget(TvApp(session: s, serve: false));
    final host = join(s, 'Ana', token: 't0');
    await t.pump();
    expect(find.byKey(const ValueKey('game-card')), findsNothing);
    host.say(const SelectGame(GameKind.quiz));
    await t.pump();
    host.say(SetSettings(GameSettings(quizQuestions: 15)));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(s.hostView, HostView.settings);
    expect(find.byKey(const ValueKey('game-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('row-changed')), findsOneWidget);
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(await framesAsked(t), lessThanOrEqualTo(2));
    // Natrag closes it.
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(s.hostView, HostView.home);
    expect(find.byKey(const ValueKey('game-card')), findsNothing);
    // A game change closes it too, and ▼ opens it again.
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(s.hostView, HostView.settings);
    expect(find.byKey(const ValueKey('game-card')), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(find.byKey(const ValueKey('game-card')), findsNothing, reason: 'a game change closes the panel');
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('the host opens the pack screen: the TV shows the pack grid; closing it brings the home back', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = Session(random: Random(1));
    await t.pumpWidget(TvApp(session: s, serve: false));
    final host = join(s, 'Ana', token: 't0');
    await t.pump();
    host.say(const SelectGame(GameKind.quiz));
    host.say(const PackScreen(true));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(s.hostView, HostView.packs);
    expect(find.byKey(const ValueKey('pack-grid')), findsOneWidget);
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    expect(await framesAsked(t), lessThanOrEqualTo(2));
    host.say(const PackScreen(false));
    await t.pump();
    expect(find.byKey(const ValueKey('pack-grid')), findsNothing);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
