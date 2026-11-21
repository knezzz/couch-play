import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/main.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 45: the whole path. A game is running; Back, Ukloni igrača, a name, Da: the session drops that player.
void main() {
  testWidgets('Back in a running game kicks the picked player through the session', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = Session(random: Random(1));
    await t.pumpWidget(TvApp(session: s, serve: false));
    final FakePeer a = join(s, 'Ana', token: 'ta');
    join(s, 'Ben', token: 'tb');
    join(s, 'Cvita', token: 'tc');
    a.say(const StartGame(GameKind.curve, null));
    await t.pump();
    expect(s.phase, Phase.curve);
    await t.binding.handlePopRoute();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text(Strings.kickPlayer));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.textContaining('Cvita').last); // the first is the names strip under the menu
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text(Strings.yes));
    await t.pump(const Duration(milliseconds: 400));
    expect(s.playerInfos.map((p) => p.name), ['Ana', 'Ben']);
    s.dispose();
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
