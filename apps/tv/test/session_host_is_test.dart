import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 45e: in a game the phones are told who the host is, on their own.
void main() {
  late Session s;
  late List<FakePeer> ps;
  int idOf(FakePeer p) => p.sent.whereType<Welcome>().first.playerId;

  void setUpSession(int n) {
    s = Session(random: Random(1))..uljezTvReady = true;
    s.uljezPacks = [UljezPack('p', 'P', [for (var i = 0; i < 8; i++) WordPair('a$i', 'b$i')])];
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
  }

  test('a TV kick of the host in a game tells every other phone who is host now', () {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.uljez, null));
    for (final p in ps) {
      expect(p.sent.whereType<HostIs>(), isEmpty, reason: 'nothing changed yet');
    }
    final old = s.hostId!;
    expect(s.kickFromTv(old), isTrue);
    final now = s.hostId!;
    expect(now, isNot(old));
    for (final p in ps.skip(1)) {
      expect(p.sent.whereType<HostIs>().last, HostIs(now), reason: 'player ${idOf(p)}');
    }
  });

  test('the host\'s phone dropping, and coming back, is told too', () async {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.uljez, null));
    final first = s.hostId!;
    ps[0].close();
    await Future<void>.delayed(Duration.zero);
    final second = s.hostId!;
    expect(second, isNot(first));
    expect(ps[1].sent.whereType<HostIs>().last, HostIs(second));
    expect(ps[2].sent.whereType<HostIs>().last, HostIs(second));
    final back = join(s, 'P0', token: 't0');
    expect(s.hostId, second, reason: 'in a game the role stays with whoever has it');
    final order = [for (final m in back.sent) m.type];
    expect(order.indexOf('lobby'), lessThan(order.indexOf('hostIs')), reason: 'a reconnecting phone gets it right after the lobby');
    expect(back.sent.whereType<HostIs>().last, HostIs(second));
    s.dispose();
  });

  test('in the lobby nothing extra is sent (the lobby state carries the host)', () async {
    setUpSession(3);
    ps[0].close(); // the host leaves in the lobby
    await Future<void>.delayed(Duration.zero);
    for (final p in ps) {
      expect(p.sent.whereType<HostIs>(), isEmpty);
    }
    s.dispose();
  });
}
