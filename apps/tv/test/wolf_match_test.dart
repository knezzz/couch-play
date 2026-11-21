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
  /// [ready] false stays in the "Spreman" stage before night 1; by default
  /// everyone is ready at once, so the tests that follow start at night 1.
  Rig({Map<int, WolfRole> roles = roles7, bool hide = true, int seed = 1, bool ready = true})
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
    if (ready) {
      for (final id in roles.keys) {
        match.onReadyToPlay(id);
      }
    }
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

  /// Everyone connected and alive says "Idemo glasati".
  void allReady() {
    for (final id in match.alive) {
      match.onReady(id, const ReadyToVote(true));
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
      // Night 1's second list is not compared: only phones with a night action
      // have it now (Task 51; step 3 removes the second pick altogether).
      // From night 2 every phone has the same picks and lists.
      'picks': m is NightPrompt && m.night > 1 ? m.picks : 0,
      'lists2': m is NightPrompt && m.night > 1 ? m.choices2.isEmpty : null,
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

  testWidgets('every phone gets the same number of choices, in both lists, with 5, 7 and 8 alive', (t) async {
    final eight = {
      for (var i = 1; i <= 8; i++)
        i: const [
          WolfRole.wolf, WolfRole.wolf, WolfRole.seer, WolfRole.doc, WolfRole.cupid, WolfRole.herb, WolfRole.villager, WolfRole.hunter
        ][i - 1]
    };
    for (final n in [5, 7, 8]) {
      final r = Rig(roles: {for (final e in eight.entries.take(n)) e.key: e.value});
      for (final id in r.roles.keys) {
        final p = r.to(id).whereType<NightPrompt>().first;
        expect(p.choices.length, n, reason: 'player $id (${r.roles[id]}) of $n');
        expect(p.ids.length, n);
        // Night 1: the second list only for a role with a night action; one sum for the rest.
        final actor = r.match.game.hasNightAction(id);
        expect(p.choices2.length, actor ? n : 0);
        expect(p.ids2.length, actor ? n : 0);
        expect(p.picks, actor ? 2 : 1);
      }
      r.match.dispose();
    }
  });

  testWidgets('and the same on a later night after someone died', (t) async {
    final r = Rig();
    r.pickAll({1: const NightPick(7), 2: const NightPick(7)});
    await r.wait(t, 4 + 15);
    r.allReady();
    for (final id in r.match.alive) {
      r.match.onVote(id, const Vote(null));
    }
    final counts = {
      for (final id in r.match.alive) id: r.to(id).whereType<NightPrompt>().last.choices.length
    };
    expect(counts.values.toSet().length, 1, reason: '$counts');
    expect(counts.values.first, r.match.alive.length);
    r.match.dispose();
  });

  testWidgets('every night message has the same text length; a role with no night action has one sum, on night 1 too', (t) async {
    final r = Rig();
    for (final id in r.roles.keys) {
      final p = r.to(id).whereType<NightPrompt>().first;
      expect(p.text.length, wolfTextWidth);
      final actor = r.match.game.hasNightAction(id);
      expect(p.picks, actor ? 2 : 1, reason: 'player $id (${r.roles[id]})');
      expect(p.choices2.isNotEmpty, actor);
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

  testWidgets('the night ends when every living player is done, no clock; a sleeping phone is waited for, a kick moves on', (t) async {
    final r = Rig();
    r.pickAll({});
    expect(r.match.stage, WolfStage.dawn);
    final s = Rig(seed: 2);
    await s.wait(t, 3600);
    expect(s.match.stage, WolfStage.night, reason: 'an hour of waiting ends nothing');
    s.match.setAway(7, true);
    s.match.setAway(6, true);
    for (final id in [1, 2, 3, 4, 5]) {
      s.match.onNightPick(id, const NightPick(null));
    }
    await s.wait(t, 3600);
    expect(s.match.stage, WolfStage.night, reason: '6 and 7 sleep: the night waits for them');
    s.match.onNightPick(6, const NightPick(null));
    s.match.expel(7);
    expect(s.match.stage, WolfStage.dawn, reason: 'the kick cleared the last wait');
    r.match.dispose();
    s.match.dispose();
  });

  testWidgets('the day ends by the majority of the connected living, not by a clock; the toggle is day-only', (t) async {
    final r = Rig();
    // night: nothing for a phone to do with the toggle, and no VoteWish is sent
    r.match.onReady(1, const ReadyToVote(true));
    expect(r.match.wishCount, 0);
    expect(r.match.wishOpen, isFalse);
    r.pickAll({});
    await r.wait(t, 4);
    expect(r.match.stage, WolfStage.day);
    for (final id in r.roles.keys) {
      expect(r.to(id).whereType<VoteWish>().length, 1, reason: 'one at the start of the day, none at night');
    }
    expect(r.to(1).whereType<VoteWish>().single, const VoteWish(open: true, ready: false, want: 0, needed: 4));
    await r.wait(t, 3600);
    expect(r.match.stage, WolfStage.day, reason: 'no day timer');
    for (final id in [1, 2, 3]) {
      r.match.onReady(id, const ReadyToVote(true));
    }
    r.match.onReady(3, const ReadyToVote(true)); // double
    expect(r.match.wishCount, 3);
    expect(r.match.stage, WolfStage.day);
    r.match.onReady(3, const ReadyToVote(false)); // undo
    expect(r.match.wishCount, 2);
    r.match.onReady(3, const ReadyToVote(true));
    r.match.onReady(4, const ReadyToVote(true));
    expect(r.match.stage, WolfStage.vote, reason: '4 of 7');
    r.match.onReady(5, const ReadyToVote(true)); // too late
    expect(r.match.wishCount, 0);
    r.match.dispose();
  });

  testWidgets('day majority is over everyone still in, locked phones included; the dead cannot wish; a kick lowers the bar', (t) async {
    final r = Rig();
    r.pickAll({1: const NightPick(7), 2: const NightPick(7)});
    await r.wait(t, 4 + 15);
    expect(r.match.stage, WolfStage.day);
    expect(r.match.alive.length, 6);
    r.match.onReady(7, const ReadyToVote(true)); // dead
    expect(r.match.wishCount, 0);
    expect(r.match.wishNeeded, 4);
    for (final id in [3, 4, 5, 6]) {
      r.match.setAway(id, true); // four villagers' phones are locked
    }
    r.match.onReady(1, const ReadyToVote(true));
    r.match.onReady(2, const ReadyToVote(true));
    r.match.onReady(3, const ReadyToVote(true));
    expect(r.match.stage, WolfStage.day, reason: '3 of 6: the day is not decided over sleeping heads');
    r.match.setAway(3, false);
    r.match.expel(6);
    expect(r.match.wishNeeded, 3, reason: '5 left');
    expect(r.match.stage, WolfStage.vote, reason: '1, 2, 3 are 3 of the 5 left');
    r.match.dispose();
  });

  testWidgets('the vote waits for every living player who may vote, sleeping ones too; a kick clears the wait', (t) async {
    final r = Rig(roles: {1: WolfRole.wolf, 2: WolfRole.villager, 3: WolfRole.villager, 4: WolfRole.villager, 5: WolfRole.seer});
    r.pickAll({});
    await r.wait(t, 4);
    r.allReady();
    expect(r.match.stage, WolfStage.vote);
    await r.wait(t, 3600);
    expect(r.match.stage, WolfStage.vote);
    r.match.setAway(5, true);
    for (final id in [1, 2, 3, 4]) {
      r.match.onVote(id, const Vote(null));
    }
    await r.wait(t, 3600);
    expect(r.match.stage, WolfStage.vote, reason: '5 sleeps: not decided without them');
    r.match.expel(5);
    expect(r.match.stage, isNot(WolfStage.vote), reason: 'the kick cleared the wait');
    r.match.dispose();
  });

  testWidgets('nobody still in is connected: no clock, and after 10 minutes the match is given up once', (t) async {
    final r = Rig();
    var gaveUp = 0;
    r.match.onAbandon = () => gaveUp++;
    for (final id in r.roles.keys) {
      r.match.setAway(id, true);
    }
    await r.wait(t, 599);
    expect(gaveUp, 0);
    await r.wait(t, 1);
    expect(gaveUp, 1);
    await r.wait(t, 900);
    expect(gaveUp, 1);
    expect(r.match.stage, WolfStage.night);
    r.match.dispose();
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
    expect(r.match.stage, WolfStage.day, reason: 'the day has no clock');
    r.allReady();
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
    expect(p.picked, 99, reason: 'echoed like an actor\'s pick, so a reload looks the same');
    r.match.dispose();
  });

  testWidgets('a reload shows picks the same way for an actor and a sum phone', (t) async {
    final r = Rig();
    r.match.onNightPick(4, const NightPick(3, second: 5, special: true)); // the doctor
    r.match.onNightPick(7, const NightPick(2, second: 4, special: true)); // a villager with a sum
    for (final id in [4, 7]) {
      r.match.rejoin(id);
      final p = r.to(id).whereType<NightPrompt>().last;
      expect([p.picked != null, p.picked2 != null, p.special], [true, true, true], reason: 'player $id');
    }
    r.match.dispose();
  });

  testWidgets('a rejoin during the vote keeps the vote already cast', (t) async {
    final r = Rig(roles: {1: WolfRole.wolf, 2: WolfRole.villager, 3: WolfRole.villager, 4: WolfRole.villager, 5: WolfRole.seer});
    r.pickAll({});
    await r.wait(t, 4);
    r.allReady();
    expect(r.match.stage, WolfStage.vote);
    r.match.onVote(3, const Vote(1));
    r.match.rejoin(3);
    expect(r.to(3).whereType<VotePrompt>().last.picked, 1);
    expect(r.to(2).whereType<VotePrompt>().last.picked, isNull);
    r.match.dispose();
  });

  testWidgets('the longest hint (an alpha, two packmates, 16-letter names) is not cut', (t) async {
    final long = {for (var i = 1; i <= 6; i++) i: 'Abcdefghijklmnop'.replaceRange(0, 1, '${i}')};
    final roles = {1: WolfRole.alpha, 2: WolfRole.wolf, 3: WolfRole.wolf, 4: WolfRole.villager, 5: WolfRole.villager, 6: WolfRole.villager};
    final sent = <int, List<Message>>{};
    final m = WolfMatch(
      ids: roles.keys.toList(),
      nameOf: (id) => long[id]!,
      settings: const GameSettings(),
      send: (id, msg) => (sent[id] ??= []).add(msg),
      clock: () => Duration.zero,
      random: Random(1),
      fixedRoles: roles,
    )..start();
    for (final id in roles.keys) {
      m.onReadyToPlay(id);
    }
    m.onNightPick(2, const NightPick(4));
    m.onNightPick(3, const NightPick(5));
    final text = sent[1]!.whereType<NightPrompt>().last.text;
    expect(text.length, wolfTextWidth);
    expect(text.contains('${long[2]} → ${long[4]}'), isTrue);
    expect(text.contains('${long[3]} → ${long[5]}'), isTrue);
    expect(text.trimRight().endsWith('vukodlak.'), isTrue, reason: 'the alpha hint is whole: $text');
    m.dispose();
  });

  testWidgets('a kicked player is out at once; the night does not wait for them; no role is shown when hidden', (t) async {
    final r = Rig();
    for (final id in r.match.alive) {
      if (id != 6) r.match.onNightPick(id, const NightPick(null));
    }
    expect(r.match.stage, WolfStage.night, reason: 'waiting for 6');
    r.match.expel(6);
    expect(r.match.stage, WolfStage.dawn, reason: 'everyone else was done');
    expect(r.match.isAlive(6), isFalse);
    expect(r.match.story.where((e) => e.key == 'playerLeft').single.args.containsKey('role'), isFalse);
    expect(r.match.publicRole(6), isNull);
    r.match.dispose();
  });

  testWidgets('a kicked hunter takes no shot, and the match goes on', (t) async {
    final r = Rig();
    r.match.expel(5);
    expect(r.match.game.pendingHunters, isEmpty);
    r.pickAll({});
    await r.wait(t, 4);
    expect(r.match.stage, WolfStage.day);
    r.match.dispose();
  });

  testWidgets('roles shown: a kicked player\'s role is in the story', (t) async {
    final r = Rig(hide: false);
    r.match.expel(7);
    expect(r.match.story.where((e) => e.key == 'playerLeft').single.args['role'], 'villager');
    r.match.dispose();
  });

  testWidgets('no vote count anywhere: not in the story, not on any phone, whoever the mayor is', (t) async {
    final r = Rig(roles: {
      1: WolfRole.wolf, 2: WolfRole.mayor, 3: WolfRole.villager, 4: WolfRole.villager, 5: WolfRole.seer, 6: WolfRole.villager
    });
    r.pickAll({});
    await r.wait(t, 4);
    r.allReady();
    for (final id in r.match.alive) {
      r.match.onVote(id, Vote(id == 1 ? 2 : 1));
    }
    await r.wait(t, 20);
    for (final e in r.match.story) {
      expect(e.args.containsKey('votes'), isFalse, reason: '$e');
      expect(e.key, isNot('mayorBreaksTie'));
    }
    for (final id in r.roles.keys) {
      for (final m in r.to(id)) {
        final j = jsonEncode(m.toJson());
        expect(j.contains('votes'), isFalse, reason: j);
        expect(j.contains('tally'), isFalse);
      }
    }
    expect(r.match.lastOut, 1, reason: 'only who is out is public');
    r.match.dispose();
  });

  testWidgets('kick mid-night, then a pick: every phone keeps the same choice count and ids', (t) async {
    final r = Rig();
    final before = {for (final id in r.match.alive) id: r.to(id).whereType<NightPrompt>().last};
    r.match.expel(6);
    r.match.onNightPick(7, const NightPick(null));
    for (final id in r.match.alive) {
      final now = r.to(id).whereType<NightPrompt>().last;
      expect(now.choices.length, before[id]!.choices.length, reason: 'player $id (${r.roles[id]})');
      expect(now.ids, before[id]!.ids, reason: 'player $id');
      expect(now.choices2.length, before[id]!.choices2.length);
      expect(now.ids2, before[id]!.ids2);
    }
    // a reconnect shows the same list too
    r.match.rejoin(3);
    expect(r.to(3).whereType<NightPrompt>().last.ids, before[3]!.ids);
    r.match.dispose();
  });

  testWidgets('a pick on the kicked player is refused, not applied', (t) async {
    final r = Rig();
    r.match.expel(6);
    r.match.onNightPick(1, const NightPick(6));
    expect(r.match.game.pickOf(1), isNull);
    r.match.dispose();
  });

  testWidgets('kick during the vote: the vote list stays the same for a rejoin', (t) async {
    final r = Rig(roles: {1: WolfRole.wolf, 2: WolfRole.villager, 3: WolfRole.villager, 4: WolfRole.villager, 5: WolfRole.seer, 6: WolfRole.villager});
    r.pickAll({});
    await r.wait(t, 4);
    r.allReady();
    final first = r.to(3).whereType<VotePrompt>().last.ids;
    r.match.expel(6);
    r.match.rejoin(3);
    expect(r.to(3).whereType<VotePrompt>().last.ids, first);
    r.match.dispose();
  });

  testWidgets('nobody\'s vote is revealed: no event, no getter, no phone message shows who voted for whom', (t) async {
    final r = Rig(roles: {
      1: WolfRole.wolf, 2: WolfRole.mayor, 3: WolfRole.villager, 4: WolfRole.villager, 5: WolfRole.seer, 6: WolfRole.villager
    });
    r.pickAll({});
    await r.wait(t, 4);
    r.allReady();
    r.match.onVote(2, const Vote(1));
    r.match.onVote(3, const Vote(1));
    r.match.onVote(4, const Vote(5));
    expect(r.match.votedCount, 3);
    r.match.rejoin(3);
    r.match.rejoin(4);
    for (final id in r.roles.keys) {
      final own = {2: 1, 3: 1, 4: 5}[id];
      for (final p in r.to(id).whereType<VotePrompt>()) {
        expect(p.picked == null || p.picked == own, isTrue, reason: 'player $id sees only their own vote: ${p.picked}');
      }
    }
    for (final id in [5, 6, 1]) {
      r.match.onVote(id, Vote(id == 1 ? 2 : 1));
    }
    await r.wait(t, 1);
    expect(r.match.lastOut, 1);
    for (final e in r.match.story) {
      expect(e.args.keys.toSet().intersection({'voter', 'voters', 'votes', 'target', 'for'}), isEmpty, reason: '$e');
    }
    // the two free-text fields phones show as received never carry anyone's vote
    final voted = ['P2 → P1', 'P3 → P1', 'P4 → P5', 'P5 → P1', 'P6 → P1', 'P1 → P2'];
    for (final id in r.roles.keys) {
      for (final m in r.to(id)) {
        final text = m is Morning ? m.text : (m is NightPrompt ? m.text : '');
        for (final v in voted) {
          expect(text.contains(v), isFalse, reason: 'player $id: "$text"');
        }
      }
    }
    r.match.dispose();
  });

  testWidgets('a kick during the vote: those who voted for the kicked player still count as voted, and a kicked tramp does not win', (t) async {
    final r = Rig(roles: {1: WolfRole.wolf, 2: WolfRole.tramp, 3: WolfRole.villager, 4: WolfRole.villager, 5: WolfRole.seer, 6: WolfRole.villager});
    r.pickAll({});
    await r.wait(t, 4);
    r.allReady();
    for (final id in [1, 3, 4]) {
      r.match.onVote(id, const Vote(2));
    }
    expect(r.match.votedCount, 3);
    r.match.expel(2);
    expect(r.match.votedCount, 3, reason: 'the voters still count as voted');
    r.match.onVote(5, const Vote(2)); // a late vote for the kicked player is a skip
    expect(r.match.votedCount, 4);
    r.match.onVote(6, const Vote(null));
    await r.wait(t, 1);
    expect(r.match.winner, isNot(WolfWinner.tramp));
    expect(r.match.lastOut, isNull, reason: 'nobody is out of that vote');
    r.match.dispose();
  });

  testWidgets('a confirmed night answer is final, counts after a reload, and the reload says done the same for every role', (t) async {
    final r = Rig();
    // an actor (seer 3), a wolf (1) and a sum villager (7) confirm; then everybody reloads
    r.match.onNightPick(3, const NightPick(1));
    r.match.onNightPick(1, const NightPick(7));
    r.match.onNightPick(7, const NightPick(2));
    for (final id in [3, 1, 7]) {
      r.match.rejoin(id);
      final p = r.to(id).whereType<NightPrompt>().last;
      expect(p.done, isTrue, reason: 'player $id (${r.roles[id]}) must see Poslano');
      expect(p.picked, isNotNull, reason: 'its own choice is echoed for every role');
    }
    // a phone that did not confirm is not done
    r.match.rejoin(4);
    expect(r.to(4).whereType<NightPrompt>().last.done, isFalse);
    // a second confirm cannot change it
    r.match.onNightPick(3, const NightPick(2));
    r.match.onNightPick(1, const NightPick(2));
    expect(r.match.game.pickOf(3), 1);
    expect(r.match.game.pickOf(1), 7);
    r.match.rejoin(3);
    expect(r.to(3).whereType<NightPrompt>().last.picked, 1);
    // and the confirmed answer still counts when the night ends
    r.match.dispose();
  });

  testWidgets('the confirmed pick is used at the end of the night after the rejoin', (t) async {
    final r = Rig();
    r.match.onNightPick(1, const NightPick(7));
    r.match.onNightPick(2, const NightPick(7));
    r.match.rejoin(1);
    r.match.rejoin(2);
    r.match.onNightPick(1, const NightPick(6)); // too late to change
    for (final id in r.match.alive) {
      r.match.onNightPick(id, const NightPick(null));
    }
    expect(r.match.stage, WolfStage.dawn);
    expect(r.match.game.isAlive(7), isFalse, reason: 'the wolves\' confirmed pick killed 7');
    r.match.dispose();
  });

  testWidgets('the rejoin message has the same shape for every role (privacy)', (t) async {
    final r = Rig();
    for (final id in r.roles.keys) {
      r.match.onNightPick(id, const NightPick(null));
      if (!r.match.alive.contains(id)) break;
    }
    r.match.dispose();
    final s = Rig(seed: 5);
    for (final id in s.roles.keys) {
      s.match.onNightPick(id, id == 3 ? const NightPick(1) : const NightPick(2));
    }
    s.match.dispose();
    final q = Rig(seed: 6);
    q.match.onNightPick(1, const NightPick(7));
    q.match.onNightPick(7, const NightPick(7));
    q.match.rejoin(1);
    q.match.rejoin(7);
    List<String> keys(int id) => (q.to(id).whereType<NightPrompt>().last.toJson().keys.toList()..sort());
    expect(keys(1), keys(7));
    expect(q.to(1).whereType<NightPrompt>().last.text.length, q.to(7).whereType<NightPrompt>().last.text.length);
    q.match.dispose();
  });

  // ---- Task 51: role first, "Spreman" before night 1 ----

  testWidgets('no night until every living player is ready; the TV counts them', (t) async {
    final r = Rig(ready: false);
    final m = r.match;
    expect(m.stage, WolfStage.ready);
    expect((m.readyCount, m.readyTotal), (0, 7));
    for (final id in r.roles.keys) {
      expect(r.to(id).whereType<NightPrompt>(), isEmpty);
      expect(r.to(id).whereType<RoleMsg>().length, 1, reason: 'the role card is there from the start');
      expect(r.to(id).whereType<PlayWait>().last.ready, isFalse);
    }
    for (var id = 1; id <= 6; id++) {
      m.onReadyToPlay(id);
      m.onReadyToPlay(id); // pressing twice changes nothing
    }
    expect(m.stage, WolfStage.ready);
    expect(m.readyCount, 6);
    for (final id in r.roles.keys) {
      final w = r.to(id).whereType<PlayWait>().last;
      expect((w.count, w.total, w.ready), (6, 7, id <= 6), reason: 'player $id');
      expect(r.to(id).whereType<NightPrompt>(), isEmpty);
    }
    m.onReadyToPlay(7);
    expect(m.stage, WolfStage.night);
    for (final id in r.roles.keys) {
      expect(r.to(id).whereType<NightPrompt>().length, 1);
    }
    expect(m.story.last.key, 'firstNight');
    m.onReadyToPlay(1); // late: nothing happens, no new prompt
    expect(r.to(1).whereType<NightPrompt>().length, 1);
    m.dispose();
  });

  testWidgets('the host\'s kick of the one who is not ready starts night 1; a phone coming back gets its own wait state', (t) async {
    final r = Rig(ready: false);
    final m = r.match;
    for (var id = 1; id <= 6; id++) {
      m.onReadyToPlay(id);
    }
    m.rejoin(3);
    final w = r.to(3).whereType<PlayWait>().last;
    expect((w.ready, w.count, w.total), (true, 6, 7));
    m.rejoin(7);
    expect(r.to(7).whereType<PlayWait>().last.ready, isFalse);
    m.expel(7);
    expect(m.stage, WolfStage.night);
    expect(r.to(1).whereType<NightPrompt>().first.ids, isNot(contains(7)));
    m.dispose();
  });

  testWidgets('a kick of someone who was already ready lowers the total, and a sleeping phone is waited for', (t) async {
    final r = Rig(ready: false);
    final m = r.match;
    m.onReadyToPlay(1);
    m.setAway(6, true); // a locked phone is still waited for
    for (final id in [2, 3, 4, 5, 7]) {
      m.onReadyToPlay(id);
    }
    expect(m.stage, WolfStage.ready);
    m.expel(1);
    expect((m.readyCount, m.readyTotal), (5, 6));
    expect(m.stage, WolfStage.ready);
    m.expel(6);
    expect(m.stage, WolfStage.night);
    m.dispose();
  });

  testWidgets('one sum per night for a role with no night action, night 1 included; every phone has the same list length', (t) async {
    final r = Rig();
    for (var night = 1; night <= 2; night++) {
      if (night == 2) {
        r.pickAll({1: const NightPick(7), 2: const NightPick(7)});
        await r.wait(t, 4 + 15);
        r.allReady();
        for (final id in r.match.alive) {
          r.match.onVote(id, const Vote(null));
        }
        await r.wait(t, 20);
      }
      final p = r.to(5).whereType<NightPrompt>().last; // the hunter has no night action
      expect(p.night, night);
      expect(p.picks, 1, reason: 'night $night');
      expect(p.choices2, isEmpty);
      expect('×'.allMatches(p.text).length, 1, reason: 'one sum: ${p.text}');
      expect(p.choices.length, r.match.alive.length);
      expect(p.text.length, wolfTextWidth);
    }
    r.match.dispose();
  });
}
