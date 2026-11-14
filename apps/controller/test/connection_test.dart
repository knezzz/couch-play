import 'dart:async';

import 'package:controller/connection.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Sink implements WebSocketSink {
  final sent = <String>[];
  @override
  void add(Object? data) => sent.add(data as String);
  @override
  Future close([int? closeCode, String? closeReason]) async {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future addStream(Stream stream) async {}
  @override
  Future get done => Completer<void>().future;
}

class _Ch extends StreamChannelMixin implements WebSocketChannel {
  final incoming = StreamController<dynamic>();
  @override
  final _Sink sink = _Sink();
  @override
  Stream get stream => incoming.stream;
  @override
  Future<void> get ready => Future.value();
  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
}

void main() {
  testWidgets('reconnect re-sends Join, then the last Steer', (t) async {
    final chans = <_Ch>[];
    final c = Connection(
      Uri.parse('ws://x/ws'),
      'tok',
      connect: (_) {
        final ch = _Ch();
        chans.add(ch);
        return ch;
      },
    );
    await t.pump();
    c.send(const Join('Ana', 'tok'));
    c.send(const Steer(left: true, right: false));
    await chans[0].incoming.close(); // Wi-Fi blip
    await t.pump(const Duration(milliseconds: 600));
    await t.pump();
    expect(chans.length, 2);
    expect(chans[1].sink.sent.map((s) => Message.decode(s)), [
      const Join('Ana', 'tok'),
      const Steer(left: true, right: false),
    ]);
  });

  testWidgets('Kicked stops reconnecting until Join again sends a fresh Join', (
    t,
  ) async {
    final chans = <_Ch>[];
    final c = Connection(
      Uri.parse('ws://x/ws'),
      'tok',
      connect: (_) {
        final ch = _Ch();
        chans.add(ch);
        return ch;
      },
    );
    await t.pump();
    c.send(const Join('Ana', 'tok'));
    c.send(const Steer(left: true, right: false));
    chans[0].incoming.add(const Kicked().encode());
    await chans[0].incoming.close(); // the TV closes the socket after Kicked
    await t.pump(const Duration(seconds: 10));
    expect(chans.length, 1, reason: 'no auto-reconnect after a kick');

    c.send(const Join('Ana', 'tok')); // Join again
    await t.pump();
    await t.pump();
    expect(chans.length, 2);
    // Only the fresh Join: the old Steer must not come back.
    expect(chans[1].sink.sent.map((s) => Message.decode(s)), [
      const Join('Ana', 'tok'),
    ]);
  });
}
