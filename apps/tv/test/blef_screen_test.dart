import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/blef_match.dart' show BlefStageTv;
import 'package:tv/session/session.dart';
import 'package:tv/ui/blef/blef_screen.dart';
import 'package:tv/ui/blef/blef_view.dart';

import 'session_test.dart' show join;

PlayerInfo _p(int i) => PlayerInfo(i, ['Ana', 'Marko', 'Iva', 'Luka'][i], i, true, 0, character: characterIds[i]);
final _ps = [for (var i = 0; i < 4; i++) _p(i)];

BlefBoard _b(BlefStageTv st, {Set<int> sent = const {}, Set<int> picked = const {}, int left = 40, List<String> list = const [], List<BlefCard> shown = const [], Map<int, int>? points}) => BlefBoard(
    stage: st, number: 2, total: 7, question: 'Koliko je trajao najkraći rat u povijesti?', players: _ps, sent: sent, picked: picked, secondsLeft: left, seconds: 60, list: list, shown: shown, points: points);

Future<void> _show(WidgetTester t, BlefBoard b) async {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: BlefScreen(b)));
}

void main() {
  testWidgets('writing: the question, who has sent (lit), the count, the clock; no texts anywhere', (t) async {
    await _show(t, _b(BlefStageTv.write, sent: const {0, 2}));
    expect(find.text('Koliko je trajao najkraći rat u povijesti?'), findsOneWidget);
    expect(find.text('Poslano: 2 od 4'), findsOneWidget);
    expect(find.byKey(const ValueKey('who-0-yes')), findsOneWidget);
    expect(find.byKey(const ValueKey('who-1-no')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('seconds'))).data, '40');
    expect(find.byKey(const ValueKey('option-0')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('picking: the shuffled list in big cards, nothing marked, who has picked', (t) async {
    await _show(t, _b(BlefStageTv.pick, picked: const {1}, list: const ['38 minuta', '45 minuta', '3 dana', '1 sat']));
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('option-$i')), findsOneWidget);
    }
    expect(find.text('45 minuta'), findsOneWidget);
    expect(find.text('Odabrano: 1 od 4'), findsOneWidget);
    expect(find.textContaining('Točan'), findsNothing, reason: 'nothing marked as true');
    expect(t.takeException(), isNull);
  });

  testWidgets('reveal: entries so far, the true one green with its choosers, a fake with its author; points at the end', (t) async {
    final shown = [
      BlefCard('3 dana', false, [_ps[0]], [_ps[1], _ps[2]]),
      BlefCard('38 minuta', true, const [], [_ps[3]]),
    ];
    await _show(t, _b(BlefStageTv.reveal, shown: shown));
    expect(find.byKey(const ValueKey('card-0-fake')), findsOneWidget);
    expect(find.byKey(const ValueKey('card-1-truth')), findsOneWidget);
    expect(find.text('Lažni odgovor, autor: Ana'), findsOneWidget);
    expect(find.text('Točan odgovor'), findsOneWidget);
    expect(find.text('Marko, Iva'), findsOneWidget);
    expect(find.byKey(const ValueKey('points')), findsNothing, reason: 'not before the last entry');
    await _show(t, _b(BlefStageTv.reveal, shown: shown, points: const {0: 1000, 1: 0, 2: 500, 3: 0}));
    expect(find.text('Ana +1000'), findsOneWidget);
    expect(find.text('Iva +500'), findsOneWidget);
    expect(find.text('Marko +0'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('nobody picked an entry says so; a full 8-player reveal still fits above 1030 px', (t) async {
    final eight = [for (var i = 0; i < 9; i++) BlefCard('odgovor $i s malo duljim tekstom', i == 8, i == 8 ? const [] : [_ps[0]], i == 5 ? const [] : [_ps[1]])];
    final b8 = _b(BlefStageTv.reveal, shown: eight, points: const {0: 500});
    await _show(
        t,
        BlefBoard(
            stage: b8.stage, number: 2, total: 7, question: b8.question, players: [for (var i = 0; i < 8; i++) PlayerInfo(i, 'Igrac$i', i, true, 0, character: characterIds[i])],
            sent: const {}, picked: const {}, secondsLeft: 0, seconds: 60, shown: eight, points: const {0: 500}));
    expect(find.text('nitko'), findsOneWidget);
    expect(t.takeException(), isNull);
    expect(t.getRect(find.byKey(const ValueKey('points'))).bottom, lessThanOrEqualTo(1030));
    for (var i = 3; i < 9; i++) {
      expect(t.getRect(find.byKey(ValueKey('card-$i-${i == 8 ? 'truth' : 'fake'}'))).bottom, lessThanOrEqualTo(1030));
    }
    expect(find.byKey(const ValueKey('card-2-fake')), findsNothing, reason: 'only the latest six stay up');
    for (final w in t.widgetList<Text>(find.byType(Text))) {
      expect(w.style?.fontSize ?? 40, greaterThanOrEqualTo(40), reason: 'sofa-readable: ${w.data}');
    }
  });

  testWidgets('the view reads a live match while writing: it shows who has sent, never a fake', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = Session(random: Random(1))
      ..blefTvReady = true
      ..blefPacks = [BlefPack('b', 'B', [for (var i = 0; i < 12; i++) BlefQuestion('Pitanje $i?', 'istina $i', 'izvor')])];
    final ps = [for (var i = 0; i < 3; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.blef, null));
    expect(s.phase, Phase.blef);
    await t.pumpWidget(MaterialApp(home: BlefView(match: s.blef!, players: s.playerInfos)));
    expect(find.textContaining('Pitanje '), findsWidgets);
    expect(find.textContaining('istina'), findsNothing);
    expect(find.text('Poslano: 0 od 3'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
