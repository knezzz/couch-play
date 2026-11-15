import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join, idOf;

/// Task 20: a game goes on when someone, the host included, drops out, and
/// they can come back into the same game.
FakePeer back(Session s, String name, String token) {
  final p = FakePeer();
  s.attach(p);
  p.say(Join(name, token));
  return p;
}

void main() {
  late Session s;
  late FakePeer a, b, c;

  setUp(() {
    s = Session(random: Random(1));
    a = join(s, 'A', token: 'ta');
    b = join(s, 'B', token: 'tb');
    c = join(s, 'C', token: 'tc');
    a.say(const StartGame(GameKind.curve, null));
  });

  test('host_leaving_mid_curve_keeps_the_game_and_passes_the_host_on', () async {
    expect(s.hostId, idOf(a));
    await a.drop();
    expect(s.phase, Phase.curve);
    expect(s.hostId, idOf(b));
  });

  test('old_host_comes_back_to_the_next_round_and_the_new_host_stays', () async {
    await a.drop();
    final sidA = s.players.firstWhere((p) => p.id == idOf(a)).colorIndex;
    s.sim!.scores[sidA] = 3;
    final a2 = back(s, 'A', 'ta');
    expect(s.hostId, idOf(b), reason: 'the host role stays until the game ends');
    expect(a2.last<CurveStatus>()!.alive, isFalse, reason: 'this round is lost');
    // The round ends, the next one starts.
    s.sim!.roundOver = true;
    s.nextRound();
    expect(a2.last<CurveStatus>()!.alive, isTrue);
    expect(s.sim!.heads.firstWhere((h) => h.id == sidA).alive, isTrue);
    expect(s.sim!.scores[sidA], 3, reason: 'earlier points are kept');
  });

  test('a_non_host_comes_back_too', () async {
    await b.drop();
    expect(s.phase, Phase.curve);
    expect(s.hostId, idOf(a));
    final b2 = back(s, 'B', 'tb');
    s.sim!.roundOver = true;
    s.nextRound();
    expect(b2.last<CurveStatus>()!.alive, isTrue);
    expect(s.hostId, idOf(a));
  });

  test('the_new_host_can_kick_during_the_game', () async {
    await a.drop();
    b.say(Kick(idOf(c)));
    expect(s.players.any((p) => p.id == idOf(c)), isFalse);
  });

  test('a_new_socket_before_the_old_one_closes_stops_the_steering', () async {
    final sidB = s.players.firstWhere((p) => p.id == idOf(b)).colorIndex;
    double heading() => s.sim!.heads.firstWhere((h) => h.id == sidB).heading;
    b.say(const Steer(left: true, right: false));
    back(s, 'B', 'tb'); // the new socket arrives before the old one closes
    expect(b.closed, isTrue);
    s.sim!.startRound(); // inputs persist across rounds
    for (var i = 0; i < 130; i++) {
      s.sim!.tick(); // past the 2 s countdown
    }
    final start = heading();
    for (var i = 0; i < 30; i++) {
      s.sim!.tick();
    }
    expect(heading(), start, reason: 'no steering left over from the old socket');  });

  test('a_kicked_player_does_not_come_back', () async {
    a.say(Kick(idOf(c)));
    final c2 = back(s, 'C', 'tc');
    s.sim!.roundOver = true;
    s.nextRound();
    expect(c2.last<CurveStatus>(), isNull);
  });

  test('the_host_role_returns_to_the_oldest_after_the_game', () async {
    await a.drop();
    back(s, 'A', 'ta');
    expect(s.hostId, idOf(b));
    s.finishGame({});
    expect(s.hostId, idOf(a));
  });
}
