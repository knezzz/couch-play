import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/quiz_screen.dart';
import 'package:tv/ui/tv_theme.dart';

const _svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="red"/></svg>';
const _amber = Color(0xFFFFB020);
const _red = Color(0xFFFF4D6D);

QuizScreen _screen({required double remaining, int limit = 20, int? correct, bool picture = false}) => QuizScreen(
      picture: picture ? Uint8List.fromList(utf8.encode(_svg)) : null,
      pictureName: 'p.svg',
      question: 'Koliko je godina trajao Stogodišnji rat?',
      packTitle: 'Opće znanje',
      choices: const ['99', '116', '100', '124'],
      number: 4,
      total: 10,
      remaining: remaining,
      limitSeconds: limit,
      answered: 3,
      expected: 5,
      correctIndex: correct,
      players: [for (var i = 0; i < 5; i++) PlayerInfo(i, 'P$i', i, true, 0, character: characterIds[i])],
    );

Future<void> _pump(WidgetTester t, QuizScreen s) {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  return t.pumpWidget(MaterialApp(theme: tvTheme(), home: s));
}

Color _seg(WidgetTester t, int i) =>
    (t.widget<Container>(find.byKey(ValueKey('tick-$i'))).decoration! as BoxDecoration).color!;

/// How many segments are lit, and the colour of the lit ones.
({int lit, Set<Color> colors}) _bar(WidgetTester t) {
  final lit = <Color>[];
  for (var i = 0; i < 20; i++) {
    final c = _seg(t, i);
    if (c.a > 0.5) lit.add(c);
  }
  return (lit: lit.length, colors: lit.toSet());
}

void main() {
  testWidgets('20 segments along the top edge, all lit at the start', (t) async {
    await _pump(t, _screen(remaining: 1));
    expect(find.byWidgetPredicate((w) => w.key is ValueKey && (w.key! as ValueKey).value.toString().startsWith('tick-')), findsNWidgets(20));
    expect(t.getTopLeft(find.byKey(const ValueKey('tick-0'))).dy, 0);
    expect(_bar(t).lit, 20);
    expect(_bar(t).colors, {_amber});
  });

  testWidgets('a 20 s question loses one segment per second', (t) async {
    // Fractions that are not exact in floating point must not drop a segment early.
    await _pump(t, _screen(remaining: 0.7));
    expect(_bar(t).lit, 14);
    await _pump(t, _screen(remaining: 13.5 / 20));
    expect(_bar(t).lit, 14, reason: '13.5 s left still shows 14 segments');
    await _pump(t, _screen(remaining: 13 / 20));
    expect(_bar(t).lit, 13);
  });

  testWidgets('the segments are lit from the left and the last ones go out', (t) async {
    await _pump(t, _screen(remaining: 0.5));
    for (var i = 0; i < 20; i++) {
      expect(_seg(t, i).a > 0.5, i < 10, reason: 'segment $i');
    }
  });

  testWidgets('red for the last 5 seconds, amber before', (t) async {
    await _pump(t, _screen(remaining: 6 / 20));
    expect(_bar(t).colors, {_amber});
    await _pump(t, _screen(remaining: 5 / 20));
    expect(_bar(t).lit, 5);
    expect(_bar(t).colors, {_red});
    await _pump(t, _screen(remaining: 4.2 / 20));
    expect(_bar(t).colors, {_red});
  });

  testWidgets('follows the host\'s time: 40 s maps 20 segments, red still at 5 s', (t) async {
    await _pump(t, _screen(remaining: 0.5, limit: 40)); // 20 s left
    expect(_bar(t).lit, 10);
    expect(_bar(t).colors, {_amber});
    await _pump(t, _screen(remaining: 6 / 40, limit: 40)); // 6 s left: not red yet
    expect(_bar(t).colors, {_amber});
    await _pump(t, _screen(remaining: 5 / 40, limit: 40)); // 5 s left
    expect(_bar(t).lit, 3);
    expect(_bar(t).colors, {_red});
    await _pump(t, _screen(remaining: 4 / 10, limit: 10)); // a 10 s question, 4 s left
    expect(_bar(t).lit, 8);
    expect(_bar(t).colors, {_red});
  });

  testWidgets('the top bar is the only countdown: no ring, no second timer, in either layout', (t) async {
    await _pump(t, _screen(remaining: 0.5));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('ring')), findsNothing);
    expect(find.text('10'), findsNothing, reason: 'no seconds number');
  });

  testWidgets('a picture question has no ring in its header either, and keeps the bar', (t) async {
    await _pump(t, _screen(remaining: 0.5, picture: true));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_bar(t).lit, 10);
  });

  testWidgets('the question has the whole width back (no ring beside it)', (t) async {
    await _pump(t, _screen(remaining: 0.5));
    final q = t.getRect(find.textContaining('Koliko je godina'));
    expect(q.right, greaterThan(1800), reason: 'the text may run to the right margin');
  });

  testWidgets('no ticker in the reveal', (t) async {
    await _pump(t, _screen(remaining: 0, correct: 1));
    expect(find.byKey(const ValueKey('tick-0')), findsNothing);
  });
}
