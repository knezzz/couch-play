import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/packs/pack_store.dart';
import 'package:tv/server/game_server.dart';
import 'package:tv/session/session.dart';

class FakePeer implements PeerSocket {
  final _in = StreamController<Message>(sync: true);
  final sent = <Message>[];
  final _done = Completer<void>();
  bool closed = false;

  @override
  Stream<Message> get messages => _in.stream;
  @override
  void send(Message m) => sent.add(m);
  @override
  Future<void> get done => _done.future;
  @override
  void close() {
    closed = true;
    if (!_done.isCompleted) _done.complete();
  }

  void say(Message m) => _in.add(m);

  /// The phone vanishes (Wi-Fi lost): the socket reports done.
  Future<void> drop() async {
    if (!_done.isCompleted) _done.complete();
    await pumpEventQueue();
  }

  List<T> all<T extends Message>() => sent.whereType<T>().toList();
  T? last<T extends Message>() => all<T>().lastOrNull;
}

var _tokens = 0;

/// A phone joins. Returns its socket; the player id comes from the Welcome.
FakePeer join(Session s, String name, {String? token}) {
  final p = FakePeer();
  s.attach(p);
  p.say(Join(name, token ?? 'tok${_tokens++}'));
  return p;
}

int idOf(FakePeer p) => p.last<Welcome>()!.playerId;

const onlyHost = ErrorMsg('Only the host can do that.');
const full = ErrorMsg('The game is full (8 players).');

void main() {
  late Session s;
  late List<(GameKind, String?)> started;
  var clock = DateTime(2026, 11, 14, 12);

  setUp(() {
    clock = DateTime(2026, 11, 14, 12);
    started = [];
    s = Session(now: () => clock, random: Random(1));
    s.onStart = (k, p) => started.add((k, p));
  });

  // --- joining ---

  test('ping_gets_pong_before_joining', () {
    final p = FakePeer();
    s.attach(p);
    p.say(const Ping(7));
    expect(p.sent, [const Pong(7)]);
  });

  test('join_gets_welcome_and_lobby', () {
    final a = join(s, 'Ana', token: 'ta');
    final w = a.last<Welcome>()!;
    expect(w.colorIndex, 0);
    expect(w.token, 'ta');
    final lobby = a.last<LobbyState>()!;
    expect(lobby.hostId, w.playerId);
    expect(lobby.packs, isEmpty);
    expect(lobby.players.single.name, 'Ana');
    expect(s.players.single.connected, isTrue);
  });

  test('changes_is_bumped_on_every_change', () {
    var n = 0;
    s.changes.addListener(() => n++);
    final a = join(s, 'Ana');
    expect(n, greaterThan(0));
    final before = n;
    join(s, 'Bo');
    expect(n, greaterThan(before));
    a.say(const SetBots(1));
    expect(n, greaterThan(before + 1));
  });

  test('ninth_player_gets_full_error', () {
    final first = [for (var i = 0; i < 8; i++) join(s, 'P$i')];
    final ninth = join(s, 'Late');
    expect(ninth.sent, contains(full));
    expect(ninth.all<Welcome>(), isEmpty);
    expect(s.players.length, 8);
    expect(s.players.every((p) => p.connected), isTrue);
    expect(first.every((p) => p.all<ErrorMsg>().isEmpty), isTrue);
  });

  test('empty_or_blank_names_are_rejected', () {
    for (final bad in ['', '   ', ' \n\t ']) {
      final p = join(s, bad);
      expect(p.sent, contains(const ErrorMsg('Type a name to join.')), reason: '"$bad"');
      expect(p.all<Welcome>(), isEmpty);
    }
    expect(s.players, isEmpty);
  });

  test('names_are_trimmed_cut_and_deduped', () {
    join(s, '  Ana  ');
    join(s, 'Ana');
    join(s, 'ana');
    join(s, 'x' * 40);
    join(s, '😀' * 20);
    final names = [for (final p in s.players) p.name];
    expect(names.take(3), ['Ana', 'Ana 2', 'ana 3']);
    expect(names[3], 'x' * 16);
    expect(names[4].runes.length, 16); // plain emoji: one rune each
  });

  test('empty_token_is_rejected', () {
    final p = FakePeer();
    s.attach(p);
    p.say(const Join('Ana', ''));
    expect(p.all<Welcome>(), isEmpty);
    expect(p.all<ErrorMsg>(), isNotEmpty);
    expect(s.players, isEmpty);
  });

  test('second_join_on_the_same_socket_with_another_token_is_ignored', () {
    final a = join(s, 'Ana', token: 'ta');
    a.say(const Join('Evil', 'other'));
    expect(s.players.length, 1);
    expect(s.players.single.name, 'Ana');
  });

  test('colors_reuse_lowest_free_after_kick', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    join(s, 'C');
    expect([for (final p in s.players) p.colorIndex], [0, 1, 2]);
    a.say(Kick(idOf(b)));
    expect(b.last<Kicked>(), isNotNull);
    expect(b.closed, isTrue);
    final d = join(s, 'D');
    expect(d.last<Welcome>()!.colorIndex, 1);
  });

  // --- host ---

  test('first_player_is_host_and_host_passes_on_disconnect', () async {
    final a = join(s, 'A', token: 'ta');
    final b = join(s, 'B');
    join(s, 'C');
    expect(s.hostId, idOf(a));
    await a.drop();
    expect(s.hostId, idOf(b));
    expect(b.last<LobbyState>()!.hostId, idOf(b));
    // The host is the oldest connected player, so A is host again on return.
    final a2 = FakePeer();
    s.attach(a2);
    a2.say(const Join('A', 'ta'));
    expect(s.hostId, idOf(a));
  });

  test('host_is_null_and_minus_one_when_nobody_is_connected', () async {
    final a = join(s, 'A');
    final b = join(s, 'B');
    await a.drop();
    expect(s.hostId, idOf(b));
    await b.drop();
    expect(s.hostId, isNull);
  });

  test('non_host_start_rejected', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    b.say(const StartGame(GameKind.curve, null));
    expect(b.sent, contains(onlyHost));
    b.say(Kick(idOf(a)));
    b.say(const SetBots(2));
    expect(b.all<ErrorMsg>().where((e) => e == onlyHost).length, 3);
    expect(s.players.length, 2);
    expect(s.players.any((p) => p.bot), isFalse);
    expect(started, isEmpty);
    expect(s.phase, Phase.lobby);
  });

  test('messages_for_phones_only_are_ignored_when_sent_by_a_phone', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    final before = a.sent.length;
    for (final m in <Message>[
      const Welcome(99, 0, 'x'),
      const LobbyState(players: [], packs: [], hostId: 1),
      const QuizQuestion(1, 10, ['a', 'b', 'c', 'd'], 20),
      const QuizReveal(0, 0, 0),
      const CurveStatus(alive: true, score: 0, target: 10),
      const Results([]),
      const Effect('confetti'),
      const Pong(1),
      const Waiting('x'),
      const ErrorMsg('x'),
      const Kicked(),
    ]) {
      a.say(m);
    }
    expect(s.players.length, 2);
    expect(s.phase, Phase.lobby);
    expect(a.sent.length, before);
    expect(b.all<Kicked>(), isEmpty);
  });

  // --- kick ---

  test('kick_checks_the_player_id', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    a.say(const Kick(999));
    expect(a.sent.last, const ErrorMsg("That player isn't here."));
    a.say(Kick(idOf(a)));
    expect(a.sent.last, const ErrorMsg("You can't kick yourself."));
    expect(s.players.length, 2);
    a.say(Kick(idOf(b)));
    expect(s.players.length, 1);
    expect(b.closed, isTrue);
  });

  test('a_bot_can_be_kicked', () {
    final a = join(s, 'A');
    a.say(const SetBots(2));
    final bot = s.players.firstWhere((p) => p.bot);
    a.say(Kick(bot.id));
    expect(s.players.where((p) => p.bot).length, 1);
    expect(a.sent.whereType<ErrorMsg>(), isEmpty);
  });

  // --- reconnecting ---

  test('rejoin_with_token_restores_player', () async {
    final a = join(s, 'Ana', token: 'ta');
    final b = join(s, 'Bo');
    final idA = idOf(a);
    s.finishGame({idA: 5, idOf(b): 3}); // Ana gets 2 session points
    s.returnToLobby();
    final colorA = s.players.first.colorIndex;
    await a.drop();
    expect(s.players.first.connected, isFalse);

    final a2 = FakePeer();
    s.attach(a2);
    a2.say(const Join('Another name', 'ta'));
    final w = a2.last<Welcome>()!;
    expect(w.playerId, idA);
    expect(w.colorIndex, colorA);
    expect(w.token, 'ta');
    expect(s.players.length, 2);
    expect(s.players.first.name, 'Ana');
    expect(s.players.first.connected, isTrue);
    expect(s.sessionScores[idA], 2);
    expect(a2.last<LobbyState>()!.players.first.sessionScore, 2);
  });

  test('a_second_socket_with_the_same_token_replaces_the_first', () async {
    final a = join(s, 'Ana', token: 'ta');
    final a2 = FakePeer();
    s.attach(a2);
    a2.say(const Join('Ana', 'ta'));
    expect(a.closed, isTrue);
    expect(s.players.length, 1);
    await pumpEventQueue();
    expect(s.players.single.connected, isTrue); // the old socket closing does not undo it
    expect(s.players.single.socket, same(a2));
  });

  // --- bots ---

  test('host_sets_bots_clamped_to_eight', () {
    final a = join(s, 'A');
    join(s, 'B');
    a.say(const SetBots(20));
    expect(s.players.length, 8);
    expect(s.players.where((p) => p.bot).length, 6);
    a.say(const SetBots(2));
    final bots = s.players.where((p) => p.bot).toList();
    expect([for (final b in bots) b.name], ['Bot 1', 'Bot 2']);
    expect([for (final b in bots) b.colorIndex], [2, 3]);
    expect(bots.every((b) => b.token.isEmpty && b.socket == null && b.connected), isTrue);
    a.say(const SetBots(-3));
    expect(s.players.where((p) => p.bot), isEmpty);
    expect(a.last<LobbyState>()!.players.length, 2);
  });

  test('bot_numbers_fill_gaps_and_lobby_state_marks_bots', () {
    final a = join(s, 'A');
    a.say(const SetBots(3));
    final two = s.players.firstWhere((p) => p.name == 'Bot 2');
    a.say(Kick(two.id));
    a.say(const SetBots(3));
    expect([for (final p in s.players.where((p) => p.bot)) p.name],
        ['Bot 1', 'Bot 3', 'Bot 2']);
    expect(a.last<LobbyState>()!.players.where((p) => p.bot).length, 3);
  });

  test('non_host_set_bots_rejected', () {
    join(s, 'A');
    final b = join(s, 'B');
    b.say(const SetBots(3));
    expect(b.sent, contains(onlyHost));
    expect(s.players.where((p) => p.bot), isEmpty);
  });

  test('human_join_replaces_newest_bot_when_full', () {
    final a = join(s, 'A');
    join(s, 'B');
    a.say(const SetBots(6));
    expect(s.players.length, 8);
    final newest = s.players.last;
    expect(newest.name, 'Bot 6');
    final c = join(s, 'C');
    expect(c.all<Welcome>(), isNotEmpty);
    expect(c.sent, isNot(contains(full)));
    expect(s.players.length, 8);
    expect(s.players.where((p) => p.bot).length, 5);
    expect(s.players.any((p) => p.name == 'Bot 6'), isFalse);
    expect(c.last<Welcome>()!.colorIndex, newest.colorIndex);
  });

  test('bots_sit_out_quiz', () {
    final a = join(s, 'A');
    join(s, 'B');
    a.say(const SetBots(2));
    expect(s.participants(GameKind.quiz).every((p) => !p.bot), isTrue);
    expect(s.participants(GameKind.quiz).length, 2);
    expect(s.participants(GameKind.curve).length, 4);
  });

  test('disconnected_humans_are_not_participants', () async {
    final a = join(s, 'A');
    final b = join(s, 'B');
    join(s, 'C');
    await b.drop();
    expect(s.participants(GameKind.curve).map((p) => p.name), ['A', 'C']);
    expect(a.sent, isNotEmpty);
  });

  // --- starting games ---

  test('quiz_gets_an_error_when_switched_off', () {
    s.quizAvailable = false;
    final a = join(s, 'A');
    join(s, 'B');
    a.say(const StartGame(GameKind.quiz, null));
    expect(a.sent.last,
        const ErrorMsg("Quiz isn't ready yet. Pick Curve for now."));
    expect(s.phase, Phase.lobby);
    expect(started, isEmpty);
  });

  test('curve_needs_two_players', () {
    final a = join(s, 'A');
    a.say(const StartGame(GameKind.curve, null));
    expect(
        a.sent.last,
        const ErrorMsg(
            'Curve needs at least 2 players. Add a bot or ask a friend to join.'));
    expect(s.phase, Phase.lobby);
    expect(started, isEmpty);
    a.say(const SetBots(1));
    a.say(const StartGame(GameKind.curve, null));
    expect(s.phase, Phase.curve);
  });

  test('curve_start_builds_the_sim_with_names_and_colors', () {
    final a = join(s, 'Ana');
    final b = join(s, 'Bo');
    a.say(const SetBots(1));
    a.say(const StartGame(GameKind.curve, null));
    expect(s.phase, Phase.curve);
    expect(started, [(GameKind.curve, null)]);
    final sim = s.sim!;
    // Sim ids are the color indexes, so the renderer's color list lines up.
    expect(sim.names, {0: 'Ana', 1: 'Bo', 2: 'Bot 1'});
    expect(sim.heads.map((h) => h.id).toSet(), {0, 1, 2});
    expect(s.bots, isNotNull);
    expect(s.curveRound, 1);
    for (final p in [a, b]) {
      expect(p.last<CurveStatus>(), CurveStatus(alive: true, score: 0, target: sim.target));
    }
  });

  test('start_while_a_game_runs_is_refused', () {
    final a = join(s, 'A');
    a.say(const SetBots(1));
    a.say(const StartGame(GameKind.curve, null));
    started.clear();
    a.say(const StartGame(GameKind.curve, null));
    expect(a.sent.last, const ErrorMsg('A game is already running.'));
    expect(started, isEmpty);
    a.say(const SetBots(3));
    expect(a.sent.last, const ErrorMsg('Change the bots between games.'));
  });

  test('late_joiner_waits_until_lobby', () {
    final a = join(s, 'A');
    a.say(const SetBots(1));
    a.say(const StartGame(GameKind.curve, null));
    final c = join(s, 'Late');
    expect(c.sent, contains(const Waiting('Next game starts soon.')));
    expect(s.players.any((p) => p.name == 'Late'), isTrue);
    expect(s.sim!.names.values, isNot(contains('Late')));
    // Their steering goes nowhere.
    final before = s.sim!.heads.map((h) => h.heading).toList();
    c.say(const Steer(left: true, right: false));
    for (var i = 0; i < 200; i++) {
      s.sim!.tick();
    }
    expect(s.sim!.heads.map((h) => h.id), isNot(contains(idOf(c))));
    expect(before.length, 2);
    s.finishGame({for (final p in s.participants(GameKind.curve)) p.id: 0});
    s.returnToLobby();
    expect(c.last<LobbyState>(), isNotNull);
    expect(c.last<LobbyState>()!.players.map((p) => p.name), contains('Late'));
    expect(s.phase, Phase.lobby);
  });

  test('steer_reaches_the_sim', () {
    final a = join(s, 'A');
    a.say(const SetBots(1));
    a.say(const StartGame(GameKind.curve, null));
    final h0 = s.sim!.heads.firstWhere((h) => h.id == 0).heading;
    a.say(const Steer(left: true, right: false));
    for (var i = 0; i < 200; i++) {
      s.sim!.tick(); // countdown, then play
    }
    expect((s.sim!.heads.firstWhere((h) => h.id == 0).heading - h0).abs(), greaterThan(0.5));
  });

  // --- curve disconnects and ending ---

  test('curve_disconnect_kills_player', () async {
    final a = join(s, 'A');
    final b = join(s, 'B');
    join(s, 'C');
    a.say(const StartGame(GameKind.curve, null));
    expect(s.phase, Phase.curve);
    await b.drop();
    final heads = {for (final h in s.sim!.heads) h.id: h.alive};
    expect(heads[1], isFalse); // B had color 1
    expect(heads[0], isTrue);
    expect(heads[2], isTrue);
    expect(s.phase, Phase.curve); // two are still racing
    // B stays dead if they come back mid-match, and learns the state.
    final b2 = FakePeer();
    s.attach(b2);
    b2.say(Join('B', s.players[1].token));
    expect(b2.last<Welcome>(), isNotNull);
    expect(b2.last<CurveStatus>()!.alive, isFalse);
    expect(s.sim!.heads.firstWhere((h) => h.id == 1).alive, isFalse);
  });

  test('curve_ends_at_once_when_one_player_is_left', () async {
    final a = join(s, 'A');
    final b = join(s, 'B');
    a.say(const StartGame(GameKind.curve, null)); // only 2 humans
    expect(s.phase, Phase.curve);
    await b.drop();
    expect(s.phase, Phase.results);
    expect(a.last<Results>(), isNotNull);
    expect(s.sessionScores[idOf(a)], greaterThan(0));
  });

  test('curve_ends_when_no_human_is_connected_even_with_bots', () async {
    final a = join(s, 'A');
    a.say(const SetBots(3));
    a.say(const StartGame(GameKind.curve, null));
    expect(s.phase, Phase.curve);
    await a.drop();
    expect(s.phase, Phase.results);
  });

  test('kicking_a_player_mid_match_kills_them', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    join(s, 'C');
    a.say(const StartGame(GameKind.curve, null));
    a.say(Kick(idOf(b)));
    expect(s.sim!.heads.firstWhere((h) => h.id == 1).alive, isFalse);
    expect(s.players.any((p) => p.name == 'B'), isFalse);
    expect(s.phase, Phase.curve);
  });

  test('round_over_updates_phones_and_next_round_restarts', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    a.say(const StartGame(GameKind.curve, null));
    final sim = s.sim!;
    sim.scores[0] = 4;
    sim.roundOver = true;
    s.curveEvents([RoundOver(0)]);
    expect(a.last<CurveStatus>()!.score, 4);
    expect(b.last<CurveStatus>()!.score, 0);
    s.nextRound();
    expect(sim.roundOver, isFalse);
    expect(s.curveRound, 2);
    expect(a.last<CurveStatus>()!.alive, isTrue);
  });

  test('death_tells_that_phone', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    a.say(const StartGame(GameKind.curve, null));
    s.curveEvents([Died(1)]);
    expect(b.last<CurveStatus>()!.alive, isFalse);
    expect(a.last<CurveStatus>()!.alive, isTrue);
  });

  test('match_over_finishes_the_game_with_placement_points', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    a.say(const SetBots(1));
    a.say(const StartGame(GameKind.curve, null));
    final sim = s.sim!;
    sim.scores
      ..[0] = 20
      ..[1] = 7
      ..[2] = 12;
    sim.matchOver = true;
    s.curveEvents([RoundOver(0), MatchOver(0)]);
    expect(s.phase, Phase.results);
    final bot = s.players.firstWhere((p) => p.bot);
    // 1st gets N=3 points, 2nd 2, 3rd 1; the bot is on the scoreboard too.
    expect(s.sessionScores[idOf(a)], 3);
    expect(s.sessionScores[bot.id], 2);
    expect(s.sessionScores[idOf(b)], 1);
    final res = a.last<Results>()!;
    expect(res.placements.map((p) => p.playerId), [idOf(a), bot.id, idOf(b)]);
    expect(b.last<Results>(), isNotNull);
    s.returnToLobby();
    expect(s.phase, Phase.lobby);
    expect(s.sim, isNull);
    expect(a.last<LobbyState>()!.players.map((p) => p.sessionScore), [3, 1, 2]);
  });

  test('finish_game_scores_add_up_across_games', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    s.finishGame({idOf(a): 1, idOf(b): 9});
    s.returnToLobby();
    s.finishGame({idOf(a): 5, idOf(b): 5});
    expect(s.sessionScores[idOf(a)], 1 + 2);
    expect(s.sessionScores[idOf(b)], 2 + 2);
  });

  // --- housekeeping ---

  test('disconnected_lobby_player_is_removed_after_ten_minutes', () async {
    final a = join(s, 'A');
    final b = join(s, 'B');
    final bToken = s.players[1].token;
    await b.drop();
    clock = clock.add(const Duration(minutes: 9, seconds: 59));
    s.purgeStale();
    expect(s.players.length, 2);
    clock = clock.add(const Duration(seconds: 2));
    s.purgeStale();
    expect(s.players.map((p) => p.name), ['A']);
    expect(s.sessionScores.containsKey(idOf(b)), isFalse);
    expect(a.last<LobbyState>()!.players.length, 1);
    // Their token is forgotten: coming back with it makes a new player.
    final b2 = FakePeer();
    s.attach(b2);
    b2.say(Join('B', bToken));
    expect(s.players.length, 2);
    expect(b2.last<Welcome>()!.playerId, isNot(idOf(b)));
  });

  test('purge_leaves_players_alone_during_a_game', () async {
    final a = join(s, 'A');
    final b = join(s, 'B');
    final c = join(s, 'C');
    a.say(const StartGame(GameKind.curve, null));
    await c.drop();
    clock = clock.add(const Duration(minutes: 30));
    s.purgeStale();
    expect(s.players.length, 3);
    expect(b.sent, isNotEmpty);
  });

  test('join_hint_shows_the_url_or_the_wifi_text', () {
    expect(s.joinHint, 'Connect the TV to Wi-Fi to play.');
    s.joinUrl = 'http://192.168.1.20:8080/';
    expect(s.joinHint, 'http://192.168.1.20:8080/');
  });

  test('lobby_state_goes_to_every_connected_human_on_a_change', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    join(s, 'C');
    expect(a.last<LobbyState>()!.players.length, 3);
    expect(b.last<LobbyState>()!.players.length, 3);
    a.say(const SetBots(2));
    expect(b.last<LobbyState>()!.players.length, 5);
  });
  // --- effects on the phones ---

  test('finish_game_sends_confetti_only_to_the_winners_ties_included', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    final c = join(s, 'C');
    s.finishGame({idOf(a): 9, idOf(b): 9, idOf(c): 5});
    expect(a.all<Effect>(), [const Effect('confetti')]);
    expect(b.all<Effect>(), [const Effect('confetti')]);
    expect(c.all<Effect>(), isEmpty);
  });

  test('a bot winner does not break finish_game', () {
    final a = join(s, 'A');
    a.say(const SetBots(1));
    final bot = s.players.firstWhere((p) => p.bot);
    s.finishGame({idOf(a): 1, bot.id: 9});
    expect(a.all<Effect>(), isEmpty);
  });

  test('curve_death_sends_a_color_pulse_to_that_phone_only', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    a.say(const StartGame(GameKind.curve, null));
    s.curveEvents([Died(1)]);
    expect(b.all<Effect>(), [const Effect('colorPulse')]);
    expect(a.all<Effect>(), isEmpty);
  });

  test('a bot dying sends no effect to anyone', () {
    final a = join(s, 'A');
    final b = join(s, 'B');
    a.say(const SetBots(1));
    a.say(const StartGame(GameKind.curve, null));
    s.curveEvents([Died(2)]); // the bot's color index
    expect(a.all<Effect>(), isEmpty);
    expect(b.all<Effect>(), isEmpty);
  });

  test('placements_are_kept_for_the_results_screen', () {
    final a = join(s, 'A');
    expect(s.placements, isEmpty);
    s.finishGame({idOf(a): 1});
    expect(s.placements.map((p) => p.playerId), [idOf(a)]);
    s.returnToLobby();
    expect(s.placements, isEmpty);
  });


  // --- pack upload ---

  group('pack upload', () {
    late Directory dir;
    setUp(() async {
      dir = Directory.systemTemp.createTempSync('upload');
      s.packStore = await PackStore.load(bundled: [], userDir: dir);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Uint8List bytes({String id = 'world-flags', String title = 'World Flags', int n = 40}) =>
        Uint8List.fromList(utf8.encode(jsonEncode({
          'format': 1,
          'id': id,
          'title': title,
          'questions': [
            for (var i = 0; i < n; i++) {'q': 'q$i', 'choices': ['a', 'b', 'c', 'd'], 'answer': 0},
          ],
        })));

    test('non_host_upload_rejected', () async {
      join(s, 'Ana', token: 'ta');
      join(s, 'Bea', token: 'tb');
      for (final token in ['tb', 'nobody', '']) {
        final r = await s.onPackUpload(token, bytes());
        expect(r.ok, isFalse, reason: token);
        expect(r.message, 'Only the host can add packs.');
      }
      expect(s.packStore!.infos, isEmpty);
      expect(dir.listSync(), isEmpty);
    });

    test('host_upload_rebroadcasts_the_lobby_with_the_pack', () async {
      final a = join(s, 'Ana', token: 'ta');
      final b = join(s, 'Bea', token: 'tb');
      final r = await s.onPackUpload('ta', bytes());
      expect(r.ok, isTrue);
      expect(r.message, 'Added World Flags (40 questions).');
      const want = [PackInfo('world-flags', 'World Flags', 40)];
      expect(a.last<LobbyState>()!.packs, want);
      expect(b.last<LobbyState>()!.packs, want);
    });

    test('quiz_plays_the_uploaded_pack_by_id', () async {
      final a = join(s, 'Ana', token: 'ta');
      await s.onPackUpload('ta', bytes(n: 1));
      a.say(const StartGame(GameKind.quiz, 'world-flags'));
      expect(a.last<QuizQuestion>()!.total, 1);
      expect(s.quiz!.current.q, 'q0');
      s.dispose();
    });

    test('a one-question pack reads right', () async {
      join(s, 'Ana', token: 'ta');
      final r = await s.onPackUpload('ta', bytes(n: 1));
      expect(r.message, 'Added World Flags (1 question).');
    });

    test('the_error_text_is_passed_through', () async {
      final a = join(s, 'Ana', token: 'ta');
      final before = a.all<LobbyState>().length;
      final r = await s.onPackUpload('ta', Uint8List.fromList(utf8.encode('nope')));
      expect(r.ok, isFalse);
      expect(r.message, "The pack isn't valid JSON.");
      expect(a.all<LobbyState>().length, before); // nothing changed, nothing sent
    });

    test('later lobby broadcasts carry the stored packs', () async {
      join(s, 'Ana', token: 'ta');
      await s.onPackUpload('ta', bytes());
      final b = join(s, 'Bea', token: 'tb');
      expect(b.last<LobbyState>()!.packs.map((p) => p.id), ['world-flags']);
    });

    test('without a store, uploads say so', () async {
      final bare = Session();
      final a = FakePeer();
      bare.attach(a);
      a.say(const Join('Ana', 'ta'));
      final r = await bare.onPackUpload('ta', bytes());
      expect(r.ok, isFalse);
      expect(r.message, 'Packs are not available yet.');
    });
  });
}
