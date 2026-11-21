import 'package:controller/screens/sent_hold.dart';
import 'package:controller/strings.dart';
import 'package:controller/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hold.dart';

void main() {
  testWidgets('a long sent answer fits 360 x 640, held or not', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final long = 'Vrlo dugačak lažan odgovor od četrdeset slova ok';
    await t.pumpWidget(
      MaterialApp(
        theme: theme,
        home: SentHoldScreen(
          title: Strings.questionOf(3, 10),
          label: Strings.yourAnswerCaps,
          answer: long,
        ),
      ),
    );
    expect(find.text(Strings.sentHint), findsOneWidget);
    await expectHiddenUntilHeld(t, long);
    final g = await holdCard(t);
    expect(find.text(Strings.waitTv), findsOneWidget);
    await g.up();
    expect(t.takeException(), isNull);
  });
}
