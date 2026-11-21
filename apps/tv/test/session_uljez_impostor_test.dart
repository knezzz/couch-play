import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show join;

/// "Always the same impostor": many games through the real Session path with
/// the unseeded Random the TV uses (main.dart makes Session() with no seed).
void main() {
  test('Uljez: the impostor is uniform over the players and independent of the last game', () {
    for (final n in [3, 4, 5, 6]) {
      final s = Session()..uljezTvReady = true;
      s.uljezPacks = [UljezPack('p', 'P', [for (var i = 0; i < 20; i++) WordPair('a$i', 'b$i')])];
      final ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
      const games = 1200;
      final count = <int, int>{};
      var same = 0;
      int? last;
      for (var g = 0; g < games; g++) {
        ps[0].say(const StartGame(GameKind.uljez, null));
        expect(s.phase, Phase.uljez);
        final m = s.uljez!;
        final who = m.ids.where(m.game.isImpostor).single;
        count[who] = (count[who] ?? 0) + 1;
        if (who == last) same++;
        last = who;
        s.returnToLobby();
      }
      final expected = games / n;
      for (final id in count.keys) {
        expect(count[id]!, inInclusiveRange(expected * 0.75, expected * 1.25), reason: 'n=$n counts=$count');
      }
      expect(count.length, n, reason: 'everybody is impostor sometimes');
      expect(same / (games - 1), inInclusiveRange(1 / n - 0.06, 1 / n + 0.06), reason: 'n=$n repeats $same');
      s.dispose();
    }
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
