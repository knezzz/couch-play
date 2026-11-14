import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';

const _maxUpload = 5 * 1024 * 1024;
const _maxMessage = 64 * 1024;

const _types = {
  'html': 'text/html; charset=utf-8',
  'js': 'text/javascript',
  'mjs': 'text/javascript',
  'wasm': 'application/wasm',
  'json': 'application/json',
  'png': 'image/png',
  'svg': 'image/svg+xml',
  'css': 'text/css',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
};

class PeerSocket {
  PeerSocket._(this._ws) {
    // A phone that drops without closing is noticed within ~2 intervals.
    _ws.pingInterval = const Duration(seconds: 5);
    _ws.listen(
      (data) {
        // dart:io has no frame limit, so the frame is already in memory here;
        // this stops it reaching the decoder and drops the sender.
        if (data is String && data.length > _maxMessage ||
            data is List && data.length > _maxMessage) {
          _ws.close(WebSocketStatus.messageTooBig);
          return;
        }
        final m = data is String ? Message.decode(data) : null;
        if (m != null) _in.add(m);
      },
      onDone: _in.close,
      onError: (_) {},
    );
  }

  final WebSocket _ws;
  final _in = StreamController<Message>();

  Stream<Message> get messages => _in.stream;
  void send(Message m) {
    if (_ws.readyState == WebSocket.open) _ws.add(m.encode());
  }

  Future<void> get done => _ws.done.then((_) {}, onError: (_) {});
  void close() => _ws.close();
}

class GameServer {
  GameServer._(this._http, this._webRoot, this._onPeer, this._onPackUpload);

  final HttpServer _http;
  final Directory _webRoot;
  final void Function(PeerSocket) _onPeer;
  final Future<({bool ok, String message})> Function(String, Uint8List) _onPackUpload;

  int get port => _http.port;

  static Future<GameServer> start({
    required Directory webRoot,
    required void Function(PeerSocket) onPeer,
    required Future<({bool ok, String message})> Function(String token, Uint8List body) onPackUpload,
    int firstPort = 8080,
    int lastPort = 8090,
  }) async {
    for (var port = firstPort; port <= lastPort; port++) {
      try {
        final http = await HttpServer.bind(InternetAddress.anyIPv4, port);
        final s = GameServer._(http, webRoot, onPeer, onPackUpload);
        http.listen(s._handle);
        return s;
      } on SocketException {
        if (port == lastPort) rethrow;
      }
    }
    throw StateError('firstPort is above lastPort');
  }

  Future<void> close() => _http.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    try {
      final path = req.uri.path;
      if (path == '/ws' && WebSocketTransformer.isUpgradeRequest(req)) {
        _onPeer(PeerSocket._(await WebSocketTransformer.upgrade(req)));
      } else if (path == '/packs' && req.method == 'POST') {
        await _upload(req);
      } else if (req.method == 'GET' || req.method == 'HEAD') {
        await _static(req);
      } else {
        await _reply(req, 404);
      }
    } catch (_) {
      try {
        await _reply(req, 500);
      } catch (_) {}
    }
  }

  Future<void> _reply(HttpRequest req, int status, [String body = '']) async {
    req.response
      ..statusCode = status
      ..write(body);
    await req.response.close();
  }

  Future<void> _upload(HttpRequest req) async {
    // shortcut: an oversized body is read and discarded rather than cut off,
    // so the client sees the 413; upgrade if untrusted peers get this port.
    final buf = BytesBuilder(copy: false);
    var size = 0;
    await for (final chunk in req) {
      size += chunk.length;
      if (size <= _maxUpload) buf.add(chunk);
    }
    if (size > _maxUpload) return _reply(req, 413, PackStrings.tooBig);
    final r = await _onPackUpload(
        req.uri.queryParameters['token'] ?? '', buf.takeBytes());
    await _reply(req, r.ok ? 200 : 400, r.message);
  }

  Future<void> _static(HttpRequest req) async {
    final segs = req.uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.any((s) => s == '..' || s == '.' || s.contains('/') || s.contains('\\'))) {
      return _reply(req, 404);
    }
    var file = File([_webRoot.path, ...segs].join('/'));
    if (await FileSystemEntity.isDirectory(file.path)) {
      file = File('${file.path}/index.html');
    }
    if (!await file.exists()) return _reply(req, 404);
    final ext = file.path.split('.').last.toLowerCase();
    req.response.headers.contentType =
        ContentType.parse(_types[ext] ?? 'application/octet-stream');
    // Phones must not keep an old main.dart.js after the TV app is reinstalled.
    req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    if (req.method != 'HEAD') await req.response.addStream(file.openRead());
    await req.response.close();
  }
}
