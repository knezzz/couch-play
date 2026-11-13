import 'package:controller/connection.dart';
import 'package:controller/screens/curve_screen.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake extends Connection {
  _Fake() : super.offline();
  final sent = <Message>[];
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
}
