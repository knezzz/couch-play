import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show join;

/// "Always the same impostor": many games through the real Session path with
/// the unseeded Random the TV uses (main.dart makes Session() with no seed).
Session newSession(int n, List<dynamic> out) {
  final s = Session()..uljezTvReady = true;
  s.uljezPacks = [UljezPack('p', 'P', [for (var i = 0; i < 20; i++) WordPair('a$i', 'b$i')])];
  out.addAll([for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')]);
  return s;
}

void main() {
  test('Uljez: never last game\'s impostor, and the others are picked evenly', () {
    for (final n in [3, 4, 5, 6]) {
      final ps = <dynamic>[];
      final s = newSession(n, ps);
      const games = 1200;
      final count = <int, int>{};
      Set<int> last = {};
      for (var g = 0; g < games; g++) {
        ps[0].say(const StartGame(GameKind.uljez, null));
        expect(s.phase, Phase.uljez);
        final m = s.uljez!;
        final who = m.ids.where(m.game.isImpostor).toSet();
        expect(who.length, 1);
        expect(who.intersection(last), isEmpty, reason: 'n=$n game $g repeated $who');
        for (final id in who) {
          count[id] = (count[id] ?? 0) + 1;
        }
        last = who;
        s.returnToLobby();
      }
      final expected = games / n;
      for (final id in count.keys) {
        expect(count[id]!, inInclusiveRange(expected * 0.75, expected * 1.25), reason: 'n=$n counts=$count');
      }
      expect(count.length, n, reason: 'everybody is impostor sometimes');
      s.dispose();
    }
  });

  test('Uljez with 2 impostors (7 players): neither of last game\'s two', () {
    final ps = <dynamic>[];
    final s = newSession(7, ps);
    ps[0].say(const SetSettings(GameSettings(uljezImpostors: 2)));
    Set<int> last = {};
    for (var g = 0; g < 300; g++) {
      ps[0].say(const StartGame(GameKind.uljez, null));
      final m = s.uljez!;
      final who = m.ids.where(m.game.isImpostor).toSet();
      expect(who.length, 2);
      expect(who.intersection(last), isEmpty, reason: 'game $g repeated');
      last = who;
      s.returnToLobby();
    }
    s.dispose();
  });

  test('Uljez: when the others are too few the pick is plain random (the game still has its impostors)', () {
    final pack = UljezPack('p', 'P', [for (var i = 0; i < 8; i++) WordPair('a$i', 'b$i')]);
    final seen = <int>{};
    for (var k = 0; k < 100; k++) {
      final g = UljezGame([1, 2, 3], pack, avoid: {1, 2, 3});
      expect(g.ids.where(g.isImpostor).length, 1);
      seen.addAll(g.ids.where(g.isImpostor));
    }
    expect(seen, {1, 2, 3});
    // 2 impostors, only 1 other left: no way to avoid both, so plain random.
    final g = UljezGame([1, 2, 3, 4, 5, 6, 7], pack, impostors: 2, avoid: {1, 2, 3, 4, 5, 6});
    expect(g.ids.where(g.isImpostor).length, 2);
  });

  test('Uljez: a new session has no memory of the last one', () {
    final ps = <dynamic>[];
    var s = newSession(3, ps);
    ps[0].say(const StartGame(GameKind.uljez, null));
    s.returnToLobby();
    s.dispose();
    // A fresh session: over many first games each seat gets picked (nothing carried over).
    final first = <int>{};
    for (var k = 0; k < 60; k++) {
      final p = <dynamic>[];
      s = newSession(3, p);
      p[0].say(const StartGame(GameKind.uljez, null));
      first.addAll(s.uljez!.ids.where(s.uljez!.game.isImpostor));
      s.dispose();
    }
    expect(first.length, 3);
  });

  test('Vukodlak: the role deal gives each seat the wolf about equally often', () {
    final r = Random();
    for (final n in [4, 5, 6, 8]) {
      final count = List.filled(n, 0);
      const deals = 4000;
      for (var d = 0; d < deals; d++) {
        final roles = drawRoles(n, wolfSpecials.toSet(), r);
        for (var i = 0; i < n; i++) {
          if (roles[i] == WolfRole.wolf) count[i]++;
        }
      }
      final avg = count.reduce((a, b) => a + b) / n;
      for (final c in count) {
        expect(c, inInclusiveRange(avg * 0.85, avg * 1.15), reason: 'n=$n $count');
      }
    }
  });
}
