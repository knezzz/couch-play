import 'dart:async';

import 'package:controller/connection.dart';
import 'package:controller/screens/join_screen.dart';
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
  Future<(_Fake, List<int>)> pumpJoin(WidgetTester t) async {
    final c = _Fake();
    final joined = <int>[];
    await t.pumpWidget(
      MaterialApp(home: JoinScreen(c, onJoined: () => joined.add(1))),
    );
    await t.enterText(find.byType(TextField), 'Ana');
    await t.tap(find.text('Join'));
    await t.pump();
    return (c, joined);
  }

  testWidgets('stays on join screen until Welcome', (t) async {
    final (c, joined) = await pumpJoin(t);
    expect(c.sent.single, isA<Join>());
    expect(joined, isEmpty);
    c.inbox.add(const Welcome(0, 0, 'x'));
    await t.pump();
    expect(joined, [1]);
  });

  testWidgets('ErrorMsg is shown and the screen stays', (t) async {
    final (c, joined) = await pumpJoin(t);
    c.inbox.add(const ErrorMsg('Someone is already playing'));
    await t.pump();
    expect(find.text('Someone is already playing'), findsOneWidget);
    expect(joined, isEmpty);
  });
}
