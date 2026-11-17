import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/ui/tkobi/tkobi_screen.dart';
import 'package:tv/ui/tkobi/tkobi_view.dart';

import 'session_test.dart' show join;

PlayerInfo _p(int i) => PlayerInfo(i, ['Ana', 'Marko', 'Iva', 'Luka', 'Petra', 'Josip', 'Mia', 'Ivo'][i], i, true, 0, character: characterIds[i]);

TkobiBoard _ask({int voted = 2, int left = 10, int n = 4}) =>
    TkobiBoard(number: 3, total: 10, prompt: 'Tko će se najvjerojatnije prvi naspavati?', players: [for (var i = 0; i < n; i++) _p(i)], votedCount: voted, secondsLeft: left, seconds: 15);

Future<void> _show(WidgetTester t, TkobiBoard b) async {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: TkobiScreen(b)));
}

void main() {
  testWidgets('asking: the prompt, how many have voted (a count, not who), the clock', (t) async {
    await _show(t, _ask());
    expect(find.text('Tko će se najvjerojatnije prvi naspavati?'), findsOneWidget);
    expect(find.text('Glasalo: 2 od 4'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('seconds'))).data, '10');
    var lit = 0;
    for (var i = 0; i < 20; i++) {
      if ((t.widget<Container>(find.byKey(ValueKey('tick-$i'))).decoration as BoxDecoration).color!.a > 0.5) lit++;
    }
    expect(lit, 14, reason: '10 of 15 s is 13.3, a started segment counts: 14 of 20');
    await _show(t, _ask(left: 5));
    expect(t.widget<Text>(find.byKey(const ValueKey('seconds'))).style!.color, const Color(0xFFFF4D6D));
    expect(t.takeException(), isNull);
  });

  testWidgets('reveal: votes per player as bars (longest = most), the crowned in gold, points and totals', (t) async {
    final rows = [
      TkobiRow(_p(1), 3, 1, 5, true),
      TkobiRow(_p(0), 1, 0, 2, false),
      TkobiRow(_p(2), 0, 0, 0, false),
    ];
    await _show(t, TkobiBoard(number: 3, total: 10, prompt: 'p', players: [for (var i = 0; i < 3; i++) _p(i)], votedCount: 3, secondsLeft: 0, seconds: 15, rows: rows));
    expect(find.byKey(const ValueKey('row-1-crowned')), findsOneWidget);
    expect(find.byKey(const ValueKey('row-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('seconds')), findsNothing);
    final w1 = t.getSize(find.byKey(const ValueKey('bar-1'))).width, w0 = t.getSize(find.byKey(const ValueKey('bar-0'))).width, w2 = t.getSize(find.byKey(const ValueKey('bar-2'))).width;
    expect(w1, greaterThan(w0 * 2.5), reason: '3 votes vs 1');
    expect(w2, lessThan(w0 / 4), reason: 'no votes is a sliver');
    expect(find.text('+1'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a tie crowns both; eight rows fit above 1030 px', (t) async {
    final rows = [for (var i = 0; i < 8; i++) TkobiRow(_p(i), i < 2 ? 3 : 0, 0, 10, i < 2)];
    await _show(t, TkobiBoard(number: 1, total: 5, prompt: 'p', players: [for (var i = 0; i < 8; i++) _p(i)], votedCount: 8, secondsLeft: 0, seconds: 15, rows: rows));
    expect(find.byKey(const ValueKey('row-0-crowned')), findsOneWidget);
    expect(find.byKey(const ValueKey('row-1-crowned')), findsOneWidget);
    expect(t.getRect(find.byKey(const ValueKey('row-7'))).bottom, lessThanOrEqualTo(1030));
    expect(t.takeException(), isNull);
  });

  testWidgets('the view reads a live match while asking and shows no votes', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = Session(random: Random(1))
      ..tkobiTvReady = true
      ..tkobiPacks = [TkobiPack('b', 'B', [for (var i = 0; i < 40; i++) 'Tko će se najvjerojatnije ${i}x?'])];
    final ps = [for (var i = 0; i < 3; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.tkobi, null));
    expect(s.phase, Phase.tkobi);
    await t.pumpWidget(MaterialApp(home: TkobiView(match: s.tkobi!, players: s.playerInfos)));
    expect(find.textContaining('Tko će se'), findsWidgets);
    expect(find.text('Glasalo: 0 od 3'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('confetti plays once when someone is crowned at the reveal', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var at = Duration.zero;
    final s = Session(random: Random(1), clock: () => at)
      ..tkobiTvReady = true
      ..tkobiPacks = [TkobiPack('b', 'B', [for (var i = 0; i < 40; i++) 'Tko će se najvjerojatnije ${i}x?'])];
    final ps = [for (var i = 0; i < 3; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.tkobi, null));
    final ids = [for (final p in ps) p.sent.whereType<Welcome>().first.playerId];
    for (final p in ps) {
      p.say(Vote(ids[1]));
    }
    expect(s.tkobi!.reveal, isNotNull, reason: 'everyone voted: the reveal');
    await t.pumpWidget(MaterialApp(home: EffectLayer(child: TkobiView(match: s.tkobi!, players: s.playerInfos))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0), reason: 'the confetti controller is running');
    await t.pump(const Duration(seconds: 6));
    expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'and it ends');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
