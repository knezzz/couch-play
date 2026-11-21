import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 52 item 6: at a round's end every phone is told how it ended for it.
void main() {
  late Session s;
  late FakePeer a, b;
  var at = Duration.zero;

  void start() {
    at = Duration.zero;
    s = Session(random: Random(1), clock: () => at);
    a = join(s, 'A', token: 'ta');
    b = join(s, 'B', token: 'tb');
    a.say(const StartGame(GameKind.curve, null));
  }

  testWidgets('a winner, and everyone else, are told apart', (t) async {
    start();
    expect(a.last<CurveStatus>()!.end, isNull, reason: 'a running round has no end');
    s.curveEvents([Died(1), RoundOver(0)]);
    expect(a.last<CurveStatus>()!.end, RoundEnd.won);
    expect(b.last<CurveStatus>()!.end, RoundEnd.over);
    s.dispose();
  });

  testWidgets('crashing on the last tick together is a tie for those who crashed', (t) async {
    start();
    s.curveEvents([Died(0), Died(1), RoundOver(null)]);
    expect(a.last<CurveStatus>()!.end, RoundEnd.tie);
    expect(b.last<CurveStatus>()!.end, RoundEnd.tie);
    s.dispose();
  });

  testWidgets('a crash before the last tick is "over", not a tie', (t) async {
    start();
    s.curveEvents([Died(1)]);
    expect(b.last<CurveStatus>()!.end, isNull, reason: 'the round is still running');
    s.curveEvents([Died(0), RoundOver(null)]);
    expect(a.last<CurveStatus>()!.end, RoundEnd.tie);
    expect(b.last<CurveStatus>()!.end, RoundEnd.over);
    s.dispose();
  });

  testWidgets('the next round starts without an end', (t) async {
    start();
    s.sim!.roundOver = true; // as the sim has it when RoundOver comes
    s.curveEvents([Died(1), RoundOver(0)]);
    at += Session.momentTime;
    await t.pump(Session.momentTime);
    for (var i = 0; i < 4; i++) {
      at += const Duration(seconds: 1);
      await t.pump(const Duration(seconds: 1));
    }
    expect(s.curveRound, 2);
    expect(a.last<CurveStatus>()!.end, isNull);
    s.dispose();
  });
}
