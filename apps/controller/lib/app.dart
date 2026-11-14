import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'connection.dart';
import 'screens/curve_screen.dart';
import 'screens/join_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/results_screen.dart';
import 'screens/wait_screen.dart';

enum _Screen { join, lobby, wait, curve, quiz, results, kicked }

/// Routes the TV's messages to a screen. No web imports, so it runs in tests.
class App extends StatefulWidget {
  const App(this.conn, {super.key});
  final Connection conn;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  _Screen _screen = _Screen.join;
  int _myId = -1;
  LobbyState? _lobby;
  String _waitReason = '';
  String? _error;
  bool _alive = true;
  QuizQuestion? _question;
  QuizReveal? _reveal;
  List<Placement> _placements = const [];
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

  void _onMessage(Message m) => setState(() {
    switch (m) {
      case Welcome():
        _myId = m.playerId;
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
        _screen = _Screen.quiz;
      case QuizReveal():
        if (_question != null) {
          _reveal = m;
          _screen = _Screen.quiz;
        }
      case Results():
        _placements = m.placements;
        _screen = _Screen.results;
      case Kicked():
        _screen = _Screen.kicked;
      case ErrorMsg():
        _error = m.message;
      default:
        break;
    }
  });

  Widget _body() => switch (_screen) {
    _Screen.join => JoinScreen(widget.conn, onJoined: () {}),
    _Screen.lobby =>
      _lobby == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : LobbyScreen(widget.conn, _lobby!, _myId),
    _Screen.wait => WaitScreen(_waitReason),
    _Screen.curve => CurveScreen(widget.conn, alive: _alive),
    _Screen.quiz => QuizScreen(widget.conn, _question!, _reveal, key: ValueKey(_question!.number)),
    _Screen.results => ResultsScreen(_placements, _myId),
    _Screen.kicked => _Kicked(
      onJoinAgain: () => setState(() => _screen = _Screen.join),
    ),
  };

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Couchplay',
    theme: ThemeData.dark(useMaterial3: true),
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
                      child: const Text('OK'),
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
            'You were removed from the game.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onJoinAgain, child: const Text('Join again')),
        ],
      ),
    ),
  );
}
