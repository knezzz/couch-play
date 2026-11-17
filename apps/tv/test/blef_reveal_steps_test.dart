import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/blef_match.dart';
import 'package:tv/session/session.dart';
import 'package:tv/ui/blef/blef_view.dart';

import 'session_blef_test.dart' show pack;
import 'session_test.dart' show join;

/// The Blef reveal goes through the answers one by one (4 s each, fakes first, the true one last), then
/// every row and the points stay up for a while before the next question.
void main() {
  testWidgets('one row per step on the TV, all rows stay for the final hold, then the next question', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var at = Duration.zero;
    final s = Session(random: Random(1), clock: () => at)
      ..blefTvReady = true
      ..blefPacks = [pack('one')];
    final ps = [for (var i = 0; i < 4; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.blef, null));
    final m = s.blef!;
    for (var i = 0; i < 4; i++) {
      ps[i].say(BlefFake('laž $i'));
    }
    expect(m.stage, BlefStageTv.pick);
    for (final p in ps) {
      p.say(BlefPick(p.last<BlefList>()!.ids.first));
    }
    expect(m.stage, BlefStageTv.reveal);
    await t.pumpWidget(MaterialApp(home: BlefView(match: m, players: s.playerInfos)));

    Future<void> advance(Duration d) async {
      for (var left = d; left > Duration.zero; left -= const Duration(milliseconds: 500)) {
        at += const Duration(milliseconds: 500);
        await t.pump(const Duration(milliseconds: 500));
      }
    }

    int rows() => find.byWidgetPredicate((w) => w.key is ValueKey && (w.key as ValueKey).value.toString().startsWith('card-')).evaluate().length;
    const entries = 5; // 4 fakes and the truth
    for (var k = 1; k <= entries; k++) {
      expect(m.revealStep, k - 1);
      expect(rows(), k, reason: 'at step $k only $k answer(s) are up');
      if (k < entries) {
        expect(find.byKey(ValueKey('card-${k - 1}-${k == entries ? 'truth' : 'fake'}')), findsOneWidget);
        await advance(BlefMatch.stepTime);
      }
    }
    expect(find.byKey(const ValueKey('card-4-truth')), findsOneWidget, reason: 'the true answer comes last');
    expect(find.byKey(const ValueKey('points')), findsOneWidget, reason: 'the points show with the last answer');
    // The last step stays up for the final hold: still all rows, same question.
    await advance(const Duration(seconds: 7));
    expect(m.number, 1, reason: 'still question 1 after 7 s on the last answer');
    expect(rows(), entries);
    await advance(const Duration(seconds: 2));
    expect(m.number, 2, reason: 'the next question after the final hold (about 8 s)');
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
