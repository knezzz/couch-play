import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

import '../packs/pack_store.dart';
import '../packs/test_pack.dart';
import '../server/game_server.dart';
import '../sound/sfx.dart';
import 'bots.dart';
import '../strings.dart';

enum Phase { lobby, quiz, curve, results }

const maxPlayers = 8;
const _staleAfter = Duration(minutes: 10);

Duration Function() _monotonic() {
  final w = Stopwatch()..start();
  return () => w.elapsed;
}

const _onlyHost = ErrorMsg(Strings.onlyHost);
const _full = ErrorMsg(Strings.gameFull);
const _waiting = Waiting(Strings.nextGameSoon);

class Player {
  Player(this.id, this.name, this.colorIndex,
      {this.token = '', this.bot = false, this.character = ''});

  /// Stable for the whole session. Bots and humans share one id space.
  final int id;
  String name;

  /// 0..7, unique among current players; the lowest free one when handed out.
  int colorIndex;

  /// An id from `characterIds`, unique among the players.
  String character;

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
  /// [clock] is a monotonic time since any fixed origin; the quiz runs on it.
  Session({DateTime Function()? now, Random? random, Duration Function()? clock})
      : _now = now ?? DateTime.now,
        _random = random ?? Random(),
        _clock = clock ?? _monotonic();

  final DateTime Function() _now;
  final Random _random;
  final Duration Function() _clock;

  final _players = <Player>[];
  final _scores = <int, int>{};
  var _nextId = 1;
  var _phase = Phase.lobby;

  /// Bumped on every change, for UI rebuilds.
  final ValueNotifier<int> _changes = ValueNotifier(0);
  ValueListenable<int> get changes => _changes;

  /// Called when the host starts a game, after the session is ready for it.
  void Function(GameKind kind, String? packId)? onStart;

  /// Built-in and uploaded quiz packs. Null until main.dart has loaded them.
  PackStore? packStore;

  /// The host uploads a quiz pack; [token] must be the current host's. The
  /// message is shown to the host as it is: the success text or PackStore's error.
  Future<({bool ok, String message})> onPackUpload(String token, Uint8List bytes) async {
    final host = _byId(hostId ?? -1);
    if (host == null || token.isEmpty || host.token != token) {
      return (ok: false, message: Strings.onlyHostAddsPacks);
    }
    final store = packStore;
    if (store == null) return (ok: false, message: Strings.packsNotReady);
    final err = await store.add(bytes);
    if (err != null) return (ok: false, message: err);
    final pack = (parsePack(bytes) as PackOk).pack; // add() just accepted it
    if (_phase == Phase.lobby) _broadcastLobby();
    return (ok: true, message: Strings.packAdded(pack.title, pack.questions.length));
  }

  /// The one place a pack id becomes a pack. No pack picked plays the store's
  /// default pack, or the test pack when there is no store.
  late QuizPack? Function(String? packId) packLookup =
      (id) => id == null ? (packStore?.defaultPack ?? testPack) : packStore?.get(id);

  /// What the TV lobby shows as the join address; null means no network
  /// ([noWifiText]).
  String? get joinUrl => _joinUrl;
  set joinUrl(String? v) {
    _joinUrl = v;
    _notify();
  }

  String? _joinUrl;
  String get joinHint => _joinUrl ?? Strings.noWifi;

  void dispose() {
    _quizTimer?.cancel();
    _waitTimer?.cancel();
    _changes.dispose();
  }

  void _notify() => _changes.value++;

  // --- who is here ---

  /// Everyone in the session in join order: humans and bots.
  List<Player> get players => List.unmodifiable(_players);

  /// The same, as sent to phones (and what the TV lobby draws).
  List<PlayerInfo> get playerInfos => [
        for (final p in _players)
          PlayerInfo(p.id, p.name, p.colorIndex, p.connected, _scores[p.id] ?? 0,
              bot: p.bot, character: p.character),
      ];

  /// The oldest connected human, so the role passes on when the host drops and
  /// goes back to them if they return. Null if no human is connected.
  int? get hostId {
    // During a game the role stays with whoever has it, even if the oldest
    // player comes back.
    final g = _gameHost == null ? null : _byId(_gameHost!);
    if (g != null && g.connected) return g.id;
    for (final p in _players) {
      if (!p.bot && p.connected) return p.id;
    }
    return null;
  }

  Phase get phase => _phase;

  // The host of the running game; null in the lobby and results, where the
  // host is simply the oldest connected human.
  int? _gameHost;

  /// The game's host left or was removed: the next-oldest connected human
  /// takes over and keeps the role until the game ends.
  void _keepGameHost() {
    final g = _gameHost == null ? null : _byId(_gameHost!);
    if (_gameHost == null || (g != null && g.connected)) return;
    _gameHost = null;
    _gameHost = hostId;
  }

  /// The placements of the game that just ended; empty outside the results
  /// phase. The TV's results screen draws these.
  List<Placement> get placements => List.unmodifiable(_placements);
  var _placements = <Placement>[];

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
      case Join(:final name, :final token, :final character):
        _join(peer, name, token, character);
      case Steer(:final left, :final right):
        final p = _playerOf(peer);
        if (p != null) _steer(p, left, right);
      case StartGame(:final game, :final packId):
        _start(peer, game, packId);
      case Kick(:final playerId):
        _kick(peer, playerId);
      case SetCharacter(:final id):
        final p = _playerOf(peer);
        if (p != null) _setCharacter(p, id);
      case SetBots(:final count):
        _setBots(peer, count);
      case SelectGame(:final game):
        _selectGame(peer, game);
      case SetSettings(:final settings):
        _setSettings(peer, settings);
      case Answer(:final index):
        final p = _playerOf(peer);
        if (p != null) _answer(p, index);
      default:
        // Everything else is a TV-to-phone type; a phone has no business
        // sending it.
        break;
    }
  }

  void _join(PeerSocket peer, String rawName, String token, String? character) {
    if (token.isEmpty || token.length > 64) {
      peer.send(const ErrorMsg(Strings.reloadPage));
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
      peer.send(const ErrorMsg(Strings.typeName));
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
        token: token, character: _freeCharacter(character))
      ..socket = peer;
    _players.add(p);
    _scores[p.id] = 0;
    peer.send(Welcome(p.id, p.colorIndex, token, character: p.character));
    if (_phase == Phase.lobby) {
      sfx.play(Sound.join);
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
    peer.send(Welcome(p.id, p.colorIndex, p.token, character: p.character));
    switch (_phase) {
      case Phase.lobby:
        _broadcastLobby();
      case Phase.curve:
        // Back in the match from the next round; this one stays lost.
        final sid = _simIdOf[p.id];
        if (sid != null && _gone.remove(p.id)) _sim?.revive(sid);
        // The old socket's last Steer must not keep turning the head; if it
        // never reported closing, nothing else zeroes it.
        if (sid != null) _sim?.setInput(sid, left: false, right: false);
        // Only someone in this match can end its pause.
        if (sid != null) _resumeIfEnough();
        final status = _statusFor(p);
        // Still paused: the phone waits too, it must not show the steering.
        peer.send(sid != null && _paused ? Waiting(pauseText!) : status ?? _waiting);
      case Phase.quiz:
        if (_quizIds.contains(p.id)) _resumeQuiz();
        _quizRejoin(p);
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
    _dropFromGame(p, returnable: true);
    _keepGameHost();
    if (_phase == Phase.lobby) _broadcastLobby();
    _notify();
    _checkCurveEnd();
    _checkQuizEnd();
  }

  void _broadcastLobby() {
    if (_selectedBy != hostId) _selected = null; // a new host starts clean
    final lobby = LobbyState(
        players: playerInfos,
        packs: packStore?.infos ?? const [],
        hostId: hostId ?? -1,
        selected: _selected,
        settings: _settings);
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
      peer.send(const ErrorMsg(Strings.gameRunning));
      return;
    }
    switch (game) {
      case GameKind.quiz:
        // The host's chosen pack; a pack named in StartGame still wins (old callers).
        if (packId == null) _dropMissingPack(); // removed since it was saved
        final pack = packLookup(packId ?? _settings.quizPackId);
        if (pack == null || pack.questions.isEmpty) {
          peer.send(const ErrorMsg(Strings.packUnavailable));
          return;
        }
        _startQuiz(pack, participants(GameKind.quiz));
        onStart?.call(game, packId);
      case GameKind.curve:
        final parts = participants(GameKind.curve);
        if (parts.length < 2) {
          peer.send(const ErrorMsg(Strings.curveNeedsTwo));
          return;
        }
        _startCurve(parts);
        onStart?.call(game, packId);
      case GameKind.vukodlak:
        peer.send(const ErrorMsg(Strings.vukodlakSoon)); // Task 33 builds it
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
      peer.send(const ErrorMsg(Strings.noSuchPlayer));
      return;
    }
    if (target.id == from.id) {
      peer.send(const ErrorMsg(Strings.cannotKickSelf));
      return;
    }
    final socket = target.socket;
    _remove(target); // bots can be kicked too
    socket?.send(const Kicked());
    socket?.close();
    if (_phase == Phase.lobby) _broadcastLobby();
    _notify();
    _checkCurveEnd();
    _checkQuizEnd();
  }

  void _setBots(PeerSocket peer, int count) {
    final from = _playerOf(peer);
    if (from == null) return;
    if (from.id != hostId) {
      peer.send(_onlyHost);
      return;
    }
    if (_phase != Phase.lobby) {
      peer.send(const ErrorMsg(Strings.botsBetweenGames));
      return;
    }
    setBotCount(count);
  }

  /// What the host set for this session (no persistence). A game takes the
  /// values it starts with; changes only count from the next game.
  GameSettings get settings => _settings;

  /// The game whose details the host has open; null while they browse. It goes
  /// when a game starts or ends and when the host changes.
  GameKind? get selectedGame => _selected;
  GameKind? _selected;
  int? _selectedBy; // the host who chose it

  /// The title of the pack Igraj would start: the chosen one or the default.
  String? get selectedPackTitle => packLookup(_settings.quizPackId)?.title;

  void _selectGame(PeerSocket peer, GameKind? game) {
    final from = _playerOf(peer);
    if (from == null || _phase != Phase.lobby) return;
    if (from.id != hostId) {
      peer.send(_onlyHost);
      return;
    }
    _selected = game;
    _selectedBy = from.id;
    _broadcastLobby();
    _notify();
  }
  GameSettings _settings = const GameSettings();

  /// Sound effects; silent until the TV hands in a real player.
  Sfx sfx = const SilentSfx();
  File? _settingsFile;

  /// Remembers the settings in [file] across restarts: reads it now (a missing
  /// or broken file means the defaults) and writes it on every host change.
  void loadSettings(File file) {
    _settingsFile = file;
    try {
      _settings =
          GameSettings.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>).clamped();
    } catch (_) {
      _settings = const GameSettings();
    }
    _dropMissingPack();
  }

  /// A chosen pack the TV no longer has becomes the default pack.
  void _dropMissingPack() {
    final id = _settings.quizPackId;
    if (id == null || packLookup(id) != null) return;
    _settings = GameSettings(
        quizSeconds: _settings.quizSeconds,
        quizQuestions: _settings.quizQuestions,
        revealSeconds: _settings.revealSeconds,
        curveCountdown: _settings.curveCountdown,
        curveMode: _settings.curveMode);
  }

  /// [want] if it is a character and nobody has it, else a random free one.
  /// 8 players at most and 16 characters: there is always one.
  String _freeCharacter(String? want) {
    final taken = {for (final p in _players) p.character};
    if (want != null && isCharacter(want) && !taken.contains(want)) return want;
    final free = [for (final c in characterIds) if (!taken.contains(c)) c];
    return free[_random.nextInt(free.length)];
  }

  void _setCharacter(Player p, String id) {
    if (_phase != Phase.lobby || !isCharacter(id) || id == p.character) return;
    if (_players.any((q) => q.character == id)) {
      p.socket?.send(const ErrorMsg(Strings.characterTaken));
      return;
    }
    p.character = id;
    _broadcastLobby();
    _notify();
  }

  void _setSettings(PeerSocket peer, GameSettings wanted) {
    final from = _playerOf(peer);
    if (from == null || _phase != Phase.lobby) return;
    if (from.id != hostId) {
      peer.send(_onlyHost);
      return;
    }
    _settings = wanted.clamped();
    _dropMissingPack();
    try {
      _settingsFile?.writeAsStringSync(jsonEncode(_settings.toJson()));
    } catch (_) {} // not remembered, still set for this session
    _broadcastLobby();
    _notify();
  }

  /// Sets the number of bots, clamped so players + bots <= 8. Lobby only.
  void setBotCount(int count) {
    if (_phase != Phase.lobby) return;
    final humans = _players.where((p) => !p.bot).length;
    final want = count.clamp(0, maxPlayers - humans);
    var bots = _players.where((p) => p.bot).toList();
    while (bots.length > want) {
      _remove(bots.removeLast()); // the newest goes first
    }
    while (bots.length < want) {
      final names = {for (final p in _players) p.name.toLowerCase()};
      var n = 1;
      while (names.contains(Strings.botName(n).toLowerCase())) {
        n++;
      }
      final bot = Player(_nextId++, Strings.botName(n), _lowestFreeColor(),
          bot: true, character: _freeCharacter(null));
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
    _selected = null;
    _wasCounting = false; // the last match may have ended mid-countdown
    _countTicks = 0;
    _simIdOf
      ..clear()
      ..addEntries(parts.map((p) => MapEntry(p.id, p.colorIndex)));
    _gone.clear();
    final sim = CurveSim([for (final p in parts) p.colorIndex],
        config: CurveConfig.forMode(_settings.curveMode,
            countdown: _settings.curveCountdown.toDouble()),
        random: _random, names: {for (final p in parts) p.colorIndex: p.name});
    _sim = sim;
    _bots = Bots(sim, [for (final p in parts) if (p.bot) p.colorIndex], _random);
    _curveRound = 1;
    _gameHost = hostId;
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

  // --- Quiz ---

  QuizRound? _quiz;
  QuizPack? _quizPack;
  Timer? _quizTimer;
  Duration _quizOrigin = Duration.zero; // _clock() when the round began
  Duration _stepStart = Duration.zero; // round time when the current step began
  final _quizIds = <int>{}; // everyone who was in the round at the start
  final _picks = <int, int>{}; // player id -> shown choice, this question

  /// The running quiz, or null. The TV screen reads the rest from the getters
  /// below and rebuilds on [changes] (bumped every 100 ms while the quiz runs).
  QuizRound? get quiz => _quiz;

  /// Players who have answered this question.
  int get quizAnswered =>
      _picks.keys.where((id) => _byId(id)?.connected ?? false).length;

  /// Players the round is still waiting for or has: in the round and connected.
  int get quizExpected => _quizIds.where((id) => _byId(id)?.connected ?? false).length;

  /// Who picked what (player id -> shown choice index). Empty until the reveal.
  Map<int, int> get quizPicks =>
      _quiz?.step == QuizStep.revealing ? Map.unmodifiable(_picks) : const {};

  /// The countdown, 1 down to 0 while asking; 0 otherwise.
  double get quizRemaining {
    final q = _quiz;
    if (q == null || q.step != QuizStep.asking) return 0;
    final spent = _quizNow() - _stepStart;
    return (1 - spent.inMilliseconds / q.limit.inMilliseconds).clamp(0.0, 1.0);
  }

  /// The running quiz pack's title, or ''.
  String get quizTitle => _quizPack?.title ?? '';

  /// The picture of the current question (SVG or photo), and its file name.
  Uint8List? get quizPicture {
    final img = _quiz?.current.image;
    return img == null ? null : _quizPack?.images[img];
  }

  String get quizPictureName => _quiz?.current.image ?? '';

  /// Frozen while the quiz waits for players to come back.
  Duration _quizNow() => (_quizPausedAt ?? _clock()) - _quizOrigin;
  Duration? _quizPausedAt; // _clock() when the pause began

  void _startQuiz(QuizPack pack, List<Player> parts) {
    _selected = null; // Igraj: the details are done with
    _quizPack = pack;
    _quizIds
      ..clear()
      ..addAll(parts.map((p) => p.id));
    _picks.clear();
    _quiz = QuizRound(pack, _quizIds.toList(),
        random: _random,
        length: _settings.quizQuestions,
        limit: Duration(seconds: _settings.quizSeconds),
        reveal: Duration(seconds: _settings.revealSeconds));
    _quizOrigin = _clock();
    _stepStart = Duration.zero;
    _gameHost = hostId;
    _phase = Phase.quiz;
    _sendQuestion();
    _quizTimer?.cancel();
    _quizTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => _quizTick());
    _notify();
  }

  QuizQuestion _questionFor(QuizRound q) {
    final left = q.limit - (_quizNow() - _stepStart);
    return QuizQuestion(q.number, q.total, q.current.choices, max(1, (left.inMilliseconds / 1000).ceil()));
  }

  void _sendQuestion() {
    final q = _quiz!;
    _lastTickSec = null;
    sfx.play(Sound.quizStart);
    final msg = _questionFor(q);
    for (final id in _quizIds) {
      _byId(id)?.socket?.send(msg);
    }
  }

  int? _lastTickSec; // the last tick slot (a second, or half a second in the last 5 s), this question

  void _sendReveal(Player p) {
    final q = _quiz!;
    final points = q.lastPoints[p.id] ?? 0;
    p.socket?.send(QuizReveal(q.current.correctIndex, points, q.totals[p.id] ?? 0));
    // A right answer is worth at least 500; the pop follows the reveal so the
    // phone already knows its points.
    if (points > 0) p.socket?.send(const Effect('scorePop'));
  }

  void _quizTick() {
    final q = _quiz;
    if (_phase != Phase.quiz || q == null || _paused) return;
    final step = q.step, number = q.number;
    final now = _quizNow();
    q.advance(now);
    if (q.step != step || q.number != number) {
      _stepStart = now;
      switch (q.step) {
        case QuizStep.revealing:
          sfx.play(q.lastPoints.values.any((v) => v > 0) ? Sound.right : Sound.wrong);
          for (final id in _quizIds) {
            final p = _byId(id);
            if (p != null) _sendReveal(p);
          }
        case QuizStep.asking:
          _picks.clear();
          _sendQuestion();
        case QuizStep.done:
          sfx.play(Sound.fanfare);
          finishGame(Map.of(q.totals));
          return;
      }
    }
    if (q.step == QuizStep.asking) {
      // The whole question ticks: a soft tock each second, then a sharper tick
      // twice a second for the last 5 s. The first second is silent.
      final left = q.limit - (now - _stepStart);
      final sec = (left.inMilliseconds / 1000).ceil();
      final last5 = sec >= 1 && sec <= 5;
      final slot = last5 ? (left.inMilliseconds / 500).ceil() : sec;
      if (sec >= 1 && sec < q.limit.inSeconds && slot != _lastTickSec) {
        _lastTickSec = slot;
        sfx.play(last5 ? Sound.tick : Sound.quizTick);
      }
    }
    _notify();
  }

  void _answer(Player p, int index) {
    final q = _quiz;
    if (_phase != Phase.quiz ||
        q == null ||
        q.step != QuizStep.asking ||
        !_quizIds.contains(p.id) ||
        !p.connected ||
        index < 0 ||
        index > 3 ||
        _picks.containsKey(p.id)) {
      return;
    }
    _picks[p.id] = index;
    q.answer(p.id, index, _quizNow());
    _notify();
  }

  /// A returning player answers again from the current question on.
  void _quizRejoin(Player p) {
    final q = _quiz;
    if (q == null || !_quizIds.contains(p.id)) {
      p.socket?.send(_waiting);
      return;
    }
    q.addPlayer(p.id);
    if (q.step == QuizStep.asking) {
      p.socket?.send(
          _picks.containsKey(p.id) ? const Waiting(Strings.lockedIn) : _questionFor(q));
    } else {
      _sendReveal(p);
    }
  }

  /// With no connected player left the quiz waits 30 s for someone to return.
  void _checkQuizEnd() {
    final q = _quiz;
    if (_phase != Phase.quiz || q == null || quizExpected > 0 || _paused) return;
    _quizPausedAt = _clock();
    _pause(null);
    _notify();
  }

  /// Someone is back: the question's clock carries on where it stopped.
  void _resumeQuiz() {
    final at = _quizPausedAt;
    if (!_paused || at == null) return;
    _stopWait();
    _quizPausedAt = null;
    _quizOrigin += _clock() - at;
  }

  void _stopQuiz() {
    _quizTimer?.cancel();
    _quizTimer = null;
    _quizPausedAt = null;
    _quiz = null;
    _quizPack = null;
    _quizIds.clear();
    _picks.clear();
  }

  /// A player who disconnects or is kicked mid-match is out for the round.
  /// A disconnect that leaves one player behind ([returnable]) pauses the match
  /// instead, so the remaining head can't win by default.
  void _dropFromGame(Player p, {bool returnable = false}) {
    if (_phase == Phase.quiz) _quiz?.removePlayer(p.id);
    if (_phase != Phase.curve) return;
    final sid = _simIdOf[p.id];
    if (sid == null || !_gone.add(p.id)) return;
    _sim?.setInput(sid, left: false, right: false);
    if (returnable && !p.bot) {
      if (_humansLeft() == 0) {
        _pause(null); // nobody is connected: wait for anyone
        return;
      }
      if (_inMatch() <= 1) {
        _pause(p);
        return;
      }
    }
    _sim?.kill(sid);
  }

  int _inMatch() => _simIdOf.keys.where((id) => !_gone.contains(id)).length;

  int _humansLeft() => _simIdOf.keys
      .map(_byId)
      .where((p) => p != null && !p.bot && p.connected)
      .length;

  // A game waits this long for players to come back: a 2-player Curve match
  // for the one who left, Quiz and Curve for anyone when nobody is connected.
  static const _waitFor30 = Duration(seconds: 30);
  bool _paused = false;
  Player? _waitingFor; // null while paused: everyone is gone
  Timer? _waitTimer;

  /// Who the paused Curve match waits for. Null when not paused or when it
  /// waits for everyone.
  String? get curveWaitingFor => _waitingFor?.name;

  /// A running game is frozen, waiting for players to return. The TV's
  /// CurveGame must not tick the sim while this is true.
  bool get paused => _paused;

  /// What the TV shows over the frozen game; null when not paused.
  String? get pauseText => !_paused
      ? null
      : _waitingFor == null
          ? Strings.waitingForPlayers
          : Strings.waitingForReturn(_waitingFor!.name);

  /// Starts (or restarts) the one 30 s wait. [who] null means everyone.
  void _pause(Player? who) {
    _paused = true;
    _waitingFor = who;
    _waitTimer?.cancel();
    _waitTimer = Timer(_waitFor30, () {
      _stopWait();
      if (_phase == Phase.curve) finishGame(_gameScores());
      if (_phase == Phase.quiz && _quiz != null) finishGame(Map.of(_quiz!.totals));
    });
    if (who == null) return; // nobody to tell
    final msg = Waiting(Strings.waitingForReturn(who.name));
    for (final q in _players) {
      if (_simIdOf.containsKey(q.id)) q.socket?.send(msg);
    }
  }

  void _stopWait() {
    _waitTimer?.cancel();
    _waitTimer = null;
    _waitingFor = null;
    _paused = false;
  }

  /// Someone came back to a paused match: with 2 or more in it again, carry on
  /// from a fresh round (scores kept).
  void _resumeIfEnough() {
    final sim = _sim;
    if (!_paused || sim == null) return;
    if (_inMatch() < 2) {
      // Someone is back but not enough: wait for the ones still away.
      final away = _simIdOf.keys
          .map(_byId)
          .where((p) => p != null && !p.bot && !p.connected)
          .firstOrNull;
      if (_waitingFor == null && away != null) _pause(away);
      return;
    }
    _stopWait();
    for (final e in _simIdOf.entries) {
      // A button held through the wait must not turn the new round's head.
      sim.setInput(e.value, left: false, right: false);
      if (_gone.contains(e.key)) sim.kill(e.value); // still away: out of this round
    }
    sim.startRound();
    _curveRound++;
    _sendStatuses();
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
    if (!_paused && (humans == 0 || inMatch <= 1)) finishGame(_gameScores());
  }

  Map<int, int> _gameScores() =>
      {for (final e in _simIdOf.entries) e.key: _sim?.scores[e.value] ?? 0};

  var _countTicks = 0;
  var _wasCounting = false;

  /// The TV calls this before every `CurveSim.tick()`: the countdown beeps once
  /// a second and says go when it ends. (The sim has no countdown hook; this
  /// counts the same ticks.)
  void beforeTick() {
    final sim = _sim;
    if (sim == null) return;
    if (sim.countingDown) {
      if (!_wasCounting) _countTicks = 0;
      _wasCounting = true;
      if (_countTicks++ % sim.config.tickHz == 0) sfx.play(Sound.countdownBeep);
    } else if (_wasCounting) {
      _wasCounting = false;
      sfx.play(Sound.countdownGo);
    }
  }

  /// Feed this the events of every `CurveSim.tick()` (CurveGame.onEvents).
  void curveEvents(List<CurveEvent> events) {
    if (_phase != Phase.curve || _sim == null) return;
    var roundOver = false, matchOver = false;
    for (final e in events) {
      switch (e) {
        case Died(:final id):
          sfx.play(Sound.crash);
          final p = _byId(_simIdOf.entries.where((x) => x.value == id).firstOrNull?.key ?? -1);
          final status = p == null ? null : _statusFor(p);
          if (status != null) {
            // The event itself says they died, whatever the head reads.
            p!.socket?.send(CurveStatus(
                alive: false, score: status.score, target: status.target));
          }
          p?.socket?.send(const Effect('colorPulse')); // bots have no socket
        case RoundOver():
          roundOver = true;
        case MatchOver():
          matchOver = true;
        case PickedUp():
          sfx.play(Sound.pickup);
      }
    }
    if (matchOver) {
      sfx.play(Sound.matchWin);
    } else if (roundOver) {
      sfx.play(Sound.roundWin);
    }
    if (roundOver) _sendStatuses();
    if (matchOver) finishGame(_gameScores());
  }

  /// Starts the next round of the match. The TV calls it 2 s after RoundOver.
  void nextRound() {
    final sim = _sim;
    if (_phase != Phase.curve || sim == null || !sim.roundOver || sim.matchOver) return;
    if (_paused) return; // paused: the return starts the next round
    sim.startRound();
    _curveRound++;
    _sendStatuses();
    _notify();
  }

  // --- the end of a game ---

  String _lastGame = '';

  /// What the results screen is for: 'Curve' or 'Kviz · title'.
  String get lastGameLabel => _lastGame;

  /// Ends the running game: adds placement points to [sessionScores], sends
  /// Results, and moves to the results phase. [gameScores] is keyed by player
  /// id. Quiz calls this too (Task 11).
  void finishGame(Map<int, int> gameScores) {
    _lastGame = _quizPack == null ? Strings.gameCurve : Strings.gameQuiz(_quizPack!.title);
    // Someone kicked mid-game is no longer a player and gets no place.
    final placements = placementPoints({
      for (final e in gameScores.entries)
        if (_byId(e.key) != null) e.key: e.value,
    });
    for (final pl in placements) {
      if (_scores.containsKey(pl.playerId)) {
        _scores[pl.playerId] = _scores[pl.playerId]! + pl.sessionPoints;
      }
    }
    _phase = Phase.results;
    _gameHost = null;
    _stopWait();
    _placements = placements;
    _stopQuiz();
    final results = Results(placements);
    final winners = {for (final pl in placements) if (pl.place == 1) pl.playerId};
    for (final p in _players) {
      p.socket?.send(results);
      if (winners.contains(p.id)) p.socket?.send(const Effect('confetti'));
    }
    _notify();
  }

  /// The host's Back + Yes: abandons a running quiz or Curve match. No
  /// placement points, scores stay as they were; phones go back to the lobby.
  void endGame() {
    if (_phase == Phase.quiz || _phase == Phase.curve) returnToLobby();
  }

  /// Leaves the results phase. The TV calls it 8 s after [finishGame].
  void returnToLobby() {
    _phase = Phase.lobby;
    _selected = null;
    _gameHost = null;
    _stopWait();
    _placements = [];
    _stopQuiz();
    _sim = null;
    _bots = null;
    _simIdOf.clear();
    _gone.clear();
    _broadcastLobby();
    _notify();
  }
}
