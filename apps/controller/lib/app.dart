import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'connection.dart';
import 'screens/curve_screen.dart';
import 'theme.dart';
import 'screens/join_screen.dart';
import 'screens/kick.dart';
import 'screens/lobby_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/results_screen.dart';
import 'screens/sumo_screen.dart';
import 'screens/wait_screen.dart';
import 'screens/blef_flow.dart';
import 'screens/koliko_flow.dart';
import 'screens/objasni_flow.dart';
import 'screens/tkobi_flow.dart';
import 'screens/uljez_flow.dart';
import 'screens/wolf_flow.dart';
import 'strings.dart';

enum _Screen {
  join,
  lobby,
  wait,
  curve,
  quiz,
  results,
  wolf,
  uljez,
  objasni,
  koliko,
  blef,
  tkobi,
  kicked,
}

/// What the browser keeps after a join, so a reload rejoins by itself.
class SavedJoin {
  const SavedJoin(this.name, this.character);
  final String name, character;
}

/// Routes the TV's messages to a screen. No web imports, so it runs in tests.
class App extends StatefulWidget {
  const App(this.conn, {this.addPack, this.saved, this.onSave, super.key});
  final Connection conn;

  /// A name kept from an earlier join: send Join at once instead of asking.
  final SavedJoin? saved;

  /// Called with the name and character to keep, or null to forget them
  /// (kicked, or the TV refused the automatic rejoin). Browser-only in main.
  final void Function(SavedJoin?)? onSave;

  /// Browser-only pack upload (see pack_upload.dart); null in tests.
  final Future<String?> Function(String token)? addPack;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late _Screen _screen = widget.saved == null ? _Screen.join : _Screen.lobby;
  late bool _rejoining = widget.saved != null; // no Welcome yet
  int _myId = -1;
  int _myColor =
      0; // from Welcome, so it survives a reload before any LobbyState
  LobbyState? _lobby;
  int? _host; // from HostIs; null until one arrives, reset by a LobbyState
  String _waitReason = '';
  String? _error;
  bool _alive = true;
  int _curveScore = 0;
  int? _curveRound;
  RoundEnd? _curveEnd;
  bool _curveSumo = false; // the round game on the TV is Sumo, not Curve
  QuizQuestion? _question;
  QuizReveal? _reveal;
  int _quizTotal = 0; // running total, from the last reveal
  List<Placement> _placements = const [];
  final _wolf = WolfInbox();
  final _uljez = UljezInbox();
  final _objasni = ObjasniInbox();
  final _koliko = KolikoInbox();
  final _blef = BlefInbox();
  final _tkobi = TkobiInbox();
  // Vukodlak and Uljez share VotePrompt; the game that started last owns it.
  bool _uljezOn = false;
  List<PlayerInfo>? _inGame; // GamePlayers: who is still in, until a lobby state
  StreamSubscription<Message>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.conn.messages.listen(_onMessage);
    final s = widget.saved;
    if (s != null) {
      widget.conn.send(
        Join(
          s.name,
          widget.conn.token,
          character: s.character.isEmpty ? null : s.character,
        ),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  final _nav = GlobalKey<NavigatorState>(); // a context below the EffectLayer

  /// Plays what the TV asks for. A pulse takes this phone's player color.
  void _playEffect(Effect m) {
    final ctx = _nav.currentContext;
    final name = EffectName.values.where((n) => n.name == m.name).firstOrNull;
    if (ctx == null || name == null) return;
    EffectLayer.play(
      ctx,
      name,
      color: playerColors[_myColor % playerColors.length],
      text: _reveal == null ? null : '+${_reveal!.yourPoints}',
    );
  }

  void _onMessage(Message m) {
    if (m is Effect) return _playEffect(m);
    final before = _screen;
    setState(() {
      switch (m) {
        case Welcome():
          _rejoining = false;
          _myId = m.playerId;
          _myColor = m.colorIndex;
          _error = null;
          _screen = _Screen.lobby;
        case LobbyState():
          _lobby = m;
          _host = null; // the lobby state says who hosts
          _uljezOn = false; // back in the lobby: no game is on
          _wolf.reset();
          _inGame = null;
          final me = m.players.where((p) => p.id == _myId).firstOrNull;
          if (me != null && !_rejoining) {
            widget.onSave?.call(SavedJoin(me.name, me.character));
          }
          if (_screen != _Screen.kicked) _screen = _Screen.lobby;
        case GamePlayers():
          _inGame = m.players;
        case HostIs():
          _host = m.host; // mid-game the TV sends this instead
        case Waiting():
          _waitReason = m.reason;
          _screen = _Screen.wait;
        case CurveStatus():
          if (_screen != _Screen.curve) _error = null;
          _alive = m.alive;
          _curveScore = m.score;
          _curveRound = m.round;
          _curveEnd = m.end;
          _curveSumo = m.sumo;
          _screen = _Screen.curve;
        case QuizQuestion():
          _question = m;
          _reveal = null;
          if (m.number == 1) _quizTotal = 0;
          _screen = _Screen.quiz;
        case QuizReveal():
          _quizTotal = m.yourTotal;
          _reveal =
              m; // also after a reconnect mid-reveal, when there is no question
          _screen = _Screen.quiz;
        case Results():
          _placements = m.placements;
          _screen = _Screen.results;
        case TkobiAsk() || TkobiResult():
          _tkobi.on(m);
          _screen = _Screen.tkobi;
        case BlefWrite() || BlefList() || BlefResult():
          if (m is BlefWrite) _error = null;
          _blef.on(m);
          _screen = _Screen.blef;
        case KolikoAsk() || KolikoResult():
          _koliko.on(m);
          _screen = _Screen.koliko;
        case ObjasniTeams() || ObjasniTurn():
          _objasni.on(m);
          _screen = _Screen.objasni;
        case UljezWord():
          _uljezOn = true;
          _uljez.on(m);
          _screen = _Screen.uljez;
        case UljezTurn() || UljezGuess() || UljezEnd():
          _uljez.on(m);
          _screen = _Screen.uljez;
        case VoteWish() when _uljezOn:
          _uljez.on(m);
          _screen = _Screen.uljez;
        case VoteWish():
          _wolf.on(m);
          _screen = _Screen.wolf;
        case VotePrompt() when _uljezOn:
          _uljez.on(m);
          _screen = _Screen.uljez;
        case RoleMsg() ||
            PlayWait() ||
            NightPrompt() ||
            Morning() ||
            VotePrompt() ||
            Farewell() ||
            WolfEnd():
          if (m is RoleMsg) _uljezOn = false;
          _wolf.on(m);
          _screen = _Screen.wolf;
        case Kicked():
          widget.onSave?.call(null);
          _screen = _Screen.kicked;
        case ErrorMsg():
          if (_rejoining) {
            // The TV refused the automatic rejoin: ask for the name again.
            _rejoining = false;
            widget.onSave?.call(null);
            _screen = _Screen.join;
          } else {
            _error = m.message;
          }
        default:
          break;
      }
    });
    // A grid, a roles list or a sheet the host left open must not stay on top
    // of a game the TV just started.
    // The host's kick list or confirm, opened by day, must not outlive the
    // day: its Ukloni would still send a Kick at night.
    if ((before == _Screen.lobby && _screen != _Screen.lobby) ||
        m is NightPrompt) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _nav.currentState?.popUntil((r) => r.isFirst),
      );
    }
  }

  /// Who hosts now: HostIs (sent mid-game) until the next LobbyState.
  int? get _hostId => _host ?? _lobby?.hostId;

  /// The host's way to remove a player who has gone away, during Uljez and in
  /// Vukodlak (night too: a night waits for every phone). Everyone knows who
  /// the host is, and the bar is the same for every role.
  bool get _kickBar {
    if (_hostId != _myId) return false;
    return switch (_screen) {
      _Screen.uljez => _uljez.screen != 'end',
      // The others wait while the caught impostor guesses.
      _Screen.wait => _uljezOn && _uljez.screen != 'end',
      _Screen.wolf =>
        _wolf.screen == 'vote' ||
            _wolf.screen == 'night' ||
            (_wolf.screen == 'idle' &&
                (_wolf.morning != null || _wolf.ready != null)),
      _ => false,
    };
  }

  PlayerInfo? get _me =>
      _lobby?.players.where((p) => p.id == _myId).firstOrNull;

  Widget _body() => switch (_screen) {
    _Screen.join => JoinScreen(widget.conn, onJoined: () {}),
    _Screen.lobby =>
      _lobby == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : LobbyScreen(widget.conn, _lobby!, _myId, addPack: widget.addPack),
    _Screen.wait => WaitScreen(_waitReason),
    _Screen.curve when _curveSumo => SumoScreen(
      widget.conn,
      alive: _alive,
      name: _me?.name ?? '',
      character: _me?.character ?? '',
      colorIndex: _myColor,
      score: _curveScore,
      round: _curveRound,
      end: _curveEnd,
    ),
    _Screen.curve => CurveScreen(
      widget.conn,
      alive: _alive,
      name: _me?.name ?? '',
      character: _me?.character ?? '',
      colorIndex: _myColor,
      score: _curveScore,
      round: _curveRound,
      end: _curveEnd,
    ),
    _Screen.quiz => QuizScreen(
      widget.conn,
      _question,
      _reveal,
      total: _quizTotal,
      key: ValueKey(_question?.number),
    ),
    _Screen.results => ResultsScreen(_placements, _myId),
    _Screen.tkobi =>
      _lobby == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : TkobiFlow(widget.conn, _lobby!, _tkobi),
    _Screen.blef => BlefFlow(
      widget.conn,
      _blef,
      error: _error,
      onSend: () => setState(() => _error = null),
    ),
    _Screen.koliko => KolikoFlow(widget.conn, _koliko),
    _Screen.objasni =>
      _lobby == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : ObjasniFlow(
              widget.conn,
              _lobby!,
              _myId,
              _objasni,
              hostId: _hostId ?? _lobby!.hostId,
            ),
    _Screen.uljez =>
      _lobby == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : UljezFlow(widget.conn, _lobby!, _myId, _uljez),
    _Screen.wolf =>
      _lobby == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : WolfFlow(widget.conn, _lobby!, _myId, _wolf),
    _Screen.kicked => _Kicked(
      onJoinAgain: () => setState(() => _screen = _Screen.join),
    ),
  };

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: Strings.appTitle,
    navigatorKey: _nav,
    builder: (_, child) => EffectLayer(child: child!),
    theme: theme,
    // The join screen shows its own errors.
    home: Column(
      children: [
        if (_error != null &&
            _screen != _Screen.join &&
            _screen != _Screen.blef)
          Material(
            color: Colors.red.shade900,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _error = null),
                      child: const Text(Strings.ok),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: _kickBar
              ? MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: _body(),
                )
              : _body(),
        ),
        if (_kickBar)
          HostKickBar(
            conn: widget.conn,
            players: _inGame ?? _lobby?.players ?? const [],
            myId: _myId,
          ),
      ],
    ),
  );
}

class _Kicked extends StatelessWidget {
  const _Kicked({required this.onJoinAgain});
  final VoidCallback onJoinAgain;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            Strings.removed,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
            ),
            onPressed: onJoinAgain,
            child: const Text(
              Strings.joinAgain,
              style: TextStyle(fontSize: 24),
            ),
          ),
        ],
      ),
    ),
  );
}
