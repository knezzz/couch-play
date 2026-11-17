import 'dart:convert';
import 'dart:math';

import 'package:core/core.dart';
import 'package:tv/session/wolf_match.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/sound/sfx.dart';

/// Seven players, ids 1..7: 1 wolf, 2 wolf, 3 seer, 4 doctor, 5 hunter, 6 herbalist, 7 villager.
const roles7 = {
  1: WolfRole.wolf,
  2: WolfRole.wolf,
  3: WolfRole.seer,
  4: WolfRole.doc,
  5: WolfRole.hunter,
  6: WolfRole.herb,
  7: WolfRole.villager,
};

class Rig {
  Rig({Map<int, WolfRole> roles = roles7, bool hide = true, int seed = 1})
      : roles = roles {
    match = WolfMatch(
      ids: roles.keys.toList(),
      nameOf: (id) => 'P$id',
      settings: GameSettings(wolfHideRoles: hide),
      send: (id, m) => (sent[id] ??= []).add((at, m)),
      clock: () => at,
      random: Random(seed),
      fixedRoles: roles,
      sfx: sounds,
    )..start();
  }
  final Map<int, WolfRole> roles;
  late final WolfMatch match;
  final sent = <int, List<(Duration, Message)>>{};
  final played = <Sound>[];
  late final sounds = _Sfx(played);
  Duration at = Duration.zero;

  Future<void> wait(WidgetTester t, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await t.pump(const Duration(seconds: 1));
      at += const Duration(seconds: 1);
    }
  }

  List<Message> to(int id) => [for (final e in sent[id] ?? const <(Duration, Message)>[]) e.$2];
  void pickAll(Map<int, NightPick> picks) {
    for (final id in match.alive) {
      match.onNightPick(id, picks[id] ?? const NightPick(null));
    }
  }
}

class _Sfx implements Sfx {
  _Sfx(this.log);
  final List<Sound> log;
  @override
  void play(Sound s) => log.add(s);
}

Map<String, Object?> shape(Message m) => {
      'type': m.type,
      'keys': (m.toJson().keys.toList()..sort()),
      'text': m is NightPrompt ? m.text.length : (m is Morning ? m.text.length : 0),
      'picks': m is NightPrompt ? m.picks : 0,
      'lists2': m is NightPrompt ? m.choices2.isEmpty : null,
    };

void main() {
  testWidgets('night one: every alive phone gets the same message types, in the same order, with the same fields', (t) async {
    final r = Rig();
    r.pickAll({1: const NightPick(3), 2: const NightPick(3), 3: const NightPick(1), 4: const NightPick(3)});
    await r.wait(t, 4);
    final reference = [for (final m in r.to(1)) shape(m)];
    for (final id in r.roles.keys) {
      expect([for (final m in r.to(id)) shape(m)], reference, reason: 'player $id (${r.roles[id]}) differs from the wolf');
    }
    expect(reference.map((e) => e['type']).toSet(), containsAll(['role', 'night', 'morning']));
    r.match.dispose();
  });

  testWidgets('every night message has the same text length and the same two-pick shape on night 1', (t) async {
    final r = Rig();
    for (final id in r.roles.keys) {
      final p = r.to(id).whereType<NightPrompt>().first;
      expect(p.text.length, wolfTextWidth);
      expect(p.picks, 2, reason: 'night 1 has two picks on every phone');
      expect(p.choices2.isNotEmpty, isTrue);
      expect(p.choices.length, p.ids.length);
    }
    r.match.dispose();
  });

  testWidgets('no message to a phone names another player\'s role', (t) async {
    final r = Rig();
    r.pickAll({3: const NightPick(1)}); // the seer looks at a wolf: only the seer may hear it
    await r.wait(t, 4);
    for (final id in r.roles.keys) {
      for (final m in r.to(id)) {
        if (m is RoleMsg) {
          expect(m.role, r.roles[id], reason: 'the role message of $id carries its own role');
          if (!r.roles[id]!.isWolf) expect(m.mates, isEmpty);
        }
        if (id != 3) {
          expect(jsonEncode(m.toJson()).contains('Vukodlak'), isFalse, reason: 'player $id got the seer result');
        }
      }
    }
    final seen = r.to(3).whereType<Morning>().single.text;
    expect(seen.contains('Rezultat: P1 je Vukodlak.'), isTrue);
    r.match.dispose();
  });

  testWidgets('the pack knows the pack, nobody else does', (t) async {
    final r = Rig();
    expect(r.to(1).whereType<RoleMsg>().first.mates, [2]);
    expect(r.to(2).whereType<RoleMsg>().first.mates, [1]);
    expect(r.to(7).whereType<RoleMsg>().first.mates, isEmpty);
    r.match.dispose();
  });

  testWidgets('a pick by one wolf shows to the other wolf only, but every phone gets a fresh prompt', (t) async {
    final r = Rig();
    final before = {for (final id in r.roles.keys) id: r.to(id).length};
    r.match.onNightPick(1, const NightPick(7));
    for (final id in r.roles.keys) {
      expect(r.to(id).length, before[id]! + 1, reason: 'player $id gets one prompt');
      final p = r.to(id).last as NightPrompt;
      expect(p.text.contains('P1 → P7'), id == 2, reason: 'only the other wolf sees the pick: $id');
    }
    r.match.dispose();
  });

  testWidgets('lights: done at 3 s is still lit at 14 s and dark at 15 s', (t) async {
    final r = Rig();
    await r.wait(t, 3);
    r.match.onNightPick(7, const NightPick(null));
    expect(r.match.lit.contains(7), isTrue);
    await r.wait(t, 11); // 14 s
    expect(r.match.lit, r.match.alive.toSet(), reason: 'no light goes out before 15 s');
    await r.wait(t, 1); // 15 s
    expect(r.match.lit.contains(7), isFalse);
    expect(r.match.lit.length, 6);
    // after that, a finish darkens at once
    r.match.onNightPick(3, const NightPick(null));
    expect(r.match.lit.contains(3), isFalse);
    r.match.dispose();
  });

  testWidgets('the night ends when everybody is done, or after 60 s', (t) async {
    final r = Rig();
    r.pickAll({});
    expect(r.match.stage, WolfStage.dawn);
    final s = Rig(seed: 2);
    await s.wait(t, 59);
    expect(s.match.stage, WolfStage.night);
    await s.wait(t, 1);
    expect(s.match.stage, WolfStage.dawn);
    r.match.dispose();
    s.match.dispose();
  });

  testWidgets('a dead hunter and a dead villager look the same to the phones and the TV', (t) async {
    Future<Rig> killed(int victim) async {
      final r = Rig();
      r.pickAll({1: NightPick(victim), 2: NightPick(victim)});
      return r;
    }

    final h = await killed(5), v = await killed(7);
    await h.wait(t, 4);
    v.at = h.at;
    expect(h.match.stage, WolfStage.farewell);
    expect(v.match.stage, WolfStage.farewell);
    List<String> shapes(Rig r, int id) => [for (final e in r.sent[id]!) '${e.$1 - Duration.zero}-${e.$2.type}-${(e.$2.toJson()..remove('ids')).keys.length}'];
    // the dead one gets a Farewell window of the same length
    final fh = h.to(5).whereType<Farewell>().single, fv = v.to(7).whereType<Farewell>().single;
    expect(fh.seconds, fv.seconds);
    // nobody shoots: the window lasts the full time for both
    await h.wait(t, 13);
    v.at = h.at; // the two games share one fake clock
    expect(h.match.stage, WolfStage.farewell);
    expect(v.match.stage, WolfStage.farewell);
    await h.wait(t, 1);
    v.at = h.at;
    expect(h.match.stage, WolfStage.day);
    expect(v.match.stage, WolfStage.day);
    expect(shapes(h, 5).length, shapes(v, 7).length);
    expect([for (final m in h.to(5)) m.type], [for (final m in v.to(7)) m.type]);
    expect(h.match.story.map((e) => e.key).toList(), v.match.story.map((e) => e.key).toList());
    h.match.dispose();
    v.match.dispose();
  });

  testWidgets('a hunter who shoots: the shot is applied after the window, and the target gets a window too', (t) async {
    final r = Rig();
    r.pickAll({1: const NightPick(5), 2: const NightPick(5)});
    await r.wait(t, 4);
    r.match.onShoot(5, const Shoot(1));
    r.match.onShoot(7, const Shoot(2)); // a non-hunter's pick does nothing
    await r.wait(t, 15);
    expect(r.match.isAlive(1), isFalse);
    expect(r.match.isAlive(2), isTrue);
    expect(r.match.stage, WolfStage.farewell, reason: 'the shot victim has a window of their own');
    expect(r.to(1).whereType<Farewell>().length, 1);
    await r.wait(t, 15);
    expect(r.match.stage, WolfStage.day);
    r.match.dispose();
  });

  testWidgets('hidden roles: the TV getters and the story never show a role', (t) async {
    final r = Rig();
    r.pickAll({1: const NightPick(7), 2: const NightPick(7)});
    await r.wait(t, 4);
    for (final id in r.roles.keys) {
      expect(r.match.publicRole(id), isNull);
    }
    expect(r.match.story.any((e) => e.args.containsKey('role')), isFalse);
    expect(r.match.story.any((e) => e.key == 'wolvesLeft'), isFalse, reason: 'the count would show a wolf died');
    r.match.dispose();
  });

  testWidgets('roles shown: a dead player\'s role is in the story and getters, living ones stay hidden', (t) async {
    final r = Rig(hide: false);
    r.pickAll({1: const NightPick(7), 2: const NightPick(7)});
    await r.wait(t, 4);
    expect(r.match.publicRole(7), WolfRole.villager);
    expect(r.match.publicRole(3), isNull);
    expect(r.match.story.where((e) => e.key == 'morningDied').single.args['role'], 'villager');
    r.match.dispose();
  });

  testWidgets('reconnect: a phone gets its own state again and nothing of anyone else', (t) async {
    final r = Rig();
    r.pickAll({3: const NightPick(1)});
    await r.wait(t, 4);
    final seerBefore = r.to(3).length;
    r.match.rejoin(3);
    final again = r.to(3).skip(seerBefore).toList();
    expect(again.whereType<RoleMsg>().single.role, WolfRole.seer);
    expect(again.whereType<Morning>().single.text.contains('P1 je Vukodlak'), isTrue);
    final wolfBefore = r.to(1).length;
    r.match.rejoin(1);
    final wolf = r.to(1).skip(wolfBefore).toList();
    expect(wolf.map((m) => jsonEncode(m.toJson())).join().contains('Rezultat'), isFalse, reason: 'the wolf never gets the seer\'s result');
    expect(wolf.whereType<RoleMsg>().single.role, WolfRole.wolf);
    r.match.dispose();
  });

  testWidgets('reconnect during the night restores the phone\'s own picks', (t) async {
    final r = Rig();
    r.match.onNightPick(4, const NightPick(3, second: 5, special: true));
    r.match.rejoin(4);
    final p = r.to(4).whereType<NightPrompt>().last;
    expect(p.picked, 3);
    expect(p.picked2, 5);
    expect(p.special, isTrue);
    r.match.dispose();
  });

  testWidgets('a full day: morning, vote, the village wins by voting out the last wolf', (t) async {
    final r = Rig(roles: {1: WolfRole.wolf, 2: WolfRole.villager, 3: WolfRole.villager, 4: WolfRole.villager, 5: WolfRole.seer});
    r.pickAll({}); // a quiet night
    await r.wait(t, 4);
    expect(r.match.stage, WolfStage.day);
    expect(r.played, [Sound.nightAmbience, Sound.howl, Sound.rooster]);
    await r.wait(t, 120);
    expect(r.match.stage, WolfStage.vote);
    expect(r.played.last, Sound.voteBell);
    for (final id in [2, 3, 4, 5]) {
      r.match.onVote(id, const Vote(1));
    }
    r.match.onVote(1, const Vote(2));
    expect(r.match.stage, WolfStage.farewell, reason: 'the voted-out wolf gets the same window');
    await r.wait(t, 15);
    expect(r.match.winner, WolfWinner.village);
    expect(r.match.stage, WolfStage.over);
    for (final id in r.roles.keys) {
      expect(r.to(id).last, isA<WolfEnd>());
    }
    expect(r.to(2).whereType<WolfEnd>().single.roles[1], WolfRole.wolf);
    r.match.dispose();
  });

  testWidgets('a wrong or foreign pick, vote or shoot at the wrong time does nothing', (t) async {
    final r = Rig();
    r.match.onVote(3, const Vote(1)); // not the vote phase
    r.match.onShoot(5, const Shoot(1)); // not a farewell
    r.pickAll({});
    r.match.onNightPick(3, const NightPick(1)); // night is over
    expect(r.match.stage, WolfStage.dawn);
    r.match.dispose();
  });

  testWidgets('a sum answer, wrong or right, is just done', (t) async {
    final r = Rig();
    r.match.onNightPick(7, const NightPick(99));
    expect(r.match.game.done, {7});
    final p = r.to(7).whereType<NightPrompt>().last;
    expect(p.picked, isNull, reason: 'no pick is recorded for a sum');
    r.match.dispose();
  });
}
