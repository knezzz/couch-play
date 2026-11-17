import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/packs/party_packs.dart';
import 'package:tv/session/blef_match.dart';
import 'package:tv/session/party_text.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer, join;

BlefPack pack(String id) => BlefPack(id, 'T $id', [for (var i = 0; i < 12; i++) BlefQuestion('$id q$i?', 'Istina$i', 's')]);

/// Task 41: Blef inside the Session.
void main() {
  late Session s;
  late List<FakePeer> ps;
  var at = Duration.zero;

  void setUpSession(int n, {int bots = 0, bool ready = true, bool packs = true}) {
    at = Duration.zero;
    s = Session(random: Random(1), clock: () => at)..blefTvReady = ready;
    if (packs) s.blefPacks = [pack('one'), pack('two')];
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
    if (bots > 0) s.setBotCount(bots);
  }

  int idOf(FakePeer p) => p.sent.whereType<Welcome>().first.playerId;

  testWidgets('the bundled packs load', (t) async {
    final packs = await loadBlefPacks(rootBundle);
    expect(packs.length, 2);
    expect(packs.every((p) => p.questions.length >= 10), isTrue);
  });

  test('refused with the soon text while the TV has no screens for it', () {
    setUpSession(3, ready: false);
    ps[0].say(const StartGame(GameKind.blef, null));
    expect(s.phase, Phase.lobby);
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.soon);
    s.dispose();
  });

  test('3 to 8 humans, no bots, only the host, a pack', () {
    setUpSession(2);
    ps[0].say(const StartGame(GameKind.blef, null));
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.blefNeedPlayers);
    s.dispose();
    setUpSession(3, bots: 1);
    ps[0].say(const StartGame(GameKind.blef, null));
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.noBots);
    s.dispose();
    setUpSession(3);
    ps[1].say(const StartGame(GameKind.blef, null));
    expect(s.phase, Phase.lobby);
    ps[0].say(const StartGame(GameKind.blef, null));
    expect(s.phase, Phase.blef);
    s.dispose();
    setUpSession(3, packs: false);
    ps[0].say(const StartGame(GameKind.blef, null));
    expect(ps[0].last<ErrorMsg>()!.message, Strings.packUnavailable);
    s.dispose();
  });

  test('the host\'s pack and question count are used; a missing saved pack falls back and keeps the other settings', () {
    setUpSession(3);
    ps[0].say(const SetSettings(GameSettings(blefPackId: 'two', blefQuestions: 5, kolikoQuestions: 15)));
    expect(s.settings.blefPackId, 'two');
    ps[0].say(const SetSettings(GameSettings(blefPackId: 'gone', blefQuestions: 5, kolikoQuestions: 15)));
    expect(s.settings.blefPackId, isNull);
    expect([s.settings.blefQuestions, s.settings.kolikoQuestions], [5, 15]);
    ps[0].say(const SetSettings(GameSettings(blefPackId: 'two', blefQuestions: 5)));
    ps[0].say(const StartGame(GameKind.blef, null));
    expect(s.blef!.total, 5);
    expect(ps[1].last<LobbyState>()!.blefPacks.map((p) => p.id), ['one', 'two']);
    s.dispose();
  });

  test('a fake and a pick are the sending phone\'s own player; the true answer is refused to that phone only', () {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.blef, null));
    final m = s.blef!;
    final truth = m.game.current.answer;
    ps[1].say(BlefFake(truth));
    expect(ps[1].last<ErrorMsg>()!.message, BlefText.truth);
    expect(ps[0].sent.whereType<ErrorMsg>().where((e) => e.message == BlefText.truth), isEmpty);
    ps[1].say(const BlefFake('Moja laž'));
    expect(m.sent, {idOf(ps[1])});
    ps[0].say(const BlefFake('a'));
    ps[2].say(const BlefFake('b'));
    expect(m.stage, BlefStageTv.pick);
    final l = ps[1].sent.whereType<BlefList>().single;
    ps[1].say(BlefPick(l.ids.first));
    expect(m.picked, {idOf(ps[1])});
    s.dispose();
  });

  test('a reload gets the public lobby, then the question with its own sent fake', () async {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.blef, null));
    ps[2].say(const BlefFake('Tajna'));
    await ps[2].drop();
    final again = join(s, 'P2', token: 't2');
    final order = [for (final m in again.sent) m.type];
    expect(order.indexOf('lobby'), lessThan(order.indexOf('blefWrite')));
    expect(again.sent.whereType<BlefWrite>().last.sent, 'Tajna');
    s.dispose();
  });

  testWidgets('a finished game gives placement points and goes to the results', (t) async {
    setUpSession(3);
    ps[0].say(const SetSettings(GameSettings(blefQuestions: 5)));
    ps[0].say(const StartGame(GameKind.blef, null));
    final m = s.blef!;
    for (var q = 0; q < 5; q++) {
      for (final p in ps) {
        p.say(BlefFake('laž ${idOf(p)}'));
      }
      final truthId = m.game.entries.indexWhere((e) => e.isTruth);
      for (final p in ps) {
        final l = p.sent.whereType<BlefList>().last;
        p.say(BlefPick(idOf(p) == idOf(ps[0]) && l.ids.contains(truthId) ? truthId : l.ids.last));
      }
      at += const Duration(seconds: 20);
      await t.pump(const Duration(seconds: 20));
    }
    expect(s.phase, Phase.results);
    expect(s.placements.length, 3);
    expect(s.lastGameLabel, PartyText.blefName);
    s.returnToLobby();
    expect(s.blef, isNull);
    s.dispose();
  });

  test('a disconnect and a kick are dropping out', () async {
    setUpSession(4);
    ps[0].say(const StartGame(GameKind.blef, null));
    await ps[2].drop();
    expect(s.blef!.game.away, contains(idOf(ps[2])));
    ps[0].say(Kick(idOf(ps[1])));
    expect(s.blef!.game.away, contains(idOf(ps[1])));
    s.dispose();
  });
}
