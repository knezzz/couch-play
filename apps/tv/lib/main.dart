import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'server/controller_files.dart';
import 'server/game_server.dart';
import 'server/lan_address.dart';
import 'session/bots.dart';
import 'ui/curve/curve_game.dart';

const _perf = bool.fromEnvironment('PERF');
const _botCount = int.fromEnvironment('BOTS', defaultValue: 7);

// Temporary until palette.dart lands in Task 6.
const _colors = [
  Color(0xFFFF4D6D), Color(0xFFFFB020), Color(0xFF2ECC71), Color(0xFF22B8F0),
  Color(0xFF9B5CFF), Color(0xFFFF7AD9), Color(0xFFF5E94B), Color(0xFFFF7A2F),
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TvApp());
}

class TvApp extends StatefulWidget {
  const TvApp({super.key});
  @override
  State<TvApp> createState() => _TvAppState();
}

class _TvAppState extends State<TvApp> {
  String _status = 'Starting…';
  CurveGame? _game;
  CurveSim? _sim;
  Bots? _bots;
  PeerSocket? _driver; // the phone that started the match
  String? _driverToken;
  GameServer? _server;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final zip = await rootBundle.load('assets/controller.zip');
      final support = await getApplicationSupportDirectory();
      final web = Directory('${support.path}/web');
      if (await web.exists()) await web.delete(recursive: true);
      await extractControllerZip(zip.buffer.asUint8List(), web);
      final server = await GameServer.start(
        webRoot: web,
        onPeer: _onPeer,
        onPackUpload: (_, _) async => 'Packs are not available yet.',
      );
      _server = server;
      final ip = pickLanAddress(await NetworkInterface.list(type: InternetAddressType.IPv4));
      _set(ip == null
          ? 'Connect the TV to Wi-Fi to play.'
          : 'http://$ip:${server.port}/');
    } catch (e) {
      _set('Could not start: $e');
    }
  }

  void _set(String s) {
    if (mounted) setState(() => _status = s);
  }

  // Temporary wiring, replaced by the session in Task 6.
  void _onPeer(PeerSocket peer) {
    peer.messages.listen((m) {
      switch (m) {
        case Ping(:final t):
          peer.send(Pong(t));
        case Join(:final token):
          if (_sim == null) {
            _driverToken = token;
            _attach(peer, token);
            _startMatch();
          } else if (token == _driverToken) {
            _attach(peer, token); // phone woke up or reloaded
          }
        case Steer(:final left, :final right):
          if (peer == _driver) _sim?.setInput(0, left: left, right: right);
        default:
      }
    });
  }

  void _attach(PeerSocket peer, String token) {
    _driver = peer;
    peer.send(Welcome(0, 0, token));
    // Let go of the keys if the socket drops; a reconnect takes over again.
    peer.done.then((_) {
      if (_driver == peer) _sim?.setInput(0, left: false, right: false);
    });
  }

  void _startMatch() {
    final n = _botCount.clamp(0, 7);
    final sim = CurveSim([for (var i = 0; i <= n; i++) i]);
    _sim = sim;
    _bots = Bots(sim, [for (var i = 1; i <= n; i++) i], Random());
    _newGame();
  }

  // Trails are never cleared, so every round gets a fresh CurveGame.
  void _newGame() {
    setState(() => _game = CurveGame(_sim!, _colors,
        onBeforeTick: _bots!.tick, onEvents: _onEvents));
  }

  void _onEvents(List<CurveEvent> events) {
    if (!events.any((e) => e is RoundOver)) return;
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_sim!.matchOver) {
        _startMatch();
      } else {
        _sim!.startRound();
        _newGame();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return MaterialApp(
      title: 'Couchplay',
      showPerformanceOverlay: _perf,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: game != null
            ? GameWidget(game: game)
            : Center(child: Text(_status, style: const TextStyle(fontSize: 48))),
      ),
    );
  }
}
