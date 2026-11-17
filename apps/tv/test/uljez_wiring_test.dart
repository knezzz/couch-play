import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/main.dart';
import 'package:tv/session/game_ready.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/uljez/uljez_screen.dart';
import 'package:tv/ui/uljez/uljez_view.dart';

import 'session_test.dart' show FakePeer, join;

/// Uljez inside the real app.
void main() {
  testWidgets('the table is ready on the TV', (t) async {
    expect(kUljezTvReady, isTrue, reason: 'flipped with the table screens');
  });

  testWidgets('the host starts Uljez with 3 players: the table is on screen, Back asks to end it', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = Session(random: Random(1));
    s.uljezPacks = [
      const UljezPack('p', 'Probni', [
        WordPair('Lubenica', 'Dinja'),
        WordPair('Pas', 'Vuk'),
        WordPair('Kava', 'Čaj'),
        WordPair('Zagreb', 'Split'),
      ]),
    ];
    await t.pumpWidget(TvApp(session: s, serve: false));
    late FakePeer host;
    for (var i = 0; i < 3; i++) {
      final p = join(s, 'Igrac${i + 1}', token: 't$i');
      if (i == 0) host = p;
    }
    host.say(const StartGame(GameKind.uljez, null));
    await t.pump();
    expect(s.phase, Phase.uljez);
    expect(find.byType(UljezView), findsOneWidget);
    expect(find.byType(UljezScreen), findsOneWidget);
    for (var i = 1; i <= 3; i++) {
      expect(find.text('Igrac$i'), findsOneWidget);
    }
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.text(Strings.endGameTitle), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
