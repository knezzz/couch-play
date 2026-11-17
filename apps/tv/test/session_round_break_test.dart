import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 37: after each Curve round the scores show for a few seconds before
/// the next round starts (the TV draws them while [Session.roundBreak] is on).
void main() {
  late Session s;
  late FakePeer a;
  var at = Duration.zero;

  /// Advances the session's clock and the fake timers together.
  Future<void> wait(WidgetTester t, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await t.pump(const Duration(seconds: 1));
      at += const Duration(seconds: 1);
    }
  }

  void startMatch() {
    at = Duration.zero;
    s = Session(random: Random(1), clock: () => at);
    a = join(s, 'A', token: 'ta');
    join(s, 'B', token: 'tb');
    a.say(const StartGame(GameKind.curve, null));
  }

  void endRound() {
    s.sim!.scores[0] = 4;
    s.sim!.roundOver = true;
    s.curveEvents([RoundOver(0)]);
  }

  testWidgets('a round over starts a 4 s break; the next round starts when it ends, not before', (t) async {
    startMatch();
    expect(s.roundBreak, isFalse);
    endRound();
    expect(s.roundBreak, isTrue);
    expect(s.roundBreakRemaining, Session.roundBreakTime);
    expect(Session.roundBreakTime, const Duration(seconds: 4));
    await wait(t, 3);
    expect(s.curveRound, 1, reason: 'still showing the scores');
    expect(s.sim!.roundOver, isTrue);
    expect(s.roundBreak, isTrue);
    await wait(t, 1);
    expect(s.curveRound, 2);
    expect(s.sim!.roundOver, isFalse);
    expect(s.roundBreak, isFalse);
    s.dispose();
  });

  testWidgets('the break counts down and the session tells the screens', (t) async {
    startMatch();
    var notified = 0;
    s.changes.addListener(() => notified++);
    endRound();
    final n = notified;
    expect(n, greaterThan(0), reason: 'the TV is told the break began');
    await wait(t, 1);
    expect(s.roundBreakRemaining, const Duration(seconds: 3));
    await wait(t, 3);
    expect(notified, greaterThan(n), reason: 'and when it ended');
    expect(s.roundBreakRemaining, Duration.zero);
    s.dispose();
  });

  testWidgets('the last round of a match has no break: the results come at once', (t) async {
    startMatch();
    s.sim!.scores
      ..[0] = 20
      ..[1] = 3;
    s.sim!.matchOver = true;
    s.sim!.roundOver = true;
    s.curveEvents([RoundOver(0), MatchOver(0)]);
    expect(s.phase, Phase.results);
    expect(s.roundBreak, isFalse);
    s.dispose();
  });

  testWidgets('abandoning the game in a break cancels it', (t) async {
    startMatch();
    endRound();
    s.endGame();
    expect(s.roundBreak, isFalse);
    await wait(t, 5);
    expect(s.phase, Phase.lobby);
    expect(s.curveRound, 1, reason: 'no round starts in the lobby');
    s.dispose();
  });

  testWidgets('nextRound called by hand ends the break at once and the timer does not start a second round', (t) async {
    startMatch();
    endRound();
    s.nextRound();
    expect(s.roundBreak, isFalse);
    expect(s.curveRound, 2);
    await wait(t, 5);
    expect(s.curveRound, 2);
    s.dispose();
  });

  testWidgets('every round gets its break', (t) async {
    startMatch();
    for (var r = 1; r <= 3; r++) {
      endRound();
      expect(s.roundBreak, isTrue, reason: 'round $r');
      await wait(t, 4);
      expect(s.curveRound, r + 1);
    }
    s.dispose();
  });
}
