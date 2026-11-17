import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
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
  testWidgets('an idle home with 8 players asks for about 8 frames a second, not 60', (t) async {
    final s = await _homeWith8(t);
    final asked = await framesAsked(t);
    // ignore: avoid_print
    print('idle home, 5 s: frames asked = $asked (a 60 fps ticker would be ~312, the old 8 fps drift 40)');
    expect(asked, lessThanOrEqualTo(2), reason: 'something on the home keeps asking for frames');
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
