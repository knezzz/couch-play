import 'package:controller/app.dart';
import 'package:controller/screens/curve_screen.dart';
import 'package:controller/screens/lobby_screen.dart';
import 'package:controller/screens/quiz_screen.dart';
import 'package:controller/screens/results_screen.dart';
import 'package:controller/strings.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

const _wide = 'WWWWWWWWWWWWWWWW';

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(360, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

LobbyState _lobby() => const LobbyState(
  hostId: 0,
  packs: [PackInfo('g', 'Opće znanje s dugim imenom paketa pitanja', 50)],
  players: [
    PlayerInfo(0, _wide, 0, true, 0),
    PlayerInfo(1, _wide, 1, false, 0),
    PlayerInfo(2, 'Ana', 2, true, 0),
  ],
);

void main() {
  _nameFits();
  testWidgets('Croatian host lobby fits at 360 px with 16-letter names', (
    t,
  ) async {
    _phone(t);
    await t.pumpWidget(
      MaterialApp(
        home: LobbyScreen(
          FakeConnection(),
          _lobby(),
          0,
          addPack: (_) async => null,
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'Croatian guest lobby fits (long host name in the waiting line)',
    (t) async {
      _phone(t);
      await t.pumpWidget(
        MaterialApp(home: LobbyScreen(FakeConnection(), _lobby(), 2)),
      );
      expect(t.takeException(), isNull);
      expect(find.text(Strings.startedBy(_wide)), findsOneWidget);
    },
  );

  testWidgets('kick sheet, quiz and results fit at 360 px in Croatian', (
    t,
  ) async {
    _phone(t);
    t.view.physicalSize = const Size(360, 1800); // the card carousel is tall
    final c = FakeConnection();
    await t.pumpWidget(MaterialApp(home: LobbyScreen(c, _lobby(), 0)));
    await t.tap(find.widgetWithText(TextButton, Strings.remove).first);
    await t.pumpAndSettle();
    expect(find.text(Strings.removeTitle(_wide)), findsOneWidget);
    expect(t.takeException(), isNull);

    const q = QuizQuestion(10, 10, [
      'Prvi odgovor',
      'Drugi odgovor',
      'Treći odgovor',
      'Četvrti odgovor',
    ], 20);
    await t.pumpWidget(MaterialApp(home: QuizScreen(c, q, null, total: 12345)));
    expect(t.takeException(), isNull);
    await t.pumpWidget(
      MaterialApp(
        home: QuizScreen(c, q, const QuizReveal(0, 0, 12345), total: 12345),
      ),
    );
    expect(find.text(Strings.notThisTime), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(
      MaterialApp(home: ResultsScreen(const [Placement(0, 8, 0, 11)], 0)),
    );
    expect(find.text(Strings.placed(8)), findsOneWidget);
    expect(find.text(Strings.sessionPoints(11)), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('join, kicked and crashed screens fit at 360 px in Croatian', (
    t,
  ) async {
    _phone(t);
    final c = FakeConnection();
    await t.pumpWidget(App(c));
    expect(t.takeException(), isNull);
    c.inbox.add(const Welcome(0, 0, 'tok'));
    await t.pump();
    await t.pump();
    c.inbox.add(const Kicked());
    await t.pump();
    await t.pump();
    expect(find.text(Strings.removed), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  for (final w in [360.0, 390.0]) {
    testWidgets(
      'host chip name ellipsizes before the star at ${w.toInt()} px',
      (t) async {
        t.view.physicalSize = Size(w, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(home: LobbyScreen(FakeConnection(), _lobby(), 0)),
        );
        // The name's room (the Flexible around it), not its ellipsized text.
        final name = t.getRect(
          find
              .ancestor(
                of: find.text(_wide).first,
                matching: find.byType(Flexible),
              )
              .first,
        );
        final badge = t.getRect(find.byIcon(Icons.star));
        expect(badge.left - name.right, greaterThanOrEqualTo(6));
      },
    );
  }

  testWidgets('Curve steering arrows are drawn, not font glyphs', (t) async {
    _phone(t);
    await t.pumpWidget(MaterialApp(home: CurveScreen(FakeConnection())));
    expect(find.byKey(const ValueKey('steer-left')), findsOneWidget);
    expect(find.byKey(const ValueKey('steer-right')), findsOneWidget);
    for (final g in ['◀', '▶']) {
      expect(find.text(g), findsNothing);
    }
    await t.pumpWidget(const SizedBox()); // stop the ping timer
  });

  test('Croatian plural of "bod"', () {
    expect(
      [1, 2, 4, 5, 11, 12, 14, 21, 22, 25, 101].map(Strings.points).toList(),
      [
        'bod',
        'boda',
        'boda',
        'bodova',
        'bodova',
        'bodova',
        'bodova',
        'bod',
        'boda',
        'bodova',
        'bod',
      ],
    );
  });
}

void _nameFits() {
  testWidgets(
    'host chip shows a long name without an ellipsis at 360 px (star only)',
    (t) async {
      t.view.physicalSize = const Size(360, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      // 5 wide letters in the test font (18 px each) fit beside the star and
      // "Promijeni lik"; a 'DOMAĆIN' pill would not leave room for them.
      const name = 'Čedom';
      final l = LobbyState(
        hostId: 0,
        packs: const [],
        players: const [PlayerInfo(0, name, 0, true, 0)],
      );
      await t.pumpWidget(
        MaterialApp(home: LobbyScreen(FakeConnection(), l, 0)),
      );
      final p = t.renderObject<RenderParagraph>(find.text(name).first);
      expect(p.didExceedMaxLines, isFalse);
    },
  );
}
