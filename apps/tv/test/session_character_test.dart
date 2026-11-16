import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer;

/// Task 29: every player has a character, one each.
void main() {
  late Session s;
  var tokens = 0;

  FakePeer join(String name, {String? character, String? token}) {
    final p = FakePeer();
    s.attach(p);
    p.say(Join(name, token ?? 't${tokens++}', character: character));
    return p;
  }

  String ofPlayer(String name) => s.playerInfos.firstWhere((p) => p.name == name).character;

  setUp(() => s = Session(random: Random(1)));
  tearDown(() => s.dispose());

  test('a_free_pick_at_join_is_kept_and_told_to_the_phone', () {
    final a = join('Ana', character: 'owl');
    expect(ofPlayer('Ana'), 'owl');
    expect(a.last<Welcome>()!.character, 'owl');
    expect(a.last<LobbyState>()!.players.single.character, 'owl');
  });

  test('a_taken_or_unknown_or_missing_pick_gets_a_random_free_one', () {
    join('Ana', character: 'owl');
    join('Ben', character: 'owl');
    join('Cy', character: 'dragon');
    join('Di');
    final all = [for (final n in ['Ana', 'Ben', 'Cy', 'Di']) ofPlayer(n)];
    expect(all.every(isCharacter), isTrue, reason: '$all');
    expect(all.toSet(), hasLength(4), reason: 'one each: $all');
    expect(all.first, 'owl', reason: 'Ana was first');
  });

  test('eight_humans_or_humans_with_bots_always_get_different_ones', () {
    for (var i = 0; i < 5; i++) {
      join('P$i', character: 'fox'); // everyone wants the fox
    }
    s.setBotCount(3);
    final all = [for (final p in s.playerInfos) p.character];
    expect(all, hasLength(8));
    expect(all.every(isCharacter), isTrue);
    expect(all.toSet(), hasLength(8), reason: '$all');
    expect(s.playerInfos.where((p) => p.bot).every((p) => p.character.isNotEmpty), isTrue);
  });

  test('a_human_who_wants_a_bots_character_gets_it_only_once_the_bot_is_gone', () {
    join('Ana');
    s.setBotCount(1);
    final botChar = s.playerInfos.firstWhere((p) => p.bot).character;
    join('Ben', character: botChar);
    expect(ofPlayer('Ben'), isNot(botChar), reason: 'the bot has it');
  });

  test('change_to_a_free_character_works_and_every_phone_is_told', () {
    final a = join('Ana', character: 'owl');
    final b = join('Ben', character: 'cat');
    a.say(const SetCharacter('frog'));
    expect(ofPlayer('Ana'), 'frog');
    expect(b.last<LobbyState>()!.players.firstWhere((p) => p.name == 'Ana').character, 'frog');
    expect(a.last<ErrorMsg>(), isNull);
    a.say(const SetCharacter('owl')); // free again
    expect(ofPlayer('Ana'), 'owl');
  });

  test('a_taken_character_is_refused_with_a_message', () {
    final a = join('Ana', character: 'owl');
    join('Ben', character: 'cat');
    a.say(const SetCharacter('cat'));
    expect(ofPlayer('Ana'), 'owl');
    expect(a.last<ErrorMsg>(), const ErrorMsg(Strings.characterTaken));
  });

  test('two_phones_racing_for_the_same_one_one_wins', () {
    final a = join('Ana', character: 'owl');
    final b = join('Ben', character: 'cat');
    a.say(const SetCharacter('lion'));
    b.say(const SetCharacter('lion'));
    expect(ofPlayer('Ana'), 'lion');
    expect(ofPlayer('Ben'), 'cat');
    expect(b.last<ErrorMsg>(), const ErrorMsg(Strings.characterTaken));
  });

  test('an_unknown_id_and_choosing_your_own_do_nothing', () {
    final a = join('Ana', character: 'owl');
    a.say(const SetCharacter('dragon'));
    a.say(const SetCharacter('owl'));
    expect(ofPlayer('Ana'), 'owl');
    expect(a.last<ErrorMsg>(), isNull);
  });

  test('reconnect_keeps_the_character_whatever_the_new_join_asks_for', () async {
    final a = join('Ana', character: 'owl', token: 'ta');
    join('Ben', character: 'cat');
    await a.drop();
    final a2 = FakePeer();
    s.attach(a2);
    a2.say(const Join('Ana', 'ta', character: 'fox'));
    expect(ofPlayer('Ana'), 'owl');
    expect(a2.last<Welcome>()!.character, 'owl');
    // A disconnected player's character stays theirs.
    await a2.drop();
    join('Cy', character: 'owl');
    expect(ofPlayer('Cy'), isNot('owl'));
  });

  testWidgets('no_changes_once_a_game_has_started', (t) async {
    final a = join('Ana', character: 'owl');
    join('Ben', character: 'cat');
    a.say(const StartGame(GameKind.curve, null));
    await t.pump();
    a.say(const SetCharacter('frog'));
    expect(ofPlayer('Ana'), 'owl');
  });

  test('a_character_frees_up_when_its_player_is_removed', () {
    final a = join('Ana', character: 'owl');
    final b = join('Ben', character: 'cat');
    a.say(Kick(s.players.firstWhere((p) => p.name == 'Ben').id));
    expect(b.closed, isTrue);
    join('Cy', character: 'cat');
    expect(ofPlayer('Cy'), 'cat');
  });
}
