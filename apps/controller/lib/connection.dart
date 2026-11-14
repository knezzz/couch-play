import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket to the TV. Reconnects with 0.5, 1, 2, 4, 4... s backoff and
/// re-sends the last Join (so the TV recognises the same token) and Steer.
class Connection {
  Connection(this.ws, this.token, {WebSocketChannel Function(Uri)? connect})
    : _connect = connect ?? WebSocketChannel.connect {
    _open();
  }

  /// For tests: no socket; override [send].
  Connection.offline()
    : ws = null,
      token = 'test',
      _connect = WebSocketChannel.connect;

  final Uri? ws;
  final WebSocketChannel Function(Uri) _connect;

  /// Stable per-browser id, kept in localStorage by main.dart.
  final String token;
  final _messages = StreamController<Message>.broadcast();
  WebSocketChannel? _channel;
  Join? _join;
  Steer? _steer; // re-sent after a reconnect so a held finger keeps steering
  int _attempt = 0;

  Stream<Message> get messages => _messages.stream;

  void send(Message m) {
    if (m is Join) _join = m;
    if (m is Steer) _steer = m;
    try {
      _channel?.sink.add(m.encode());
    } catch (_) {} // socket closed: the reconnect re-sends Join and Steer
  }

  void _open() {
    final ch = _channel = _connect(ws!);
    ch.ready.then((_) {
      _attempt = 0;
      if (_join != null) send(_join!);
      if (_steer != null) send(_steer!);
    }, onError: (_) {});
    ch.stream.listen(
      (raw) {
        final m = Message.decode(raw as String);
        if (m != null) _messages.add(m);
      },
      onDone: _retry,
      onError: (_) {},
    );
  }

  void _retry() {
    final secs = min(0.5 * pow(2, _attempt), 4.0);
    _attempt++;
    Timer(Duration(milliseconds: (secs * 1000).round()), _open);
  }
}
