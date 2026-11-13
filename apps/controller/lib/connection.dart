import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket to the TV. Reconnects with 0.5, 1, 2, 4, 4... s backoff and
/// re-sends the last Join so the TV recognises the same token.
class Connection {
  Connection(this.ws, this.token) {
    _open();
  }

  /// For tests: no socket; override [send].
  Connection.offline()
      : ws = null,
        token = 'test';

  final Uri? ws;
  /// Stable per-browser id, kept in localStorage by main.dart.
  final String token;
  final _messages = StreamController<Message>.broadcast();
  WebSocketChannel? _channel;
  Join? _join;
  int _attempt = 0;

  Stream<Message> get messages => _messages.stream;

  void send(Message m) {
    if (m is Join) _join = m;
    _channel?.sink.add(m.encode());
  }

  void _open() {
    final ch = _channel = WebSocketChannel.connect(ws!);
    ch.ready.then((_) {
      _attempt = 0;
      if (_join != null) send(_join!);
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
