import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join;

/// Session.kickFromTv: the TV remote's kick does what the host phone's does.
void main() {
  late Session s;
  late List<FakePeer> ps;
  int idOf(FakePeer p) => p.sent.whereType<Welcome>().first.playerId;

  void setUpSession(int n) {
    s = Session(random: Random(1))..uljezTvReady = true;
    s.uljezPacks = [UljezPack('p', 'P', [for (var i = 0; i < 8; i++) WordPair('a$i', 'b$i')])];
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
  }

  test('a player is removed, told Kicked and the lobby updated; an unknown id is false', () {
    setUpSession(3);
    final id = idOf(ps[1]);
    expect(s.kickFromTv(id), isTrue);
    expect(ps[1].sent.whereType<Kicked>(), isNotEmpty);
    expect(s.players.any((p) => p.id == id), isFalse);
    expect(ps[0].last<LobbyState>()!.players.length, 2);
    expect(s.kickFromTv(id), isFalse);
    expect(s.kickFromTv(9999), isFalse);
    s.dispose();
  });

  test('the host can be kicked from the TV: the next player is host', () {
    setUpSession(3);
    final host = s.hostId!;
    expect(s.kickFromTv(host), isTrue);
    expect(s.hostId, isNot(host));
    expect(s.hostId, isNot(-1));
    expect(ps[0].sent.whereType<Kicked>(), isNotEmpty);
    s.dispose();
  });

  test('mid-game it clears the wait: a kicked Uljez speaker is skipped', () {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.uljez, null));
    final u = s.uljez!;
    final speaker = u.speaker!;
    expect(s.kickFromTv(speaker), isTrue);
    expect(u.alive.contains(speaker), isFalse);
    expect(u.speaker, isNot(speaker));
    s.dispose();
  });
}
