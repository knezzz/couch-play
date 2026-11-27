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
import 'game_ready.dart';
import 'blef_match.dart';
import 'koliko_match.dart';
import 'tenkovi_match.dart';
import 'tkobi_match.dart';
import 'objasni_match.dart';
import 'party_text.dart';
import 'uljez_match.dart';
import 'uljez_text.dart';
import 'wolf_match.dart';
import 'wolf_text.dart';
import '../strings.dart';

enum Phase { lobby, quiz, curve, wolf, uljez, objasni, koliko, blef, tkobi, tenkovi, results }

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
/// [curveEvents] as its `onEvents`. After a RoundOver the session itself waits
/// [roundBreakTime] (the TV shows the scores while [roundBreak] is on) and then
/// starts the next round.
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
    _wolf?.dispose();
    _wolfEndTimer?.cancel();
    _uljez?.dispose();
    _objasni?.dispose();
    _koliko?.dispose();
    _blef?.dispose();
    _tenkovi?.dispose();
    _tkobi?.dispose();
    _roundBreakTimer?.cancel();
    _momentTimer?.cancel();
    _changes.dispose();
  }

  void _notify() {
    _tellHost();
    _tellPlayers();
    _changes.value++;
  }

  int? _hostTold;
  String? _playersTold;

  /// Who is still in the running game, as the phones' kick list needs it.
  /// Null outside a game.
  GamePlayers? _gamePlayers() {
    final Iterable<int>? ids = switch (_phase) {
      Phase.wolf => _wolf?.alive,
      // the caught impostor is out but still in the game while they guess
      Phase.uljez => _uljez == null ? null : [..._uljez!.alive, ?_uljez!.game.guesser],
      Phase.objasni => _objasni?.ids,
      Phase.koliko => _koliko?.ids,
      Phase.blef => _blef?.ids,
      Phase.tkobi => _tkobi?.ids,
      Phase.tenkovi => _tenkovi?.ids,
      Phase.quiz => _quizIds,
      Phase.curve => _simIdOf.keys,
      _ => null,
    };
    if (ids == null) return null;
    final in_ = ids.toSet();
    return GamePlayers([for (final i in playerInfos) if (in_.contains(i.id)) i]);
  }

  /// The lobby state is not resent mid-game, so the list is sent on its own
  /// whenever it changes (same for every phone, night included).
  bool get _wolfDawn => _phase == Phase.wolf && _wolf?.stage == WolfStage.dawn;

  void _tellPlayers() {
    // The night's dead are announced with the Morning, not before.
    if (_wolfDawn) return;
    final m = _gamePlayers();
    if (m == null) {
      _playersTold = null;
      return;
    }
    final key = jsonEncode(m.toJson());
    if (key == _playersTold) return;
    _playersTold = key;
    for (final p in _players) {
      p.socket?.send(m);
    }
  }

  /// In a game the lobby state is not resent, so the phones are told on their
  /// own whenever the host changes (kick, drop, return). In the lobby the
  /// lobby state carries it.
  void _tellHost() {
    final h = hostId;
    if (h == null || h == _hostTold) return;
    _hostTold = h;
    if (_phase == Phase.lobby) return;
    for (final p in _players) {
      p.socket?.send(HostIs(h));
    }
  }

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
      case SumoMove(:final dir, :final force):
        final p = _playerOf(peer);
        if (p != null) _sumoMove(p, dir, force);
      case SumoDash():
        final p = _playerOf(peer);
        if (p != null) _sumoDash(p);
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
      case PackScreen(:final open):
        _packScreen(peer, open);
      case Answer(:final index):
        final p = _playerOf(peer);
        if (p != null) _answer(p, index);
      case NightPick():
        final p = _playerOf(peer);
        if (p != null) _wolf?.onNightPick(p.id, m);
      case Vote():
        final p = _playerOf(peer);
        if (p == null) break;
        _wolf?.onVote(p.id, m);
        _uljez?.onVote(p.id, m);
        _tkobi?.onVote(p.id, m);
      case TenkoviFire():
        final p = _playerOf(peer);
        if (p != null) _tenkovi?.onFire(p.id, m);
      case Guess():
        final p = _playerOf(peer);
        if (p != null) _uljez?.onGuess(p.id, m);
      case UljezDone():
        final p = _playerOf(peer);
        if (p != null) _uljez?.onDone(p.id);
      case ReadyToPlay():
        final p = _playerOf(peer);
        if (p != null) _wolf?.onReadyToPlay(p.id);
      case ReadyToVote():
        final p = _playerOf(peer);
        if (p == null) break;
        _wolf?.onReady(p.id, m);
        _uljez?.onReady(p.id, m);
      case BlefFake():
        final p = _playerOf(peer);
        if (p != null) _blef?.onFake(p.id, m);
      case BlefPick():
        final p = _playerOf(peer);
        if (p != null) _blef?.onPick(p.id, m);
      case NumberAnswer():
        final p = _playerOf(peer);
        if (p != null) _koliko?.onNumber(p.id, m);
      case Reshuffle():
        final p = _playerOf(peer);
        if (p != null) _objasni?.onReshuffle(p.id);
      case Go():
        final p = _playerOf(peer);
        if (p != null) _objasni?.onGo(p.id);
      case ObjasniAction():
        final p = _playerOf(peer);
        if (p != null) _objasni?.onAction(p.id, m);
      case Shoot():
        final p = _playerOf(peer);
        if (p != null) _wolf?.onShoot(p.id, m);
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
    // The (public) lobby too: a reloaded phone needs the names and colours.
    if (_phase == Phase.wolf || _phase == Phase.uljez || _phase == Phase.objasni || _phase == Phase.koliko || _phase == Phase.blef || _phase == Phase.tkobi || _phase == Phase.tenkovi) peer.send(_lobbyMsg());
    final host = hostId;
    if (_phase != Phase.lobby && host != null) peer.send(HostIs(host)); // after the lobby state
    final gp = _gamePlayers();
    if (gp != null && !_wolfDawn) peer.send(gp); // at dawn the Morning brings it
    switch (_phase) {
      case Phase.lobby:
        _broadcastLobby();
      case Phase.curve:
        // Back in the match from the next round; this one stays lost.
        final sid = _simIdOf[p.id];
        if (sid != null && _gone.remove(p.id)) _sim?.revive(sid);
        // The old socket's last Steer must not keep turning the head; if it
        // never reported closing, nothing else zeroes it.
        if (sid != null) _sim?.clearInput(sid);
        // Only someone in this match can end its pause.
        if (sid != null) _resumeIfEnough();
        final status = _statusFor(p);
        // Still paused: the phone waits too, it must not show the steering.
        peer.send(sid != null && _paused ? Waiting(pauseText!) : status ?? _waiting);
      case Phase.quiz:
        if (_quizIds.contains(p.id)) _resumeQuiz();
        _quizRejoin(p);
      case Phase.wolf:
        // Only that player's own state again; an outsider just waits.
        if (_wolf?.ids.contains(p.id) == true) {
          _wolf!.rejoin(p.id);
          _wolf!.setAway(p.id, false);
        } else {
          peer.send(_waiting);
        }
      case Phase.uljez:
        if (_uljez?.ids.contains(p.id) == true) {
          _uljez!.rejoin(p.id);
          _uljez!.setAway(p.id, false);
        } else {
          peer.send(_waiting);
        }
      case Phase.objasni:
        if (_objasni?.ids.contains(p.id) == true) {
          _objasni!.setAway(p.id, false);
          _objasni!.rejoin(p.id);
        } else {
          peer.send(_waiting);
        }
      case Phase.koliko:
        if (_koliko?.ids.contains(p.id) == true) {
          _koliko!.setAway(p.id, false);
          _koliko!.rejoin(p.id);
        } else {
          peer.send(_waiting);
        }
      case Phase.blef:
        if (_blef?.ids.contains(p.id) == true) {
          _blef!.setAway(p.id, false);
          _blef!.rejoin(p.id);
        } else {
          peer.send(_waiting);
        }
      case Phase.tkobi:
        if (_tkobi?.ids.contains(p.id) == true) {
          _tkobi!.setAway(p.id, false);
          _tkobi!.rejoin(p.id);
        } else {
          peer.send(_waiting);
        }
      case Phase.tenkovi:
        if (_tenkovi?.ids.contains(p.id) == true) {
          _tenkovi!.setAway(p.id, false);
          _tenkovi!.rejoin(p.id);
        } else {
          peer.send(_waiting);
        }
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
    _wolf?.setAway(p.id, true);
    _uljez?.setAway(p.id, true);
    _objasni?.setAway(p.id, true);
    _koliko?.setAway(p.id, true);
    _blef?.setAway(p.id, true);
    _tkobi?.setAway(p.id, true);
    _tenkovi?.setAway(p.id, true);
    _keepGameHost();
    if (_phase == Phase.lobby) _broadcastLobby();
    _notify();
    _checkCurveEnd();
    _checkQuizEnd();
  }

  void _broadcastLobby() {
    if (_viewHost != hostId) {
      _viewHost = hostId;
      _packs = false; // the pack screen was the old host's
    }
    final lobby = _lobbyMsg();
    for (final p in _players) {
      p.socket?.send(lobby);
    }
  }

  LobbyState _lobbyMsg() {
    _normalizePacks(); // packs may have loaded since the settings were read
    return LobbyState(
        players: playerInfos,
        packs: packStore?.infos ?? const [],
        hostId: hostId ?? -1,
        selected: _game,
        changes: List.unmodifiable(_feed),
        changed: _changed,
        hostView: hostView,
        uljezPacks: [for (final p in uljezPacks) PackInfo(p.id, p.title, p.pairs.length)],
        objasniPacks: [for (final p in objasniPacks) PackInfo(p.id, p.title, p.words.length)],
        tkobiPacks: [for (final p in tkobiPacks) PackInfo(p.id, p.title, p.prompts.length)],
        blefPacks: [for (final p in blefPacks) PackInfo(p.id, p.title, p.questions.length)],
        kolikoPacks: [for (final p in kolikoPacks) PackInfo(p.id, p.title, p.questions.length, pictures: p.questions.any((q) => q.image != null))],
        settings: _settings);
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
    final error = _launch(game, packId);
    if (error != null) peer.send(ErrorMsg(error));
  }

  /// The remote picked a game on the TV home: the same selection the host's
  /// phone makes (every phone is told), with the TV's own click.
  void selectFromTv(GameKind game) {
    if (_phase != Phase.lobby) return;
    sfx.play(Sound.menuMove); // moving on an empty home clicks too
    _moveTo(game, ChangeBy.remote); // with nobody in the room too: the TV and the next phone must agree
  }

  /// OK on the TV home: Igraj for the host, with the same checks. Null when the
  /// game started, else why not (the home shows it).
  String? startFromTv(GameKind game) {
    if (hostId == null) return Strings.homeNeedPlayers;
    if (_phase != Phase.lobby) return Strings.gameRunning;
    final error = _launch(game, null);
    if (error == null) sfx.play(Sound.menuConfirm);
    return error;
  }

  /// Starts [game] from the lobby, or says why not. [packId] only from an old
  /// StartGame; the host's chosen pack is used otherwise.
  String? _launch(GameKind game, String? packId) {
    switch (game) {
      case GameKind.quiz:
        // The host's chosen pack; a pack named in StartGame still wins (old callers).
        _normalizePacks();
        final pack = packId != null ? packLookup(packId) : _quizUnion();
        if (pack == null || pack.questions.isEmpty) return Strings.packUnavailable;
        _startQuiz(pack, participants(GameKind.quiz));
      case GameKind.curve:
        final parts = participants(GameKind.curve);
        if (parts.length < 2) return Strings.curveNeedsTwo;
        _startCurve(parts);
      case GameKind.sumo:
        if (_players.any((p) => p.bot)) return Strings.sumoNoBots;
        final parts = participants(GameKind.sumo);
        if (parts.length < 2) return Strings.sumoNeedsTwo;
        _startSumo(parts);
      case GameKind.vukodlak:
        if (!wolfTvReady) return Strings.vukodlakSoon;
        if (_players.any((p) => p.bot)) return WolfText.noBots;
        final parts = participants(GameKind.vukodlak);
        if (parts.length < 5 || parts.length > 8) return WolfText.needPlayers;
        _startWolf(parts);
      case GameKind.uljez:
        if (!uljezTvReady) return Strings.uljezSoon;
        if (_players.any((p) => p.bot)) return UljezText.noBots;
        final parts = participants(GameKind.uljez);
        if (parts.length < 3 || parts.length > 8) return UljezText.needPlayers;
        final pack = _unionUljez();
        if (pack == null) return Strings.packUnavailable;
        _startUljez(parts, pack);
      // The party games: their TV screens are not built yet (the flags in game_ready.dart).
      case GameKind.objasni:
        if (!objasniTvReady) return PartyText.soon;
        if (_players.any((p) => p.bot)) return PartyText.noBots;
        final parts = participants(GameKind.objasni);
        if (parts.length < 4 || parts.length > 8) return PartyText.objasniNeedPlayers;
        final pack = _unionObjasni();
        if (pack == null) return Strings.packUnavailable;
        _startObjasni(parts, pack);
      case GameKind.koliko:
        if (!kolikoTvReady) return PartyText.soon;
        if (_players.any((p) => p.bot)) return PartyText.noBots;
        final parts = participants(GameKind.koliko);
        if (parts.length < 2 || parts.length > 8) return PartyText.kolikoNeedPlayers;
        final pack = _unionKoliko();
        if (pack == null) return Strings.packUnavailable;
        _startKoliko(parts, pack);
      case GameKind.blef:
        if (!blefTvReady) return PartyText.soon;
        if (_players.any((p) => p.bot)) return PartyText.noBots;
        final parts = participants(GameKind.blef);
        if (parts.length < 3 || parts.length > 8) return PartyText.blefNeedPlayers;
        final pack = _unionBlef();
        if (pack == null) return Strings.packUnavailable;
        _startBlef(parts, pack);
      case GameKind.tkobi:
        if (!tkobiTvReady) return PartyText.soon;
        if (_players.any((p) => p.bot)) return PartyText.noBots;
        final parts = participants(GameKind.tkobi);
        if (parts.length < 3 || parts.length > 8) return PartyText.tkobiNeedPlayers;
        final pack = _unionTkobi();
        if (pack == null) return Strings.packUnavailable;
        _startTkobi(parts, pack);
      case GameKind.tenkovi:
        if (_players.any((p) => p.bot)) return PartyText.noBots;
        final parts = participants(GameKind.tenkovi);
        if (parts.length < 2 || parts.length > 8) return PartyText.tenkoviNeedPlayers;
        _startTenkovi(parts);
    }
    onStart?.call(game, packId);
    return null;
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
    _kickPlayer(target);
  }

  /// The TV remote's kick (Back menu, "Izbaci igrača"): the same as the host
  /// phone's, for any player, the host included (the next player becomes host).
  /// False if there is no such player.
  bool kickFromTv(int playerId) {
    final target = _byId(playerId);
    if (target == null) return false;
    _kickPlayer(target);
    return true;
  }

  void _kickPlayer(Player target) {
    final socket = target.socket;
    final wasHost = target.id == hostId;
    _wolf?.expel(target.id); // out of a running Vukodlak now
    _uljez?.expel(target.id); // and of a running Uljez
    _objasni?.setAway(target.id, true); // and Objasni counts it as gone
    _objasni?.kicked(target.id);
    _koliko?.setAway(target.id, true);
    _blef?.setAway(target.id, true);
    _tkobi?.setAway(target.id, true);
    _tenkovi?.setAway(target.id, true);
    _remove(target); // bots can be kicked too
    if (wasHost) _keepGameHost();
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
    final before = _players.where((p) => p.bot).length;
    setBotCount(count);
    final after = _players.where((p) => p.bot).length;
    if (after != before) {
      _changedSetting('bots', before, after, ChangeBy.phone);
      _broadcastLobby();
      _notify();
    }
  }

  /// What the host set for this session (no persistence). A game takes the
  /// values it starts with; changes only count from the next game.
  GameSettings get settings => _settings;

  /// The one game every screen shows (the host's ‹ › and the remote's ◀ ▶
  /// move it). It is remembered across games and hosts; quiz at the start.
  GameKind? get selectedGame => _game;
  GameKind get homeGame => _game;
  GameKind _game = GameKind.values.first;

  // ---- the shared lobby state: what changed, where the host is ----

  final _feed = <LobbyChange>[];
  LobbyChange? _changed;
  bool _panel = false; // the TV settings panel is open
  bool _packs = false; // the host is in the pack screen
  int? _viewHost;

  /// What the host changed, newest first, at most 5. Lives in the session only.
  List<LobbyChange> get feed => List.unmodifiable(_feed);

  /// The setting change every screen outlines; a game change clears it.
  LobbyChange? get changed => _changed;

  /// Where the host is: the pack screen, the settings (the TV panel), the card.
  HostView get hostView => _packs ? HostView.packs : _panel ? HostView.settings : HostView.home;

  void _log(LobbyChange c) {
    _feed.insert(0, c);
    if (_feed.length > 5) _feed.removeLast();
  }

  void _moveTo(GameKind game, ChangeBy by) {
    if (game == _game) return;
    _game = game;
    _changed = null;
    _panel = false;
    _packs = false;
    if (hostId != null) _log(LobbyChange.game(game, by)); // nobody there to have done it
    _broadcastLobby();
    _notify();
  }

  /// A game starts or ends: no outline, no panel, no pack screen. The feed and
  /// the shown game stay.
  void _closeHostView() {
    _changed = null;
    _panel = false;
    _packs = false;
  }

  /// ▼ on the TV home: the settings panel opens (once).
  void openSettingsFromTv() {
    if (_phase != Phase.lobby || _panel) return;
    _panel = true;
    _log(LobbyChange.settings(_game, ChangeBy.remote));
    _broadcastLobby();
    _notify();
  }

  /// Natrag on the TV panel.
  void closeSettingsFromTv() {
    if (_phase != Phase.lobby || !_panel) return;
    _panel = false;
    _broadcastLobby();
    _notify();
  }

  /// The remote edits the panel: the same as the host's settings message.
  void setSettingsFromTv(GameSettings wanted) {
    if (_phase != Phase.lobby) return;
    _applySettings(wanted, ChangeBy.remote);
  }

  void _packScreen(PeerSocket peer, bool open) {
    final from = _playerOf(peer);
    if (from == null || _phase != Phase.lobby || from.id != hostId || _packs == open) return;
    _packs = open;
    if (open) _log(LobbyChange.packs(_game, ChangeBy.phone));
    _broadcastLobby();
    _notify();
  }

  void _selectGame(PeerSocket peer, GameKind? game) {
    final from = _playerOf(peer);
    if (from == null || _phase != Phase.lobby) return;
    if (from.id != hostId) {
      peer.send(_onlyHost);
      return;
    }
    if (game != null) _moveTo(game, ChangeBy.phone);
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
    _normalizePacks();
  }

  // ---- packs are multi-select: the settings keep the packs switched OFF ----

  static const _packGames = [
    GameKind.quiz,
    GameKind.uljez,
    GameKind.objasni,
    GameKind.koliko,
    GameKind.blef,
    GameKind.tkobi,
  ];

  /// Every pack of [game] the TV has, in lobby order.
  List<String> _packIds(GameKind game) => switch (game) {
        GameKind.quiz => packStore != null ? [for (final i in packStore!.infos) i.id] : [testPack.id],
        GameKind.uljez => [for (final p in uljezPacks) p.id],
        GameKind.objasni => [for (final p in objasniPacks) p.id],
        GameKind.koliko => [for (final p in kolikoPacks) p.id],
        GameKind.blef => [for (final p in blefPacks) p.id],
        GameKind.tkobi => [for (final p in tkobiPacks) p.id],
        _ => const [],
      };

  /// The ticked packs of [game]: every pack not in the off-set (so a pack that
  /// appears later starts ticked). Never empty while the game has packs.
  List<String> tickedPackIds(GameKind game) {
    _normalizePacks(); // an old single id is decided once the packs have loaded
    final all = _packIds(game), off = _settings.offPacks(game);
    final ticked = [for (final i in all) if (!off.contains(i)) i];
    return ticked.isEmpty ? all : ticked;
  }

  /// How many packs of [game] are ticked and how many exist (all = equal).
  ({int ticked, int total}) packSelection(GameKind game) =>
      (ticked: tickedPackIds(game).length, total: _packIds(game).length);

  /// Keeps at least one pack ticked in every game: a change that would untick
  /// them all is undone for that game (the [previous] selection stays). Ids of
  /// packs the TV does not have (yet) stay in the off-set: harmless, and an
  /// upload may return.
  void _normalizePacks([GameSettings? previous]) {
    final changes = <GameKind, Set<String>>{};
    for (final g in _packGames) {
      final all = _packIds(g);
      if (all.isEmpty) continue; // not loaded yet: decide later
      final off = _settings.offPacks(g);
      if (!all.every(off.contains)) continue;
      final before = previous?.offPacks(g) ?? const <String>{};
      changes[g] = all.every(before.contains) ? <String>{} : before;
    }
    if (changes.isNotEmpty) _settings = _settings.withOffPacks(changes);
  }

  String _packsTitle(int ticked, int total) => ticked >= total ? PartyText.allPacks : PartyText.somePacks(ticked, total);

  /// The union of the ticked packs of a game, or null with none loaded.
  T? _union<T>(GameKind game, List<T> packs, String Function(T) idOf,
      T Function(String id, String title, List<T> packs) merge) {
    _normalizePacks();
    final ticked = tickedPackIds(game);
    final chosen = [for (final p in packs) if (ticked.contains(idOf(p))) p];
    if (chosen.isEmpty) return null;
    return merge('union-${game.name}', _packsTitle(chosen.length, packs.length), chosen);
  }

  QuizPack? _quizUnion() {
    _normalizePacks();
    if (packStore == null) return packLookup(null);
    final chosen = [
      for (final id in tickedPackIds(GameKind.quiz))
        if (packLookup(id) != null) packLookup(id)!
    ];
    if (chosen.isEmpty) return null;
    return unionQuiz('union-quiz', _packsTitle(chosen.length, _packIds(GameKind.quiz).length), chosen);
  }

  UljezPack? _unionUljez() => _union(GameKind.uljez, uljezPacks, (p) => p.id, unionUljez);
  ObjasniPack? _unionObjasni() => _union(GameKind.objasni, objasniPacks, (p) => p.id, unionObjasni);
  KolikoPack? _unionKoliko() => _union(GameKind.koliko, kolikoPacks, (p) => p.id, unionKoliko);
  BlefPack? _unionBlef() => _union(GameKind.blef, blefPacks, (p) => p.id, unionBlef);
  TkobiPack? _unionTkobi() => _union(GameKind.tkobi, tkobiPacks, (p) => p.id, unionTkobi);

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
    _applySettings(wanted, ChangeBy.phone);
  }

  void _applySettings(GameSettings wanted, ChangeBy by) {
    final previous = _settings;
    _settings = wanted.clamped();
    _normalizePacks(previous);
    try {
      _settingsFile?.writeAsStringSync(jsonEncode(_settings.toJson()));
    } catch (_) {} // not remembered, still set for this session
    final was = previous.toJson(), now = _settings.toJson();
    for (final k in now.keys) {
      if (jsonEncode(was[k]) != jsonEncode(now[k])) _changedSetting(k, was[k], now[k], by);
    }
    _broadcastLobby();
    _notify();
  }

  /// One setting changed: an entry, the outline, and the TV panel opens (the
  /// pack screen stays when the host is in it).
  void _changedSetting(String key, Object? old, Object? now, ChangeBy by) {
    final c = LobbyChange.setting(_game, key, old, now, by);
    _log(c);
    _changed = c;
    _panel = true;
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

  // Curve and Sumo share the round machinery (countdown, moment, break, drop-outs, results):
  // the session only talks to the sim through RoundSim.
  RoundSim? _sim;
  Bots? _bots;
  var _curveRound = 0;
  // Player id -> sim id (the color index) for everyone in the running match.
  final _simIdOf = <int, int>{};
  final _gone = <int>{}; // player ids killed by a disconnect or a kick

  /// The running Curve match, or null.
  CurveSim? get sim => switch (_sim) { final CurveSim s => s, _ => null };

  /// The running Curve or Sumo match, or null (what the TV loop and the overlays use).
  RoundSim? get roundSim => _sim;

  /// The running Sumo match, or null.
  SumoSim? get sumo => switch (_sim) { final SumoSim s => s, _ => null };
  Bots? get bots => _bots;

  /// Bumped for every round of a match; the TV makes a fresh `CurveGame` each time.
  int get curveRound => _curveRound;

  // --- Tko bi? ---

  List<TkobiPack> tkobiPacks = [];
  TkobiMatch? _tkobi;
  TkobiMatch? get tkobi => _tkobi;

  TkobiPack? tkobiPack(String? id) {
    if (id == null) return tkobiPacks.firstOrNull;
    return tkobiPacks.where((p) => p.id == id).firstOrNull;
  }

  void _startTkobi(List<Player> parts, TkobiPack pack) {
    _tkobi?.dispose();
    _gameHost = hostId;
    _closeHostView();
    _phase = Phase.tkobi;
    _tkobi = TkobiMatch(
      ids: [for (final p in parts) p.id],
      pack: pack,
      settings: _settings,
      send: (id, m) => _byId(id)?.socket?.send(m),
      clock: _clock,
      random: _random,
      sfx: sfx,
      notify: _notify,
      onOver: (scores) => finishGame(scores, game: PartyText.tkobiName),
    )..start();
    _notify();
  }

  // --- Tenkovi ---

  TenkoviTvMatch? _tenkovi;
  TenkoviTvMatch? get tenkovi => _tenkovi;

  void _startTenkovi(List<Player> parts) {
    _tenkovi?.dispose();
    _gameHost = hostId;
    _closeHostView();
    _phase = Phase.tenkovi;
    _tenkovi = TenkoviTvMatch(
      ids: [for (final p in parts) p.id],
      settings: _settings,
      send: (id, m) => _byId(id)?.socket?.send(m),
      random: _random,
      sfx: sfx,
      notify: _notify,
      onOver: (scores) => finishGame(scores, game: PartyText.tenkoviName),
    )..start();
    _notify();
  }

  // --- Blef ---

  List<BlefPack> blefPacks = [];
  BlefMatch? _blef;
  BlefMatch? get blef => _blef;

  BlefPack? blefPack(String? id) {
    if (id == null) return blefPacks.firstOrNull;
    return blefPacks.where((p) => p.id == id).firstOrNull;
  }

  void _startBlef(List<Player> parts, BlefPack pack) {
    _blef?.dispose();
    _gameHost = hostId;
    _closeHostView();
    _phase = Phase.blef;
    _blef = BlefMatch(
      ids: [for (final p in parts) p.id],
      pack: pack,
      settings: _settings,
      send: (id, m) => _byId(id)?.socket?.send(m),
      clock: _clock,
      random: _random,
      sfx: sfx,
      notify: _notify,
      onOver: (scores) => finishGame(scores, game: PartyText.blefName),
    )..start();
    _notify();
  }

  // --- Koliko? ---

  List<KolikoPack> kolikoPacks = [];
  KolikoMatch? _koliko;
  KolikoMatch? get koliko => _koliko;

  KolikoPack? kolikoPack(String? id) {
    if (id == null) return kolikoPacks.firstOrNull;
    return kolikoPacks.where((p) => p.id == id).firstOrNull;
  }

  void _startKoliko(List<Player> parts, KolikoPack pack) {
    _koliko?.dispose();
    _gameHost = hostId;
    _closeHostView();
    _phase = Phase.koliko;
    _koliko = KolikoMatch(
      ids: [for (final p in parts) p.id],
      pack: pack,
      settings: _settings,
      send: (id, m) => _byId(id)?.socket?.send(m),
      clock: _clock,
      random: _random,
      sfx: sfx,
      notify: _notify,
      onOver: (scores) => finishGame(scores, game: PartyText.kolikoName),
    )..start();
    _notify();
  }

  // --- Objasni ---

  /// The word packs, loaded from the bundled assets by main.dart.
  List<ObjasniPack> objasniPacks = [];
  ObjasniMatch? _objasni;
  ObjasniMatch? get objasni => _objasni;

  ObjasniPack? objasniPack(String? id) {
    if (id == null) return objasniPacks.firstOrNull;
    return objasniPacks.where((p) => p.id == id).firstOrNull;
  }

  void _startObjasni(List<Player> parts, ObjasniPack pack) {
    _objasni?.dispose();
    _gameHost = hostId;
    _closeHostView();
    _phase = Phase.objasni;
    _objasni = ObjasniMatch(
      ids: [for (final p in parts) p.id],
      pack: pack,
      settings: _settings,
      hostId: () => hostId,
      send: (id, m) => _byId(id)?.socket?.send(m),
      clock: _clock,
      random: _random,
      sfx: sfx,
      notify: _notify,
      onOver: (scores) => finishGame(scores, game: PartyText.objasniName),
    )..start();
    _notify();
  }

  // --- Uljez ---

  /// The word packs, loaded from the bundled assets by main.dart. Empty until then.
  List<UljezPack> uljezPacks = [];
  UljezMatch? _uljez;
  UljezMatch? get uljez => _uljez;
  Set<int> _lastImpostors = {};

  /// The pack with [id], or the first one for null; null if there is none.
  UljezPack? uljezPack(String? id) {
    if (id == null) return uljezPacks.firstOrNull;
    return uljezPacks.where((p) => p.id == id).firstOrNull;
  }

  void _startUljez(List<Player> parts, UljezPack pack) {
    _uljez?.dispose();
    _gameHost = hostId;
    _closeHostView();
    _phase = Phase.uljez;
    _uljez = UljezMatch(
      ids: [for (final p in parts) p.id],
      pack: pack,
      settings: _settings,
      send: (id, m) => _byId(id)?.socket?.send(m),
      clock: _clock,
      random: _random,
      avoid: _lastImpostors,
      sfx: sfx,
      notify: _notify,
      onOver: (scores) => finishGame(scores, game: UljezText.name),
    )
      ..onAbandon = returnToLobby
      ..start();
    // Kept for the whole session; a leaver in it is harmless (not in the next ids).
    _lastImpostors = {for (final p in parts) if (_uljez!.game.isImpostor(p.id)) p.id};
    _notify();
  }

  // --- Vukodlak: the match holds the rules and every private message ---

  /// Start is refused ('soon') until the TV has screens for the game; tests
  /// of the session itself switch these on.
  bool wolfTvReady = kWolfTvReady;
  bool uljezTvReady = kUljezTvReady;
  bool objasniTvReady = kObjasniTvReady;
  bool kolikoTvReady = kKolikoTvReady;
  bool blefTvReady = kBlefTvReady;
  bool tkobiTvReady = kTkobiTvReady;
  WolfMatch? _wolf;
  Timer? _wolfEndTimer;
  WolfMatch? get wolf => _wolf;

  void _startWolf(List<Player> parts) {
    _wolf?.dispose();
    _gameHost = hostId;
    _closeHostView();
    _phase = Phase.wolf;
    _wolf = WolfMatch(
      ids: [for (final p in parts) p.id],
      nameOf: (id) => _byId(id)?.name ?? '',
      settings: _settings,
      send: (id, m) => _byId(id)?.socket?.send(m),
      clock: _clock,
      random: _random,
      sfx: sfx,
      notify: _notify,
      onOver: (_) {
        _wolfEndTimer?.cancel();
        _wolfEndTimer = Timer(const Duration(seconds: 10), returnToLobby);
      },
    )
      ..onAbandon = returnToLobby
      ..start();
    _notify();
  }

  void _startCurve(List<Player> parts) {
    _closeHostView();
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
    _roundBase = {};
    _gameHost = hostId;
    _phase = Phase.curve;
    _sendStatuses();
    _notify();
  }

  void _startSumo(List<Player> parts) {
    _closeHostView();
    _wasCounting = false;
    _countTicks = 0;
    _simIdOf
      ..clear()
      ..addEntries(parts.map((p) => MapEntry(p.id, p.colorIndex)));
    _gone.clear();
    _sim = SumoSim([for (final p in parts) p.colorIndex],
        config: SumoConfig.forSettings(_settings.sumoMap,
            powerUps: _settings.sumoPowerUps, countdown: _settings.curveCountdown.toDouble()),
        random: _random, names: {for (final p in parts) p.colorIndex: p.name});
    _bots = null;
    _curveRound = 1;
    _roundBase = {};
    _gameHost = hostId;
    _phase = Phase.curve;
    _sendStatuses();
    _notify();
  }

  void _steer(Player p, bool left, bool right) {
    final sid = _simIdOf[p.id];
    final sim = _sim;
    if (_phase != Phase.curve || sid == null || _gone.contains(p.id) || sim is! CurveSim) return;
    sim.setInput(sid, left: left, right: right);
  }

  void _sumoMove(Player p, int dir, int force) {
    final sid = _simIdOf[p.id];
    final sim = _sim;
    if (_phase != Phase.curve || sid == null || _gone.contains(p.id) || sim is! SumoSim) return;
    sim.setMove(sid, dir, force);
  }

  void _sumoDash(Player p) {
    final sid = _simIdOf[p.id];
    final sim = _sim;
    if (_phase != Phase.curve || sid == null || _gone.contains(p.id) || sim is! SumoSim) return;
    sim.dash(sid);
  }

  CurveStatus? _statusFor(Player p, {RoundEnd? end}) {
    final sim = _sim;
    final sid = _simIdOf[p.id];
    if (sim == null || sid == null) return null;
    final head = sim.heads.where((h) => h.id == sid).firstOrNull;
    return CurveStatus(
        alive: (head?.alive ?? false) && !_gone.contains(p.id),
        score: sim.scores[sid] ?? 0,
        target: sim.target,
        round: _curveRound,
        end: end,
        sumo: sim is SumoSim);
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

  /// Who has answered this question (never what): for the faces on the TV.
  Set<int> get quizAnsweredIds => {
        for (final id in _picks.keys)
          if (_byId(id)?.connected ?? false) id,
      };

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
    _closeHostView(); // Igraj: the details are done with
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
    _lastBeatSec = null;
    sfx.play(Sound.quizStart);
    final msg = _questionFor(q);
    for (final id in _quizIds) {
      _byId(id)?.socket?.send(msg);
    }
  }

  int? _lastBeatSec; // the last second whose heartbeat played, this question
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
    final askedFor = now - _stepStart;
    q.advance(now);
    if (q.step != step || q.number != number) {
      _stepStart = now;
      switch (q.step) {
        case QuizStep.revealing:
          // Time ran out (not everyone answered early): the three falling notes.
          if (step == QuizStep.asking && askedFor >= q.limit) sfx.play(Sound.timeUp);
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
      // The whole question ticks: a soft tock each second (the first second is
      // quiet), then in the last 5 s a high click about twice a second and a
      // heartbeat each second, and in the last 3 s four clicks a second.
      final leftMs = (q.limit - (now - _stepStart)).inMilliseconds;
      final sec = (leftMs / 1000).ceil();
      if (sec >= 1 && sec <= 5) {
        if (sec != _lastBeatSec) {
          _lastBeatSec = sec;
          sfx.play(Sound.heartbeat);
        }
        final fast = leftMs <= 3000;
        final slot = (fast ? 2000 : 1000) + (leftMs / (fast ? 250 : 500)).ceil();
        if (slot != _lastTickSec) {
          _lastTickSec = slot;
          sfx.play(Sound.tickUrgent);
        }
      } else if (sec > 5 && sec < q.limit.inSeconds && sec != _lastTickSec) {
        _lastTickSec = sec;
        sfx.play(Sound.quizTick);
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
    _sim?.clearInput(sid);
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

  Duration _waitEnds = Duration.zero;

  /// How long the paused match still waits (30 s from the last time it started waiting); null
  /// when not paused. Never negative.
  Duration? get pauseRemaining {
    if (!_paused) return null;
    final left = _waitEnds - _clock();
    return left.isNegative ? Duration.zero : left;
  }

  /// Who the pause waits for, for the TV's card; null when not paused or waiting for everyone.
  PlayerInfo? get pauseWaitingFor {
    final w = _waitingFor;
    if (!_paused || w == null) return null;
    return PlayerInfo(w.id, w.name, w.colorIndex, w.connected, _scores[w.id] ?? 0, bot: w.bot, character: w.character);
  }

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
    _waitEnds = _clock() + _waitFor30;
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
    _endRoundBreak();
    if (sim.matchOver) {
      // The match was won while the phone was away (the winner moment): no new round, the results.
      finishGame(_gameScores());
      return;
    }
    for (final e in _simIdOf.entries) {
      // A button held through the wait must not turn the new round's head.
      sim.clearInput(e.value);
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
      if (_countTicks++ % sim.tickHz == 0) sfx.play(Sound.countdownBeep);
    } else if (_wasCounting) {
      _wasCounting = false;
      sfx.play(Sound.countdownGo);
    }
  }

  /// What the TV's game loop calls before every tick: the countdown sounds and the
  /// bots' steering. The loop can tick once more after the session has left the game
  /// (the match ends inside the same loop, or Back was pressed), when the bots are
  /// gone: it must do nothing then (a null check here crashed the BRAVIA).
  void beforeGameTick() {
    if (_phase != Phase.curve || _sim == null) return;
    beforeTick();
    _bots?.tick(); // Sumo has no bots
  }

  /// Feed this the events of every `CurveSim.tick()` (CurveGame.onEvents).
  void curveEvents(List<CurveEvent> events) {
    if (_phase != Phase.curve || _sim == null) return;
    var roundOver = false, matchOver = false;
    final died = <int>[];
    int? survivor, matchWinner;
    for (final e in events) {
      switch (e) {
        case Died(:final id):
          died.add(id);
          sfx.play(_sim is SumoSim ? Sound.sumoFall : Sound.crash);
          final p = _byId(_simIdOf.entries.where((x) => x.value == id).firstOrNull?.key ?? -1);
          final status = p == null ? null : _statusFor(p);
          if (status != null) {
            // The event itself says they died, whatever the head reads.
            p!.socket?.send(CurveStatus(
                alive: false, score: status.score, target: status.target, round: status.round, sumo: status.sumo));
          }
          p?.socket?.send(const Effect('colorPulse')); // bots have no socket
        case RoundOver(:final survivorId):
          roundOver = true;
          survivor = survivorId;
        case MatchOver(:final winnerId):
          matchOver = true;
          matchWinner = winnerId;
        case PickedUp():
        case SumoPickedUp():
          sfx.play(Sound.pickup);
        case Dashed():
          sfx.play(Sound.sumoDash);
        case Bumped():
          sfx.play(Sound.sumoBump);
      }
    }
    if (matchOver) {
      sfx.play(Sound.matchWin);
    } else if (roundOver) {
      sfx.play(Sound.roundWin);
    }
    if (roundOver) {
      // The new score and how the round ended for each phone, in one message.
      for (final p in _players) {
        final sid = _simIdOf[p.id];
        // The match is over too: the results follow, so no "next round soon" flag.
        final end = matchOver
            ? null
            : sid == survivor
                ? RoundEnd.won
                : survivor == null && died.contains(sid)
                    ? RoundEnd.tie
                    : RoundEnd.over;
        final status = _statusFor(p, end: end);
        if (status != null) p.socket?.send(status);
      }
    }
    if (!matchOver && !roundOver) return;
    // What each made in this round: the scores now against the scores when it started.
    final scores = _sim!.scores;
    final points = {for (final e in scores.entries) e.key: e.value - (_roundBase[e.key] ?? 0)};
    _roundBase = {...scores};
    if (matchOver) {
      _startMoment(CurveMoment([matchWinner!], points, match: true), () => finishGame(_gameScores()));
    } else {
      // Nobody left standing: those who crashed on this last tick tie.
      final tie = survivor == null;
      _startMoment(CurveMoment(tie ? died : [survivor!], points, tie: tie), _startRoundBreak);
    }
  }

  var _roundBase = <int, int>{}; // sim id -> score when the round began

  // --- the winner moment (Task 52) ---

  /// How long the frozen field shows who won, before the scores card or the results.
  static const momentTime = Duration(milliseconds: 1500);
  Timer? _momentTimer;
  CurveMoment? _moment;

  /// Non-null from the last crash until the card (or results) follows.
  CurveMoment? get moment => _moment;

  void _startMoment(CurveMoment m, void Function() then) {
    _momentTimer?.cancel();
    _moment = m;
    _momentTimer = Timer(momentTime, () {
      _momentTimer = null;
      _moment = null;
      // The game may have ended meanwhile (someone left, Back): then there is nothing to follow.
      if (_phase == Phase.curve) then();
      _notify();
    });
    _notify();
  }

  // --- between rounds (Task 37) ---

  /// How long the scores show between two rounds.
  static const roundBreakTime = Duration(seconds: 4);
  Timer? _roundBreakTimer;
  Duration? _roundBreakEnd;

  /// True from a round's end until the next round starts: the TV shows the
  /// scores (sim.scores, sim.target, the players' faces) instead of the field.
  bool get roundBreak => _roundBreakEnd != null;

  /// Time left of the break; zero when there is none.
  Duration get roundBreakRemaining {
    final end = _roundBreakEnd;
    if (end == null) return Duration.zero;
    final left = end - _clock();
    return left.isNegative ? Duration.zero : left > roundBreakTime ? roundBreakTime : left;
  }

  void _startRoundBreak() {
    _roundBreakTimer?.cancel();
    _roundBreakEnd = _clock() + roundBreakTime;
    _roundBreakTimer = Timer(roundBreakTime, () {
      _roundBreakEnd = null;
      _roundBreakTimer = null;
      nextRound();
      _notify();
    });
    _notify();
  }

  void _endRoundBreak() {
    _momentTimer?.cancel();
    _momentTimer = null;
    _moment = null;
    _roundBreakTimer?.cancel();
    _roundBreakTimer = null;
    _roundBreakEnd = null;
  }

  /// Starts the next round of the match. [curveEvents] schedules it itself
  /// [roundBreakTime] after a RoundOver; calling it by hand ends the break now.
  void nextRound() {
    final sim = _sim;
    if (_phase != Phase.curve || sim == null || !sim.roundOver || sim.matchOver) return;
    if (_paused) return; // paused: the return starts the next round
    _endRoundBreak();
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
  void finishGame(Map<int, int> gameScores, {String? game}) {
    _lastGame = game ?? (_sim is SumoSim ? Strings.gameSumo : _quizPack == null ? Strings.gameCurve : Strings.gameQuiz(_quizPack!.title));
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
    if (_phase == Phase.quiz || _phase == Phase.curve || _phase == Phase.wolf || _phase == Phase.uljez || _phase == Phase.objasni || _phase == Phase.koliko || _phase == Phase.blef || _phase == Phase.tkobi || _phase == Phase.tenkovi) returnToLobby();
  }

  /// Leaves the results phase. The TV calls it 8 s after [finishGame].
  void returnToLobby() {
    _phase = Phase.lobby;
    _closeHostView();
    _gameHost = null;
    _stopWait();
    _placements = [];
    _stopQuiz();
    _wolf?.dispose();
    _wolf = null;
    _wolfEndTimer?.cancel();
    _uljez?.dispose();
    _uljez = null;
    _objasni?.dispose();
    _objasni = null;
    _koliko?.dispose();
    _koliko = null;
    _blef?.dispose();
    _blef = null;
    _tkobi?.dispose();
    _tkobi = null;
    _tenkovi?.dispose();
    _tenkovi = null;
    _endRoundBreak();
    _sim = null;
    _bots = null;
    _simIdOf.clear();
    _gone.clear();
    _broadcastLobby();
    _notify();
  }
}

/// What the TV shows over the frozen Curve field after the last crash: [ids] are sim ids (colour
/// indexes): the round winner, the match winner, or those who crashed together ([tie]).
class CurveMoment {
  const CurveMoment(this.ids, this.points, {this.match = false, this.tie = false});
  final List<int> ids;

  /// Sim id -> points made in this round (+N on the winner screen).
  final Map<int, int> points;
  final bool match, tie;
}
