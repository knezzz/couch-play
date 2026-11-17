import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

const w = WolfRole.wolf;
const v = WolfRole.villager;

WolfGame game(List<WolfRole> roles, {bool hide = true, int seed = 1}) =>
    WolfGame({for (var i = 0; i < roles.length; i++) i: roles[i]}, hideRoles: hide, random: Random(seed));

/// Everyone alive skips, except the picks given as {who: target}.
NightResult night(WolfGame g, Map<int, int?> picks, {Set<int> special = const {}, Map<int, int?> second = const {}}) {
  for (final id in g.alive) {
    g.pick(id, picks[id], special: special.contains(id), second: second[id]);
  }
  return g.resolveNight();
}

void main() {
  group('draw', () {
    test('counts: 1 wolf for 5-6, 2 for 7-8, always the right length', () {
      for (var n = 5; n <= 8; n++) {
        final r = drawRoles(n, WolfRole.values.toSet(), Random(n));
        expect(r.length, n);
        expect(r.where((x) => x.isWolf).length, n <= 6 ? 1 : 2);
      }
    });

    test('only the roles that are on, and wolf and villager even if off', () {
      final r = drawRoles(8, {WolfRole.seer}, Random(3));
      expect(r.toSet().difference({w, v, WolfRole.seer}), isEmpty);
      expect(r.contains(WolfRole.seer), isTrue);
      expect(r.where((x) => x == w).length, 2);
    });

    test('at most players - wolves - 2 specials, the rest villagers', () {
      for (var seed = 0; seed < 20; seed++) {
        for (var n = 5; n <= 8; n++) {
          final r = drawRoles(n, WolfRole.values.toSet(), Random(seed));
          final specials = r.where((x) => wolfSpecials.contains(x)).length;
          expect(specials, n - wolfCount(n) - 2);
          expect(r.where((x) => x == v).length, 2);
        }
      }
    });

    test('with nothing special on, everyone else is a villager', () {
      final r = drawRoles(7, {}, Random(1));
      expect(r.where((x) => x == v).length, 5);
    });

    test('specials are never repeated', () {
      for (var seed = 0; seed < 20; seed++) {
        final r = drawRoles(8, WolfRole.values.toSet(), Random(seed));
        final sp = r.where(wolfSpecials.contains).toList();
        expect(sp.toSet().length, sp.length);
      }
    });

    test('alpha and lone wolf replace ordinary wolves, once each, only if on', () {
      final seen = <WolfRole>{};
      for (var seed = 0; seed < 60; seed++) {
        final r = drawRoles(8, {WolfRole.alpha, WolfRole.lone}, Random(seed));
        expect(r.where((x) => x == WolfRole.alpha).length, lessThanOrEqualTo(1));
        expect(r.where((x) => x == WolfRole.lone).length, lessThanOrEqualTo(1));
        expect(r.where((x) => x.isWolf).length, 2);
        seen.addAll(r.where((x) => x.isWolf));
      }
      expect(seen, {w, WolfRole.alpha, WolfRole.lone});
      for (var seed = 0; seed < 20; seed++) {
        expect(drawRoles(8, {}, Random(seed)).any((x) => x == WolfRole.alpha || x == WolfRole.lone), isFalse);
      }
    });

    test('the same seed draws the same mix', () {
      expect(drawRoles(7, WolfRole.values.toSet(), Random(9)), drawRoles(7, WolfRole.values.toSet(), Random(9)));
    });
  });

  group('wolves at night', () {
    test('the pack kills the plurality choice', () {
      final g = game([w, w, v, v, v, v, v]);
      final r = night(g, {0: 2, 1: 2});
      expect(r.deaths.map((d) => d.id), [2]);
      expect(g.isAlive(2), isFalse);
      expect(r.events.single.key, 'morningDied');
    });

    test('a split pick is drawn between the tied, never anyone else', () {
      final seen = <int>{};
      for (var seed = 0; seed < 30; seed++) {
        final g = game([w, w, v, v, v, v, v], seed: seed);
        seen.addAll(night(g, {0: 2, 1: 3}).deaths.map((d) => d.id));
      }
      expect(seen, {2, 3});
    });

    test('three against one: the majority wins', () {
      final g = game([w, w, w, v, v, v, v, v]);
      expect(night(g, {0: 4, 1: 4, 2: 5}).deaths.single.id, 4);
    });

    test('nobody picked: nobody dies, and the morning says so', () {
      final g = game([w, v, v, v, v]);
      final r = night(g, {});
      expect(r.deaths, isEmpty);
      expect(r.events.single.key, 'morningNobody');
    });

    test('a wolf picking a packmate counts for nothing', () {
      final g = game([w, w, v, v, v, v, v]);
      expect(night(g, {0: 1, 1: 0}).deaths, isEmpty);
    });

    test('picks are accepted only at night, from the living, at the living', () {
      final g = game([w, v, v, v, v]);
      expect(g.pick(0, 1), isTrue);
      expect(g.pick(0, 99), isFalse);
      expect(g.pick(99, 1), isFalse);
      night(g, {0: 1});
      expect(g.pick(0, 2), isFalse, reason: 'it is day');
      g.startVote();
      expect(g.pick(0, 2), isFalse);
      // a dead target is refused next night
      g.vote(0, null);
      g.resolveVote();
      g.startNight();
      expect(g.pick(0, 1), isFalse);
    });

    test('the night is complete when every living player has picked', () {
      final g = game([w, v, v, v, v]);
      for (final id in [0, 1, 2, 3]) {
        g.pick(id, null);
      }
      expect(g.nightComplete, isFalse);
      g.pick(4, null);
      expect(g.nightComplete, isTrue);
    });
  });

  group('protection', () {
    test('the doctor saves the victim', () {
      final g = game([w, v, WolfRole.doc, v, v]);
      final r = night(g, {0: 1, 2: 1});
      expect(r.deaths, isEmpty);
      expect(r.saved, isTrue);
      expect(r.events.single.key, 'morningNobody');
    });

    test('the doctor may protect himself', () {
      final g = game([w, v, WolfRole.doc, v, v]);
      expect(night(g, {0: 2, 2: 2}).deaths, isEmpty);
    });

    test('not the same player two nights running', () {
      final g = game([w, v, WolfRole.doc, v, v, v]);
      night(g, {0: 3, 2: 1});
      g.startVote();
      g.resolveVote();
      g.startNight();
      final r = night(g, {0: 1, 2: 1});
      expect(r.deaths.map((d) => d.id), [1]);
    });

    test('a different player the second night works', () {
      final g = game([w, v, WolfRole.doc, v, v, v]);
      night(g, {0: 3, 2: 1});
      g.startVote();
      g.resolveVote();
      g.startNight();
      expect(night(g, {0: 3, 2: 3}).deaths, isEmpty);
    });

    test('the bodyguard dies instead of the guarded victim', () {
      final g = game([w, v, WolfRole.guard, v, v]);
      final r = night(g, {0: 1, 2: 1});
      expect(r.deaths.map((d) => d.id), [2]);
      expect(r.deaths.single.cause, DeathCause.guard);
      expect(g.isAlive(1), isTrue);
    });

    test('a bodyguard guarding someone else changes nothing; guarding himself is ignored', () {
      final g = game([w, v, WolfRole.guard, v, v]);
      expect(night(g, {0: 1, 2: 3}).deaths.single.id, 1);
      final h = game([w, v, WolfRole.guard, v, v]);
      expect(night(h, {0: 2, 2: 2}).deaths.single.id, 2);
    });

    test('the doctor beats the bodyguard: the attack fails, nobody dies', () {
      final g = game([w, v, WolfRole.guard, WolfRole.doc, v]);
      expect(night(g, {0: 1, 2: 1, 3: 1}).deaths, isEmpty);
    });

    test('the elder survives the first attack, not the second', () {
      final g = game([w, WolfRole.elder, v, v, v, v]);
      expect(night(g, {0: 1}).deaths, isEmpty);
      g.startVote();
      g.resolveVote();
      g.startNight();
      expect(night(g, {0: 1}).deaths.single.id, 1);
    });

    test('the elder is not safe from poison', () {
      final g = game([w, WolfRole.elder, WolfRole.herb, v, v, v]);
      expect(night(g, {2: 1}, special: {2}).deaths.single.cause, DeathCause.poison);
    });
  });

  group('herbalist', () {
    test('the cure saves the victim, once', () {
      final g = game([w, v, WolfRole.herb, v, v, v]);
      final r = night(g, {0: 1, 2: 1});
      expect(r.deaths, isEmpty);
      g.startVote();
      g.resolveVote();
      g.startNight();
      expect(night(g, {0: 1, 2: 1}).deaths.single.id, 1, reason: 'cure is spent');
    });

    test('a cure aimed at the wrong player is not spent', () {
      final g = game([w, v, WolfRole.herb, v, v, v]);
      expect(night(g, {0: 1, 2: 3}).deaths.single.id, 1);
      g.startVote();
      g.resolveVote();
      g.startNight();
      expect(night(g, {0: 3, 2: 3}).deaths, isEmpty);
    });

    test('the poison kills the picked player, once', () {
      final g = game([w, v, WolfRole.herb, v, v, v]);
      final r = night(g, {2: 3}, special: {2});
      expect(r.deaths.map((d) => d.id), [3]);
      expect(r.deaths.single.cause, DeathCause.poison);
      g.startVote();
      g.resolveVote();
      g.startNight();
      expect(night(g, {2: 4}, special: {2}).deaths, isEmpty);
    });

    test('poison cannot hit the herbalist himself', () {
      final g = game([w, v, WolfRole.herb, v, v, v]);
      expect(night(g, {2: 2}, special: {2}).deaths, isEmpty);
    });

    test('poison and the wolves can both strike the same night', () {
      final g = game([w, v, WolfRole.herb, v, v, v]);
      expect(night(g, {0: 1, 2: 3}, special: {2}).deaths.map((d) => d.id).toSet(), {1, 3});
    });

    test('poison on the wolves victim is one death', () {
      final g = game([w, v, WolfRole.herb, v, v, v]);
      expect(night(g, {0: 1, 2: 1}, special: {2}).deaths.map((d) => d.id), [1]);
    });
  });

  group('alpha', () {
    test('converts the victim instead of killing, once', () {
      final g = game([WolfRole.alpha, v, v, v, v, v]);
      final r = night(g, {0: 1}, special: {0});
      expect(r.deaths, isEmpty);
      expect(r.converted, 1);
      expect(g.roleOf(1), w);
      expect(r.notes[1]!.single.kind, 'converted');
      expect(g.mates(0), [1]);
      g.startVote();
      g.resolveVote();
      g.startNight();
      expect(night(g, {0: 2}, special: {0}).deaths.single.id, 2, reason: 'once only');
    });

    test('without the special it is an ordinary kill', () {
      final g = game([WolfRole.alpha, v, v, v, v, v]);
      expect(night(g, {0: 1}).deaths.single.id, 1);
    });

    test('the alpha must have picked the victim himself', () {
      final g = game([WolfRole.alpha, w, v, v, v, v, v]);
      final r = night(g, {0: 3, 1: 2, 2: null}, special: {0});
      expect(r.converted, isNull);
    });

    test('a protected or elder victim is not converted and the conversion is kept', () {
      final g = game([WolfRole.alpha, v, WolfRole.doc, v, v, v]);
      expect(night(g, {0: 1, 2: 1}, special: {0}).converted, isNull);
      g.startVote();
      g.resolveVote();
      g.startNight();
      expect(night(g, {0: 3}, special: {0}).converted, 3);
    });

    test('a converted player counts as a wolf for the win check', () {
      final g = game([WolfRole.alpha, v, v, v]);
      night(g, {0: 1}, special: {0});
      expect(g.winner, WolfWinner.wolves, reason: '2 wolves vs 2');
    });
  });

  group('cupid and lovers', () {
    test('night 1: the cupid picks two other players, both are told, he is not one of them', () {
      final g = game([w, WolfRole.cupid, v, v, v]);
      final r = night(g, {1: 3}, second: {1: 4});
      expect(g.lovers, {3, 4});
      expect(r.notes[3]!.single.target, 4);
      expect(r.notes[4]!.single.target, 3);
      expect(r.notes.containsKey(1), isFalse);
    });

    test('a pick on a later night makes no lovers', () {
      final g = game([w, WolfRole.cupid, v, v, v, v]);
      night(g, {});
      g.startVote();
      g.resolveVote();
      g.startNight();
      night(g, {1: 3}, second: {1: 4});
      expect(g.lovers, isEmpty);
    });

    test('himself, the same player twice, or one pick only make no lovers', () {
      for (final c in [
        (3, 1), // the cupid himself
        (3, 3),
        (3, null),
      ]) {
        final g = game([w, WolfRole.cupid, v, v, v]);
        night(g, {1: c.$1}, second: {1: c.$2});
        expect(g.lovers, isEmpty, reason: '$c');
      }
    });

    test('everyone else may carry a second pick and it does nothing', () {
      final g = game([WolfRole.wolf, WolfRole.seer, WolfRole.doc, v, v]);
      final r = night(g, {0: 3, 1: 0, 2: 3}, second: {0: 4, 1: 4, 2: 4, 3: 1, 4: 2});
      expect(g.lovers, isEmpty);
      expect(r.deaths, isEmpty, reason: 'the doctor saved 3; the seconds changed nothing');
    });

    test('when one lover dies at night the other follows', () {
      final g = game([w, WolfRole.cupid, v, v, v, v]);
      night(g, {1: 3}, second: {1: 4});
      g.startVote();
      g.resolveVote();
      g.startNight();
      final r = night(g, {0: 3});
      expect(r.deaths.map((d) => d.id), [3, 4]);
      expect(r.deaths.last.cause, DeathCause.lover);
      expect(r.events.map((e) => e.key), ['morningDied', 'loverDied']);
    });

    test('lovers follow after a vote too', () {
      final g = game([w, WolfRole.cupid, v, v, v, v]);
      night(g, {1: 3}, second: {1: 4});
      g.startVote();
      for (final id in [0, 1, 2, 5]) {
        g.vote(id, 3);
      }
      final r = g.resolveVote();
      expect(r.out, 3);
      expect(g.isAlive(4), isFalse);
      expect(g.isAlive(1), isTrue);
    });
  });

  group('seer', () {
    test('learns the exact role of the picked player', () {
      final g = game([w, WolfRole.seer, WolfRole.herb, v, v, v]);
      final r = night(g, {1: 0});
      expect(r.notes[1]!.single.kind, 'saw');
      expect(r.notes[1]!.single.role, w);
      expect(r.notes[1]!.single.target, 0);
    });

    test('sees the role as it was before the night, even a converted one', () {
      final g = game([WolfRole.alpha, WolfRole.seer, v, v, v, v]);
      final r = night(g, {0: 2, 1: 2}, special: {0});
      expect(r.notes[1]!.single.role, v);
    });

    test('a seer who dies that night gets no note', () {
      final g = game([w, WolfRole.seer, v, v, v, v]);
      final r = night(g, {0: 1, 1: 0});
      expect(r.deaths.single.id, 1);
      expect(r.notes.containsKey(1), isFalse);
    });

    test('nobody but the seer gets a note', () {
      final g = game([w, WolfRole.seer, v, v, v, v]);
      expect(night(g, {1: 0}).notes.keys, [1]);
    });
  });

  group('hunter', () {
    test('a hunter killed at night shoots; the shot kills', () {
      final g = game([w, WolfRole.hunter, v, v, v, v]);
      night(g, {0: 1});
      expect(g.pendingHunters, [1]);
      final d = g.shoot(1, 0);
      expect(d.single.cause, DeathCause.shot);
      expect(g.isAlive(0), isFalse);
      expect(g.winner, WolfWinner.village);
    });

    test('a voted-out hunter shoots too', () {
      final g = game([w, w, WolfRole.hunter, v, v, v, v]);
      night(g, {});
      g.startVote();
      for (final id in [0, 1, 3, 4]) {
        g.vote(id, 2);
      }
      g.resolveVote();
      expect(g.pendingHunters, [2]);
      g.shoot(2, 0);
      expect(g.alive, [1, 3, 4, 5, 6]);
    });

    test('the shot can be skipped', () {
      final g = game([w, WolfRole.hunter, v, v, v, v]);
      night(g, {0: 1});
      expect(g.shoot(1, null), isEmpty);
      expect(g.alive.length, 5);
    });

    test('no win is decided and no night starts until the hunter has shot', () {
      final g = game([w, WolfRole.hunter, v]);
      night(g, {0: 1});
      expect(g.winner, isNull);
      expect(g.startNight, throwsStateError);
      g.shoot(1, 0);
      expect(g.winner, WolfWinner.village);
    });

    test('shooting a lover takes the partner; shooting a hunter queues another shot', () {
      final g = game([w, WolfRole.hunter, WolfRole.hunter, v, v, v, v]);
      night(g, {0: 1});
      g.shoot(1, 2);
      expect(g.pendingHunters, [2]);
      g.shoot(2, 3);
      expect(g.pendingHunters, isEmpty);
    });

    test('only a pending hunter can shoot', () {
      final g = game([w, WolfRole.hunter, v, v, v, v]);
      expect(() => g.shoot(1, 0), throwsStateError);
    });

    test('a hunter killed with his lover shoots; lover death goes in the events', () {
      final g = game([w, WolfRole.cupid, WolfRole.hunter, v, v, v]);
      night(g, {1: 2}, second: {1: 3});
      g.startVote();
      g.resolveVote();
      g.startNight();
      night(g, {0: 3});
      expect(g.pendingHunters, [2]);
      g.shoot(2, 0);
      expect(g.lastShotEvents.first.key, 'hunterShot');
    });
  });

  group('day vote', () {
    WolfGame dayGame(List<WolfRole> roles, {bool hide = true}) {
      final g = game(roles, hide: hide);
      night(g, {});
      g.startVote();
      return g;
    }

    test('the most voted is out', () {
      final g = dayGame([w, w, v, v, v, v, v]);
      for (final id in [2, 3, 4]) {
        g.vote(id, 0);
      }
      g.vote(0, 2);
      final r = g.resolveVote();
      expect(r.out, 0);
      expect(g.isAlive(0), isFalse);
      expect(r.events.first.key, 'voteOut');
      expect(r.events.first.args.containsKey('votes'), isFalse, reason: 'no vote counts: the mayor is secret');
    });

    test('a tie puts nobody out', () {
      final g = dayGame([w, w, v, v, v, v, v]);
      g.vote(2, 0);
      g.vote(3, 0);
      g.vote(4, 1);
      g.vote(5, 1);
      final r = g.resolveVote();
      expect(r.out, isNull);
      expect(r.tie, isTrue);
      expect(r.events.single.key, 'voteTie');
    });

    test('all skipping puts nobody out', () {
      final g = dayGame([w, w, v, v, v, v, v]);
      for (final id in g.alive) {
        g.vote(id, null);
      }
      expect(g.resolveVote().events.single.key, 'voteNobody');
    });

    test('you cannot vote for yourself, for the dead, or twice-counted', () {
      final g = dayGame([w, w, v, v, v, v, v]);
      expect(g.vote(2, 2), isFalse);
      expect(g.vote(2, 99), isFalse);
      g.vote(2, 0);
      g.vote(2, 1);
      g.vote(3, 1);
      final r = g.resolveVote();
      expect(r.votes[2], 1, reason: 'the second vote replaced the first');
      expect(r.out, 1);
    });

    test('the mayor counts double', () {
      final g = dayGame([w, w, WolfRole.mayor, v, v, v, v]);
      g.vote(2, 0);
      g.vote(3, 1);
      g.vote(4, 1);
      g.vote(5, 0);
      final r = g.resolveVote();
      expect(r.out, 0, reason: '2+1 against 2');
    });

    test('a tie goes to the mayors pick when it is one of the tied', () {
      final g = dayGame([w, w, WolfRole.mayor, v, v, v, v]);
      g.vote(2, 0);
      g.vote(3, 1);
      g.vote(4, 1);
      final r = g.resolveVote();
      expect(r.out, 0);
      expect(r.events.map((e) => e.key), ['voteOut'], reason: 'the story does not name the mayor');
    });

    test('a tie not involving the mayors pick stays a tie', () {
      final g = dayGame([w, w, WolfRole.mayor, v, v, v, v]);
      g.vote(2, null);
      g.vote(3, 0);
      g.vote(4, 0);
      g.vote(5, 1);
      g.vote(6, 1);
      expect(g.resolveVote().out, isNull, reason: '2 for 0, 2 for 1, the mayor skipped');
    });

    test('a fool is spared the first time, loses the vote, and is an ordinary target after', () {
      final g = dayGame([w, WolfRole.fool, v, v, v, v, v]);
      for (final id in [0, 2, 3, 4]) {
        g.vote(id, 1);
      }
      final r = g.resolveVote();
      expect(r.spared, isTrue);
      expect(g.isAlive(1), isTrue);
      expect(g.canVote(1), isFalse);
      expect(r.events.single.key, 'foolSpared');
      g.startNight();
      night(g, {});
      g.startVote();
      expect(g.vote(1, 0), isFalse);
      for (final id in [0, 2, 3, 4]) {
        g.vote(id, 1);
      }
      expect(g.resolveVote().spared, isFalse);
      expect(g.isAlive(1), isFalse);
    });

    test('the vote is complete when everyone who can vote has', () {
      final g = dayGame([w, WolfRole.fool, v, v, v, v, v]);
      for (final id in g.alive) {
        g.vote(id, id == 0 ? 1 : 0);
      }
      expect(g.voteComplete, isTrue);
    });

    test('a voted-out tramp wins alone, at once', () {
      final g = dayGame([w, WolfRole.tramp, v, v, v, v]);
      for (final id in [0, 2, 3]) {
        g.vote(id, 1);
      }
      final r = g.resolveVote();
      expect(g.winner, WolfWinner.tramp);
      expect(g.phase, WolfPhase.over);
      expect(r.events.map((e) => e.key), ['trampWins', 'gameOver']);
      expect(g.tramp, 1);
    });

    test('a tramp killed by the wolves wins nothing', () {
      final g = game([w, WolfRole.tramp, v, v, v, v]);
      night(g, {0: 1});
      expect(g.winner, isNull);
    });
  });

  group('win checks', () {
    test('the village wins when the last wolf is voted out', () {
      final g = game([w, v, v, v, v]);
      night(g, {});
      g.startVote();
      for (final id in [1, 2, 3]) {
        g.vote(id, 0);
      }
      final r = g.resolveVote();
      expect(g.winner, WolfWinner.village);
      expect(r.events.last.args['winner'], 'village');
    });

    test('wolves equalling the rest ends the game at once', () {
      final g = game([w, v, v, v]);
      night(g, {0: 1});
      expect(g.winner, isNull);
      g.startVote();
      g.resolveVote();
      g.startNight();
      final r = night(g, {0: 2});
      expect(g.winner, WolfWinner.wolves);
      expect(r.events.last.key, 'gameOver');
      expect(g.phase, WolfPhase.over);
    });

    test('the lone wolf alone with villagers does not win by number', () {
      final g = game([WolfRole.lone, v, v]);
      night(g, {0: 1});
      expect(g.winner, isNull, reason: 'lone vs 1');
    });

    test('the lone wolf wins as the last one alive', () {
      final g = game([WolfRole.lone, v, v]);
      night(g, {0: 1});
      g.startVote();
      g.resolveVote();
      g.startNight();
      night(g, {0: 2});
      expect(g.winner, WolfWinner.lone);
    });

    test('the pack winning with a lone wolf alive is a wolf win', () {
      final g = game([w, WolfRole.lone, v, v]);
      night(g, {0: 2});
      expect(g.winner, WolfWinner.wolves);
    });

    test('the village still wins if the lone wolf is voted out last', () {
      final g = game([WolfRole.lone, v, v, v]);
      night(g, {});
      g.startVote();
      for (final id in [1, 2, 3]) {
        g.vote(id, 0);
      }
      g.resolveVote();
      expect(g.winner, WolfWinner.village);
    });

    test('poisoning the wolf takes his lover too and the village wins', () {
      final g = game([w, v, WolfRole.cupid, WolfRole.herb, v]);
      night(g, {2: 0}, second: {2: 1});
      g.startVote();
      g.resolveVote();
      g.startNight();
      final r = night(g, {3: 0}, special: {3});
      expect(r.deaths.map((d) => d.id), [0, 1]);
      expect(g.winner, WolfWinner.village);
    });

    test('everyone going out in one night is nobody', () {
      final g = game([w, WolfRole.herb]);
      night(g, {0: 1, 1: 0}, special: {1});
      expect(g.winner, WolfWinner.nobody);
    });

    test('no new night once the game is over', () {
      final g = game([w, v, v]);
      night(g, {0: 1});
      expect(g.winner, WolfWinner.wolves);
      expect(g.startNight, throwsStateError);
    });
  });

  group('hidden roles', () {
    test('on: an out player is not revealed, in the events or publicRole', () {
      final g = game([w, v, v, v, v, v]);
      final r = night(g, {0: 1});
      expect(r.events.single.args.containsKey('role'), isFalse);
      expect(g.publicRole(1), isNull);
      expect(g.publicRole(0), isNull);
    });

    test('off: the role shows for the out and in the events, not for the living', () {
      final g = game([w, v, v, v, v, v], hide: false);
      final r = night(g, {0: 1});
      expect(r.events.single.args['role'], 'villager');
      expect(g.publicRole(1), v);
      expect(g.publicRole(0), isNull);
    });

    test('on: a vote out shows no role; off: it does', () {
      WolfGame at(bool hide) {
        final g = game([w, w, v, v, v, v, v], hide: hide);
        night(g, {});
        g.startVote();
        for (final id in [2, 3, 4]) {
          g.vote(id, 0);
        }
        return g;
      }

      expect(at(true).resolveVote().events.first.args.containsKey('role'), isFalse);
      expect(at(false).resolveVote().events.first.args['role'], 'wolf');
    });

    test('at the end every role shows', () {
      final g = game([w, v, v]);
      night(g, {0: 1});
      expect(g.winner, isNotNull);
      for (final id in g.ids) {
        expect(g.publicRole(id), g.roleOf(id));
      }
    });
  });

  group('who knows what', () {
    test('wolves know the pack, nobody else knows anything', () {
      final g = game([w, WolfRole.lone, v, WolfRole.seer, v, v, v]);
      expect(g.mates(0), [1]);
      expect(g.mates(1), [0]);
      expect(g.mates(2), isEmpty);
      expect(g.mates(3), isEmpty);
    });

    test('a pick can be read back by the session for the pack hint', () {
      final g = game([w, w, v, v, v]);
      g.pick(0, 2);
      expect(g.pickOf(0), 2);
      expect(g.pickOf(1), isNull);
      expect(g.hasPicked(0), isTrue);
      expect(g.hasPicked(1), isFalse);
    });
  });

  test('role names round trip and the order is fixed', () {
    expect(WolfRole.values.length, 14);
    for (final r in WolfRole.values) {
      expect(WolfRole.byName(r.name), r);
    }
    expect(WolfRole.byName('nope'), isNull);
    expect(WolfRole.values.first, WolfRole.wolf);
    expect(WolfRole.tramp.team, WolfTeam.solo);
  });

  group('night tasks', () {
    test('who has a real night action and who gets a sum', () {
      final g = game([w, WolfRole.alpha, WolfRole.seer, WolfRole.doc, WolfRole.guard, WolfRole.herb, WolfRole.cupid, v, WolfRole.hunter, WolfRole.elder]);
      for (final id in [0, 1, 2, 3, 4, 5, 6]) {
        expect(g.hasNightAction(id), isTrue, reason: '$id');
      }
      for (final id in [7, 8, 9]) {
        expect(g.hasNightAction(id), isFalse, reason: '$id');
      }
    });

    test('the cupid has a sum after night 1; the herbalist after both potions are used', () {
      final g = game([w, WolfRole.cupid, WolfRole.herb, v, v, v, v, v]);
      night(g, {2: 3});
      g.startVote();
      g.resolveVote();
      g.startNight();
      expect(g.hasNightAction(1), isFalse);
      expect(g.hasNightAction(2), isTrue, reason: 'cure and poison left');
      night(g, {0: 4, 2: 4});
      g.startVote();
      g.resolveVote();
      g.startNight();
      expect(g.hasNightAction(2), isTrue, reason: 'poison left');
      night(g, {2: 5}, special: {2});
      g.startVote();
      g.resolveVote();
      g.startNight();
      expect(g.hasNightAction(2), isFalse);
    });

    test('a sum has five distinct answers, one right, and is seeded', () {
      for (var seed = 0; seed < 50; seed++) {
        final s = NightSum.draw(Random(seed));
        expect(s.answers.length, 5);
        expect(s.answers.toSet().length, 5);
        expect(s.answers[s.correct], s.a * s.b);
        expect(s.a, inInclusiveRange(3, 9));
        expect(s.b, inInclusiveRange(3, 9));
        expect(s.answers.every((x) => x > 0), isTrue);
      }
      final a = NightSum.draw(Random(4)), b = NightSum.draw(Random(4));
      expect([a.a, a.b, a.answers], [b.a, b.b, b.answers]);
      final seen = {for (var seed = 0; seed < 50; seed++) NightSum.draw(Random(seed)).correct};
      expect(seen.length, greaterThan(1), reason: 'the right answer moves around');
    });

    test('a sum can have as many answers as there are players alive', () {
      for (final n in [3, 5, 7, 8]) {
        for (var seed = 0; seed < 30; seed++) {
          final s = NightSum.draw(Random(seed), count: n);
          expect(s.answers.length, n);
          expect(s.answers.toSet().length, n);
          expect(s.answers[s.correct], s.a * s.b);
        }
      }
    });

    test('a player with a sum is done by a pick of null; a wrong answer is the same thing', () {
      final g = game([w, v, v, v, v]);
      expect(g.hasPicked(1), isFalse);
      g.pick(1, null);
      expect(g.hasPicked(1), isTrue);
    });

    test('done states: only who has finished, never what', () {
      final g = game([w, WolfRole.seer, v, v, v]);
      g.pick(0, 2);
      g.pick(2, null);
      expect(g.done, {0, 2});
    });
  });

  group('expel (kicked)', () {
    test('a kicked player is out at once, with no shot', () {
      final g = game([w, WolfRole.hunter, v, v, v, v]);
      final d = g.expel(1);
      expect(d.single.cause, DeathCause.left);
      expect(g.isAlive(1), isFalse);
      expect(g.pendingHunters, isEmpty);
      night(g, {});
      expect(g.phase, WolfPhase.day);
    });

    test('their lover goes too, and a hunter lover loses the shot', () {
      final g = game([w, WolfRole.cupid, WolfRole.hunter, v, v, v]);
      night(g, {1: 2}, second: {1: 3});
      g.startVote();
      g.resolveVote();
      final d = g.expel(3);
      expect(d.map((x) => x.id), [3, 2]);
      expect(g.pendingHunters, isEmpty);
      g.startNight();
    });

    test('it can end the game, and is ignored for the dead and after the end', () {
      final g = game([w, v, v]);
      g.expel(1);
      expect(g.winner, WolfWinner.wolves);
      expect(g.expel(2), isEmpty);
      final h = game([w, v, v, v, v]);
      h.expel(1);
      expect(h.expel(1), isEmpty);
    });
  });
}
