import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/wolf_text.dart';
import 'package:tv/vukodlak/story_hr.dart';
import 'package:tv/vukodlak/wolf_story.dart';

String _name(int id) => const {1: 'Ana', 2: 'Luka', 3: 'Maja'}[id] ?? '?';

void main() {
  final rnd = Random(3);

  test('a line is one of the key\'s lines, with the name filled in', () {
    for (var i = 0; i < 30; i++) {
      final s = wolfStoryLine(const WolfEvent('morningDied', {'player': 1}), _name, rnd);
      expect(s, contains('Ana'));
      expect(s, isNot(contains('{')));
      expect(storyHr['morningDied']!.map((l) => l.replaceAll('{name}', 'Ana')), contains(s));
    }
  });

  test('it varies: over many picks every line of a key turns up', () {
    final seen = {
      for (var i = 0; i < 300; i++) wolfStoryLine(const WolfEvent('nightFalls', {'night': 2}), _name, rnd),
    };
    expect(seen, storyHr['nightFalls']!.toSet());
  });

  test('an event with a role uses the Role twin and the role\'s Croatian name', () {
    final s = wolfStoryLine(const WolfEvent('morningDied', {'player': 2, 'role': 'seer'}), _name, rnd);
    expect(s, contains('Luka'));
    expect(s, contains(WolfText.roleNames[WolfRole.seer]!));
    expect(s, isNot(contains('{')));
  });

  test('without a role (hidden) a role name is never in the line', () {
    for (final key in ['morningDied', 'loverDied', 'voteOut', 'playerLeft']) {
      for (var i = 0; i < 40; i++) {
        final s = wolfStoryLine(WolfEvent(key, const {'player': 3}), _name, rnd);
        for (final role in WolfText.roleNames.values) {
          expect(s, isNot(contains(role)), reason: '$key: "$s"');
        }
      }
    }
  });

  test('the hunter\'s shot names the hunter and the one hit', () {
    final s = wolfStoryLine(const WolfEvent('hunterShot', {'hunter': 1, 'player': 2}), _name, rnd);
    expect(s, contains('Ana'));
    expect(s, contains('Luka'));
  });

  test('game over: gameOver plus the winner, capitalised', () {
    for (final (w, key) in [
      ('village', 'gameOverVillage'),
      ('wolves', 'gameOverWolves'),
      ('lone', 'gameOverLone'),
      ('tramp', 'gameOverTramp'),
      ('nobody', 'gameOverNobody'),
    ]) {
      final s = wolfStoryLine(WolfEvent('gameOver', {'winner': w}), _name, rnd);
      expect(s, isNotEmpty, reason: w);
      expect(storyHr[key]!.map((l) => l.replaceAll('{name}', '?')), contains(s), reason: w);
    }
  });

  test('wolvesLeft fills in the count', () {
    final s = wolfStoryLine(const WolfEvent('wolvesLeft', {'count': 2}), _name, rnd);
    expect(s, contains('2'));
  });

  test('an unknown key is an empty line, not a crash', () {
    expect(wolfStoryLine(const WolfEvent('nope'), _name, rnd), '');
  });

  test('the story the TV shows is the last beat: a marker alone, or the events since the last marker', () {
    const story = [
      WolfEvent('firstNight'),
      WolfEvent('morningDied', {'player': 1}),
      WolfEvent('loverDied', {'player': 2}),
    ];
    expect(currentBeat(story).map((e) => e.key), ['morningDied', 'loverDied']);
    expect(currentBeat([...story, const WolfEvent('dayStarts', {'day': 1})]).map((e) => e.key), ['dayStarts']);
    expect(currentBeat(const []), isEmpty);
  });
}
