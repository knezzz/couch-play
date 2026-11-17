import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'packs/pack_store.dart';
import 'packs/uljez_packs.dart';
import 'server/controller_files.dart';
import 'server/game_server.dart';
import 'server/lan_address.dart';
import 'session/session.dart';
import 'ui/back_guard.dart';
import 'ui/curve/curve_game.dart';
import 'ui/curve/curve_hud.dart';
import 'ui/home_screen.dart';
import 'ui/perf_log.dart';
import 'ui/results_screen.dart';
import 'ui/uljez/uljez_view.dart';
import 'ui/wolf/wolf_view.dart';
import 'ui/quiz_screen.dart';
import 'ui/tv_theme.dart';
import 'sound/audio_sfx.dart';
import 'strings.dart';

const _perf = bool.fromEnvironment('PERF');
// QA/perf: pre-seeds this many bots when the first phone joins, e.g. BOTS=7.
// The host can still change it with the - / + buttons.
const _botCount = int.fromEnvironment('BOTS');
// QA only: e.g. QA_POWERUP=ghost puts that power-up just ahead of the first
// human every round.
const _qaPowerUp = String.fromEnvironment('QA_POWERUP');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // A TV has no touch: focus rings show from the start, not after a key press.
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  if (_perf) PerfLog.start();
  runApp(const TvApp());
}

class TvApp extends StatefulWidget {
  /// Tests pass their own [session] and set [serve] false (no web server, no
  /// assets).
  const TvApp({super.key, this.session, this.serve = true});
  final Session? session;
  final bool serve;
  @override
  State<TvApp> createState() => _TvAppState();
}

class _TvAppState extends State<TvApp> {
  late final Session _session = widget.session ?? Session();
  final _nav = GlobalKey<NavigatorState>(); // a context below the EffectLayer
  GameServer? _server;
  Timer? _purge, _resultsTimer;
  String? _error;

  // The CurveGame on screen. Trails are never cleared by the game itself, so
  // every round gets a fresh one.
  CurveGame? _game;
  CurveSim? _gameSim;
  int _gameRound = -1;
  var _botsSeeded = false;

  // The game the home shows. The session forgets its selection when a game
  // starts; the home comes back to the same game.
  GameKind? _homeGame;
  // Why OK did nothing (e.g. nobody has joined), shown a few seconds.
  String? _notice;
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    PerfLog.screen = () => switch (_session.phase) {
          Phase.lobby => 'home',
          final p => p.name,
        };
    _session.changes.addListener(_onSession);
    _purge = Timer.periodic(const Duration(minutes: 1), (_) => _session.purgeStale());
    if (widget.serve) _start();
  }

  @override
  void dispose() {
    _purge?.cancel();
    _resultsTimer?.cancel();
    _noticeTimer?.cancel();
    _session.changes.removeListener(_onSession);
    _server?.close();
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    AudioSfx.load().then((sfx) => _session.sfx = sfx); // never throws; silent if it fails
    try {
      final zip = await rootBundle.load('assets/controller.zip');
      final support = await getApplicationSupportDirectory();
      final web = Directory('${support.path}/web');
      if (await web.exists()) await web.delete(recursive: true);
      await extractControllerZip(zip.buffer.asUint8List(), web);
      _session.packStore = await PackStore.load(
          bundled: await loadBundledPacks(rootBundle), userDir: Directory('${support.path}/packs'));
      _session.uljezPacks = await loadUljezPacks(rootBundle);
      _session.loadSettings(File('${support.path}/settings.json'));
      final server = await GameServer.start(
        webRoot: web,
        onPeer: _session.attach,
        onPackUpload: _session.onPackUpload,
      );
      _server = server;
      final ip = pickLanAddress(await NetworkInterface.list(type: InternetAddressType.IPv4));
      _session.joinUrl = ip == null ? null : 'http://$ip:${server.port}/';
    } catch (e) {
      if (mounted) setState(() => _error = Strings.startFailed(e));
    }
  }

  void _onSession() {
    if (!mounted) return;
    _homeGame = _session.selectedGame ?? _homeGame;
    if (!_botsSeeded && _botCount > 0 && _session.players.any((p) => !p.bot)) {
      _botsSeeded = true;
      _session.setBotCount(_botCount); // notifies again; the next pass does the rest
      return;
    }
    // Results stay up for 8 s, then back to the lobby.
    if (_session.phase == Phase.results) {
      _resultsTimer ??= Timer(resultsHold, () {
        _resultsTimer = null;
        _session.returnToLobby();
      });
    } else {
      _resultsTimer?.cancel();
      _resultsTimer = null;
    }
    final sim = _session.sim;
    if (_session.phase == Phase.curve && sim != null) {
      if (sim != _gameSim || _session.curveRound != _gameRound) {
        _newGame(sim);
      } else {
        setState(() {}); // e.g. the pause text appears or goes
      }
    } else if (_game != null) {
      setState(() {
        _game = null;
        _gameSim = null;
        _gameRound = -1;
      });
    } else {
      setState(() {}); // lobby content changed
    }
  }

  void _play(GameKind game) {
    final why = _session.startFromTv(game);
    if (why == null) return;
    _noticeTimer?.cancel();
    setState(() => _notice = why);
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  /// Who is in the running Curve match and their score (the sim's head ids are the colour indices).
  List<CurveHudPlayer> _hudPlayers() {
    final sim = _gameSim;
    if (sim == null) return const [];
    final infos = {for (final p in _session.playerInfos) p.colorIndex: p};
    return [
      for (final h in sim.heads)
        if (infos[h.id] case final p?)
          CurveHudPlayer(name: p.name, colorIndex: p.colorIndex, character: p.character, score: sim.scores[h.id] ?? 0, away: !p.connected),
    ];
  }

  void _newGame(CurveSim sim) {
    if (_qaPowerUp.isNotEmpty) {
      final human = _session.players.where((p) => !p.bot).firstOrNull;
      final h = human == null
          ? null
          : sim.heads.where((h) => h.id == human.colorIndex).firstOrNull;
      if (h != null) {
        sim.placePowerUp(PowerUpKind.values.byName(_qaPowerUp),
            h.x + cos(h.heading) * 120, h.y + sin(h.heading) * 120);
      }
    }
    setState(() {
      _gameSim = sim;
      _gameRound = _session.curveRound;
      _game = CurveGame(sim, playerColors,
          characters: {for (final p in _session.playerInfos) p.colorIndex: p.character},
          onBeforeTick: _session.beforeGameTick,
          onEvents: _onCurveEvents,
          holdWhen: () => _session.paused);
    });
  }

  void _onCurveEvents(List<CurveEvent> events) {
    _session.curveEvents(events);
    final fx = _nav.currentContext;
    if (fx != null) {
      for (final e in events) {
        if (e is Died) {
          EffectLayer.play(fx, EffectName.edgeGlow, color: playerColors[e.id % playerColors.length]);
        }
      }
    }
    if (events.any((e) => e is RoundOver) && _session.phase == Phase.curve) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _session.nextRound();
      });
    }
  }

  /// Over the frozen game while it waits for players to come back.
  Widget? _pauseOverlay() {
    final text = _session.pauseText;
    if (text == null) return null;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
        color: const Color(0xCC000000),
        child: Text(text, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w700)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final quiz = _session.phase == Phase.quiz ? _session.quiz : null;
    return MaterialApp(
      title: 'Couchplay',
      navigatorKey: _nav,
      builder: (_, child) => BackGuard(
        navigatorKey: _nav,
        active: () => _session.phase == Phase.quiz || _session.phase == Phase.curve || _session.phase == Phase.wolf || _session.phase == Phase.uljez,
        changes: _session.changes,
        onEnd: _session.endGame,
        child: EffectLayer(child: child!),
      ),
      theme: tvTheme(),
      home: _error != null
          ? Scaffold(body: Center(child: Text(_error!, style: const TextStyle(fontSize: 40))))
          : quiz != null
              ? Scaffold(
                  body: Stack(children: [
                    QuizScreen(
                    question: quiz.current.q,
                    picture: _session.quizPicture,
                    pictureName: _session.quizPictureName,
                    choices: quiz.current.choices,
                    number: quiz.number,
                    total: quiz.total,
                    remaining: _session.quizRemaining,
                    limitSeconds: quiz.limit.inSeconds,
                    answered: _session.quizAnswered,
                    expected: _session.quizExpected,
                    correctIndex:
                        quiz.step == QuizStep.asking ? null : quiz.current.correctIndex,
                    packTitle: _session.quizTitle,
                    picks: _session.quizPicks,
                    points: quiz.lastPoints,
                    players: _session.playerInfos,
                    totals: quiz.totals,
                    ),
                    ?_pauseOverlay(),
                  ]),
                )
          : game != null
              ? Scaffold(
                  body: Stack(children: [
                    Column(children: [
                      CurveHud(
                        round: _session.curveRound,
                        target: _gameSim?.target ?? 0,
                        modeName: Strings.curveModeName(_session.settings.curveMode),
                        players: _hudPlayers(),
                      ),
                      Expanded(child: GameWidget(key: ValueKey('$_gameSim-$_gameRound'), game: game, autofocus: false)),
                    ]),
                    ?_pauseOverlay(),
                  ]),
                )
              : _session.phase == Phase.wolf && _session.wolf != null
              ? WolfView(match: _session.wolf!, players: _session.playerInfos)
              : _session.phase == Phase.uljez && _session.uljez != null
              ? UljezView(match: _session.uljez!, players: _session.playerInfos)
              : _session.phase == Phase.results
              ? ResultsScreen(
                  placements: _session.placements,
                  players: _session.playerInfos,
                  label: _session.lastGameLabel)
              : HomeScreen(
                  joinUrl: _session.joinUrl,
                  players: _session.playerInfos,
                  settings: _session.settings,
                  selected: _session.selectedGame ?? _homeGame,
                  packTitle: _session.selectedPackTitle,
                  notice: _notice,
                  onSelect: (k) {
                    _homeGame = k;
                    _session.selectFromTv(k);
                  },
                  onPlay: _play),
    );
  }
}
