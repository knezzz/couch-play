import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/main.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/curve/round_break_card.dart';
import 'package:tv/ui/tv_theme.dart';

import 'session_test.dart' show join;

/// Task 37: no bar during play; after each round the scores show for a few seconds
/// (faces, points, how far to the target) before the next countdown.
List<BreakPlayer> _four() => const [
      BreakPlayer(name: 'Ana', colorIndex: 1, character: 'owl', score: 9),
      BreakPlayer(name: 'Luka', colorIndex: 0, character: 'fox', score: 12),
      BreakPlayer(name: 'Marko', colorIndex: 2, character: 'frog', score: 7),
      BreakPlayer(name: 'Robot 1', colorIndex: 4, character: 'panda', score: 4),
    ];

Future<void> _pump(WidgetTester t, Widget w) {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  return t.pumpWidget(MaterialApp(theme: tvTheme(), home: w));
}

Finder _face(String id) => find.byWidgetPredicate((w) => w is CharacterFace && w.id == id);

void main() {
  testWidgets('the card: the round, the target, each player with face, name and points, leader first, and the countdown', (t) async {
    await _pump(t, RoundBreakCard(round: 3, target: 30, players: _four(), remaining: () => const Duration(seconds: 3, milliseconds: 200)));
    expect(find.text(Strings.curveBreakTitle(3)), findsOneWidget);
    expect(find.text(Strings.curveBreakTarget(30)), findsOneWidget);
    expect(find.text(Strings.curveBreakNext(4)), findsOneWidget, reason: '3.2 s left rounds up to 4');
    for (final (name, id, score, ci) in [('Luka', 'fox', '12', 0), ('Ana', 'owl', '9', 1), ('Marko', 'frog', '7', 2), ('Robot 1', 'panda', '4', 4)]) {
      final row = find.byKey(ValueKey('break-$ci'));
      expect(find.descendant(of: row, matching: find.text(name)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text(score)), findsOneWidget);
      expect(find.descendant(of: row, matching: _face(id)), findsOneWidget);
    }
    double y(int ci) => t.getTopLeft(find.byKey(ValueKey('break-$ci'))).dy;
    expect(y(0), lessThan(y(1)));
    expect(y(1), lessThan(y(2)));
    expect(y(2), lessThan(y(4)));
  });

  testWidgets('each row has a bar that fills to score / target', (t) async {
    await _pump(t, RoundBreakCard(round: 1, target: 30, players: _four(), remaining: () => const Duration(seconds: 4)));
    for (final (ci, score) in [(0, 12), (1, 9), (2, 7), (4, 4)]) {
      final track = t.getSize(find.byKey(ValueKey('break-track-$ci'))).width;
      final fill = t.getSize(find.byKey(ValueKey('break-fill-$ci'))).width;
      expect(fill / track, closeTo(score / 30, 0.01), reason: 'player $ci');
    }
  });

  testWidgets('a score past the target fills the bar and no more; 0 is an empty bar', (t) async {
    await _pump(
        t,
        RoundBreakCard(round: 2, target: 10, remaining: () => Duration.zero, players: const [
          BreakPlayer(name: 'A', colorIndex: 0, character: 'fox', score: 13),
          BreakPlayer(name: 'B', colorIndex: 1, character: 'owl', score: 0),
        ]));
    expect(t.getSize(find.byKey(const ValueKey('break-fill-0'))).width, t.getSize(find.byKey(const ValueKey('break-track-0'))).width);
    expect(t.getSize(find.byKey(const ValueKey('break-fill-1'))).width, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('8 players fit the card and the screen', (t) async {
    await _pump(
        t,
        RoundBreakCard(round: 12, target: 70, remaining: () => const Duration(seconds: 2), players: [
          for (var i = 0; i < 8; i++) BreakPlayer(name: 'Abcdefghijklmnop', colorIndex: i, character: characterIds[i], score: 70 - i),
        ]));
    expect(t.takeException(), isNull);
    final r = t.getRect(find.byKey(const ValueKey('round-break')));
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(1030), reason: 'clear of the overscan');
  });

  testWidgets('the seconds tick down by themselves', (t) async {
    var left = const Duration(seconds: 3);
    await _pump(t, RoundBreakCard(round: 1, target: 10, players: _four(), remaining: () => left));
    expect(find.text(Strings.curveBreakNext(3)), findsOneWidget);
    left = const Duration(seconds: 1);
    await t.pump(const Duration(seconds: 1));
    expect(find.text(Strings.curveBreakNext(1)), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('in the real app: no bar during play; when a round ends the scores card shows, and goes when the next round starts', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var at = Duration.zero;
    final s = Session(random: Random(1), clock: () => at);
    await t.pumpWidget(TvApp(session: s, serve: false));
    final a = join(s, 'Ana', token: 'ta');
    join(s, 'Ben', token: 'tb');
    a.say(const StartGame(GameKind.curve, null));
    await t.pump();
    expect(find.byKey(const ValueKey('round-break')), findsNothing, reason: 'nothing on the field during play');
    s.sim!.scores[0] = 4;
    s.sim!.roundOver = true;
    s.curveEvents([RoundOver(0)]);
    await t.pump();
    expect(find.byKey(const ValueKey('winner-banner')), findsOneWidget, reason: 'the winner first');
    expect(find.byKey(const ValueKey('round-break')), findsNothing);
    at += Session.momentTime;
    await t.pump(Session.momentTime);
    expect(s.roundBreak, isTrue);
    expect(find.byKey(const ValueKey('round-break')), findsOneWidget);
    expect(find.text(Strings.curveBreakTitle(1)), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      at += const Duration(seconds: 1);
      await t.pump(const Duration(seconds: 1));
    }
    expect(s.roundBreak, isFalse);
    expect(find.byKey(const ValueKey('round-break')), findsNothing, reason: 'the next round runs');
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('the title never truncates, even a long round number on a small window', (t) async {
    for (final size in [const Size(1280, 720), const Size(1920, 1080)]) {
      t.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
          theme: tvTheme(),
          home: RoundBreakCard(round: 12, target: 30, players: _four(), remaining: () => const Duration(seconds: 3))));
      final p = t.renderObject<RenderParagraph>(find.byKey(const ValueKey('break-title')));
      expect(p.didExceedMaxLines, isFalse, reason: 'no ellipsis at $size');
      expect(find.text(Strings.curveBreakTitle(12)), findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });
}
