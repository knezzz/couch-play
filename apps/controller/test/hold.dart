import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Puts a finger on the hold-to-see card (the sent answer). Release with
/// `await g.up(); await t.pump();`.
Future<TestGesture> holdCard(WidgetTester t) async {
  final g = await t.startGesture(
    t.getCenter(find.byKey(const ValueKey('role-card'))),
  );
  await t.pump();
  return g;
}

/// A sent answer is hidden, shows while held, and is hidden again after.
Future<void> expectHiddenUntilHeld(WidgetTester t, String answer) async {
  expect(find.text(answer), findsNothing, reason: 'hidden before a hold');
  final g = await holdCard(t);
  expect(find.text(answer), findsOneWidget, reason: 'shown while held');
  await g.up();
  await t.pump();
  expect(find.text(answer), findsNothing, reason: 'hidden again after');
}
