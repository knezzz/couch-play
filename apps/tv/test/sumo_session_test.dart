import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 55: Sumo runs through the same round machinery as Curve.
void main() {
  late Session s;
  var at = Duration.zero;

  /// [n] phones join (the first is the host); the host sends [settings] first if given.
  List<FakePeer> lobby(int n, {GameSettings? settings}) {
    at = Duration.zero;
    s = Session(random: Random(1), clock: () => at);
    final ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
    if (settings != null) ps.first.say(SetSettings(settings));
    return ps;
  }

  Future<void> wait(WidgetTester t, int ms) async {
    await t.pump(Duration(milliseconds: ms));
    at += Duration(milliseconds: ms);
  }

  test('Sumo starts like Curve and the phones are told it is Sumo', () {
    final ps = lobby(3);
    ps.first.say(const StartGame(GameKind.sumo, null));
    expect(s.phase, Phase.curve);
    expect(s.sumo, isNotNull);
    expect(s.sim, isNull, reason: 'not a Curve sim');
    expect(s.roundSim, same(s.sumo));
    for (final p in ps) {
      final st = p.last<CurveStatus>()!;
      expect(st.sumo, isTrue);
      expect(st.alive, isTrue);
      expect(st.target, 20);
      expect(st.round, 1);
    }
    s.dispose();
  });

  test('Curve statuses stay Curve', () {
    final ps = lobby(2);
    ps.first.say(const StartGame(GameKind.curve, null));
    expect(ps.last.last<CurveStatus>()!.sumo, isFalse);
    expect(s.sim, isNotNull);
    expect(s.sumo, isNull);
    s.dispose();
  });

  test('needs two players and no robots', () {
    final ps = lobby(1);
    ps.first.say(const StartGame(GameKind.sumo, null));
    expect(ps.first.last<ErrorMsg>(), const ErrorMsg(Strings.sumoNeedsTwo));
    expect(s.phase, Phase.lobby);
    final qs = lobby(2);
    qs.first.say(const SetBots(1));
    qs.first.say(const StartGame(GameKind.sumo, null));
    expect(qs.first.last<ErrorMsg>(), const ErrorMsg(Strings.sumoNoBots));
    expect(s.phase, Phase.lobby);
    s.dispose();
  });

  test('the host settings reach the sim: the map and the power-ups', () {
    final ps = lobby(2, settings: const GameSettings(sumoMap: SumoMap.ice, sumoPowerUps: false, curveCountdown: 3));
    ps.first.say(const StartGame(GameKind.sumo, null));
    final sim = s.sumo!;
    expect(sim.ice, isTrue);
    expect(sim.config.powerUps, isFalse);
    expect(sim.config.countdown, 3);
    s.dispose();
    final qs = lobby(2);
    qs.first.say(const StartGame(GameKind.sumo, null));
    expect(s.sumo!.ice, isFalse);
    expect(s.sumo!.config.powerUps, isTrue);
    s.dispose();
  });

  test('a phone\'s joystick and Dash move its own wrestler, and only while it plays', () {
    final ps = lobby(2);
    ps.first.say(const StartGame(GameKind.sumo, null));
    final sim = s.sumo!;
    final myId = s.playerInfos.first.colorIndex;
    final otherId = s.playerInfos.last.colorIndex;
    while (sim.countingDown) {
      sim.tick();
    }
    sim.place(myId, 0, 0);
    sim.place(otherId, 300, 300);
    ps.first.say(const SumoMove(0, 3));
    for (var i = 0; i < 10; i++) {
      sim.tick();
    }
    expect(sim.velocityOf(myId).$1, greaterThan(50));
    expect(sim.velocityOf(otherId).$1, 0);
    ps.first.say(const SumoMove(0, 0));
    ps.first.say(const SumoDash());
    final ev = sim.tick();
    expect(ev.whereType<Dashed>().single.id, myId);
    s.dispose();
  });

  test('a Curve Steer does nothing in Sumo, and Sumo input does nothing in Curve', () {
    final ps = lobby(2);
    ps.first.say(const StartGame(GameKind.sumo, null));
    ps.first.say(const Steer(left: true, right: false)); // must not throw
    s.dispose();
    final qs = lobby(2);
    qs.first.say(const StartGame(GameKind.curve, null));
    qs.first.say(const SumoMove(0, 3));
    qs.first.say(const SumoDash()); // ignored
    expect(s.phase, Phase.curve);
    s.dispose();
  });

  testWidgets('the last wrestler out: the winner moment (1.5 s), the scores card, and the next round', (t) async {
    final ps = lobby(2);
    ps.first.say(const StartGame(GameKind.sumo, null));
    final sim = s.sumo!;
    final ids = s.playerInfos.map((p) => p.colorIndex).toList();
    while (sim.countingDown) {
      sim.tick();
    }
    sim.place(ids[1], 500, 0);
    final ev = sim.tick();
    s.curveEvents(ev);
    expect(ev.whereType<Died>().single.id, ids[1]);
    expect(s.moment, isNotNull);
    expect(s.moment!.ids, [ids[0]]);
    expect(s.moment!.points[ids[0]], 1);
    expect(ps.last.last<CurveStatus>()!.alive, isFalse);
    expect(ps.last.last<CurveStatus>()!.sumo, isTrue);
    expect(ps.first.last<CurveStatus>()!.end, RoundEnd.won);
    await wait(t, 1500);
    expect(s.roundBreak, isTrue);
    await wait(t, 4000);
    expect(s.roundBreak, isFalse);
    expect(s.curveRound, 2);
    expect(sim.roundOver, isFalse);
    expect(ps.first.last<CurveStatus>()!.round, 2);
    s.dispose();
  });

  testWidgets('the match ends at 10 x (players - 1): results labelled Sumo', (t) async {
    final ps = lobby(2);
    ps.first.say(const StartGame(GameKind.sumo, null));
    final sim = s.sumo!;
    final ids = s.playerInfos.map((p) => p.colorIndex).toList();
    sim.scores[ids[0]] = 9;
    while (sim.countingDown) {
      sim.tick();
    }
    sim.place(ids[1], 500, 0);
    s.curveEvents(sim.tick());
    expect(sim.matchOver, isTrue);
    expect(s.moment!.match, isTrue);
    expect(ps.first.last<CurveStatus>()!.end, isNull);
    await wait(t, 1500);
    expect(s.phase, Phase.results);
    expect(s.lastGameLabel, 'Sumo');
    expect(s.placements.first.playerId, s.playerInfos.first.id);
    s.dispose();
  });

  testWidgets('a phone that drops is out for the round, and its held stick is let go', (t) async {
    final ps = lobby(3);
    ps.first.say(const StartGame(GameKind.sumo, null));
    final sim = s.sumo!;
    final id2 = s.playerInfos[2].colorIndex;
    while (sim.countingDown) {
      sim.tick();
    }
    ps[2].say(const SumoMove(4, 3));
    ps[2].close();
    await t.pump();
    final ev = sim.tick();
    expect(ev.whereType<Died>().map((e) => e.id), [id2]);
    expect(sim.heads.firstWhere((h) => h.id == id2).alive, isFalse);
    s.dispose();
  });

  testWidgets('a match with two phones pauses when one leaves, and waits for them', (t) async {
    final ps = lobby(2);
    ps.first.say(const StartGame(GameKind.sumo, null));
    ps.last.close();
    await t.pump();
    expect(s.paused, isTrue);
    expect(s.pauseWaitingFor, isNotNull);
    s.dispose();
  });
}
