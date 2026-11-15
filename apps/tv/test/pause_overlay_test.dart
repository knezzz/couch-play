import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/main.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer, join;

/// The real TvApp around a real Session: the pause text must reach the screen
/// when a player leaves a 2-player Curve match, and leave it again.
void main() {
  late Session s;
  late FakePeer a, b;
  final text = find.text(Strings.waitingForReturn('Ana'));

  Future<void> run(WidgetTester t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    s = Session(random: Random(1));
    await t.pumpWidget(TvApp(session: s, serve: false));
    a = join(s, 'Ana', token: 'ta');
    b = join(s, 'Ben', token: 'tb');
    a.say(const StartGame(GameKind.curve, null));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(text, findsNothing);
  }

  testWidgets('the_pause_text_shows_when_a_player_leaves_and_goes_on_return', (t) async {
    await run(t);
    a.close();
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    expect(text, findsOneWidget);
    await t.pump(const Duration(seconds: 20));
    expect(text, findsOneWidget);
    final a2 = FakePeer();
    s.attach(a2);
    a2.say(const Join('Ana', 'ta'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(text, findsNothing);
    expect(b.last<CurveStatus>(), isNotNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the_pause_text_goes_when_the_match_ends', (t) async {
    await run(t);
    a.close();
    await t.pump();
    expect(text, findsOneWidget);
    await t.pump(const Duration(seconds: 31));
    expect(s.phase, Phase.results);
    expect(text, findsNothing);
    await t.pumpWidget(const SizedBox());
  });
}
