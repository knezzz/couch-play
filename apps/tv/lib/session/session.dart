import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

import '../server/game_server.dart';
import 'bots.dart';

enum Phase { lobby, quiz, curve, results }

/// Shown by the TV lobby instead of the join URL when there is no network.
const noWifiText = 'Connect the TV to Wi-Fi to play.';

const maxPlayers = 8;
const _staleAfter = Duration(minutes: 10);

const _onlyHost = ErrorMsg('Only the host can do that.');
const _full = ErrorMsg('The game is full (8 players).');
const _waiting = Waiting('Next game starts soon.');

class Player {
  Player(this.id, this.name, this.colorIndex, {this.token = '', this.bot = false});

  /// Stable for the whole session. Bots and humans share one id space.
  final int id;
  String name;

  /// 0..7, unique among current players; the lowest free one when handed out.
  int colorIndex;

  /// Empty for bots.
  final String token;
  final bool bot;
  bool connected = true;
  PeerSocket? socket;
  DateTime? disconnectedAt;
}

/// The lobby and the session around the games: who is here, who is host, the
/// scoreboard, and which game is on. Pure Dart apart from [changes], so tests
/// drive it with fake [PeerSocket]s.
///
/// Curve: [onStart] fires after Session has built [sim] and [bots] from the
/// connected humans and the bots. The TV builds a `CurveGame` from them, passes
/// [curveEvents] as its `onEvents`, and calls [nextRound] 2 s after a RoundOver.
/// The sim's player ids are the players' color indexes (unique, 0..7), so the
/// renderer's color list lines up with [playerColors].
class Session {
  Session({DateTime Function()? now, Random? random})
      : _now = now ?? DateTime.now,
        _random = random ?? Random();

  final DateTime Function() _now;
  final Random _random;

  final _players = <Player>[];
  final _scores = <int, int>{};
  var _nextId = 1;
  var _phase = Phase.lobby;

  /// Bumped on every change, for UI rebuilds.
  final ValueNotifier<int> _changes = ValueNotifier(0);
  ValueListenable<int> get changes => _changes;

  /// Called when the host starts a game, after the session is ready for it.
  void Function(GameKind kind, String? packId)? onStart;

  /// Task 11 turns this on. Until then StartGame(quiz) gets an ErrorMsg.
  bool quizAvailable = false;

  /// What the TV lobby shows as the join address; null means no network
  /// ([noWifiText]).
  String? joinUrl;
  String get joinHint => joinUrl ?? noWifiText;

  void dispose() => _changes.dispose();

  void _notify() => _changes.value++;

  // --- who is here ---

  /// Everyone in the session in join order: humans and bots.
  List<Player> get players => List.unmodifiable(_players);

  /// The same, as sent to phones (and what the TV lobby draws).
  List<PlayerInfo> get playerInfos => [
        for (final p in _players)
          PlayerInfo(p.id, p.name, p.colorIndex, p.connected, _scores[p.id] ?? 0,
              bot: p.bot),
      ];

  /// The oldest connected human, so the role passes on when the host drops and
  /// goes back to them if they return. Null if no human is connected.
  int? get hostId {
    for (final p in _players) {
      if (!p.bot && p.connected) return p.id;
    }
    return null;
  }

  Phase get phase => _phase;

  /// Session points per player id.
  Map<int, int> get sessionScores => Map.unmodifiable(_scores);

  /// Who plays [kind] if it started now: Curve takes connected humans and bots,
  /// Quiz only connected humans.
  List<Player> participants(GameKind kind) => [
        for (final p in _players)
          if (kind == GameKind.curve ? (p.bot || p.connected) : (!p.bot && p.connected)) p,
      ];

  Player? _byId(int id) => _players.where((p) => p.id == id).firstOrNull;
  Player? _playerOf(PeerSocket s) => _players.where((p) => p.socket == s).firstOrNull;

  int _lowestFreeColor() {
    final used = {for (final p in _players) p.colorIndex};
    var c = 0;
    while (used.contains(c)) {
      c++;
    }
    return c;
  }

  // --- phones ---

  /// A phone's socket. The session reads its messages and tracks its close.
  void attach(PeerSocket p) {
    p.messages.listen((m) => _onMessage(p, m), onError: (_) {});
    p.done.then((_) => _onClosed(p));
  }

  void _onMessage(PeerSocket peer, Message m) {
    switch (m) {
      case Ping(:final t):
        peer.send(Pong(t));
      case Join(:final name, :final token):
        _join(peer, name, token);
      case Steer(:final left, :final right):
        final p = _playerOf(peer);
        if (p != null) _steer(p, left, right);
      case StartGame(:final game, :final packId):
        _start(peer, game, packId);
      case Kick(:final playerId):
        _kick(peer, playerId);
      case SetBots(:final count):
        _setBots(peer, count);
      default:
        // Answer waits for Task 11. Everything else is a TV-to-phone type;
        // a phone has no business sending it.
        break;
    }
  }

  void _join(PeerSocket peer, String rawName, String token) {
    if (token.isEmpty || token.length > 64) {
      peer.send(const ErrorMsg('Reload the page and try again.'));
      return;
    }
    final attached = _playerOf(peer);
    if (attached != null && attached.token != token) return;
    final existing = _players.where((p) => !p.bot && p.token == token).firstOrNull;
    if (existing != null) {
      _reattach(existing, peer);
      return;
    }
    final name = cleanName(rawName);
    if (name == null) {
      peer.send(const ErrorMsg('Type a name to join.'));
      return;
    }
    if (_players.length >= maxPlayers) {
      // A human takes the newest bot's seat, but only between games.
      final bot = _phase == Phase.lobby ? _players.where((p) => p.bot).lastOrNull : null;
      if (bot == null) {
        peer.send(_full);
        return;
      }
      _remove(bot);
    }
    final p = Player(
        _nextId++, dedupeName(name, _players.map((p) => p.name)), _lowestFreeColor(),
        token: token)
      ..socket = peer;
    _players.add(p);
    _scores[p.id] = 0;
    peer.send(Welcome(p.id, p.colorIndex, token));
    if (_phase == Phase.lobby) {
      _broadcastLobby();
    } else {
      peer.send(_waiting);
    }
    _notify();
  }

  void _reattach(Player p, PeerSocket peer) {
    final old = p.socket;
    p.socket = peer;
    p.connected = true;
    p.disconnectedAt = null;
    if (old != null && old != peer) old.close();
    peer.send(Welcome(p.id, p.colorIndex, p.token));
    switch (_phase) {
      case Phase.lobby:
        _broadcastLobby();
      case Phase.curve:
        final status = _statusFor(p);
        peer.send(status ?? _waiting);
      case Phase.quiz:
      case Phase.results:
        peer.send(_waiting);
    }
    _notify();
  }

  void _onClosed(PeerSocket peer) {
    final p = _playerOf(peer);
    if (p == null) return;
    p.socket = null;
    p.connected = false;
    p.disconnectedAt = _now();
    _dropFromGame(p);
    if (_phase == Phase.lobby) _broadcastLobby();
    _notify();
    _checkCurveEnd();
  }

  void _broadcastLobby() {
    final lobby = LobbyState(players: playerInfos, packs: const [], hostId: hostId ?? -1);
    for (final p in _players) {
      p.socket?.send(lobby);
    }
  }

  /// A lobby player who stayed away for more than 10 minutes is dropped.
  /// Call it every so often (the TV does, once a minute).
  void purgeStale() {
    if (_phase != Phase.lobby) return;
    final now = _now();
    final stale = [
      for (final p in _players)
        if (!p.bot &&
            !p.connected &&
            p.disconnectedAt != null &&
            now.difference(p.disconnectedAt!) > _staleAfter)
          p,
    ];
    if (stale.isEmpty) return;
    stale.forEach(_remove);
    _broadcastLobby();
    _notify();
  }

  void _remove(Player p) {
    _dropFromGame(p);
    _players.remove(p);
    _scores.remove(p.id);
  }

  // --- host actions ---

  void _start(PeerSocket peer, GameKind game, String? packId) {
    final from = _playerOf(peer);
    if (from == null) return;
    if (from.id != hostId) {
      peer.send(_onlyHost);
      return;
    }
    if (_phase != Phase.lobby) {
      peer.send(const ErrorMsg('A game is already running.'));
      return;
    }
    switch (game) {
      case GameKind.quiz:
        if (!quizAvailable) {
          peer.send(const ErrorMsg("Quiz isn't ready yet. Pick Curve for now."));
          return;
        }
        _phase = Phase.quiz;
        _notify();
        onStart?.call(game, packId);
      case GameKind.curve:
        final parts = participants(GameKind.curve);
        if (parts.length < 2) {
          peer.send(const ErrorMsg(
              'Curve needs at least 2 players. Add a bot or ask a friend to join.'));
          return;
        }
        _startCurve(parts);
        onStart?.call(game, packId);
    }
  }

  void _kick(PeerSocket peer, int playerId) {
    final from = _playerOf(peer);
    if (from == null) return;
    if (from.id != hostId) {
      peer.send(_onlyHost);
      return;
    }
    final target = _byId(playerId);
    if (target == null) {
      peer.send(const ErrorMsg("That player isn't here."));
      return;
    }
    if (target.id == from.id) {
      peer.send(const ErrorMsg("You can't kick yourself."));
      return;
    }
    final socket = target.socket;
    _remove(target); // bots can be kicked too
    socket?.send(const Kicked());
    socket?.close();
    if (_phase == Phase.lobby) _broadcastLobby();
    _notify();
    _checkCurveEnd();
  }

  void _setBots(PeerSocket peer, int count) {
    final from = _playerOf(peer);
    if (from == null) return;
    if (from.id != hostId) {
      peer.send(_onlyHost);
      return;
    }
    if (_phase != Phase.lobby) {
      peer.send(const ErrorMsg('Change the bots between games.'));
      return;
    }
    final humans = _players.where((p) => !p.bot).length;
    final want = count.clamp(0, maxPlayers - humans);
    var bots = _players.where((p) => p.bot).toList();
    while (bots.length > want) {
      _remove(bots.removeLast()); // the newest goes first
    }
    while (bots.length < want) {
      final names = {for (final p in _players) p.name.toLowerCase()};
      var n = 1;
      while (names.contains('bot $n')) {
        n++;
      }
      final bot = Player(_nextId++, 'Bot $n', _lowestFreeColor(), bot: true);
      _players.add(bot);
      _scores[bot.id] = 0;
      bots.add(bot);
    }
    _broadcastLobby();
    _notify();
  }

  // --- Curve ---

  CurveSim? _sim;
  Bots? _bots;
  var _curveRound = 0;
  // Player id -> sim id (the color index) for everyone in the running match.
  final _simIdOf = <int, int>{};
  final _gone = <int>{}; // player ids killed by a disconnect or a kick

  /// The running Curve match, or null.
  CurveSim? get sim => _sim;
  Bots? get bots => _bots;

  /// Bumped for every round of a match; the TV makes a fresh `CurveGame` each time.
  int get curveRound => _curveRound;

  void _startCurve(List<Player> parts) {
    _simIdOf
      ..clear()
      ..addEntries(parts.map((p) => MapEntry(p.id, p.colorIndex)));
    _gone.clear();
    final sim = CurveSim([for (final p in parts) p.colorIndex],
        random: _random, names: {for (final p in parts) p.colorIndex: p.name});
    _sim = sim;
    _bots = Bots(sim, [for (final p in parts) if (p.bot) p.colorIndex], _random);
    _curveRound = 1;
    _phase = Phase.curve;
    _sendStatuses();
    _notify();
  }

  void _steer(Player p, bool left, bool right) {
    final sid = _simIdOf[p.id];
    if (_phase != Phase.curve || sid == null || _gone.contains(p.id)) return;
    _sim?.setInput(sid, left: left, right: right);
  }

  CurveStatus? _statusFor(Player p) {
    final sim = _sim;
    final sid = _simIdOf[p.id];
    if (sim == null || sid == null) return null;
    final head = sim.heads.where((h) => h.id == sid).firstOrNull;
    return CurveStatus(
        alive: (head?.alive ?? false) && !_gone.contains(p.id),
        score: sim.scores[sid] ?? 0,
        target: sim.target);
  }

  void _sendStatuses() {
    for (final p in _players) {
      final status = _statusFor(p);
      if (status != null) p.socket?.send(status);
    }
  }

  /// A player who disconnects or is kicked mid-match crashes for good.
  void _dropFromGame(Player p) {
    if (_phase != Phase.curve) return;
    final sid = _simIdOf[p.id];
    if (sid == null || !_gone.add(p.id)) return;
    _sim?.setInput(sid, left: false, right: false);
    _sim?.kill(sid);
  }

  /// Ends the match at once when fewer than 2 are still in it, or when no
  /// human is connected (bots alone are not worth watching).
  void _checkCurveEnd() {
    if (_phase != Phase.curve || _sim == null) return;
    final inMatch = _simIdOf.keys.where((id) => !_gone.contains(id)).length;
    final humans = _simIdOf.keys
        .map(_byId)
        .where((p) => p != null && !p.bot && p.connected)
        .length;
    if (inMatch <= 1 || humans == 0) finishGame(_gameScores());
  }

  Map<int, int> _gameScores() =>
      {for (final e in _simIdOf.entries) e.key: _sim?.scores[e.value] ?? 0};

  /// Feed this the events of every `CurveSim.tick()` (CurveGame.onEvents).
  void curveEvents(List<CurveEvent> events) {
    if (_phase != Phase.curve || _sim == null) return;
    var roundOver = false, matchOver = false;
    for (final e in events) {
      switch (e) {
        case Died(:final id):
          final p = _byId(_simIdOf.entries.where((x) => x.value == id).firstOrNull?.key ?? -1);
          final status = p == null ? null : _statusFor(p);
          if (status != null) {
            // The event itself says they died, whatever the head reads.
            p!.socket?.send(CurveStatus(
                alive: false, score: status.score, target: status.target));
          }
        case RoundOver():
          roundOver = true;
        case MatchOver():
          matchOver = true;
        case PickedUp():
          break;
      }
    }
    if (roundOver) _sendStatuses();
    if (matchOver) finishGame(_gameScores());
  }

  /// Starts the next round of the match. The TV calls it 2 s after RoundOver.
  void nextRound() {
    final sim = _sim;
    if (_phase != Phase.curve || sim == null || !sim.roundOver || sim.matchOver) return;
    sim.startRound();
    _curveRound++;
    _sendStatuses();
    _notify();
  }

  // --- the end of a game ---

  /// Ends the running game: adds placement points to [sessionScores], sends
  /// Results, and moves to the results phase. [gameScores] is keyed by player
  /// id. Quiz calls this too (Task 11).
  void finishGame(Map<int, int> gameScores) {
    final placements = placementPoints(gameScores);
    for (final pl in placements) {
      if (_scores.containsKey(pl.playerId)) {
        _scores[pl.playerId] = _scores[pl.playerId]! + pl.sessionPoints;
      }
    }
    _phase = Phase.results;
    final results = Results(placements);
    for (final p in _players) {
      p.socket?.send(results);
    }
    _notify();
  }

  /// Leaves the results phase. The TV calls it 8 s after [finishGame].
  void returnToLobby() {
    _phase = Phase.lobby;
    _sim = null;
    _bots = null;
    _simIdOf.clear();
    _gone.clear();
    _broadcastLobby();
    _notify();
  }
}
