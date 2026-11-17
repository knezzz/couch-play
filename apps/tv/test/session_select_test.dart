import 'dart:convert';
import 'dart:io';
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

  test('nothing_is_selected_at_first', () {
    setUpSession();
    expect(s.selectedGame, isNull);
    expect(a.last<LobbyState>()!.selected, isNull);
    s.dispose();
  });

  test('the_host_selects_and_every_phone_is_told', () {
    setUpSession();
    a.say(const SelectGame(GameKind.quiz));
    expect(s.selectedGame, GameKind.quiz);
    expect(a.last<LobbyState>()!.selected, GameKind.quiz);
    expect(b.last<LobbyState>()!.selected, GameKind.quiz);
    a.say(const SelectGame(null));
    expect(s.selectedGame, isNull);
    expect(b.last<LobbyState>()!.selected, isNull);
    s.dispose();
  });

  test('a_non_host_cannot_select', () {
    setUpSession();
    b.say(const SelectGame(GameKind.curve));
    expect(s.selectedGame, isNull);
    expect(b.last<ErrorMsg>(), const ErrorMsg(Strings.onlyHost));
    s.dispose();
  });

  test('the_selection_goes_when_the_host_changes_and_does_not_come_back', () async {
    setUpSession();
    a.say(const SelectGame(GameKind.curve));
    await a.drop();
    expect(s.hostId, isNot(0));
    expect(s.selectedGame, isNull, reason: 'Ben is host now');
    final a2 = FakePeer();
    s.attach(a2);
    a2.say(const Join('Ana', 'ta')); // Ana is the oldest again
    expect(s.hostId, isNot(-1));
    expect(s.selectedGame, isNull);
    s.dispose();
  });

  testWidgets('igraj_starts_the_selected_game_with_its_settings_and_clears_the_selection', (t) async {
    setUpSession();
    a.say(const SelectGame(GameKind.quiz));
    a.say(const SetSettings(GameSettings(quizPackId: 'big', quizQuestions: 5)));
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    expect(s.phase, Phase.quiz);
    expect(s.quizTitle, 'Veliki');
    expect(s.quiz!.total, 5);
    expect(s.selectedGame, isNull);
    s.finishGame({for (final p in s.players) p.id: 0});
    s.returnToLobby();
    expect(s.selectedGame, isNull);
    s.dispose();
  });

  test('no_pack_chosen_means_the_default_and_one_that_does_not_exist_is_dropped', () {
    setUpSession();
    expect(s.selectedPackTitle, 'Zadani');
    a.say(const SetSettings(GameSettings(quizPackId: 'big')));
    expect(s.selectedPackTitle, 'Veliki');
    a.say(const SetSettings(GameSettings(quizPackId: 'gone')));
    expect(s.settings.quizPackId, isNull);
    expect(s.selectedPackTitle, 'Zadani');
    s.dispose();
  });

  testWidgets('a_stale_selection_after_the_game_started_is_ignored', (t) async {
    setUpSession();
    a.say(const StartGame(GameKind.curve, null));
    await t.pump();
    a.say(const SelectGame(GameKind.quiz));
    expect(s.selectedGame, isNull);
    s.dispose();
  });

  testWidgets('a_saved_pack_the_tv_no_longer_has_falls_back_to_the_default_at_load_and_at_igraj', (t) async {
    final dir = Directory.systemTemp.createTempSync('sel');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/settings.json')
      ..writeAsStringSync(jsonEncode(const GameSettings(quizPackId: 'gone').toJson()));
    setUpSession();
    s.loadSettings(file);
    expect(s.settings.quizPackId, isNull, reason: 'dropped at load');
    // Removed after it was chosen: Igraj still starts the default.
    var have = true;
    final lookup = s.packLookup;
    s.packLookup = (id) => id == 'tmp' ? (have ? pack('tmp', 'Privremeni') : null) : lookup(id);
    a.say(const SetSettings(GameSettings(quizPackId: 'tmp')));
    expect(s.settings.quizPackId, 'tmp');
    have = false;
    a.say(const StartGame(GameKind.quiz, null));
    await t.pump();
    expect(s.phase, Phase.quiz);
    expect(s.quizTitle, 'Zadani');
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
      s.selectFromTv(GameKind.quiz);
      expect(s.selectedGame, GameKind.quiz);
      expect(a.last<LobbyState>()!.selected, GameKind.quiz);
      expect(b.last<LobbyState>()!.selected, GameKind.quiz);
      expect(sfx.played, [Sound.menuMove]);
      s.dispose();
    });

    test('selectFromTv_with_nobody_in_the_room_does_nothing', () {
      s = Session(random: Random(1));
      s.selectFromTv(GameKind.quiz);
      expect(s.selectedGame, isNull);
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

    testWidgets('a_game_started_from_the_tv_clears_the_selection_like_igraj_does', (t) async {
      setUpWithSound();
      s.selectFromTv(GameKind.curve);
      s.startFromTv(GameKind.curve);
      await t.pump();
      expect(s.selectedGame, isNull);
      s.dispose();
    });
  });
}
