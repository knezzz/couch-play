import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/main.dart';
import 'package:tv/session/game_ready.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/wolf/village_screen.dart';
import 'package:tv/ui/wolf/wolf_view.dart';

import 'session_test.dart' show FakePeer, join;

/// Vukodlak inside the real app.
void main() {
  testWidgets('the village is ready on the TV', (t) async {
    expect(kWolfTvReady, isTrue, reason: 'flipped with the village screens');
  });

  testWidgets('the host starts Vukodlak with 5 players: the village is on screen, Back asks to end it', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = Session(random: Random(1));
    await t.pumpWidget(TvApp(session: s, serve: false));
    late FakePeer host;
    for (var i = 0; i < 5; i++) {
      final p = join(s, 'Igrac${i + 1}', token: 't$i');
      if (i == 0) host = p;
    }
    host.say(const StartGame(GameKind.vukodlak, null));
    await t.pump();
    expect(s.phase, Phase.wolf);
    expect(find.byType(WolfView), findsOneWidget);
    expect(find.byType(VillageScreen), findsOneWidget);
    for (var i = 1; i <= 5; i++) {
      expect(find.text('Igrac$i'), findsOneWidget);
    }
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.text(Strings.endGameTitle), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
