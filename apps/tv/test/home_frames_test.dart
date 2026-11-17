import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/main.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show join;

/// The BRAVIA logged 60 frames a second on the home (3624-3639 a minute). An idle home
/// must ask for no frames at all while nothing changes, not one per vsync.
///
/// Counts how many 16 ms steps of an otherwise idle 5 s the engine would have had a
/// frame scheduled for. A running ticker/animation asks for every step (about 300); the
/// old timer-stepped drift asked for 8 a second (40).
Future<int> framesAsked(WidgetTester t, {Duration span = const Duration(seconds: 5)}) async {
  var asked = 0;
  for (var left = span; left > Duration.zero; left -= const Duration(milliseconds: 16)) {
    // Let 16 ms pass (timers fire, tickers are due) WITHOUT drawing a frame, then see
    // whether anything asked for one; draw it, as the engine would, to clear the request.
    await t.binding.delayed(const Duration(milliseconds: 16));
    if (t.binding.hasScheduledFrame) {
      asked++;
      await t.pump();
    }
  }
  return asked;
}

Future<Session> _homeWith8(WidgetTester t) async {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final s = Session(random: Random(1));
  await t.pumpWidget(TvApp(session: s, serve: false));
  for (var i = 0; i < 8; i++) {
    join(s, 'Igrac${i + 1}', token: 't$i');
  }
  await t.pump();
  await t.pump(const Duration(seconds: 1)); // the card fade-in and the first frames settle
  return s;
}

void main() {
  // The BRAVIA's PERF lines were from an EMPTY home ('Čekamo igrače', nobody joined): 61 frames a second
  // and ~10 tickers. Not reproduced here, so these pin that the empty and one-player homes are idle too.
  for (final n in [0, 1]) {
    testWidgets('an idle home with $n player(s), a join URL shown, asks for no frames', (t) async {
      t.view
        ..physicalSize = const Size(1920, 1080)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = Session(random: Random(1))..joinUrl = 'http://192.168.1.5:8080/';
      await t.pumpWidget(TvApp(session: s, serve: false));
      for (var i = 0; i < n; i++) {
        join(s, 'Igrac${i + 1}', token: 't$i');
      }
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'a ticker is running on the home');
      expect(await framesAsked(t), lessThanOrEqualTo(2));
      await t.pumpWidget(const SizedBox());
      s.dispose();
    });
  }

  testWidgets('an idle home with 8 players asks for about 8 frames a second, not 60', (t) async {
    final s = await _homeWith8(t);
    final asked = await framesAsked(t);
    // ignore: avoid_print
    print('idle home, 5 s: frames asked = $asked (a 60 fps ticker would be ~312, the old 8 fps drift 40)');
    expect(asked, lessThanOrEqualTo(2), reason: 'something on the home keeps asking for frames');
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });

  // The BRAVIA logged 60 frames a second (12-24 tickers) on the home AFTER phones joined and a game was
  // played. This walks that real path: join four phones, play a whole quiz, results, back to the home.
  testWidgets('the home after joined phones and a whole quiz game asks for no frames', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var now = Duration.zero;
    final s = Session(random: Random(1), clock: () => now)..joinUrl = 'http://192.168.1.5:8080/';
    await t.pumpWidget(TvApp(session: s, serve: false));
    final ps = [for (var i = 0; i < 4; i++) join(s, 'P$i', token: 't$i')];
    await t.pump();
    ps[0].say(const StartGame(GameKind.quiz, null));
    for (var i = 0; i < 4000 && s.phase != Phase.results; i++) {
      if (s.quiz != null && s.quiz!.step == QuizStep.asking) {
        for (final p in ps) {
          p.say(Answer(s.quiz!.current.correctIndex));
        }
      }
      now += const Duration(milliseconds: 100);
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(s.phase, Phase.results);
    for (var i = 0; i < 200 && s.phase != Phase.lobby; i++) {
      now += const Duration(milliseconds: 100);
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(s.phase, Phase.lobby, reason: 'back on the home');
    await t.pump(const Duration(seconds: 7)); // the confetti and the Večeras strip settle
    expect(find.byKey(const ValueKey('tonight')), findsOneWidget, reason: 'the strip with tonight\'s totals is up');
    expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'a ticker is still running on the home');
    expect(await framesAsked(t), lessThanOrEqualTo(2));
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('the home after a Curve game that was left (Flame loop removed) asks for no frames', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = Session(random: Random(1))..joinUrl = 'http://192.168.1.5:8080/';
    await t.pumpWidget(TvApp(session: s, serve: false));
    final ps = [for (var i = 0; i < 3; i++) join(s, 'P$i', token: 't$i')];
    await t.pump();
    ps[0].say(const StartGame(GameKind.curve, null));
    expect(s.phase, Phase.curve);
    await t.pump(const Duration(seconds: 1));
    for (var i = 0; i < 100; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0), reason: 'the game runs a loop');
    s.endGame();
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    expect(s.phase, Phase.lobby);
    expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'the Flame loop is gone');
    expect(await framesAsked(t), lessThanOrEqualTo(2));
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('with remote key presses it settles back to the idle rate after each press', (t) async {
    final s = await _homeWith8(t);
    for (final key in [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
    ]) {
      await t.sendKeyEvent(key);
      await t.pump(const Duration(seconds: 1)); // the selection change finishes
    }
    final asked = await framesAsked(t);
    // ignore: avoid_print
    print('home after key presses, 5 s: frames asked = $asked');
    expect(asked, lessThanOrEqualTo(2));
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('with the settings panel open it is still the idle rate', (t) async {
    final s = await _homeWith8(t);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump(const Duration(seconds: 1));
    final asked = await framesAsked(t);
    // ignore: avoid_print
    print('home with the panel open, 5 s: frames asked = $asked');
    expect(asked, lessThanOrEqualTo(2));
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('8 phones pinging every second (the controller measures its round trip) add no frames to the idle home', (t) async {
    final s = Session(random: Random(1));
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(TvApp(session: s, serve: false));
    final phones = [for (var i = 0; i < 8; i++) join(s, 'Igrac${i + 1}', token: 't$i')];
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    var asked = 0;
    for (var ms = 0; ms < 5000; ms += 16) {
      if (ms % 1000 == 0 && ms > 0) {
        for (final p in phones) {
          p.say(Ping(ms));
        }
      }
      await t.binding.delayed(const Duration(milliseconds: 16));
      if (t.binding.hasScheduledFrame) {
        asked++;
        await t.pump();
      }
    }
    // ignore: avoid_print
    print('home with 8 phones pinging, 5 s: frames asked = $asked');
    expect(asked, lessThanOrEqualTo(2));
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
