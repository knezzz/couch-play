import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/packs/party_packs.dart';
import 'package:tv/session/koliko_match.dart';
import 'package:tv/session/party_text.dart';
import 'package:tv/session/session.dart';
import 'package:tv/strings.dart';

import 'session_test.dart' show FakePeer, join;

KolikoPack pack(String id) => KolikoPack(id, 'T $id', [for (var i = 0; i < 20; i++) KolikoQuestion('$id q$i?', 50.0 + i, 'm', null, 's')]);

/// Task 40: Koliko? inside the Session.
void main() {
  late Session s;
  late List<FakePeer> ps;
  var at = Duration.zero;

  void setUpSession(int n, {int bots = 0, bool ready = true, bool packs = true}) {
    at = Duration.zero;
    s = Session(random: Random(1), clock: () => at)..kolikoTvReady = ready;
    if (packs) s.kolikoPacks = [pack('one'), pack('two')];
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
    if (bots > 0) s.setBotCount(bots);
  }

  int idOf(FakePeer p) => p.sent.whereType<Welcome>().first.playerId;

  testWidgets('the bundled packs load', (t) async {
    final packs = await loadKolikoPacks(rootBundle);
    expect(packs.length, 4);
    expect(packs.every((p) => p.questions.length >= 15), isTrue);
  });

  test('refused with the soon text while the TV has no screens for it', () {
    setUpSession(3, ready: false);
    ps[0].say(const StartGame(GameKind.koliko, null));
    expect(s.phase, Phase.lobby);
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.soon);
    s.dispose();
  });

  test('2 to 8 humans, no bots, only the host, a pack', () {
    setUpSession(1);
    ps[0].say(const StartGame(GameKind.koliko, null));
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.kolikoNeedPlayers);
    s.dispose();
    setUpSession(2, bots: 1);
    ps[0].say(const StartGame(GameKind.koliko, null));
    expect(ps[0].last<ErrorMsg>()!.message, PartyText.noBots);
    s.dispose();
    setUpSession(2);
    ps[1].say(const StartGame(GameKind.koliko, null));
    expect(s.phase, Phase.lobby);
    ps[0].say(const StartGame(GameKind.koliko, null));
    expect(s.phase, Phase.koliko);
    s.dispose();
    setUpSession(2, packs: false);
    ps[0].say(const StartGame(GameKind.koliko, null));
    expect(ps[0].last<ErrorMsg>()!.message, Strings.packUnavailable);
    s.dispose();
  });

  test('the host\'s pack and question count are used; a missing saved pack falls back and keeps the other settings', () {
    setUpSession(2);
    ps[0].say(const SetSettings(GameSettings(kolikoPackId: 'two', kolikoQuestions: 5, kolikoSeconds: 20, objasniSeconds: 90)));
    expect(s.settings.kolikoOffPacks, {'one'}, reason: 'an old single id means only that pack');
    expect(s.settings.kolikoPackId, isNull);
    ps[0].say(const SetSettings(GameSettings(kolikoPackId: 'gone', kolikoQuestions: 5, objasniSeconds: 90)));
    expect(s.settings.kolikoPackId, isNull);
    expect([s.settings.kolikoQuestions, s.settings.objasniSeconds], [5, 90]);
    ps[0].say(const SetSettings(GameSettings(kolikoPackId: 'two', kolikoQuestions: 5)));
    ps[0].say(const StartGame(GameKind.koliko, null));
    expect(s.koliko!.pack.id, 'two');
    expect(s.koliko!.total, 5);
    expect(ps[1].last<LobbyState>()!.kolikoPacks.map((p) => p.id), ['one', 'two']);
    s.dispose();
  });

  test('a number from a phone is that phone\'s own player; the TV learns who answered', () {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.koliko, null));
    final m = s.koliko!;
    ps[1].say(const NumberAnswer(7));
    expect(m.answered, {idOf(ps[1])});
    expect(m.game.valueOf(idOf(ps[1])), 7);
    s.dispose();
  });

  test('a reload gets the public lobby, then the open question with its own number', () async {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.koliko, null));
    ps[2].say(const NumberAnswer(42));
    await ps[2].drop();
    final again = join(s, 'P2', token: 't2');
    final order = [for (final m in again.sent) m.type];
    expect(order.indexOf('lobby'), lessThan(order.indexOf('kolikoAsk')));
    expect(again.sent.whereType<KolikoAsk>().last.sent, 42);
    s.dispose();
  });

  testWidgets('a finished game gives placement points and goes to the results', (t) async {
    setUpSession(2);
    ps[0].say(const SetSettings(GameSettings(kolikoQuestions: 5)));
    ps[0].say(const StartGame(GameKind.koliko, null));
    final m = s.koliko!;
    for (var q = 0; q < 5; q++) {
      ps[0].say(NumberAnswer(m.game.current.answer));
      ps[1].say(NumberAnswer(m.game.current.answer + 5));
      at += const Duration(seconds: 8);
      await t.pump(const Duration(seconds: 8));
    }
    expect(s.phase, Phase.results);
    expect(s.placements.first.playerId, idOf(ps[0]));
    expect(s.placements.first.sessionPoints, 1);
    expect(s.lastGameLabel, PartyText.kolikoName);
    s.returnToLobby();
    expect(s.koliko, isNull);
    s.dispose();
  });

  test('a disconnect is dropping out and a kick too', () async {
    setUpSession(3);
    ps[0].say(const StartGame(GameKind.koliko, null));
    await ps[2].drop();
    expect(s.koliko!.game.away, contains(idOf(ps[2])));
    ps[0].say(Kick(idOf(ps[1])));
    expect(s.koliko!.game.away, contains(idOf(ps[1])));
    s.dispose();
  });
}
