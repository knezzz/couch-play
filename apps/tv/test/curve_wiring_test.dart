import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/server/game_server.dart';
import 'package:tv/session/curve_wiring.dart';

Future<void> waitFor(bool Function() done, String what) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('Timed out waiting for $what');
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

class _Phone {
  _Phone(this.ws) {
    ws.listen((d) {
      final m = Message.decode(d as String);
      if (m != null) got.add(m);
    });
  }
  final WebSocket ws;
  final got = <Message>[];

  static Future<_Phone> connect(int port) async =>
      _Phone(await WebSocket.connect('ws://127.0.0.1:$port/ws'));

  var _barrier = 1000;

  /// Sends [m], then a Ping and waits for its Pong. The server handles one
  /// socket's messages in order, so the Pong means [m] has been handled.
  Future<void> send(Message m) async {
    ws.add(m.encode());
    final t = _barrier++;
    ws.add(Ping(t).encode());
    await waitFor(() => got.contains(Pong(t)), 'Pong($t) after ${m.runtimeType}');
  }

  bool get welcomed => got.any((m) => m is Welcome);
  bool get refused => got.any((m) => m is ErrorMsg);
  Future<void> close() => ws.close();
}

void main() {
  late CurveWiring wiring;
  late GameServer server;
  var matches = 0;

  setUp(() async {
    matches = 0;
    wiring = CurveWiring(botCount: 1, random: Random(1), onMatch: () => matches++);
    server = await GameServer.start(
      webRoot: Directory.systemTemp,
      onPeer: wiring.onPeer,
      onPackUpload: (_, _) async => null,
      firstPort: 0,
      lastPort: 0,
    );
  });
  tearDown(() => server.close());

  double heading0() => wiring.sim!.heads.firstWhere((h) => h.id == 0).heading;

  /// Runs 200 ticks (the 2 s countdown plus ~1.3 s of play) and reports
  /// whether player 0 turned. Bots are not ticked, so only Steer can turn it.
  bool turnedOver200Ticks() {
    final before = heading0();
    for (var i = 0; i < 200; i++) {
      wiring.sim!.tick();
    }
    return (heading0() - before).abs() > 0.5;
  }

  test('first_phone_steers_player_zero', () async {
    final a = await _Phone.connect(server.port);
    await a.send(const Join('A', 'tokA'));
    expect(a.welcomed, isTrue);
    await a.send(const Steer(left: true, right: false));
    expect(turnedOver200Ticks(), isTrue);
    await a.close();
  });

  test('new_phone_steers_after_the_first_one_left', () async {
    final a = await _Phone.connect(server.port);
    await a.send(const Join('A', 'tokA'));
    await a.close();

    // A fresh browser context has a new token. This used to be ignored,
    // so the phone looked connected but its line ran straight.
    // The server notices A's close asynchronously, so retry until it does.
    final b = await _Phone.connect(server.port);
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (!b.welcomed && DateTime.now().isBefore(end)) {
      await b.send(const Join('B', 'tokB'));
    }
    expect(b.welcomed, isTrue);
    await b.send(const Steer(left: true, right: false));
    expect(turnedOver200Ticks(), isTrue);
    await b.close();
  });

  test('same_token_reattaches_and_keeps_the_match', () async {
    final a = await _Phone.connect(server.port);
    await a.send(const Join('A', 'tokA'));
    final sim = wiring.sim;
    await a.close();

    final again = await _Phone.connect(server.port);
    await again.send(const Join('A', 'tokA'));
    expect(again.welcomed, isTrue);
    expect(wiring.sim, same(sim));
    await again.send(const Steer(left: true, right: false));
    expect(turnedOver200Ticks(), isTrue);
    await again.close();
  });

  test('reload_where_the_old_socket_closes_late', () async {
    final old = await _Phone.connect(server.port);
    await old.send(const Join('A', 'tokA'));
    final fresh = await _Phone.connect(server.port); // reloaded page
    await fresh.send(const Join('A', 'tokA'));
    expect(fresh.welcomed, isTrue);
    await old.close(); // unload finishes after the new page joined
    await fresh.send(const Steer(left: true, right: false));
    expect(turnedOver200Ticks(), isTrue);
    await fresh.close();
  });

  // The phone sends Steer only when a button changes, so a button that is
  // still held when a round or match starts must keep steering.
  test('held_button_survives_a_new_round', () async {
    final a = await _Phone.connect(server.port);
    await a.send(const Join('A', 'tokA'));
    await a.send(const Steer(left: true, right: false));
    wiring.sim!.startRound();
    expect(turnedOver200Ticks(), isTrue);
    await a.close();
  });

  test('held_button_survives_a_new_match', () async {
    final a = await _Phone.connect(server.port);
    await a.send(const Join('A', 'tokA'));
    await a.send(const Steer(left: true, right: false));
    wiring.startMatch();
    expect(turnedOver200Ticks(), isTrue);
    await a.close();
  });

  test('released_button_stays_released_in_a_new_round', () async {
    final a = await _Phone.connect(server.port);
    await a.send(const Join('A', 'tokA'));
    await a.send(const Steer(left: true, right: false));
    await a.send(const Steer(left: false, right: false));
    wiring.sim!.startRound();
    expect(turnedOver200Ticks(), isFalse);
    await a.close();
  });

  test('second_phone_is_told_while_the_first_is_playing', () async {
    final a = await _Phone.connect(server.port);
    await a.send(const Join('A', 'tokA'));
    final b = await _Phone.connect(server.port);
    await b.send(const Join('B', 'tokB'));
    expect(b.welcomed, isFalse);
    expect(b.refused, isTrue);
    await b.send(const Steer(left: true, right: false));
    expect(turnedOver200Ticks(), isFalse);
    await a.close();
    await b.close();
  });

  test('ping_gets_pong_without_joining', () async {
    final a = await _Phone.connect(server.port);
    await a.send(const Ping(9));
    expect(a.got, contains(const Pong(9)));
    await a.close();
  });
}
