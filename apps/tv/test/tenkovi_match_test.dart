import 'dart:convert';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/tenkovi_match.dart';
import 'package:tv/sound/sfx.dart';

class _Sfx implements Sfx {
  _Sfx(this.log);
  final List<Sound> log;
  @override
  void play(Sound s) => log.add(s);
}

class Rig {
  Rig({int n = 3, int rounds = 1, TenkoviMapPick map = TenkoviMapPick.earth, int seed = 1}) {
    match = TenkoviTvMatch(
      ids: [for (var i = 1; i <= n; i++) i],
      settings: GameSettings(tenkoviRounds: rounds, tenkoviMap: map),
      send: (id, m) => (sent[id] ??= []).add(m),
      random: Random(seed),
      sfx: _Sfx(played),
      onOver: (s) => result = s,
      breakTime: const Duration(seconds: 2),
    )..start();
  }
  late final TenkoviTvMatch match;
  final sent = <int, List<Message>>{};
  final played = <Sound>[];
  Map<int, int>? result;

  TenkoviTurn last(int id) => sent[id]!.whereType<TenkoviTurn>().last;

  /// Runs the volley to its end (at most 20 s of ticks).
  void fly() {
    for (var i = 0; i < 20 * 60 && match.stage == TenkoviStageTv.fly; i++) {
      match.tick();
    }
  }
}

const _up = TenkoviFire(90, 5, TenkoviShell.grenade);

void main() {
  testWidgets('every phone gets the same turn: the aim stage, wind, HP, ammo', (t) async {
    final r = Rig();
    for (final id in r.match.ids) {
      final m = r.last(id);
      expect([m.stage, m.round, m.rounds, m.hp, m.heavy, m.cluster, m.alive], ['aim', 1, 1, 100, true, true, true]);
      expect(m.map, TenkoviMap.earth);
      expect(m.wind, r.match.round.wind);
      expect([m.ready, m.total], [0, 3]);
      expect(m.sent, isNull);
    }
    r.match.dispose();
  });

  testWidgets('PRIVACY: before the volley no phone and no TV state shows anyone\'s aim', (t) async {
    final r = Rig();
    r.match.onFire(1, const TenkoviFire(137, 83, TenkoviShell.heavy));
    expect(r.match.stage, TenkoviStageTv.aim);
    expect(r.match.ready, {1}, reason: 'the TV sees a tick, nothing else');
    expect(r.match.round.projectiles, isEmpty);
    for (final id in [2, 3]) {
      final m = r.last(id);
      expect(m.sent, isNull, reason: 'phone $id gets no aim');
      expect(m.last, isNull);
      expect(m.ready, 1);
      final all = jsonEncode([for (final x in r.sent[id]!) x.toJson()]);
      expect(all.contains('137'), isFalse);
      expect(all.contains('[137'), isFalse);
      expect(all.contains(',83'), isFalse);
      expect(all.contains('"shell"'), isFalse, reason: 'a shell choice is not in any turn');
    }
    // The phone that fired gets its own aim back (a reload), and only that.
    expect(r.last(1).sent, [137, 83, TenkoviShell.heavy.index]);
    r.match.dispose();
  });

  testWidgets('every phone\'s turn has the same keys, whatever it holds', (t) async {
    final r = Rig();
    r.match.onFire(1, _up);
    final keys = {for (final id in [1, 2, 3]) r.last(id).toJson().keys.join(',')};
    expect(keys.length, 1);
    r.match.dispose();
  });

  testWidgets('the volley fires only when every connected living tank has pressed Pucaj', (t) async {
    final r = Rig();
    r.match.onFire(1, _up);
    r.match.onFire(2, _up);
    expect(r.match.stage, TenkoviStageTv.aim);
    expect(r.last(3).ready, 2);
    r.match.onFire(3, _up);
    expect(r.match.stage, TenkoviStageTv.fly);
    expect(r.match.round.projectiles.length, 3);
    expect(r.match.events.whereType<TkFired>().length, 3);
    r.match.dispose();
  });

  testWidgets('a disconnected tank is not waited for, and does not fire; it can come back', (t) async {
    final r = Rig();
    r.match.onFire(1, _up);
    r.match.setAway(3, true);
    expect(r.match.stage, TenkoviStageTv.aim);
    r.match.onFire(2, _up);
    expect(r.match.stage, TenkoviStageTv.fly);
    expect(r.match.round.projectiles.length, 2, reason: 'tank 3 stayed silent');
    r.fly();
    expect(r.match.stage, TenkoviStageTv.aim);
    r.match.setAway(3, false);
    r.match.rejoin(3);
    expect(r.last(3).stage, 'aim');
    expect(r.last(3).total, 3);
    r.match.dispose();
  });

  testWidgets('the last one to leave turns the volley loose when the others are ready', (t) async {
    final r = Rig();
    r.match.onFire(1, _up);
    r.match.onFire(2, _up);
    r.match.setAway(3, true);
    expect(r.match.stage, TenkoviStageTv.fly);
    r.match.dispose();
  });

  testWidgets('a second Pucaj and a used-up special shell are refused', (t) async {
    final r = Rig();
    r.match.onFire(1, const TenkoviFire(90, 5, TenkoviShell.heavy));
    r.match.onFire(1, const TenkoviFire(10, 10, TenkoviShell.grenade));
    expect(r.last(1).sent, [90, 5, TenkoviShell.heavy.index]);
    r.match.onFire(2, _up);
    r.match.onFire(3, _up);
    r.fly();
    expect(r.last(1).heavy, isFalse);
    r.match.onFire(1, const TenkoviFire(90, 5, TenkoviShell.heavy));
    expect(r.match.ready, isNot(contains(1)));
    r.match.dispose();
  });

  testWidgets('the phone keeps "Prošli put" for its own last volley, only', (t) async {
    final r = Rig();
    r.match.onFire(1, const TenkoviFire(120, 44, TenkoviShell.grenade));
    r.match.onFire(2, _up);
    r.match.onFire(3, _up);
    r.fly();
    if (r.match.stage == TenkoviStageTv.aim) {
      expect(r.last(1).last, [120, 44]);
      expect(r.last(2).last, [90, 5]);
      expect(r.last(1).sent, isNull, reason: 'a new turn: nothing pressed yet');
    }
    r.match.dispose();
  });

  testWidgets('a round ends at one tank: points, a break, then the next round', (t) async {
    final r = Rig(rounds: 2);
    // Take two tanks down to nothing so the next volley decides the round.
    r.match.round.tank(2).hp = 0;
    r.match.round.tank(3).hp = 0;
    r.match.round.outAt[2] = 0;
    r.match.round.outAt[3] = 0;
    r.match.onFire(1, _up);
    expect(r.match.stage, TenkoviStageTv.fly);
    r.fly();
    expect(r.match.stage, TenkoviStageTv.end);
    expect(r.match.lastWinner, isNotNull);
    expect(r.last(1).stage, 'end');
    expect(r.match.roundNo, 1);
    await t.pump(const Duration(seconds: 3));
    expect(r.match.stage, TenkoviStageTv.aim);
    expect(r.match.roundNo, 2);
    expect(r.last(1).hp, 100, reason: 'a fresh round');
    r.match.dispose();
  });

  testWidgets('the match ends after the set rounds and hands the scores to the session', (t) async {
    final r = Rig(rounds: 1);
    r.match.round.tank(2).hp = 0;
    r.match.round.tank(3).hp = 0;
    r.match.round.outAt[2] = 0;
    r.match.round.outAt[3] = 0;
    r.match.onFire(1, _up);
    r.fly();
    expect(r.result, isNull);
    await t.pump(const Duration(seconds: 3));
    expect(r.match.stage, TenkoviStageTv.over);
    expect(r.result, isNotNull);
    expect(r.result!.keys.toSet(), {1, 2, 3});
    r.match.dispose();
  });

  testWidgets('a map setting is honoured; Nasumično draws from all three', (t) async {
    expect(Rig(map: TenkoviMapPick.mars).match.round.map, TenkoviMap.mars);
    final seen = <TenkoviMap>{};
    for (var s = 0; s < 20; s++) {
      final r = Rig(map: TenkoviMapPick.random, seed: s);
      seen.add(r.match.round.map);
      r.match.dispose();
    }
    expect(seen.length, 3);
  });

  testWidgets('sounds: a blast and the round win play', (t) async {
    final r = Rig();
    r.match.onFire(1, _up);
    r.match.onFire(2, _up);
    r.match.onFire(3, _up);
    r.fly();
    expect(r.played, containsAll([Sound.cannon, Sound.blast]));
    r.match.dispose();
  });
}
