import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';
import 'package:tv/server/game_server.dart';

/// The real server, real WebSockets and real time: two people play the quiz,
/// the host closes the tab, the other one must get the reveal and question 2.
void main() {
  test('two_person_quiz_goes_on_after_the_host_closes_the_tab', () async {
    final root = await Directory.systemTemp.createTemp('webroot');
    final session = Session();
    final server = await GameServer.start(
      webRoot: root,
      onPeer: session.attach,
      onPackUpload: (_, _) async => (ok: false, message: ''),
      firstPort: 18080,
      lastPort: 18090,
    );
    addTearDown(() async {
      await server.close();
      session.dispose();
      await root.delete(recursive: true);
    });

    Future<(WebSocket, List<Message>)> phone(String name, String token) async {
      final ws = await WebSocket.connect('ws://127.0.0.1:${server.port}/ws');
      final got = <Message>[];
      ws.listen((d) {
        final m = Message.decode(d as String);
        if (m != null) got.add(m);
      });
      ws.add(Join(name, token).encode());
      return (ws, got);
    }

    Future<void> until(bool Function() ok, String what) async {
      final end = DateTime.now().add(const Duration(seconds: 10));
      while (!ok()) {
        if (DateTime.now().isAfter(end)) fail('timed out: $what');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    final (hostWs, hostGot) = await phone('Ana', 'ta');
    final (benWs, benGot) = await phone('Ben', 'tb');
    await until(() => benGot.whereType<Welcome>().isNotEmpty, 'ben joins');
    hostWs.add(const StartGame(GameKind.quiz, null).encode());
    await until(() => benGot.whereType<QuizQuestion>().isNotEmpty, 'question 1');
    await hostWs.close();
    await until(() => session.hostId == session.players.last.id, 'host passes on');
    expect(session.phase, Phase.quiz);
    benWs.add(const Answer(0).encode());
    await until(() => benGot.whereType<QuizReveal>().isNotEmpty, 'reveal');
    await until(() => benGot.whereType<QuizQuestion>().length >= 2, 'question 2');
    expect(session.phase, Phase.quiz);
    await benWs.close();
    expect(hostGot, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 40)));
}
