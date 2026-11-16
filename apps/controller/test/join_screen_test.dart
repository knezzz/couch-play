import 'dart:async';

import 'package:controller/connection.dart';
import 'package:controller/screens/join_screen.dart';
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
  // Tall: the character grid pushes the Join button below an 800x600 test view.
  void tall(WidgetTester t) {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Future<(_Fake, List<int>)> pumpJoin(WidgetTester t) async {
    tall(t);
    final c = _Fake();
    final joined = <int>[];
    await t.pumpWidget(
      MaterialApp(home: JoinScreen(c, onJoined: () => joined.add(1))),
    );
    await t.enterText(find.byType(TextField), 'Ana');
    await t.tap(find.text(Strings.join));
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

  testWidgets('a spaces-only name shows a message and sends nothing', (
    t,
  ) async {
    tall(t);
    final c = _Fake();
    await t.pumpWidget(MaterialApp(home: JoinScreen(c, onJoined: () {})));
    await t.enterText(find.byType(TextField), '   ');
    await t.tap(find.text(Strings.join));
    await t.pump();
    expect(find.text(Strings.emptyName), findsOneWidget);
    expect(c.sent, isEmpty);
  });

  group('character', () {
    Future<_Fake> join(WidgetTester t, {String? pick}) async {
      tall(t);
      final c = _Fake();
      await t.pumpWidget(
        MaterialApp(home: JoinScreen(c, onJoined: () {}, initialCharacter: 'owl')),
      );
      if (pick != null) await t.tap(find.byKey(ValueKey('char-$pick')));
      await t.enterText(find.byType(TextField), 'Ana');
      await t.tap(find.text(Strings.join));
      await t.pump();
      return c;
    }

    testWidgets('the preselected character goes out with the name', (t) async {
      final c = await join(t);
      expect((c.sent.single as Join).character, 'owl');
    });

    testWidgets('tapping another one changes what is sent', (t) async {
      final c = await join(t, pick: 'bear');
      expect((c.sent.single as Join).character, 'bear');
    });

    testWidgets('without a pinned one, a valid random character is sent', (
      t,
    ) async {
      tall(t);
      final c = _Fake();
      await t.pumpWidget(MaterialApp(home: JoinScreen(c, onJoined: () {})));
      await t.enterText(find.byType(TextField), 'Ana');
      await t.tap(find.text(Strings.join));
      await t.pump();
      expect(isCharacter((c.sent.single as Join).character ?? ''), isTrue);
    });

    for (final w in [360.0, 390.0]) {
      testWidgets('16 targets of 56 px or more fit at ${w.toInt()} px', (t) async {
        t.view.physicalSize = Size(w, 1600);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(home: JoinScreen(_Fake(), onJoined: () {})),
        );
        for (final id in characterIds) {
          final s = t.getSize(find.byKey(ValueKey('char-$id')));
          expect(s.width, greaterThanOrEqualTo(56), reason: id);
          expect(s.height, greaterThanOrEqualTo(56), reason: id);
        }
        expect(t.takeException(), isNull);
      });
    }
  });
}
