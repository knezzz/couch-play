import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/server/controller_files.dart';
import 'package:tv/server/game_server.dart';

void main() {
  late Directory root;
  final servers = <GameServer>[];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('webroot');
    await File('${root.path}/index.html').writeAsString('<html>hi</html>');
    await File('${root.parent.path}/secret').writeAsString('nope');
  });

  tearDown(() async {
    for (final s in servers) {
      await s.close();
    }
    servers.clear();
    await root.delete(recursive: true);
  });

  Future<GameServer> start({
    int firstPort = 0,
    void Function(PeerSocket)? onPeer,
    Future<({bool ok, String message})> Function(String, Uint8List)? onPackUpload,
  }) async {
    final s = await GameServer.start(
      webRoot: root,
      onPeer: onPeer ?? (_) {},
      onPackUpload: onPackUpload ?? (_, _) async => (ok: true, message: ''),
      firstPort: firstPort,
      lastPort: firstPort == 0 ? 0 : firstPort + 10,
    );
    servers.add(s);
    return s;
  }

  // HttpClient normalizes '/../', so send the raw path through a socket.
  Future<String> raw(int port, String path) async {
    final sock = await Socket.connect('127.0.0.1', port);
    sock.write('GET $path HTTP/1.0\r\n\r\n');
    final out = String.fromCharCodes(
        await sock.fold<List<int>>([], (a, b) => a..addAll(b)));
    await sock.close();
    return out;
  }

  test('serves_index_and_404s_traversal', () async {
    final s = await start();
    final ok = await raw(s.port, '/');
    expect(ok, contains('200'));
    expect(ok, contains('<html>hi</html>'));
    for (final p in ['/../secret', '/%2e%2e/secret', '/..%2fsecret']) {
      final r = await raw(s.port, p);
      expect(r, contains('404'), reason: p);
      expect(r, isNot(contains('nope')), reason: p);
    }
  });

  test('static_files_are_not_cached', () async {
    final s = await start();
    final ok = await raw(s.port, '/index.html');
    expect(ok.toLowerCase(), contains('cache-control: no-cache'));
  });

  test('falls_back_to_next_port', () async {
    final held = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    addTearDown(held.close);
    final s = await start(firstPort: held.port);
    expect(s.port, held.port + 1);
  });

  test('ws_roundtrip', () async {
    final s = await start(onPeer: (p) {
      p.messages.listen((m) {
        if (m is Ping) p.send(Pong(m.t));
      });
    });
    final ws = await WebSocket.connect('ws://127.0.0.1:${s.port}/ws');
    ws.add('garbage'); // dropped, must not break the socket
    ws.add(const Ping(5).encode());
    final first = await ws.first.timeout(const Duration(seconds: 5));
    expect(Message.decode(first as String), const Pong(5));
    await ws.close();
  });

  test('ws_oversized_message_closes_socket', () async {
    final got = <Message>[];
    final s = await start(onPeer: (p) => p.messages.listen(got.add));
    final ws = await WebSocket.connect('ws://127.0.0.1:${s.port}/ws');
    ws.listen((_) {}); // the client only sees the close while listening
    ws.add(Join('x' * (64 * 1024 + 1), 't').encode());
    await ws.done.timeout(const Duration(seconds: 5));
    expect(ws.closeCode, WebSocketStatus.messageTooBig);
    expect(got, isEmpty);
  });

  test('pack_upload_too_big_413', () async {
    var called = false;
    final s = await start(onPackUpload: (_, _) async {
      called = true;
      return (ok: true, message: '');
    });
    final c = HttpClient();
    final req = await c.post('127.0.0.1', s.port, '/packs?token=t');
    req.add(Uint8List(5 * 1024 * 1024 + 1));
    final res = await req.close();
    expect(res.statusCode, 413);
    expect(await utf8.decodeStream(res), 'The pack is larger than 5 MB.');
    expect(called, isFalse);
    c.close();
  });

  test('pack_upload_result_maps_to_200_and_400', () async {
    String? tokenSeen;
    final s = await start(onPackUpload: (token, body) async {
      tokenSeen = token;
      return body.isEmpty
          ? (ok: false, message: 'Empty file.')
          : (ok: true, message: 'Added it.');
    });
    final c = HttpClient();
    final bad = await (await c.post('127.0.0.1', s.port, '/packs?token=abc')).close();
    expect(bad.statusCode, 400);
    expect(await utf8.decodeStream(bad), 'Empty file.');
    expect(tokenSeen, 'abc');
    final req = await c.post('127.0.0.1', s.port, '/packs?token=abc');
    req.add([1, 2, 3]);
    final ok = await req.close();
    expect(ok.statusCode, 200);
    expect(await utf8.decodeStream(ok), 'Added it.');
    c.close();
  });

  test('extracts_controller_zip', () async {
    final a = Archive()
      ..addFile(ArchiveFile('index.html', 2, [104, 105]))
      ..addFile(ArchiveFile('canvaskit/c.wasm', 1, [0]))
      ..addFile(ArchiveFile('../evil', 1, [0]));
    final bytes = Uint8List.fromList(ZipEncoder().encode(a));
    final dir = await extractControllerZip(bytes, root.createTempSync('x'));
    expect(File('${dir.path}/index.html').readAsStringSync(), 'hi');
    expect(File('${dir.path}/canvaskit/c.wasm').existsSync(), isTrue);
    expect(File('${dir.parent.path}/evil').existsSync(), isFalse);
  });
}
