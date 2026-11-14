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
  bool _driverOpen = false;

  void onPeer(PeerSocket peer) {
    peer.messages.listen((m) {
      switch (m) {
        case Ping(:final t):
          peer.send(Pong(t));
        case Join(:final token):
          if (sim == null) {
            _token = token;
            _attach(peer, token);
            startMatch();
          } else if (token == _token) {
            _attach(peer, token); // phone woke up or reloaded
          } else if (!_driverOpen) {
            // The driver left and this is a new browser (new token): start
            // over with it. Dropping this Join silently left a phone that
            // looked connected but could never steer.
            _token = token;
            _attach(peer, token);
            startMatch();
          } else {
            peer.send(const ErrorMsg('Someone is already playing. Ask them to close their page, then join again.'));
          }
        case Steer(:final left, :final right):
          if (peer == _driver) sim?.setInput(0, left: left, right: right);
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
      sim?.setInput(0, left: false, right: false);
    });
  }

  void startMatch() {
    final n = botCount.clamp(0, 7);
    final s = CurveSim([for (var i = 0; i <= n; i++) i], random: random);
    sim = s;
    bots = Bots(s, [for (var i = 1; i <= n; i++) i], random);
    onMatch();
  }
}
