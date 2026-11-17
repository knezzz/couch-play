import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/objasni_match.dart';
import 'package:tv/session/session.dart';
import 'package:tv/ui/objasni/objasni_screen.dart';
import 'package:tv/ui/objasni/objasni_view.dart';

import 'session_objasni_test.dart' show pack;
import 'session_test.dart' show join;

PlayerInfo _p(int i) => PlayerInfo(i, 'Igrac$i', i, true, 0, character: characterIds[i]);

ObjasniBoard _board({
  ObjasniStageTv stage = ObjasniStageTv.play,
  int left = 40,
  List<ObjasniMarked> words = const [],
  int? winner,
  int? paused,
  int turnTeam = 0,
}) =>
    ObjasniBoard(
      stage: stage,
      teams: [[_p(0), _p(1)], [_p(2), _p(3)]],
      scores: const [7, 5],
      target: 30,
      turnTeam: turnTeam,
      explainer: _p(turnTeam == 0 ? 0 : 2),
      words: words,
      secondsLeft: left,
      turnSeconds: 60,
      summarySeconds: 4,
      winnerTeam: winner,
      pausedSeconds: paused,
    );

Future<void> _show(WidgetTester t, ObjasniBoard b) async {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: ObjasniScreen(b)));
}

void main() {
  testWidgets('play: the explainer big, both scores, the target, the seconds and the ticker', (t) async {
    await _show(t, _board());
    expect(find.text('Igrac0'), findsOneWidget);
    expect(find.text('Tim 1'), findsOneWidget);
    expect(find.text('Tim 2'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('score-0'))).data, '7');
    expect(t.widget<Text>(find.byKey(const ValueKey('score-1'))).data, '5');
    expect(t.widget<Text>(find.byKey(const ValueKey('seconds'))).data, '40');
    expect(find.textContaining('30'), findsWidgets);
    var lit = 0;
    for (var i = 0; i < 20; i++) {
      final c = (t.widget<Container>(find.byKey(ValueKey('tick-$i'))).decoration as BoxDecoration).color!;
      if (c.a > 0.5) lit++;
    }
    expect(lit, 14, reason: '40 of 60 s is 14 of 20 segments');
    expect(t.takeException(), isNull);
  });

  testWidgets('the turn\'s words appear as they are done: green, grey, red with its label', (t) async {
    await _show(t, _board(words: const [ObjasniMarked('pas', ObjasniMark.correct), ObjasniMarked('mačka', ObjasniMark.skip), ObjasniMarked('vuk', ObjasniMark.foul)]));
    expect(find.byKey(const ValueKey('word-0-correct')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-1-skip')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-2-foul')), findsOneWidget);
    expect(find.text('pas'), findsOneWidget);
    expect(find.textContaining('prekršaj'), findsOneWidget);
  });

  testWidgets('the last 5 seconds go red', (t) async {
    await _show(t, _board(left: 5));
    expect(t.widget<Text>(find.byKey(const ValueKey('seconds'))).style!.color, const Color(0xFFFF4D6D));
    await _show(t, _board(left: 6));
    expect(t.widget<Text>(find.byKey(const ValueKey('seconds'))).style!.color, isNot(const Color(0xFFFF4D6D)));
  });

  testWidgets('setup shows the two teams with every member; ready names the next explainer', (t) async {
    await _show(t, _board(stage: ObjasniStageTv.setup));
    for (var i = 0; i < 4; i++) {
      expect(find.text('Igrac$i'), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('seconds')), findsNothing, reason: 'no clock in setup');
    await _show(t, _board(stage: ObjasniStageTv.ready, turnTeam: 1));
    expect(find.byKey(const ValueKey('explainer')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('explainer'))).data, 'Igrac2');
    expect(find.textContaining('Spreman'), findsOneWidget);
  });

  testWidgets('summary: the words and the next turn in seconds; over: the winner in the team colour', (t) async {
    await _show(t, _board(stage: ObjasniStageTv.summary, words: const [ObjasniMarked('pas', ObjasniMark.correct)]));
    expect(find.byKey(const ValueKey('word-0-correct')), findsOneWidget);
    expect(find.text('Sljedeći krug za 4 s'), findsOneWidget);
    await _show(t, _board(stage: ObjasniStageTv.over, winner: 1));
    expect(t.widget<Text>(find.byKey(const ValueKey('winner'))).data, 'Pobjeđuje Tim 2!');
    expect(t.widget<Text>(find.byKey(const ValueKey('winner'))).style!.color, objasniTeamColors[1]);
  });

  testWidgets('a team gone: the pause covers the board with the wait text and seconds', (t) async {
    await _show(t, _board(paused: 22));
    expect(find.byKey(const ValueKey('paused')), findsOneWidget);
    expect(find.text('22 s'), findsOneWidget);
    await _show(t, _board());
    expect(find.byKey(const ValueKey('paused')), findsNothing);
  });

  testWidgets('no word of the pack is ever drawn: the view reads a live match in setup', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = Session(random: Random(1))
      ..objasniTvReady = true
      ..objasniPacks = [pack('one')];
    final ps = [for (var i = 0; i < 4; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.objasni, null));
    expect(s.phase, Phase.objasni);
    await t.pumpWidget(MaterialApp(home: ObjasniView(match: s.objasni!, players: s.playerInfos)));
    for (var i = 0; i < 4; i++) {
      expect(find.text('P$i'), findsOneWidget);
    }
    expect(find.textContaining('one-w'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
