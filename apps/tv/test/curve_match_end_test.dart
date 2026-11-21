import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 52 review must-fix: a won match must end, whatever the phones do in the winner moment.
void main() {
  late Session s;
  late FakePeer a, b;

  Future<void> start(WidgetTester t) async {
    s = Session(random: Random(1));
    a = join(s, 'Ana', token: 'ta');
    b = join(s, 'Ben', token: 'tb');
    a.say(const StartGame(GameKind.curve, null));
    await t.pump();
  }

  FakePeer back(String name, String token) {
    final p = FakePeer();
    s.attach(p);
    p.say(Join(name, token));
    return p;
  }

  void matchWon() {
    s.sim!.scores
      ..[0] = 20
      ..[1] = 3;
    s.sim!.matchOver = true;
    s.sim!.roundOver = true;
    s.curveEvents([Died(1), RoundOver(0), MatchOver(0)]);
  }

  testWidgets('the loser drops and returns during the match moment: the results still come, play does not go on', (t) async {
    await start(t);
    matchWon();
    expect(s.moment!.match, isTrue);
    final round = s.curveRound;
    b.close();
    await t.pump(const Duration(milliseconds: 300));
    final b2 = back('Ben', 'tb');
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(Session.momentTime);
    expect(s.phase, Phase.results, reason: 'the TV said who won the game');
    expect(s.curveRound, round, reason: 'no new round on a won match');
    expect(a.last<Results>(), isNotNull);
    expect(b2.last<Results>(), isNotNull);
    s.dispose();
  });

  testWidgets('a drop and return during a round moment still carries on with the next round', (t) async {
    await start(t);
    s.sim!.scores[0] = 4;
    s.sim!.roundOver = true;
    s.curveEvents([Died(1), RoundOver(0)]);
    final round = s.curveRound;
    b.close();
    await t.pump(const Duration(milliseconds: 300));
    back('Ben', 'tb');
    await t.pump(const Duration(milliseconds: 100));
    expect(s.curveRound, round + 1);
    expect(s.phase, Phase.curve);
    await t.pump(Session.momentTime);
    expect(s.phase, Phase.curve);
    s.dispose();
  });

  testWidgets('at the end of the match no phone is told "next round": no round-end flag', (t) async {
    await start(t);
    matchWon();
    expect(a.last<CurveStatus>()!.end, isNull);
    expect(b.last<CurveStatus>()!.end, isNull);
    await t.pump(Session.momentTime);
    s.dispose();
  });

  testWidgets('at the end of a round the flag is still sent', (t) async {
    await start(t);
    s.sim!.scores[0] = 4;
    s.sim!.roundOver = true;
    s.curveEvents([Died(1), RoundOver(0)]);
    expect(a.last<CurveStatus>()!.end, RoundEnd.won);
    expect(b.last<CurveStatus>()!.end, RoundEnd.over);
    await t.pump(Session.momentTime);
    s.dispose();
  });
}
