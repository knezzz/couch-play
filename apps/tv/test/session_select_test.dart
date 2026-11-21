import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';

import 'session_sound_test.dart' show FakeSfx;
import 'session_test.dart' show FakePeer, join;
import 'package:tv/sound/sfx.dart';

/// Task 27: the host's game selection.
void main() {
  late Session s;
  late FakePeer a, b;

  QuizPack pack(String id, String title) => QuizPack(id, title, [
        for (var i = 0; i < 6; i++) PackQuestion('$id$i?', null, const ['a', 'b', 'c', 'd'], 0),
      ], const {});

  void setUpSession() {
    s = Session(random: Random(1));
    s.packLookup = (id) => switch (id) {
          null => pack('default', 'Zadani'),
          'big' => pack('big', 'Veliki'),
          _ => null,
        };
    a = join(s, 'Ana', token: 'ta');
    b = join(s, 'Ben', token: 'tb');
  }

  test('the_first_game_is_shown_at_first', () {
    setUpSession();
    expect(s.selectedGame, GameKind.quiz);
    expect(a.last<LobbyState>()!.selected, GameKind.quiz);
    s.dispose();
  });

  test('the_host_selects_and_every_phone_is_told', () {
    setUpSession();
    a.say(const SelectGame(GameKind.curve));
    expect(s.selectedGame, GameKind.curve);
    expect(a.last<LobbyState>()!.selected, GameKind.curve);
    expect(b.last<LobbyState>()!.selected, GameKind.curve);
    a.say(const SelectGame(null));
    expect(s.selectedGame, GameKind.curve, reason: 'no game is not a state any more');
    s.dispose();
  });

  test('a_non_host_cannot_select', () {
    setUpSession();
    b.say(const SelectGame(GameKind.curve));
    expect(s.selectedGame, GameKind.quiz);
    expect(b.last<ErrorMsg>(), const ErrorMsg(Strings.onlyHost));
    s.dispose();
  });

  test('the_game_stays_when_the_host_changes: every screen shows the same one', () async {
    setUpSession();
    a.say(const SelectGame(GameKind.curve));
    await a.drop();
    expect(s.hostId, isNot(0));
    expect(s.selectedGame, GameKind.curve, reason: 'Ben is host now and sees the same game');
    expect(b.last<LobbyState>()!.selected, GameKind.curve);
    final a2 = FakePeer();
    s.attach(a2);
    a2.say(const Join('Ana', 'ta')); // Ana is the oldest again
    expect(s.hostId, isNot(-1));
    expect(s.selectedGame, GameKind.curve);
    s.dispose();
  });

  testWidgets('igraj_starts_the_selected_game_with_its_settings_and_the_card_stays_on_it', (t) async {
    setUpSession();
    a.say(const SelectGame(GameKind.quiz));
    a.say(const SetSettings(GameSettings(quizQuestions: 5)));
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    expect(s.phase, Phase.quiz);
    expect(s.quizTitle, 'Zadani');
    expect(s.quiz!.total, 5);
    s.finishGame({for (final p in s.players) p.id: 0});
    s.returnToLobby();
    expect(s.selectedGame, GameKind.quiz);
    s.dispose();
  });

  testWidgets('a_stale_selection_after_the_game_started_is_ignored', (t) async {
    setUpSession();
    a.say(const StartGame(GameKind.curve, null));
    await t.pump();
    a.say(const SelectGame(GameKind.objasni));
    expect(s.selectedGame, GameKind.quiz);
    s.dispose();
  });

  group('the_tv_remote_drives_the_home', () {
    late FakeSfx sfx;
    void setUpWithSound() {
      setUpSession();
      sfx = FakeSfx();
      s.sfx = sfx;
      sfx.played.clear();
    }

    test('selectFromTv_selects_tells_every_phone_and_clicks', () {
      setUpWithSound();
      s.selectFromTv(GameKind.blef);
      expect(s.selectedGame, GameKind.blef);
      expect(a.last<LobbyState>()!.selected, GameKind.blef);
      expect(b.last<LobbyState>()!.selected, GameKind.blef);
      expect(sfx.played, [Sound.menuMove]);
      s.dispose();
    });

    test('selectFromTv_with_nobody_in_the_room_selects_nothing_but_still_clicks', () {
      s = Session(random: Random(1));
      final sfx = FakeSfx();
      s.sfx = sfx;
      s.selectFromTv(GameKind.blef);
      expect(s.selectedGame, GameKind.quiz, reason: 'no host to move it');
      expect(sfx.played, [Sound.menuMove]);
      s.dispose();
    });

    testWidgets('startFromTv_starts_the_quiz_with_the_hosts_settings_and_confirms', (t) async {
      setUpWithSound();
      a.say(const SetSettings(GameSettings(quizQuestions: 5, quizSeconds: 15)));
      expect(s.startFromTv(GameKind.quiz), isNull);
      await t.pump();
      expect(s.phase, Phase.quiz);
      expect(s.quizTitle, 'Zadani');
      expect(sfx.played, contains(Sound.menuConfirm));
      s.dispose();
    });

    testWidgets('startFromTv_starts_curve_for_two_players', (t) async {
      setUpWithSound();
      expect(s.startFromTv(GameKind.curve), isNull);
      await t.pump();
      expect(s.phase, Phase.curve);
      s.dispose();
    });

    test('startFromTv_says_why_it_cannot_and_stays_quiet', () {
      s = Session(random: Random(1));
      s.sfx = FakeSfx();
      expect(s.startFromTv(GameKind.quiz), Strings.homeNeedPlayers, reason: 'nobody has joined');
      a = join(s, 'Ana', token: 'ta');
      expect(s.startFromTv(GameKind.curve), Strings.curveNeedsTwo);
      expect(s.phase, Phase.lobby);
      expect((s.sfx as FakeSfx).played.where((x) => x == Sound.menuConfirm), isEmpty);
      s.dispose();
    });

    testWidgets('startFromTv_during_a_game_is_refused', (t) async {
      setUpWithSound();
      s.startFromTv(GameKind.curve);
      await t.pump();
      expect(s.startFromTv(GameKind.quiz), Strings.gameRunning);
      s.dispose();
    });

    testWidgets('a_game_started_from_the_tv_leaves_the_card_on_that_game', (t) async {
      setUpWithSound();
      s.selectFromTv(GameKind.curve);
      s.startFromTv(GameKind.curve);
      await t.pump();
      expect(s.selectedGame, GameKind.curve);
      s.dispose();
    });
  });
}
