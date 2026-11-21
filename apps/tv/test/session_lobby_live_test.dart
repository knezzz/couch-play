import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 48 part 1: one shared game, settings, change feed and host view for
/// every phone and the TV.
void main() {
  late Session s;
  late FakePeer a, b;

  void setUpSession() {
    s = Session(random: Random(1))..uljezTvReady = true;
    s.uljezPacks = [UljezPack('p', 'P', [for (var i = 0; i < 8; i++) WordPair('a$i', 'b$i')])];
    a = join(s, 'Ana', token: 'ta');
    b = join(s, 'Ben', token: 'tb');
  }

  LobbyState lobbyOf(FakePeer p) => p.last<LobbyState>()!;

  test('one shared game: always set, the same on the TV and on every phone; the host moves it from the phone or the remote', () {
    setUpSession();
    expect(s.selectedGame, GameKind.quiz, reason: 'the default');
    expect(lobbyOf(a).selected, GameKind.quiz);
    a.say(const SelectGame(GameKind.uljez));
    expect(s.selectedGame, GameKind.uljez);
    for (final p in [a, b]) {
      expect(lobbyOf(p).selected, GameKind.uljez);
    }
    s.selectFromTv(GameKind.objasni);
    expect(s.selectedGame, GameKind.objasni);
    expect(lobbyOf(b).selected, GameKind.objasni);
    a.say(const SelectGame(null));
    expect(s.selectedGame, GameKind.objasni, reason: 'no game is not a state any more');
    b.say(const SelectGame(GameKind.curve));
    expect(s.selectedGame, GameKind.objasni, reason: 'only the host');
    s.dispose();
  });

  test('a game change adds a "game" entry (by phone / remote), clears the outline and closes the panel', () {
    setUpSession();
    a.say(const SetSettings(GameSettings(quizQuestions: 15)));
    expect(s.hostView, HostView.settings);
    expect(s.changed, isNotNull);
    a.say(const SelectGame(GameKind.uljez));
    expect(s.hostView, HostView.home);
    expect(s.changed, isNull);
    expect(s.feed.first, const LobbyChange.game(GameKind.uljez, ChangeBy.phone));
    s.selectFromTv(GameKind.objasni);
    expect(s.feed.first, const LobbyChange.game(GameKind.objasni, ChangeBy.remote));
    final n = s.feed.length;
    s.selectFromTv(GameKind.objasni);
    a.say(const SelectGame(GameKind.objasni));
    expect(s.feed.length, n, reason: 'the same game again is no change');
    expect(lobbyOf(b).changes, s.feed);
    expect(lobbyOf(b).changed, isNull);
    s.dispose();
  });

  test('a host settings message: one "setting" entry per key that changed, the last is outlined, the TV panel opens', () {
    setUpSession();
    a.say(const SetSettings(GameSettings(quizQuestions: 15)));
    expect(s.feed, [const LobbyChange.setting(GameKind.quiz, 'quizQuestions', 10, 15, ChangeBy.phone)]);
    expect(s.changed, s.feed.first);
    expect(s.hostView, HostView.settings);
    for (final p in [a, b]) {
      final l = lobbyOf(p);
      expect(l.changes, s.feed);
      expect(l.changed, s.changed);
      expect(l.hostView, HostView.settings);
      expect(l.settings.quizQuestions, 15, reason: 'the settings are shared');
    }
    // two keys in one message
    a.say(const SetSettings(GameSettings(quizQuestions: 15, quizSeconds: 25, revealSeconds: 6)));
    expect(s.feed.length, 3);
    expect(s.feed.take(2).map((c) => c.key).toSet(), {'quizSeconds', 'revealSeconds'});
    expect(s.changed, s.feed.first);
    // a message that changes nothing adds nothing
    final before = s.feed;
    a.say(const SetSettings(GameSettings(quizQuestions: 15, quizSeconds: 25, revealSeconds: 6)));
    expect(s.feed, before);
    // a pack change is the game's OffPacks key, with the raw sorted ids
    a.say(const SelectGame(GameKind.uljez));
    s.uljezPacks = [UljezPack('p', 'P', [WordPair('a', 'b')]), UljezPack('q', 'Q', [WordPair('c', 'd')])];
    a.say(const SetSettings(GameSettings(quizQuestions: 15, quizSeconds: 25, revealSeconds: 6, uljezOffPacks: {'q'})));
    expect(s.feed.first, const LobbyChange.setting(GameKind.uljez, 'uljezOffPacks', <String>[], ['q'], ChangeBy.phone));
    s.dispose();
  });

  test('a non-host settings message changes nothing and leaves no entry', () {
    setUpSession();
    b.say(const SetSettings(GameSettings(quizQuestions: 15)));
    expect(s.feed, isEmpty);
    expect(s.hostView, HostView.home);
    s.dispose();
  });

  test('the remote: ▼ opens the panel (a "settings" entry, by remote, once), Natrag closes it, the outline stays', () {
    setUpSession();
    s.openSettingsFromTv();
    expect(s.hostView, HostView.settings);
    expect(s.feed, [const LobbyChange.settings(GameKind.quiz, ChangeBy.remote)]);
    s.openSettingsFromTv();
    expect(s.feed.length, 1, reason: 'already open');
    expect(lobbyOf(b).hostView, HostView.settings);
    s.closeSettingsFromTv();
    expect(s.hostView, HostView.home);
    expect(lobbyOf(b).hostView, HostView.home);
    expect(s.feed.length, 1);
    s.dispose();
  });

  test('the remote editing settings in the panel counts as by remote', () {
    setUpSession();
    s.setSettingsFromTv(const GameSettings(quizQuestions: 20));
    expect(s.feed.first, const LobbyChange.setting(GameKind.quiz, 'quizQuestions', 10, 20, ChangeBy.remote));
    expect(s.settings.quizQuestions, 20);
    expect(s.hostView, HostView.settings);
    expect(lobbyOf(a).settings.quizQuestions, 20);
    s.dispose();
  });

  test('the host in the pack screen: the TV shows the pack grid, ticking keeps it there, closing goes back', () {
    setUpSession();
    a.say(const PackScreen(true));
    expect(s.hostView, HostView.packs);
    expect(s.feed.first, const LobbyChange.packs(GameKind.quiz, ChangeBy.phone));
    a.say(const PackScreen(true));
    expect(s.feed.length, 1, reason: 'already in it');
    a.say(const SetSettings(GameSettings(uljezOffPacks: {'x'})));
    expect(s.hostView, HostView.packs);
    expect(lobbyOf(b).hostView, HostView.packs);
    a.say(const PackScreen(false));
    expect(s.hostView, HostView.settings, reason: 'the panel opened by the change is still there');
    b.say(const PackScreen(true));
    expect(s.hostView, HostView.settings, reason: 'a guest cannot open it');
    s.dispose();
  });

  test('the pack screen closes with a game change, and when the host leaves', () async {
    setUpSession();
    a.say(const PackScreen(true));
    a.say(const SelectGame(GameKind.uljez));
    expect(s.hostView, HostView.home);
    a.say(const PackScreen(true));
    await a.drop();
    expect(s.hostView, isNot(HostView.packs), reason: 'Ben is host now');
    s.dispose();
  });

  test('the host\'s bots count is an entry with the key bots', () {
    setUpSession();
    a.say(const SetBots(2));
    expect(s.feed.first, const LobbyChange.setting(GameKind.quiz, 'bots', 0, 2, ChangeBy.phone));
    expect(s.changed, s.feed.first);
    a.say(const SetBots(2));
    expect(s.feed.length, 1);
    s.dispose();
  });

  test('the list is newest first and never more than 5', () {
    setUpSession();
    for (var n = 11; n <= 18; n++) {
      a.say(SetSettings(GameSettings(quizQuestions: 10, quizSeconds: 10 + 5 * (n - 10))));
    }
    expect(s.feed.length, 5);
    expect(lobbyOf(a).changes.length, 5);
    final last = s.feed.first;
    expect(last.new_, s.settings.quizSeconds);
    expect(s.feed[1].new_, s.settings.quizSeconds - 5);
    s.dispose();
  });

  test('a guest who joins mid-change gets the current state in the lobby message', () {
    setUpSession();
    a.say(const SetSettings(GameSettings(quizQuestions: 15)));
    a.say(const PackScreen(true));
    final c = join(s, 'Cvita', token: 'tc');
    final l = lobbyOf(c);
    expect(l.selected, GameKind.quiz);
    expect(l.settings.quizQuestions, 15);
    expect(l.changed, s.changed);
    expect(l.changes, s.feed);
    expect(l.hostView, HostView.packs);
    s.dispose();
  });

  test('a game start and the way back leave the lobby with the card on the same game, no outline, no panel; the feed stays', () async {
    setUpSession();
    a.say(const SelectGame(GameKind.uljez));
    a.say(const SetSettings(GameSettings(quizQuestions: 15)));
    final feed = s.feed;
    a.say(const StartGame(GameKind.uljez, null));
    s.returnToLobby();
    expect(s.selectedGame, GameKind.uljez);
    expect(s.hostView, HostView.home);
    expect(s.changed, isNull);
    expect(s.feed, feed);
    s.dispose();
  });

  test('the feed lives in the session only: a new session starts empty', () {
    setUpSession();
    a.say(const SetSettings(GameSettings(quizQuestions: 15)));
    s.dispose();
    setUpSession();
    expect(s.feed, isEmpty);
    expect(s.changed, isNull);
    s.dispose();
  });
}
