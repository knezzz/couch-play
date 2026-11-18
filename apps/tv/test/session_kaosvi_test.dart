import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/kaosvi_match.dart';
import 'package:tv/session/party_text.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer, join;

KaosviPack pack(String id) => KaosviPack(id, 'T $id', [for (var i = 0; i < 25; i++) '$id: navedi $i.']);

/// Task 43: Kao svi inside the Session.
void main() {
  late Session s;
  late List<FakePeer> ps;
  var at = Duration.zero;

  void setUpSession(int n, {int bots = 0, bool ready = true, bool packs = true}) {
    at = Duration.zero;
    s = Session(random: Random(1), clock: () => at)..kaosviTvReady = ready;
    if (packs) s.kaosviPacks = [pack('one'), pack('two')];
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
    if (bots > 0) s.setBotCount(bots);
  }

  int idOf(FakePeer p) => p.sent.whereType<Welcome>().first.playerId;

  test('refused with the soon text while the TV has no screens for it', () {
    setUpSession(3, ready: false);
    ps[0].say(const StartGame(GameKind.kaosvi, null));
    expect(s.phase, Phase.lobby);
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.soon);
    s.dispose();
  });

  test('3 to 8 humans, no bots, only the host, a pack', () {
    setUpSession(2);
    ps[0].say(const StartGame(GameKind.kaosvi, null));
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.kaosviNeedPlayers);
    s.dispose();
    setUpSession(3, bots: 1);
    ps[0].say(const StartGame(GameKind.kaosvi, null));
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.noBots);
    s.dispose();
    setUpSession(3);
    ps[1].say(const StartGame(GameKind.kaosvi, null));
    expect(s.phase, Phase.lobby);
    ps[0].say(const StartGame(GameKind.kaosvi, null));
    expect(s.phase, Phase.kaosvi);
    s.dispose();
    setUpSession(3, packs: false);
    ps[0].say(const StartGame(GameKind.kaosvi, null));
    expect(ps[0].last<ErrorMsg>()!.message, Strings.packUnavailable);
    s.dispose();
  });

  test('the host\'s pack, question count and target are used; a missing saved pack falls back and keeps the other settings', () {
    setUpSession(3);
    ps[0].say(const SetSettings(GameSettings(kaosviPackId: 'two', kaosviQuestions: 8, kaosviTarget: 5, tkobiPrompts: 15)));
    expect(s.settings.kaosviOffPacks, {'one'}, reason: 'an old single id means only that pack');
    expect(s.settings.kaosviPackId, isNull);
    ps[0].say(const SetSettings(GameSettings(kaosviPackId: 'gone', kaosviQuestions: 8, kaosviTarget: 5, tkobiPrompts: 15)));
    expect(s.settings.kaosviPackId, isNull);
    expect([s.settings.kaosviQuestions, s.settings.kaosviTarget, s.settings.tkobiPrompts], [8, 5, 15]);
    ps[0].say(const SetSettings(GameSettings(kaosviPackId: 'two', kaosviQuestions: 8, kaosviTarget: 5)));
    ps[0].say(const StartGame(GameKind.kaosvi, null));
    expect(s.kaosvi!.total, 8);
    expect(s.kaosvi!.target, 5);
    expect(s.kaosvi!.q, startsWith('two:'));
    expect(ps[1].last<LobbyState>()!.kaosviPacks.map((p) => p.id), ['one', 'two']);
    s.dispose();
  });

  test('an answer is the sending phone\'s own player; only the HOST\'s merge and Gotovo count', () {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.kaosvi, null));
    final m = s.kaosvi!;
    ps[0].say(const KaosviAnswer('jabuka'));
    ps[1].say(const KaosviAnswer('Jabuka'));
    expect(m.sent, {idOf(ps[0]), idOf(ps[1])});
    ps[2].say(const KaosviAnswer('kruška'));
    expect(m.stage, KaosviStageTv.merge);
    final groups = ps[0].sent.whereType<KaosviMerging>().last.groups;
    expect(groups.length, 2);
    expect(ps[1].sent.whereType<KaosviMerging>().last.groups, isEmpty);
    ps[1].say(KaosviMerge(groups[0].id, groups[1].id));
    expect(m.game.groups.length, 2, reason: 'not the host');
    ps[1].say(const KaosviDone());
    expect(m.stage, KaosviStageTv.merge);
    ps[0].say(KaosviMerge(groups[0].id, groups[1].id));
    expect(m.game.groups.length, 1);
    ps[0].say(const KaosviDone());
    expect(m.stage, KaosviStageTv.reveal);
    s.dispose();
  });

  test('a reload gets the public lobby, then the open question with its own answer', () async {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.kaosvi, null));
    ps[2].say(const KaosviAnswer('moj'));
    await ps[2].drop();
    final again = join(s, 'P2', token: 't2');
    final order = [for (final m in again.sent) m.type];
    expect(order.indexOf('lobby'), lessThan(order.indexOf('kaosviAsk')));
    expect(again.sent.whereType<KaosviAsk>().last.sent, 'moj');
    s.dispose();
  });

  testWidgets('a finished game gives placement points and goes to the results', (t) async {
    setUpSession(3);
    ps[0].say(const SetSettings(GameSettings(kaosviQuestions: 8, kaosviTarget: 5)));
    ps[0].say(const StartGame(GameKind.kaosvi, null));
    for (var q = 0; q < 5; q++) {
      ps[0].say(const KaosviAnswer('a'));
      ps[1].say(const KaosviAnswer('a'));
      ps[2].say(const KaosviAnswer('b'));
      ps[0].say(const KaosviDone());
      at += const Duration(seconds: 8);
      await t.pump(const Duration(seconds: 8));
    }
    expect(s.phase, Phase.results);
    expect(s.placements.first.gameScore, 5);
    expect(s.placements.last.gameScore, 0);
    expect(s.lastGameLabel, PartyText.kaosviName);
    s.returnToLobby();
    expect(s.kaosvi, isNull);
    s.dispose();
  });

  test('a disconnect and a kick are dropping out', () async {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.kaosvi, null));
    await ps[2].drop();
    expect(s.kaosvi!.game.away, contains(idOf(ps[2])));
    ps[0].say(Kick(idOf(ps[1])));
    expect(s.kaosvi!.game.away, contains(idOf(ps[1])));
    s.dispose();
  });
}
