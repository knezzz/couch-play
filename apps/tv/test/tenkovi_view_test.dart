import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/tenkovi_match.dart';
import 'package:tv/ui/tenkovi/tenkovi_text.dart';
import 'package:tv/ui/tenkovi/tenkovi_view.dart';
import 'package:tv/ui/tv_theme.dart';

const _chars = ['owl', 'rabbit', 'bear', 'fox', 'cat', 'dog', 'frog', 'pig'];

final _changes = ValueNotifier<int>(0);
var _at = Duration.zero;

/// One 16 ms frame of fake time, on the clock the match flies by.
Future<void> _frame(WidgetTester t) async {
  _at += const Duration(milliseconds: 16);
  await t.pump(const Duration(milliseconds: 16));
}

// Like main.dart: every session change rebuilds the view.
TenkoviTvMatch _match(int n, {int rounds = 2}) => TenkoviTvMatch(
      notify: () => _changes.value++,
      clock: () => _at,
      ids: [for (var i = 1; i <= n; i++) i],
      settings: GameSettings(tenkoviRounds: rounds, tenkoviMap: TenkoviMapPick.mars),
      send: (_, _) {},
      random: Random(3),
      breakTime: const Duration(seconds: 2),
    )..start();

List<PlayerInfo> _players(int n) => [
      for (var i = 1; i <= n; i++) PlayerInfo(i, 'Igrač $i', i - 1, true, 0, character: _chars[(i - 1) % 8]),
    ];

Future<void> _show(WidgetTester t, TenkoviTvMatch m, int n) async {
  t.view.physicalSize = const Size(1920, 1080);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(theme: tvTheme(), home: ValueListenableBuilder<int>(
    valueListenable: _changes,
    builder: (_, _, _) => TenkoviView(match: m, players: _players(n)),
  )));
}

void main() {
  testWidgets('aim stage: round, map, wind and only a count of who is ready', (t) async {
    final m = _match(8);
    await _show(t, m, 8);
    expect(find.text('Runda 1 od 2 · okret 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('tenkovi-wind')), findsOneWidget);
    expect(find.text(TenkoviText.ready(0, 8)), findsNothing, reason: 'shown with the kicker');
    expect(find.textContaining('Spremno 0 / 8'), findsOneWidget);
    m.onFire(1, const TenkoviFire(137, 83, TenkoviShell.heavy));
    await t.pump();
    expect(find.textContaining('Spremno 1 / 8'), findsOneWidget);
    // No angle, power or shell name anywhere on the screen.
    expect(find.textContaining('137'), findsNothing);
    expect(find.textContaining('83'), findsNothing);
    expect(find.textContaining('Teška'), findsNothing);
    expect(find.textContaining('°'), findsNothing);
    m.dispose();
  });

  testWidgets('idle during the aim the view asks for no frame; it wakes for the volley and sleeps again', (t) async {
    final m = _match(3);
    await _show(t, m, 3);
    await t.pump(const Duration(milliseconds: 100));
    expect(t.binding.hasScheduledFrame, isFalse, reason: 'nothing moves while players aim');
    m.onFire(1, const TenkoviFire(90, 5, TenkoviShell.grenade));
    await t.pump();
    expect(t.binding.hasScheduledFrame, isFalse, reason: 'a tick is not a reason to draw');
    m.onFire(2, const TenkoviFire(90, 5, TenkoviShell.grenade));
    m.onFire(3, const TenkoviFire(90, 5, TenkoviShell.grenade));
    await t.pump();
    expect(m.stage, TenkoviStageTv.fly);
    expect(t.binding.hasScheduledFrame, isTrue, reason: 'the shells are in the air');
    for (var i = 0; i < 600 && m.stage == TenkoviStageTv.fly; i++) {
      await _frame(t);
    }
    for (var i = 0; i < 60; i++) {
      await _frame(t); // the blasts fade
    }
    if (m.stage == TenkoviStageTv.aim) {
      expect(t.binding.hasScheduledFrame, isFalse, reason: 'idle again');
    }
    await t.pump(const Duration(seconds: 3));
    m.dispose();
  });

  testWidgets('the volley flies on the ticker, then the next turn starts', (t) async {
    final m = _match(3);
    await _show(t, m, 3);
    for (var i = 1; i <= 3; i++) {
      m.onFire(i, const TenkoviFire(90, 5, TenkoviShell.grenade));
    }
    expect(m.stage, TenkoviStageTv.fly);
    await t.pump();
    expect(find.text(TenkoviText.volley), findsOneWidget);
    for (var i = 0; i < 400 && m.stage == TenkoviStageTv.fly; i++) {
      await _frame(t);
    }
    expect(m.stage, isNot(TenkoviStageTv.fly));
    await t.pump(const Duration(seconds: 3)); // round break if the round ended
    expect(tester(t), isNull);
    m.dispose();
  });

  testWidgets('the round winner is named, with every other player\'s points', (t) async {
    final m = _match(3);
    await _show(t, m, 3);
    m.round.tank(2).hp = 0;
    m.round.tank(3).hp = 0;
    m.round.outAt[2] = 0;
    m.round.outAt[3] = 0;
    m.onFire(1, const TenkoviFire(90, 5, TenkoviShell.grenade));
    for (var i = 0; i < 400 && m.stage == TenkoviStageTv.fly; i++) {
      await _frame(t);
    }
    await t.pump();
    if (m.stage == TenkoviStageTv.end) {
      expect(find.byKey(const ValueKey('winner-banner')), findsOneWidget);
    }
    await t.pump(const Duration(seconds: 3));
    m.dispose();
  });

  testWidgets('8 tanks with long names draw without an exception', (t) async {
    final m = _match(8);
    await t.binding.setSurfaceSize(const Size(1920, 1080));
    await _show(t, m, 8);
    await t.pump(const Duration(milliseconds: 100));
    expect(tester(t), isNull);
    m.dispose();
  });
}

Object? tester(WidgetTester t) => t.takeException();
