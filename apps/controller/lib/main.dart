import 'dart:math';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'app.dart';
import 'connection.dart';
import 'pack_upload.dart';

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
    path: '/ws',
  );
  runApp(App(Connection(ws, _token()), addPack: pickAndUploadPack));
}
