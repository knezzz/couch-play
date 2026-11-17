import 'dart:math';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/main.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/curve/curve_hud.dart';
import 'package:tv/ui/tv_theme.dart';

import 'session_test.dart' show join;

List<CurveHudPlayer> _four() => const [
      CurveHudPlayer(name: 'Luka', colorIndex: 0, character: 'fox', score: 12),
      CurveHudPlayer(name: 'Ana', colorIndex: 1, character: 'owl', score: 9),
      CurveHudPlayer(name: 'Marko', colorIndex: 2, character: 'frog', score: 7),
      CurveHudPlayer(name: 'Robot 1', colorIndex: 4, character: 'panda', score: 4),
    ];

Future<void> _pump(WidgetTester t, Widget w) {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  return t.pumpWidget(MaterialApp(theme: tvTheme(), home: Scaffold(body: w)));
}

Finder _face(String id) => find.byWidgetPredicate((w) => w is CharacterFace && w.id == id);

void main() {
  testWidgets('the bar: the round and the target, each player with face, name and score, and the mode', (t) async {
    await _pump(t, CurveHud(round: 3, target: 30, modeName: 'Kaos', players: _four()));
    expect(find.text(Strings.curveRound(3, 30)), findsOneWidget);
    expect(find.text('Kaos'), findsOneWidget);
    for (final (name, id, score, ci) in [('Luka', 'fox', '12', 0), ('Ana', 'owl', '9', 1), ('Marko', 'frog', '7', 2), ('Robot 1', 'panda', '4', 4)]) {
      final row = find.byKey(ValueKey('hud-$ci'));
      expect(find.descendant(of: row, matching: find.text(name)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text(score)), findsOneWidget);
      expect(find.descendant(of: row, matching: _face(id)), findsOneWidget);
    }
    expect(t.getSize(find.byKey(const ValueKey('curve-hud'))).height, 88);
  });

  testWidgets('the leader comes first', (t) async {
    await _pump(
        t,
        CurveHud(round: 1, target: 20, modeName: 'Mirno', players: const [
          CurveHudPlayer(name: 'Dva', colorIndex: 1, character: 'owl', score: 2),
          CurveHudPlayer(name: 'Pet', colorIndex: 0, character: 'fox', score: 5),
        ]));
    expect(t.getTopLeft(find.byKey(const ValueKey('hud-0'))).dx, lessThan(t.getTopLeft(find.byKey(const ValueKey('hud-1'))).dx));
  });

  testWidgets('8 players with long names fit the bar: nothing overflows, nothing past the edges', (t) async {
    await _pump(
        t,
        CurveHud(round: 12, target: 70, modeName: 'Uravnoteženo', players: [
          for (var i = 0; i < 8; i++) CurveHudPlayer(name: 'Abcdefghijklmnop', colorIndex: i, character: characterIds[i], score: 70 - i),
        ]));
    expect(t.takeException(), isNull);
    final r = t.getRect(find.byKey(const ValueKey('curve-hud')));
    expect(r.right, lessThanOrEqualTo(1920));
    for (var i = 0; i < 8; i++) {
      final f = t.getRect(_face(characterIds[i]));
      expect(f.right, lessThanOrEqualTo(1920), reason: 'face $i');
    }
  });

  testWidgets('away players are dimmed', (t) async {
    await _pump(
        t,
        CurveHud(round: 1, target: 10, modeName: 'Kaos', players: const [
          CurveHudPlayer(name: 'Tu', colorIndex: 0, character: 'fox', score: 1),
          CurveHudPlayer(name: 'Odsutan', colorIndex: 1, character: 'owl', score: 1, away: true),
        ]));
    double opacityOf(int ci) => t.widget<Opacity>(find.byKey(ValueKey('hud-$ci'))).opacity;
    expect(opacityOf(0), 1);
    expect(opacityOf(1), lessThan(1));
  });

  testWidgets('in the real app a running Curve has the bar above the arena, with the live scores', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = Session(random: Random(1));
    await t.pumpWidget(TvApp(session: s, serve: false));
    final a = join(s, 'Ana', token: 'ta');
    join(s, 'Ben', token: 'tb');
    a.say(const StartGame(GameKind.curve, null));
    await t.pump();
    expect(s.phase, Phase.curve);
    expect(find.byKey(const ValueKey('curve-hud')), findsOneWidget);
    expect(find.text(Strings.curveRound(1, 10)), findsOneWidget, reason: 'round 1, first to 10 x (players - 1)');
    expect(find.byKey(const ValueKey('hud-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('hud-1')), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    final hud = t.getRect(find.byKey(const ValueKey('curve-hud')));
    final game = t.getRect(find.byWidgetPredicate((w) => w is GameWidget));
    expect(game.top, greaterThanOrEqualTo(hud.bottom - 1), reason: 'the arena is below the bar');
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
