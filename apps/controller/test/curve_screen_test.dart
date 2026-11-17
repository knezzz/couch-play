import 'dart:async';

import 'package:controller/connection.dart';
import 'package:controller/screens/curve_screen.dart';
import 'package:controller/strings.dart';
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

  testWidgets('header shows face, name and score; the Pong shows nothing', (
    t,
  ) async {
    final c = _Fake();
    await t.pumpWidget(
      MaterialApp(
        home: CurveScreen(
          c,
          name: 'Ana',
          character: characterIds[3],
          colorIndex: 2,
          score: 12,
        ),
      ),
    );
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text(Strings.curveScore(12)), findsOneWidget);
    expect(find.byType(CharacterFace), findsOneWidget);
    c.inbox.add(Pong(DateTime.now().millisecondsSinceEpoch));
    await t.pump();
    expect(find.textContaining('rtt'), findsNothing);
    expect(find.textContaining('p95'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the header says the round when the TV sends one', (t) async {
    final c = _Fake();
    await t.pumpWidget(
      MaterialApp(home: CurveScreen(c, name: 'Ana', score: 12, round: 3)),
    );
    expect(find.text('Runda 3 · 12 bodova'), findsOneWidget);
    await t.pumpWidget(
      MaterialApp(home: CurveScreen(c, name: 'Ana', score: 12)),
    );
    expect(find.text('12 bodova'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('both buttons are in the player colour, with the steering hint', (
    t,
  ) async {
    final c = _Fake();
    await t.pumpWidget(
      MaterialApp(home: CurveScreen(c, name: 'Ana', colorIndex: 2)),
    );
    for (final k in ['steer-left', 'steer-right']) {
      final box = t.widget<Container>(
        find
            .ancestor(
              of: find.byKey(ValueKey(k)),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        playerColors[2],
        reason: k,
      );
    }
    expect(find.text(Strings.curveHint), findsOneWidget);
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

  testWidgets('a button still works after release during a crash', (t) async {
    final c = _Fake();
    await t.pumpWidget(MaterialApp(home: CurveScreen(c)));
    final g = await t.startGesture(const Offset(50, 300));
    await t.pumpWidget(MaterialApp(home: CurveScreen(c, alive: false)));
    await g.up(); // released while dead
    await t.pumpWidget(MaterialApp(home: CurveScreen(c)));
    c.sent.clear();
    final g2 = await t.startGesture(const Offset(50, 300));
    expect(c.sent.last, const Steer(left: true, right: false));
    await g2.up();
    expect(c.sent.last, const Steer(left: false, right: false));
    await t.pumpWidget(const SizedBox());
  });
}
