import 'dart:math';
import 'dart:ui' show VoidCallback;

import 'package:core/core.dart';

import '../server/game_server.dart';
import 'bots.dart';

/// Temporary wiring for the Task 5 gate, replaced by the session in Task 6.
/// The first phone to join drives player 0 against [botCount] bots.
class CurveWiring {
  CurveWiring({required this.botCount, required this.random, required this.onMatch});

  final int botCount;
  final Random random;
  final VoidCallback onMatch; // a new sim/bots pair is ready

  CurveSim? sim;
  Bots? bots;
  PeerSocket? _driver;
  String? _token;
  String _name = 'Player';
  bool _driverOpen = false;
  // Held buttons, kept only so a new match (a new sim) starts with them.
  // Rounds keep inputs inside CurveSim.
  bool _left = false, _right = false;

  void onPeer(PeerSocket peer) {
    peer.messages.listen((m) {
      switch (m) {
        case Ping(:final t):
          peer.send(Pong(t));
        case Join(:final name, :final token):
          if (sim == null) {
            _token = token;
            _name = _cleanName(name);
            _attach(peer, token);
            startMatch();
          } else if (token == _token) {
            _attach(peer, token); // phone woke up or reloaded
          } else if (!_driverOpen) {
            // The driver left and this is a new browser (new token): start
            // over with it. Dropping this Join silently left a phone that
            // looked connected but could never steer.
            _token = token;
            _name = _cleanName(name);
            _left = _right = false;
            _attach(peer, token);
            startMatch();
          } else {
            peer.send(const ErrorMsg('Someone is already playing. Ask them to close their page, then join again.'));
          }
        case Steer(:final left, :final right):
          if (peer == _driver) {
            _left = left;
            _right = right;
            sim?.setInput(0, left: left, right: right);
          }
        default:
      }
    });
  }

  void _attach(PeerSocket peer, String token) {
    _driver = peer;
    _driverOpen = true;
    peer.send(Welcome(0, 0, token));
    // Let go of the keys if the socket drops; a reconnect takes over again.
    peer.done.then((_) {
      if (_driver != peer) return;
      _driverOpen = false;
      _left = _right = false;
      sim?.setInput(0, left: false, right: false);
    });
  }

  // Temporary; Task 6's cleanName replaces it.
  static String _cleanName(String raw) {
    final t = raw.trim();
    return t.isEmpty ? 'Player' : String.fromCharCodes(t.runes.take(16));
  }

  void startMatch() {
    final n = botCount.clamp(0, 7);
    final s = CurveSim([for (var i = 0; i <= n; i++) i],
        random: random,
        names: {0: _name, for (var i = 1; i <= n; i++) i: 'Bot $i'});
    sim = s;
    bots = Bots(s, [for (var i = 1; i <= n; i++) i], random);
    s.setInput(0, left: _left, right: _right);
    onMatch();
  }
}
