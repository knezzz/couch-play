import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/packs/party_packs.dart';
import 'package:tv/session/party_text.dart';
import 'package:tv/session/session.dart';
import 'package:tv/session/tkobi_match.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer, join;

TkobiPack pack(String id) => TkobiPack(id, 'T $id', [for (var i = 0; i < 40; i++) '$id: tko bi $i?']);

/// Task 42: Tko bi? inside the Session.
void main() {
  late Session s;
  late List<FakePeer> ps;
  var at = Duration.zero;

  void setUpSession(int n, {int bots = 0, bool ready = true, bool packs = true}) {
    at = Duration.zero;
    s = Session(random: Random(1), clock: () => at)..tkobiTvReady = ready;
    if (packs) s.tkobiPacks = [pack('one'), pack('two')];
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
    if (bots > 0) s.setBotCount(bots);
  }

  int idOf(FakePeer p) => p.sent.whereType<Welcome>().first.playerId;

  testWidgets('the bundled packs load', (t) async {
    final packs = await loadTkobiPacks(rootBundle);
    expect(packs.map((p) => p.id).toSet(), {'tkobi-blago', 'tkobi-ljuto'});
    expect(packs.every((p) => p.prompts.length >= 30), isTrue);
  });

  test('refused with the soon text while the TV has no screens for it', () {
    setUpSession(3, ready: false);
    ps[0].say(const StartGame(GameKind.tkobi, null));
    expect(s.phase, Phase.lobby);
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.soon);
    s.dispose();
  });

  test('3 to 8 humans, no bots, only the host, a pack', () {
    setUpSession(2);
    ps[0].say(const StartGame(GameKind.tkobi, null));
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.tkobiNeedPlayers);
    s.dispose();
    setUpSession(3, bots: 1);
    ps[0].say(const StartGame(GameKind.tkobi, null));
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.noBots);
    s.dispose();
    setUpSession(3);
    ps[1].say(const StartGame(GameKind.tkobi, null));
    expect(s.phase, Phase.lobby);
    ps[0].say(const StartGame(GameKind.tkobi, null));
    expect(s.phase, Phase.tkobi);
    s.dispose();
    setUpSession(3, packs: false);
    ps[0].say(const StartGame(GameKind.tkobi, null));
    expect(ps[0].last<ErrorMsg>()!.message, Strings.packUnavailable);
    s.dispose();
  });

  test('the host\'s pack and prompt count are used; a missing saved pack falls back and keeps the other settings', () {
    setUpSession(3);
    ps[0].say(const SetSettings(GameSettings(tkobiOffPacks: {'one'}, tkobiPrompts: 5, blefQuestions: 10)));
    expect(s.settings.tkobiOffPacks, {'one'});
    ps[0].say(const SetSettings(GameSettings(tkobiOffPacks: {'gone'}, tkobiPrompts: 5, blefQuestions: 10)));
    expect(s.tickedPackIds(GameKind.tkobi), ['one', 'two'], reason: 'an id the TV does not have switches nothing off');
    expect([s.settings.tkobiPrompts, s.settings.blefQuestions], [5, 10]);
    ps[0].say(const SetSettings(GameSettings(tkobiOffPacks: {'one'}, tkobiPrompts: 5)));
    ps[0].say(const StartGame(GameKind.tkobi, null));
    expect(s.tkobi!.total, 5);
    expect(s.tkobi!.text, startsWith('two:'));
    expect(ps[1].last<LobbyState>()!.tkobiPacks.map((p) => p.id), ['one', 'two']);
    s.dispose();
  });

  test('a vote is the sending phone\'s own player and nobody learns who voted for whom', () {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.tkobi, null));
    ps[1].say(Vote(idOf(ps[2])));
    expect(s.tkobi!.votedCount, 1);
    expect(s.tkobi!.game.pickOf(idOf(ps[1])), idOf(ps[2]));
    for (final p in ps) {
      expect(p.sent.whereType<TkobiResult>(), isEmpty);
    }
    s.dispose();
  });

  test('a reload gets the public lobby, then the prompt with its own vote', () async {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.tkobi, null));
    ps[2].say(Vote(idOf(ps[0])));
    await ps[2].drop();
    final again = join(s, 'P2', token: 't2');
    final order = [for (final m in again.sent) m.type];
    expect(order.indexOf('lobby'), lessThan(order.indexOf('tkobiAsk')));
    expect(again.sent.whereType<TkobiAsk>().last.picked, idOf(ps[0]));
    s.dispose();
  });

  testWidgets('a finished game gives placement points and goes to the results', (t) async {
    setUpSession(3);
    ps[0].say(const SetSettings(GameSettings(tkobiPrompts: 5)));
    ps[0].say(const StartGame(GameKind.tkobi, null));
    for (var q = 0; q < 5; q++) {
      ps[0].say(Vote(idOf(ps[2])));
      ps[1].say(Vote(idOf(ps[2])));
      ps[2].say(Vote(idOf(ps[0]))); // the crowned one voted for someone else
      at += const Duration(seconds: 7);
      await t.pump(const Duration(seconds: 7));
    }
    expect(s.phase, Phase.results);
    expect(s.placements.last.playerId, idOf(ps[2]));
    expect(s.placements.last.gameScore, 0, reason: 'being crowned scores nothing; their own vote missed');
    expect(s.placements.first.gameScore, 5);
    expect(s.lastGameLabel, PartyText.tkobiName);
    s.returnToLobby();
    expect(s.tkobi, isNull);
    s.dispose();
  });

  test('a disconnect and a kick are dropping out', () async {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.tkobi, null));
    await ps[2].drop();
    expect(s.tkobi!.game.away, contains(idOf(ps[2])));
    ps[0].say(Kick(idOf(ps[1])));
    expect(s.tkobi!.game.away, contains(idOf(ps[1])));
    s.dispose();
  });
}
