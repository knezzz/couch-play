import 'dart:convert';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

ObjasniPack pack([int n = 120]) => ObjasniPack('p', 'Paket', [for (var i = 0; i < n; i++) 'riječ$i']);

ObjasniGame game(int n, {int seed = 1, int turn = 60, int target = 3, ObjasniPack? p}) =>
    ObjasniGame([for (var i = 1; i <= n; i++) i], p ?? pack(), turnSeconds: turn, target: target, random: Random(seed));

/// Begin, then start the turn of whoever explains.
void go(ObjasniGame g) {
  if (g.phase == ObjasniPhase.setup) g.begin();
  g.startTurn();
}

/// A whole turn: [right] correct words, then time runs out.
void turn(ObjasniGame g, int right, {int skips = 0, int fouls = 0}) {
  go(g);
  final foulers = g.ids.where((i) => g.teamOf(i) != g.turnTeam).toList();
  for (var i = 0; i < right; i++) {
    g.correct(g.explainer!);
  }
  for (var i = 0; i < skips; i++) {
    g.skip(g.explainer!);
  }
  for (var i = 0; i < fouls; i++) {
    g.foul(foulers.first);
  }
  g.endTurn();
  g.nextTurn();
}

void main() {
  group('pack', () {
    test('parses {"id","title","words"}', () {
      final j = {'id': 'x', 'title': 'T', 'words': [for (var i = 0; i < 100; i++) 'w$i']};
      final p = ObjasniPack.fromJson(j);
      expect([p.id, p.title, p.words.length], ['x', 'T', 100]);
    });

    test('rejects bad shapes, empty words, duplicates (any case), and fewer than 100 words', () {
      List<String> w(int n) => [for (var i = 0; i < n; i++) 'w$i'];
      final bad = <Map<String, dynamic>>[
        {'id': 'x', 'title': 'T'},
        {'id': 'x', 'words': w(100)},
        {'id': 1, 'title': 'T', 'words': w(100)},
        {'id': 'x', 'title': 'T', 'words': 'no'},
        {'id': 'x', 'title': 'T', 'words': [...w(100), '']},
        {'id': 'x', 'title': 'T', 'words': [...w(100), '  ']},
        {'id': 'x', 'title': 'T', 'words': [...w(100), 5]},
        {'id': 'x', 'title': 'T', 'words': [...w(100), 'W1']},
        {'id': 'x', 'title': 'T', 'words': [...w(100), ' w1 ']},
        {'id': 'x', 'title': 'T', 'words': w(99)},
      ];
      for (final b in bad) {
        expect(() => ObjasniPack.fromJson(jsonDecode(jsonEncode(b)) as Map<String, dynamic>), throwsA(isA<FormatException>()), reason: '$b');
      }
    });
  });

  group('teams', () {
    test('4-8 players only', () {
      expect(() => game(3), throwsArgumentError);
      expect(() => game(9), throwsArgumentError);
      for (var n = 4; n <= 8; n++) {
        game(n);
      }
    });

    test('two teams of as near equal size as possible, everyone in exactly one', () {
      for (var n = 4; n <= 8; n++) {
        final g = game(n);
        final a = g.teamMembers(0), b = g.teamMembers(1);
        expect((a.length - b.length).abs(), lessThanOrEqualTo(1), reason: 'n=$n');
        expect([...a, ...b]..sort(), g.ids);
        for (final id in a) {
          expect(g.teamOf(id), 0);
        }
        for (final id in b) {
          expect(g.teamOf(id), 1);
        }
      }
    });

    test('Promiješaj draws again (only before the game begins)', () {
      final g = game(6);
      final seen = {g.teamMembers(0).join(',')};
      for (var i = 0; i < 30; i++) {
        g.reshuffle();
        seen.add(g.teamMembers(0).join(','));
        expect((g.teamMembers(0).length - g.teamMembers(1).length).abs(), lessThanOrEqualTo(1));
      }
      expect(seen.length, greaterThan(3));
      g.begin();
      final before = [...g.teamMembers(0)];
      g.reshuffle();
      expect(g.teamMembers(0), before, reason: 'too late');
    });

    test('the same seed gives the same teams', () {
      expect(game(7, seed: 5).teamMembers(0), game(7, seed: 5).teamMembers(0));
    });
  });

  group('a turn', () {
    test('the teams alternate and the explainer rotates inside each team', () {
      final g = game(6, target: 1000);
      final explainers = <int>[];
      final teams = <int>[];
      for (var t = 0; t < 12; t++) {
        g.begin();
        teams.add(g.turnTeam);
        explainers.add(g.explainer!);
        g.startTurn();
        g.endTurn();
        g.nextTurn();
      }
      expect(teams, [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1]);
      // each team of 3: everyone explains once every 3 of its turns
      expect(explainers.where((e) => g.teamOf(e) == 0).take(3).toSet().length, 3);
      expect(explainers.where((e) => g.teamOf(e) == 1).take(3).toSet().length, 3);
      expect(explainers[0], explainers[6]);
    });

    test('Točno is +1 for the explainer\'s team; Preskoči is -1; the next word comes up at once', () {
      final g = game(4);
      go(g);
      final w1 = g.word!;
      g.correct(g.explainer!);
      expect(g.score(g.turnTeam), 1);
      final w2 = g.word!;
      expect(w2, isNot(w1));
      g.skip(g.explainer!);
      expect(g.score(g.turnTeam), 0);
      g.skip(g.explainer!);
      expect(g.score(g.turnTeam), -1, reason: 'a team can go below 0');
      expect(g.score(1 - g.turnTeam), 0);
    });

    test('Prekršaj by a player of the other team: -1 for the explainer\'s team, the word is over', () {
      final g = game(6);
      go(g);
      final w = g.word!;
      final other = g.teamMembers(1 - g.turnTeam).first;
      g.foul(other);
      expect(g.score(g.turnTeam), -1);
      expect(g.word, isNot(w));
      expect(g.score(1 - g.turnTeam), 0);
    });

    test('who may press what: only the explainer scores or skips; only the other team calls a foul', () {
      final g = game(6);
      go(g);
      final ex = g.explainer!;
      final mate = g.teamMembers(g.turnTeam).firstWhere((i) => i != ex);
      final other = g.teamMembers(1 - g.turnTeam).first;
      expect(g.correct(mate), isFalse);
      expect(g.skip(other), isFalse);
      expect(g.foul(mate), isFalse, reason: 'the guessers cannot call a foul on themselves');
      expect(g.foul(ex), isFalse);
      expect(g.correct(other), isFalse);
      expect(g.score(g.turnTeam), 0);
      expect(g.correct(ex), isTrue);
    });

    test('this turn\'s words are listed with how they ended', () {
      final g = game(6);
      go(g);
      final words = <String>[g.word!];
      g.correct(g.explainer!);
      words.add(g.word!);
      g.skip(g.explainer!);
      words.add(g.word!);
      g.foul(g.teamMembers(1 - g.turnTeam).first);
      expect([for (final w in g.turnWords) w.word], words.take(3).toList());
      expect([for (final w in g.turnWords) w.mark], [ObjasniMark.correct, ObjasniMark.skip, ObjasniMark.foul]);
    });

    test('time up: the word on screen is lost for no points and is not listed', () {
      final g = game(4);
      go(g);
      g.correct(g.explainer!);
      final lost = g.word!;
      g.endTurn();
      expect(g.phase, ObjasniPhase.summary);
      expect(g.score(0) + g.score(1), 1);
      expect(g.turnWords.map((w) => w.word), isNot(contains(lost)));
      expect(g.word, isNull);
    });

    test('nothing scores outside a running turn', () {
      final g = game(4);
      expect(g.correct(g.ids.first), isFalse);
      g.begin();
      expect(g.correct(g.explainer!), isFalse, reason: 'waiting for Kreni');
      g.startTurn();
      g.endTurn();
      expect(g.correct(g.explainer ?? 1), isFalse);
    });

    test('a word does not come up twice in one game', () {
      final g = game(4, p: pack(100), target: 100000);
      final seen = <String>{};
      for (var t = 0; t < 4; t++) {
        go(g);
        for (var i = 0; i < 20; i++) {
          expect(seen.add(g.word!), isTrue, reason: 'repeat ${g.word}');
          g.correct(g.explainer!);
        }
        g.endTurn();
        g.nextTurn();
      }
      expect(seen.length, 80);
    });

    test('when the pack runs out the words start over (a game has 100+ words)', () {
      final g = game(4, p: pack(100), target: 100000);
      go(g);
      for (var i = 0; i < 130; i++) {
        expect(g.word, isNotNull);
        g.correct(g.explainer!);
      }
    });
  });

  group('word numbers: racing presses hit the word they were about', () {
    test('a double Točno scores once', () {
      final g = game(4);
      go(g);
      final n = g.wordNo;
      expect(g.correct(g.explainer!, word: n), isTrue);
      expect(g.correct(g.explainer!, word: n), isFalse);
      expect(g.score(g.turnTeam), 1);
    });

    test('two watchers calling the same word cost one point and burn one word', () {
      final g = game(6);
      go(g);
      final n = g.wordNo;
      final w = g.teamMembers(1 - g.turnTeam);
      expect(g.foul(w[0], word: n), isTrue);
      expect(g.foul(w[1], word: n), isFalse);
      expect(g.score(g.turnTeam), -1);
      expect(g.turnWords.length, 1);
    });

    test('a stale press after the next word does nothing; the new word can still be pressed', () {
      final g = game(4);
      go(g);
      final old = g.wordNo;
      g.correct(g.explainer!, word: old);
      expect(g.wordNo, isNot(old));
      expect(g.skip(g.explainer!, word: old), isFalse);
      expect(g.score(g.turnTeam), 1);
      expect(g.skip(g.explainer!, word: g.wordNo), isTrue);
    });

    test('a press without a number (an older phone) is not checked', () {
      final g = game(4);
      go(g);
      expect(g.correct(g.explainer!), isTrue);
    });

    test('the number keeps counting across turns', () {
      final g = game(4, target: 100);
      go(g);
      final first = g.wordNo;
      g.endTurn();
      g.nextTurn();
      g.startTurn();
      expect(g.wordNo, greaterThan(first));
    });
  });

  group('the end', () {
    test('the game ends when a team has the target at the end of a FULL round', () {
      final g = game(4, target: 3);
      turn(g, 3); // team 0 reaches 3 in its turn
      expect(g.phase, ObjasniPhase.ready, reason: 'team 1 has not had its turn yet');
      expect(g.winnerTeam, isNull);
      turn(g, 1); // team 1 has 1
      expect(g.phase, ObjasniPhase.over);
      expect(g.winnerTeam, 0);
    });

    test('both pass the target in one round: the higher score wins', () {
      final g = game(4, target: 3);
      turn(g, 4);
      turn(g, 5);
      expect(g.winnerTeam, 1);
    });

    test('equal scores play one more turn each, until one team leads', () {
      final g = game(4, target: 3);
      turn(g, 3);
      turn(g, 3);
      expect(g.phase, ObjasniPhase.ready, reason: '3-3: another round');
      expect(g.winnerTeam, isNull);
      turn(g, 1);
      turn(g, 1);
      expect(g.phase, ObjasniPhase.ready, reason: 'still level 4-4');
      turn(g, 2);
      turn(g, 0);
      expect(g.winnerTeam, 0);
    });

    test('below the target nobody has won, however far ahead', () {
      final g = game(4, target: 30);
      turn(g, 10);
      turn(g, 0);
      expect(g.phase, ObjasniPhase.ready);
    });

    test('session points: 1 for each player of the winning team, 0 for the others', () {
      final g = game(5, target: 2);
      turn(g, 2);
      turn(g, 0);
      expect(g.winnerTeam, 0);
      final sp = g.sessionScores;
      for (final id in g.ids) {
        expect(sp[id], g.teamOf(id) == 0 ? 1 : 0);
      }
      expect(game(4).sessionScores, isEmpty);
    });
  });

  group('dropping out', () {
    test('an away player is skipped as explainer; back again, they explain at their next turn', () {
      final g = game(6, target: 1000);
      g.begin();
      final team0 = <int>[];
      for (var t = 0; t < 6; t++) {
        if (g.turnTeam == 0) team0.add(g.explainer!);
        g.startTurn();
        g.endTurn();
        g.nextTurn();
      }
      expect(team0.toSet().length, 3, reason: 'everyone in team 0 explained once');
      // turn 6 is team 0 again: the rotation points at team0[0]; that player is away
      expect(g.turnTeam, 0);
      expect(g.explainer, team0[0]);
      g.setAway(team0[0], true);
      expect(g.explainer, team0[1], reason: 'the next connected member');
      g.setAway(team0[0], false);
      g.startTurn();
      g.endTurn();
      g.nextTurn(); // team 1
      g.startTurn();
      g.endTurn();
      g.nextTurn(); // team 0: the rotation went on past team0[1]
      expect(g.explainer, team0[2]);
    });

    test('the explainer leaving ends the turn at once with the score it had', () {
      final g = game(6);
      go(g);
      g.correct(g.explainer!);
      g.setAway(g.explainer!, true);
      expect(g.phase, ObjasniPhase.summary);
      expect(g.score(g.turnTeam), 1);
    });

    test('a team with nobody connected needs the game to pause', () {
      final g = game(4);
      g.begin();
      expect(g.teamNeedsPause, isFalse);
      for (final id in g.teamMembers(1)) {
        g.setAway(id, true);
      }
      expect(g.teamNeedsPause, isTrue);
      g.setAway(g.teamMembers(1).first, false);
      expect(g.teamNeedsPause, isFalse);
    });

    test('abandoning: the game can be ended with the scores as they are', () {
      final g = game(4, target: 100);
      turn(g, 4);
      g.abandon();
      expect(g.phase, ObjasniPhase.over);
      expect(g.winnerTeam, 0, reason: 'the higher score at the moment');
    });
  });
}
