import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/packs/uljez_packs.dart';
import 'package:tv/session/session.dart';
import 'package:tv/session/uljez_text.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer, join;

UljezPack pack(String id) => UljezPack(id, 'T $id', [for (var i = 0; i < 8; i++) WordPair('$id-a$i', '$id-b$i')]);

void main() {
  late Session s;
  late List<FakePeer> ps;

  void setUpSession(int n, {int bots = 0}) {
    s = Session(random: Random(1))..uljezTvReady = true;
    s.uljezPacks = [pack('one'), pack('two')];
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
    if (bots > 0) s.setBotCount(bots);
  }

  testWidgets('the bundled packs load', (t) async {
    final packs = await loadUljezPacks(rootBundle);
    expect(packs.length, 8);
    expect(packs.every((p) => p.pairs.length >= 40), isTrue);
    expect(packs.map((p) => p.id), contains('uljez-hrana'));
  });

  test('3 to 8 humans and no bots', () {
    setUpSession(2);
    ps[0].say(const StartGame(GameKind.uljez, null));
    expect(s.phase, Phase.lobby);
    expect(ps[0].last<ErrorMsg>()!.message, UljezText.needPlayers);
    s.dispose();
    setUpSession(3, bots: 1);
    ps[0].say(const StartGame(GameKind.uljez, null));
    expect(s.phase, Phase.lobby);
    expect(ps[0].last<ErrorMsg>()!.message, UljezText.noBots);
    s.dispose();
    setUpSession(3);
    ps[1].say(const StartGame(GameKind.uljez, null));
    expect(s.phase, Phase.lobby, reason: 'only the host starts');
    ps[0].say(const StartGame(GameKind.uljez, null));
    expect(s.phase, Phase.uljez);
    s.dispose();
  });

  test('with no packs loaded the host is told', () {
    s = Session(random: Random(1))..uljezTvReady = true;
    ps = [for (var i = 0; i < 3; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.uljez, null));
    expect(ps[0].last<ErrorMsg>()!.message, Strings.packUnavailable);
    s.dispose();
  });

  test('the host\'s pack is kept, a missing pack falls back and the other settings survive', () {
    setUpSession(3);
    ps[0].say(const SetSettings(GameSettings(uljezPackId: 'two', kolikoSeconds: 45)));
    expect(s.settings.uljezOffPacks, {'one'}, reason: 'an old single id means only that pack');
    expect(s.settings.uljezPackId, isNull);
    ps[0].say(const SetSettings(GameSettings(uljezPackId: 'gone', kolikoSeconds: 45)));
    expect(s.settings.uljezPackId, isNull);
    expect(s.settings.kolikoSeconds, 45, reason: 'dropping a missing pack keeps the other settings');
    ps[0].say(const SetSettings(GameSettings(uljezPackId: 'two')));
    ps[0].say(const StartGame(GameKind.uljez, null));
    expect(s.uljez!.pack.id, 'two');
    s.dispose();
  });

  test('the lobby lists the Uljez packs', () {
    setUpSession(3);
    final lobby = ps[0].last<LobbyState>()!;
    expect([for (final p in lobby.uljezPacks) p.id], ['one', 'two']);
    expect(lobby.uljezPacks.first.questionCount, 8);
    s.dispose();
  });

  test('each phone gets one word on its own connection; exactly one phone has the other word', () {
    setUpSession(5);
    ps[0].say(const StartGame(GameKind.uljez, null));
    final words = [for (final p in ps) p.sent.whereType<UljezWord>().single.word];
    expect(words.toSet().length, 2);
    final g = s.uljez!.game;
    expect(words.where((w) => w == g.impostorWord).length, 1);
    for (final p in ps) {
      final id = p.sent.whereType<Welcome>().first.playerId;
      expect(p.sent.whereType<UljezWord>().single.word, g.wordOf(id));
    }
    s.dispose();
  });

  test('a vote or guess from a phone is that phone\'s own player; a rejoin gets its own state', () async {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.uljez, null));
    final id = ps[1].sent.whereType<Welcome>().first.playerId;
    await ps[1].drop();
    final again = join(s, 'P1', token: 't1');
    expect(again.sent.whereType<UljezWord>().single.word, s.uljez!.game.wordOf(id));
    expect(again.sent.whereType<UljezTurn>(), isNotEmpty);
    s.dispose();
  });

  /// Round 1 by the speakers' phones, then everyone says "Idemo glasati".
  void toVote() {
    final u = s.uljez!;
    for (var i = 0; i < ps.length; i++) {
      final speaker = u.speaker!;
      ps.firstWhere((p) => p.sent.whereType<Welcome>().first.playerId == speaker).say(const UljezDone());
    }
    for (final p in ps) {
      p.say(const ReadyToVote(true));
    }
  }

  testWidgets('a game ends with placement points, the results, and back to the lobby', (t) async {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.uljez, null));
    final u = s.uljez!;
    await t.pump(const Duration(minutes: 30));
    expect(u.phase, UljezPhase.clues, reason: 'no clock ends the clues');
    toVote();
    expect(u.phase, UljezPhase.vote);
    await t.pump(const Duration(minutes: 30));
    expect(u.phase, UljezPhase.vote);
    for (final p in ps) {
      p.say(const Vote(null));
    }
    expect(s.phase, Phase.uljez, reason: 'the end screen with both words first');
    expect(u.phase, UljezPhase.over);
    expect(ps[1].sent.whereType<UljezEnd>(), isNotEmpty);
    expect(ps[1].sent.whereType<Results>(), isEmpty);
    await t.pump(const Duration(seconds: 9));
    expect(s.phase, Phase.uljez);
    await t.pump(const Duration(seconds: 1));
    expect(s.phase, Phase.results);
    expect(s.placements.length, 4);
    expect(s.lastGameLabel, UljezText.name);
    expect(ps[1].sent.whereType<UljezEnd>().single.winner, UljezWinner.impostors);
    expect(ps[1].last<Results>(), isNotNull);
    s.returnToLobby();
    expect(s.uljez, isNull);
    s.dispose();
  });

  testWidgets('Dao sam trag and Idemo glasati come from the sending phone; a locked speaker keeps the turn, a kick moves on; 10 empty minutes give up', (t) async {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.uljez, null));
    final u = s.uljez!;
    int idOf(FakePeer p) => p.sent.whereType<Welcome>().first.playerId;
    FakePeer phone(int id) => ps.firstWhere((p) => idOf(p) == id);
    final first = u.speaker!;
    final other = ps.firstWhere((p) => idOf(p) != first);
    other.say(const UljezDone());
    expect(u.speaker, first, reason: 'only the speaker\'s phone passes the turn');
    phone(first).say(const UljezDone());
    final second = u.order[1];
    expect(u.speaker, second);
    phone(second).close(); // the speaker's phone locks
    await t.pump(const Duration(minutes: 5));
    expect(u.speaker, second, reason: 'the turn waits for the sleeping speaker');
    final k = ps.indexOf(phone(second));
    final back = join(s, 'P$k', token: 't$k');
    final order = [for (final m in back.sent) m.type];
    expect(order.indexOf('uljezWord'), lessThan(order.indexOf('voteWish')), reason: 'the word before the wish: no spinner');
    expect(u.speaker, second);
    final host = ps[0];
    expect(idOf(host), isNot(second), reason: 'the seed puts the host elsewhere; the host kicks the sleeper');
    host.say(Kick(second));
    expect(u.speaker, u.order[2], reason: 'the kick clears the wait');
    for (final p in ps) {
      p.close();
    }
    await t.pump(const Duration(minutes: 9, seconds: 59));
    expect(s.phase, Phase.uljez);
    await t.pump(const Duration(seconds: 2));
    expect(s.phase, Phase.lobby);
    s.dispose();
  });

  test('refused with the soon text while the TV has no screens for it', () {
    s = Session(random: Random(1))..uljezTvReady = false; // the gate, whatever kUljezTvReady is now
    ps = [for (var i = 0; i < 6; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.uljez, null));
    expect(s.phase, Phase.lobby);
    expect(ps[0].last<ErrorMsg>()!.message, Strings.uljezSoon);
    s.dispose();
  });

  test('a kicked player is out of a running Uljez', () {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.uljez, null));
    final u = s.uljez!;
    final kicked = [for (final p in ps) if (!u.game.isImpostor(p.sent.whereType<Welcome>().first.playerId) && p != ps[0]) p].first;
    final id = kicked.sent.whereType<Welcome>().first.playerId;
    ps[0].say(Kick(id));
    expect(u.alive.contains(id), isFalse);
    s.dispose();
  });
}
