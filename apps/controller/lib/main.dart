import 'dart:math';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'connection.dart';
import 'screens/curve_screen.dart';
import 'screens/join_screen.dart';

String _token() {
  const key = 'couchplay.token';
  var t = web.window.localStorage.getItem(key);
  if (t == null) {
    final r = Random.secure();
    t = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
    web.window.localStorage.setItem(key, t);
  }
  return t;
}

void main() {
  final loc = Uri.parse(web.window.location.href);
  final ws = Uri(
      scheme: loc.scheme == 'https' ? 'wss' : 'ws',
      host: loc.host,
      port: loc.port,
      path: '/ws');
  runApp(App(Connection(ws, _token())));
}

class App extends StatefulWidget {
  const App(this.conn, {super.key});
  final Connection conn;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _joined = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Couchplay',
        theme: ThemeData.dark(useMaterial3: true),
        // Temporary until Task 6's lobby: Join goes straight to steering.
        home: _joined
            ? CurveScreen(widget.conn)
            : JoinScreen(widget.conn, onJoined: () => setState(() => _joined = true)),
      );
}
