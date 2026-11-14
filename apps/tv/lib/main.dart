import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'ui/perf_log.dart';
import 'server/controller_files.dart';
import 'server/game_server.dart';
import 'server/lan_address.dart';
import 'session/curve_wiring.dart';
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
  if (_perf) PerfLog.start();
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
  GameServer? _server;
  late final _wiring = CurveWiring(
      botCount: _botCount, random: Random(), onMatch: () => _newGame());

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
        onPeer: _wiring.onPeer,
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

  void _startMatch() => _wiring.startMatch();

  // Trails are never cleared, so every round gets a fresh CurveGame.
  void _newGame() {
    if (!mounted) return;
    setState(() => _game = CurveGame(_wiring.sim!, _colors,
        onBeforeTick: _wiring.bots!.tick, onEvents: _onEvents));
  }

  void _onEvents(List<CurveEvent> events) {
    if (!events.any((e) => e is RoundOver)) return;
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final sim = _wiring.sim!;
      if (sim.matchOver) {
        _startMatch();
      } else {
        sim.startRound();
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
