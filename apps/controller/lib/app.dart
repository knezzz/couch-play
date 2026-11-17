import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'connection.dart';
import 'screens/curve_screen.dart';
import 'theme.dart';
import 'screens/join_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/results_screen.dart';
import 'screens/wait_screen.dart';
import 'screens/uljez_flow.dart';
import 'screens/wolf_flow.dart';
import 'strings.dart';

enum _Screen { join, lobby, wait, curve, quiz, results, wolf, uljez, kicked }

/// Routes the TV's messages to a screen. No web imports, so it runs in tests.
class App extends StatefulWidget {
  const App(this.conn, {this.addPack, super.key});
  final Connection conn;

  /// Browser-only pack upload (see pack_upload.dart); null in tests.
  final Future<String?> Function(String token)? addPack;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  _Screen _screen = _Screen.join;
  int _myId = -1;
  int _myColor =
      0; // from Welcome, so it survives a reload before any LobbyState
  LobbyState? _lobby;
  String _waitReason = '';
  String? _error;
  bool _alive = true;
  QuizQuestion? _question;
  QuizReveal? _reveal;
  int _quizTotal = 0; // running total, from the last reveal
  List<Placement> _placements = const [];
  final _wolf = WolfInbox();
  final _uljez = UljezInbox();
  // Vukodlak and Uljez share VotePrompt; the game that started last owns it.
  bool _uljezOn = false;
  StreamSubscription<Message>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.conn.messages.listen(_onMessage);
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
    setState(() {
      switch (m) {
        case Welcome():
          _myId = m.playerId;
          _myColor = m.colorIndex;
          _error = null;
          _screen = _Screen.lobby;
        case LobbyState():
          _lobby = m;
          if (_screen != _Screen.kicked) _screen = _Screen.lobby;
        case Waiting():
          _waitReason = m.reason;
          _screen = _Screen.wait;
        case CurveStatus():
          if (_screen != _Screen.curve) _error = null;
          _alive = m.alive;
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
        case UljezWord():
          _uljezOn = true;
          _uljez.on(m);
          _screen = _Screen.uljez;
        case UljezTurn() || UljezGuess() || UljezEnd():
          _uljez.on(m);
          _screen = _Screen.uljez;
        case VotePrompt() when _uljezOn:
          _uljez.on(m);
          _screen = _Screen.uljez;
        case RoleMsg() ||
            NightPrompt() ||
            Morning() ||
            VotePrompt() ||
            Farewell() ||
            WolfEnd():
          if (m is RoleMsg) _uljezOn = false;
          _wolf.on(m);
          _screen = _Screen.wolf;
        case Kicked():
          _screen = _Screen.kicked;
        case ErrorMsg():
          _error = m.message;
        default:
          break;
      }
    });
  }

  Widget _body() => switch (_screen) {
    _Screen.join => JoinScreen(widget.conn, onJoined: () {}),
    _Screen.lobby =>
      _lobby == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : LobbyScreen(widget.conn, _lobby!, _myId, addPack: widget.addPack),
    _Screen.wait => WaitScreen(_waitReason),
    _Screen.curve => CurveScreen(widget.conn, alive: _alive),
    _Screen.quiz => QuizScreen(
      widget.conn,
      _question,
      _reveal,
      total: _quizTotal,
      key: ValueKey(_question?.number),
    ),
    _Screen.results => ResultsScreen(_placements, _myId),
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
        if (_error != null && _screen != _Screen.join)
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
        Expanded(child: _body()),
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
