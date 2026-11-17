import 'package:flutter_test/flutter_test.dart';
import 'package:tv/vukodlak/story_hr.dart';

// The werewolves as attackers are common knowledge; what must stay hidden is which role a player had.
const _roles = [
  'vođa čopora', 'samotnjak', 'seljanin', 'vidovnjak', 'ljekarnik', 'tjelohranitelj', 'travaric',
  'lovac', 'lovačk', 'starješin', 'načelnik', 'provodadžij', 'budal', 'lutalic',
];

void main() {
  test('every event has varied, short lines with the same placeholders', () {
    for (final MapEntry(:key, :value) in storyHr.entries) {
      expect(value.length, greaterThanOrEqualTo(3), reason: key);
      expect(value.toSet().length, value.length, reason: '$key repeats a line');
      final holes = {for (final l in value) ...RegExp(r'\{(\w+)\}').allMatches(l).map((m) => m[1])};
      for (final line in value) {
        final words = line.split(RegExp(r'\s+')).length;
        expect(words, inInclusiveRange(4, 15), reason: '$key: $line');
        expect(holes.difference({'name', 'name2', 'role', 'count'}), isEmpty, reason: key);
      }
    }
  });

  test('role-free events never name a role', () {
    for (final MapEntry(:key, :value) in storyHr.entries) {
      if (storyNamesRole.contains(key) || key.startsWith('gameOver')) continue;
      for (final line in value) {
        final l = line.toLowerCase();
        for (final r in _roles) {
          expect(l.contains(r), isFalse, reason: '$key names a role ($r): $line');
        }
      }
    }
    expect(storyHr.keys.toSet().containsAll(storyNamesRole), isTrue);
  });

  test('has a line list for every engine event, with and without the role', () {
    const engine = ['morningNobody', 'morningDied', 'loverDied', 'hunterShot', 'voteOut', 'voteTie', 'voteNobody',
        'mayorBreaksTie', 'foolSpared', 'trampWins'];
    const roleVariants = ['morningDied', 'loverDied', 'hunterShot', 'voteOut'];
    const session = ['firstNight', 'nightFalls', 'nightWait', 'dayStarts', 'voteStarts', 'hunterAims', 'wolvesLeft',
        'endReveal'];
    final winners = ['village', 'wolves', 'lone', 'tramp', 'nobody']
        .map((w) => 'gameOver${w[0].toUpperCase()}${w.substring(1)}');
    expect(storyHr.keys.toSet(), {...engine, ...session, ...winners, for (final k in roleVariants) '${k}Role'});
    for (final k in roleVariants) {
      expect(storyHr[k]!.any((l) => l.contains('{role}')), isFalse, reason: k);
      expect(storyHr['${k}Role']!.every((l) => l.contains('{role}')), isTrue, reason: k);
    }
  });
}
