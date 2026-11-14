import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'packs/pack_store.dart';
import 'server/controller_files.dart';
import 'server/game_server.dart';
import 'server/lan_address.dart';
import 'session/session.dart';
import 'ui/back_guard.dart';
import 'ui/curve/curve_game.dart';
import 'ui/lobby_screen.dart';
import 'ui/perf_log.dart';
import 'ui/results_screen.dart';
import 'ui/quiz_screen.dart';
import 'ui/tv_theme.dart';

const _perf = bool.fromEnvironment('PERF');
// QA/perf: pre-seeds this many bots when the first phone joins, e.g. BOTS=7.
// The host can still change it with the - / + buttons.
const _botCount = int.fromEnvironment('BOTS');
// QA only: e.g. QA_POWERUP=ghost puts that power-up just ahead of the first
// human every round.
const _qaPowerUp = String.fromEnvironment('QA_POWERUP');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (_perf) PerfLog.start();
  runApp(const TvApp());
}

class TvApp extends StatefulWidget {
  const TvApp({super.key});
  @override
  State<TvApp> createState() => _TvAppState();
}

class _TvAppState extends State<TvApp> {
  final _session = Session();
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

  @override
  void initState() {
    super.initState();
    _session.changes.addListener(_onSession);
    _purge = Timer.periodic(const Duration(minutes: 1), (_) => _session.purgeStale());
    _start();
  }

  @override
  void dispose() {
    _purge?.cancel();
    _resultsTimer?.cancel();
    _session.changes.removeListener(_onSession);
    _server?.close();
    _session.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final zip = await rootBundle.load('assets/controller.zip');
      final support = await getApplicationSupportDirectory();
      final web = Directory('${support.path}/web');
      if (await web.exists()) await web.delete(recursive: true);
      await extractControllerZip(zip.buffer.asUint8List(), web);
      _session.packStore = await PackStore.load(
          bundled: await loadBundledPacks(rootBundle), userDir: Directory('${support.path}/packs'));
      final server = await GameServer.start(
        webRoot: web,
        onPeer: _session.attach,
        onPackUpload: _session.onPackUpload,
      );
      _server = server;
      final ip = pickLanAddress(await NetworkInterface.list(type: InternetAddressType.IPv4));
      _session.joinUrl = ip == null ? null : 'http://$ip:${server.port}/';
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start: $e');
    }
  }

  void _onSession() {
    if (!mounted) return;
    if (!_botsSeeded && _botCount > 0 && _session.players.any((p) => !p.bot)) {
      _botsSeeded = true;
      _session.setBotCount(_botCount); // notifies again; the next pass does the rest
      return;
    }
    // Results stay up for 8 s, then back to the lobby.
    if (_session.phase == Phase.results) {
      _resultsTimer ??= Timer(const Duration(seconds: 8), () {
        _resultsTimer = null;
        _session.returnToLobby();
      });
    } else {
      _resultsTimer?.cancel();
      _resultsTimer = null;
    }
    final sim = _session.sim;
    if (_session.phase == Phase.curve && sim != null) {
      if (sim != _gameSim || _session.curveRound != _gameRound) _newGame(sim);
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
          onBeforeTick: _session.bots!.tick, onEvents: _onCurveEvents);
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

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final quiz = _session.phase == Phase.quiz ? _session.quiz : null;
    return MaterialApp(
      title: 'Couchplay',
      showPerformanceOverlay: _perf,
      navigatorKey: _nav,
      builder: (_, child) => BackGuard(
        navigatorKey: _nav,
        active: () => _session.phase == Phase.quiz || _session.phase == Phase.curve,
        onEnd: _session.endGame,
        child: EffectLayer(child: child!),
      ),
      theme: tvTheme(),
      home: _error != null
          ? Scaffold(body: Center(child: Text(_error!, style: const TextStyle(fontSize: 40))))
          : quiz != null
              ? Scaffold(
                  body: QuizScreen(
                    question: quiz.current.q,
                    svg: _session.quizSvg,
                    choices: quiz.current.choices,
                    number: quiz.number,
                    total: quiz.total,
                    remaining: _session.quizRemaining,
                    answered: _session.quizAnswered,
                    expected: _session.quizExpected,
                    correctIndex:
                        quiz.step == QuizStep.asking ? null : quiz.current.correctIndex,
                    picks: _session.quizPicks,
                    players: _session.playerInfos,
                    totals: quiz.totals,
                  ),
                )
          : game != null
              ? Scaffold(body: GameWidget(key: ValueKey('$_gameSim-$_gameRound'), game: game))
              : _session.phase == Phase.results
              ? ResultsScreen(placements: _session.placements, players: _session.playerInfos)
              : LobbyScreen(
                  joinUrl: _session.joinUrl,
                  players: _session.playerInfos,
                  hostId: _session.hostId,
                  onQuit: SystemNavigator.pop),
    );
  }
}
