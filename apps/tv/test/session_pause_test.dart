import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer, join, idOf;

/// Task 20 part 2: a 2-player Curve match waits 30 s for the player who left.
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

  testWidgets('the_match_pauses_and_the_other_phone_is_told_who_we_wait_for', (t) async {
    await start(t);
    a.close();
    await t.pump();
    expect(s.phase, Phase.curve);
    expect(s.curveWaitingFor, 'Ana');
    expect(b.last<Waiting>(), Waiting(Strings.waitingForReturn('Ana')));
    // Nothing was killed, so ticking the sim can't hand Ben the round.
    expect(s.sim!.tick(), isEmpty, reason: 'no Died event: Ana was not killed');
    expect(s.sim!.roundOver, isFalse);
    expect(s.sim!.heads.every((h) => h.alive), isTrue);
    s.dispose();
  });

  testWidgets('a_rejoin_within_30_seconds_carries_on_from_the_next_round', (t) async {
    await start(t);
    final round = s.curveRound;
    a.close();
    await t.pump();
    await t.pump(const Duration(seconds: 20));
    expect(s.phase, Phase.curve);
    final a2 = back('Ana', 'ta');
    await t.pump();
    expect(s.curveWaitingFor, isNull);
    expect(s.curveRound, round + 1);
    expect(s.sim!.heads.every((h) => h.alive), isTrue);
    expect(a2.last<CurveStatus>()!.alive, isTrue);
    expect(b.last<CurveStatus>()!.alive, isTrue);
    await t.pump(const Duration(seconds: 40)); // the 30 s timer is gone
    expect(s.phase, Phase.curve);
    s.dispose();
  });

  testWidgets('no_rejoin_in_30_seconds_ends_the_match', (t) async {
    await start(t);
    a.close();
    await t.pump();
    await t.pump(const Duration(seconds: 29));
    expect(s.phase, Phase.curve);
    await t.pump(const Duration(seconds: 2));
    expect(s.phase, Phase.results);
    expect(b.last<Results>(), isNotNull);
    expect(s.curveWaitingFor, isNull);
    s.dispose();
  });

  testWidgets('the_last_human_leaving_ends_it_at_once', (t) async {
    await start(t);
    a.close();
    await t.pump();
    b.close();
    await t.pump();
    expect(s.phase, Phase.results);
    s.dispose();
  });

  testWidgets('a_kicked_player_is_not_waited_for', (t) async {
    await start(t);
    a.say(Kick(idOf(b)));
    await t.pump();
    expect(s.phase, Phase.results);
    s.dispose();
  });

  testWidgets('back_to_the_lobby_cancels_the_wait', (t) async {
    await start(t);
    a.close();
    await t.pump();
    s.endGame();
    expect(s.curveWaitingFor, isNull);
    await t.pump(const Duration(seconds: 40));
    expect(s.phase, Phase.lobby);
    s.dispose();
  });

  testWidgets('next_round_waits_while_paused', (t) async {
    await start(t);
    a.close();
    await t.pump();
    s.sim!.roundOver = true;
    final round = s.curveRound;
    s.nextRound();
    expect(s.curveRound, round);
    s.dispose();
  });
}
