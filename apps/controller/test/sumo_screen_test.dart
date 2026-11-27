import 'dart:async';

import 'package:controller/connection.dart';
import 'package:controller/screens/sumo_screen.dart';
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
  List<Message> get moves => sent.where((m) => m is SumoMove || m is SumoDash).toList();
}

/// Task 55 (boards SumoPhone and SumoPhoneSmall): a floating joystick on the left half, Dash on the right.
void main() {
  Widget app(_Fake c, {bool alive = true, RoundEnd? end}) => MaterialApp(
        home: SumoScreen(c, alive: alive, end: end, name: 'Ana', character: 'owl', colorIndex: 1, score: 12, round: 3),
      );

  Future<void> done(WidgetTester t) => t.pumpWidget(const SizedBox()); // cancels the ping timer

  testWidgets('the joystick is wherever the thumb lands: direction in 16 steps, force in 3', (t) async {
    final c = _Fake();
    await t.pumpWidget(app(c));
    final g = await t.startGesture(const Offset(100, 300));
    expect(c.moves, isEmpty, reason: 'touching alone pushes nothing');
    await g.moveBy(const Offset(18, 0)); // a short pull right
    expect(c.moves.last, const SumoMove(0, 1));
    await g.moveBy(const Offset(20, 0)); // 38 px
    expect(c.moves.last, const SumoMove(0, 2));
    await g.moveBy(const Offset(40, 0)); // past the edge of the stick
    expect(c.moves.last, const SumoMove(0, 3));
    final n = c.moves.length;
    await g.moveBy(const Offset(10, 0)); // the same direction and force: nothing new
    expect(c.moves.length, n);
    await g.up();
    expect(c.moves.last, const SumoMove(0, 0), reason: 'let go');
    await done(t);
  });

  testWidgets('up the screen is direction 4, left 8, down 12, and the diagonal in between', (t) async {
    for (final (dx, dy, dir) in [(0.0, -70.0, 4), (-70.0, 0.0, 8), (0.0, 70.0, 12), (50.0, -50.0, 2), (-50.0, -50.0, 6)]) {
      final c = _Fake();
      await t.pumpWidget(app(c));
      final g = await t.startGesture(const Offset(150, 300));
      await g.moveBy(Offset(dx, dy));
      expect((c.moves.last as SumoMove).dir, dir, reason: '($dx, $dy)');
      await g.up();
      await done(t);
    }
  });

  testWidgets('a new direction with the thumb still down is sent; the base stays where the thumb landed', (t) async {
    final c = _Fake();
    await t.pumpWidget(app(c));
    final g = await t.startGesture(const Offset(200, 300));
    await g.moveBy(const Offset(60, 0));
    expect(c.moves.last, const SumoMove(0, 3));
    await g.moveBy(const Offset(-60, -60)); // back through the base and up
    expect((c.moves.last as SumoMove).dir, 4);
    await g.up();
    await done(t);
  });

  testWidgets('the right half is Dash: one press, then it recharges for 2 s', (t) async {
    final c = _Fake();
    await t.pumpWidget(app(c));
    await t.tapAt(const Offset(600, 300));
    await t.pump(const Duration(milliseconds: 20));
    expect(c.moves, [const SumoDash()]);
    expect(find.textContaining('još'), findsOneWidget, reason: 'the draining ring says how long');
    await t.tapAt(const Offset(600, 300));
    expect(c.moves.length, 1, reason: 'still recharging');
    await t.pump(const Duration(seconds: 1));
    await t.tapAt(const Offset(600, 300));
    expect(c.moves.length, 1);
    await t.pump(const Duration(milliseconds: 1100));
    expect(find.textContaining('još'), findsNothing, reason: 'ready');
    await t.tapAt(const Offset(600, 300));
    expect(c.moves.length, 2);
    await t.pump(const Duration(seconds: 3));
    await done(t);
  });

  testWidgets('two thumbs: steer and Dash at the same time', (t) async {
    final c = _Fake();
    await t.pumpWidget(app(c));
    final stick = await t.startGesture(const Offset(100, 300));
    await stick.moveBy(const Offset(60, 0));
    final dash = await t.startGesture(const Offset(600, 300));
    expect(c.moves.last, const SumoDash());
    await dash.up();
    expect(c.moves.where((m) => m is SumoMove).last, const SumoMove(0, 3), reason: 'the stick was not let go');
    await stick.up();
    expect(c.moves.last, const SumoMove(0, 0));
    await t.pump(const Duration(seconds: 3));
    await done(t);
  });

  testWidgets('out of the ring: the stick is let go and nothing more is sent until the next round', (t) async {
    final c = _Fake();
    await t.pumpWidget(app(c));
    final g = await t.startGesture(const Offset(100, 300));
    await g.moveBy(const Offset(60, 0));
    await t.pumpWidget(app(c, alive: false));
    expect(c.moves.last, const SumoMove(0, 0), reason: 'a held stick must not keep pushing a wrestler');
    expect(find.text(Strings.sumoOut), findsOneWidget);
    final n = c.moves.length;
    await t.tapAt(const Offset(600, 300));
    await g.moveBy(const Offset(20, 0));
    expect(c.moves.length, n);
    await g.up();
    await done(t);
  });

  testWidgets('a round that ended says how, like Curve', (t) async {
    final c = _Fake();
    await t.pumpWidget(app(c, end: RoundEnd.won));
    expect(find.text(Strings.roundWon), findsOneWidget);
    expect(find.text(Strings.nextRoundSoon), findsOneWidget);
    await done(t);
  });

  testWidgets('header: face, name and the round and score', (t) async {
    final c = _Fake();
    await t.pumpWidget(app(c));
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text(Strings.curveRoundScore(3, 12)), findsOneWidget);
    expect(find.byType(CharacterFace), findsOneWidget);
    expect(find.text(Strings.sumoDash), findsOneWidget);
    await done(t);
  });

  testWidgets('pings at 20 Hz while shown, like Curve, and stops when disposed', (t) async {
    final c = _Fake();
    await t.pumpWidget(app(c));
    await t.pump(const Duration(seconds: 1));
    expect(c.sent.whereType<Ping>().length, 20);
    await done(t);
    await t.pump(const Duration(seconds: 1));
    expect(c.sent.whereType<Ping>().length, 20);
  });

  for (final (w, h) in [(390.0, 844.0), (360.0, 640.0)]) {
    testWidgets('fits $w x $h with nothing cut and big targets', (t) async {
      t.view.physicalSize = Size(w, h);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final c = _Fake();
      await t.pumpWidget(app(c));
      expect(t.takeException(), isNull);
      final dash = t.getRect(find.byKey(const ValueKey('sumo-dash')));
      expect(dash.width, greaterThanOrEqualTo(150));
      expect(dash.height, greaterThanOrEqualTo(300));
      expect(dash.right, lessThanOrEqualTo(w));
      expect(find.text(Strings.sumoHint), findsOneWidget);
      await done(t);
    });
  }
}
