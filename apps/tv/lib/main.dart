import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'packs/pack_store.dart';
import 'packs/party_packs.dart';
import 'packs/uljez_packs.dart';
import 'server/controller_files.dart';
import 'server/game_server.dart';
import 'server/lan_address.dart';
import 'session/session.dart';
import 'ui/back_guard.dart';
import 'ui/curve/curve_game.dart';
import 'ui/curve/round_break_card.dart';
import 'ui/home_screen.dart';
import 'ui/pack_tiles.dart';
import 'ui/pause_card.dart';
import 'ui/perf_log.dart';
import 'ui/results_screen.dart';
import 'ui/blef/blef_view.dart';
import 'ui/koliko/koliko_view.dart';
import 'ui/tkobi/tkobi_view.dart';
import 'ui/objasni/objasni_view.dart';
import 'ui/uljez/uljez_view.dart';
import 'ui/wolf/wolf_view.dart';
import 'ui/quiz_screen.dart';
import 'ui/tv_theme.dart';
import 'sound/audio_sfx.dart';
import 'strings.dart';

const _perf = bool.fromEnvironment('PERF');

/// QA bisect: --dart-define=NOTICKERS=true mutes every ticker in the app. If the frames on an idle home
/// then stop, an animation was the cause; if not, something asks for frames without one.
const _noTickers = bool.fromEnvironment('NOTICKERS');
// QA/perf: pre-seeds this many bots when the first phone joins, e.g. BOTS=7.
// The host can still change it with the - / + buttons.
const _botCount = int.fromEnvironment('BOTS');
// QA only: e.g. QA_POWERUP=ghost puts that power-up just ahead of the first
// human every round.
const _qaPowerUp = String.fromEnvironment('QA_POWERUP');

void main() {
  if (_perf) {
    PerfBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
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
      _session.objasniPacks = await loadObjasniPacks(rootBundle);
      _session.kolikoPacks = await loadKolikoPacks(rootBundle);
      _session.blefPacks = await loadBlefPacks(rootBundle);
      _session.tkobiPacks = await loadTkobiPacks(rootBundle);
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
    // The next round starts by itself after the scores break (Session.roundBreak).
  }

  /// The scores for a few seconds after each Curve round (Task 37), in place of the field.
  Widget? _breakOverlay() {
    final sim = _gameSim;
    if (!_session.roundBreak || sim == null) return null;
    final infos = {for (final p in _session.playerInfos) p.colorIndex: p};
    return Positioned.fill(
      child: RoundBreakCard(
        round: _session.curveRound,
        target: sim.target,
        remaining: () => _session.roundBreakRemaining,
        players: [
          for (final h in sim.heads)
            if (infos[h.id] case final p?)
              BreakPlayer(name: p.name, colorIndex: p.colorIndex, character: p.character, score: sim.scores[h.id] ?? 0),
        ],
      ),
    );
  }

  /// Over the frozen game while it waits for players to come back.
  Widget? _pauseOverlay() {
    if (!_session.paused) return null;
    return Positioned.fill(
      child: PauseCard(who: _session.pauseWaitingFor, remaining: () => _session.pauseRemaining ?? Duration.zero),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    final quiz = _session.phase == Phase.quiz ? _session.quiz : null;
    final app = MaterialApp(
      title: 'Couchplay',
      navigatorKey: _nav,
      builder: (_, child) => BackGuard(
        navigatorKey: _nav,
        active: () => _session.phase == Phase.quiz || _session.phase == Phase.curve || _session.phase == Phase.wolf || _session.phase == Phase.uljez || _session.phase == Phase.objasni || _session.phase == Phase.koliko || _session.phase == Phase.blef || _session.phase == Phase.tkobi,
        changes: _session.changes,
        onEnd: _session.endGame,
        // Back also offers "Ukloni igrača" (the way out when a phone has left mid-game).
        players: () => _session.playerInfos,
        onKick: _session.kickFromTv,
        // Back on the results screen moves on at once instead of waiting out the hold.
        onIdleBack: () {
          if (_session.phase != Phase.results) return false;
          _session.returnToLobby();
          return true;
        },
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
                    answeredIds: _session.quizAnsweredIds,
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
                    GameWidget(key: ValueKey('$_gameSim-$_gameRound'), game: game, autofocus: false),
                    ?_breakOverlay(),
                    ?_pauseOverlay(),
                  ]),
                )
              : _session.phase == Phase.wolf && _session.wolf != null
              ? WolfView(match: _session.wolf!, players: _session.playerInfos)
              : _session.phase == Phase.uljez && _session.uljez != null
              ? UljezView(match: _session.uljez!, players: _session.playerInfos)
              : _session.phase == Phase.objasni && _session.objasni != null
              ? ObjasniView(match: _session.objasni!, players: _session.playerInfos)
              : _session.phase == Phase.koliko && _session.koliko != null
              ? KolikoView(match: _session.koliko!, players: _session.playerInfos)
              : _session.phase == Phase.blef && _session.blef != null
              ? BlefView(match: _session.blef!, players: _session.playerInfos)
              : _session.phase == Phase.tkobi && _session.tkobi != null
              ? TkobiView(match: _session.tkobi!, players: _session.playerInfos)
              : _session.phase == Phase.results
              ? ResultsScreen(
                  placements: _session.placements,
                  players: _session.playerInfos,
                  label: _session.lastGameLabel)
              : HomeScreen(
                  joinUrl: _session.joinUrl,
                  players: _session.playerInfos,
                  settings: _session.settings,
                  selected: _session.homeGame,
                  hostView: _session.hostView,
                  changed: _session.changed,
                  packGrid: _session.hostView == HostView.packs ? packTiles(_session, _session.homeGame) : null,
                  onOpenSettings: _session.openSettingsFromTv,
                  onCloseSettings: _session.closeSettingsFromTv,
                  packs: {
                    for (final k in const [GameKind.quiz, GameKind.uljez, GameKind.objasni, GameKind.koliko, GameKind.blef, GameKind.tkobi])
                      k: _session.packSelection(k),
                  },
                  quizPacks: _session.packStore?.infos.length ?? 0,
                  quizQuestions: _session.packStore?.infos.fold<int>(0, (a, p) => a + p.questionCount) ?? 0,
                  notice: _notice,
                  onSelect: _session.selectFromTv,
                  onPlay: _play),
    );
    return _noTickers ? TickerMode(enabled: false, child: app) : app;
  }
}
