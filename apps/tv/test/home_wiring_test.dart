import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/main.dart';
import 'package:tv/session/session.dart';
import 'package:tv/ui/home_screen.dart';

import 'session_test.dart' show FakePeer, join;

/// The home inside the real app: what the host's phone and the remote do to it.
void main() {
  late Session s;
  late FakePeer a;

  Future<void> start(WidgetTester t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    s = Session(random: Random(1));
    await t.pumpWidget(TvApp(session: s, serve: false));
    a = join(s, 'Ana', token: 'ta');
    join(s, 'Ben', token: 'tb');
    await t.pump();
  }

  Finder title(String name) => find.byKey(ValueKey('title-$name'));

  testWidgets('every game is on the home', (t) async {
    await start(t);
    expect(homeGames.toSet(), GameKind.values.toSet());
    for (final g in GameKind.values) {
      a.say(SelectGame(g));
      await t.pump();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(s.selectedGame, g);
    }
  });

  for (final (kind, name) in [(GameKind.vukodlak, 'Vukodlak'), (GameKind.uljez, 'Uljez')]) {
    testWidgets('the host\'s phone selecting $name moves the TV there, and OK does not start Curve or Kviz', (t) async {
      await start(t);
      a.say(SelectGame(kind));
      await t.pump();
      expect(title(name), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.select);
      await t.pump();
      expect(s.phase, isNot(Phase.curve));
      expect(s.phase, isNot(Phase.quiz));
      await t.pump(const Duration(seconds: 5)); // the notice goes away
    });
  }

  testWidgets('the remote can walk to every game and the session follows', (t) async {
    await start(t);
    final seen = <GameKind?>[s.selectedGame];
    for (var i = 0; i < homeGames.length; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      seen.add(s.selectedGame);
    }
    expect(seen.skip(1).toSet(), homeGames.toSet());
  });
}
