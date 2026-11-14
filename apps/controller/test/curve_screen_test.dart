import 'dart:async';

import 'package:controller/connection.dart';
import 'package:controller/screens/curve_screen.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake extends Connection {
  _Fake() : super.offline();
  final sent = <Message>[];
  final inbox = StreamController<Message>.broadcast();
  @override
  Stream<Message> get messages => inbox.stream;
  @override
  void send(Message m) => sent.add(m);
}

void main() {
  testWidgets('left half sends Steer on press and release', (t) async {
    final c = _Fake();
    await t.pumpWidget(MaterialApp(home: CurveScreen(c)));
    final g = await t.startGesture(const Offset(50, 300));
    expect(c.sent.last, const Steer(left: true, right: false));
    await g.up();
    expect(c.sent.last, const Steer(left: false, right: false));
    await t.pumpWidget(const SizedBox()); // cancels the ping timer
  });

  testWidgets('release after a rebuild still sends Steer(false, false)', (
    t,
  ) async {
    final c = _Fake();
    await t.pumpWidget(MaterialApp(home: CurveScreen(c)));
    final g = await t.startGesture(const Offset(50, 300));
    c.inbox.add(const Pong(0)); // Pong -> setState -> rebuild, like every 1 s
    await t.pump();
    await g.up();
    expect(c.sent.last, const Steer(left: false, right: false));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('pings at 20 Hz while shown and stops when disposed', (t) async {
    final c = _Fake();
    await t.pumpWidget(MaterialApp(home: CurveScreen(c)));
    await t.pump(const Duration(seconds: 1));
    expect(c.sent.whereType<Ping>().length, 20);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    expect(c.sent.whereType<Ping>().length, 20);
  });

  test('percentile', () {
    final v = List.generate(100, (i) => i + 1);
    expect(percentile(v, .95), 95);
    expect(percentile([], .95), 0);
  });

  testWidgets('shows rtt, p95 and sample count', (t) async {
    final c = _Fake();
    await t.pumpWidget(MaterialApp(home: CurveScreen(c)));
    c.inbox.add(Pong(DateTime.now().millisecondsSinceEpoch));
    await t.pump();
    expect(find.textContaining('n=1'), findsOneWidget);
    expect(find.textContaining('p95'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('crashing while holding a side sends Steer(false, false)', (
    t,
  ) async {
    final c = _Fake();
    await t.pumpWidget(MaterialApp(home: CurveScreen(c)));
    final g = await t.startGesture(const Offset(50, 300));
    expect(c.sent.last, const Steer(left: true, right: false));
    await t.pumpWidget(MaterialApp(home: CurveScreen(c, alive: false)));
    expect(c.sent.last, const Steer(left: false, right: false));
    await g.up();
    await t.pumpWidget(const SizedBox());
  });
}
