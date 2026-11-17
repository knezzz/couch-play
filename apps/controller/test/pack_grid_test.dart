import 'package:controller/screens/lobby_screen.dart';
import 'package:controller/strings.dart';
import 'package:controller/theme.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

const _packs = [
  PackInfo('a', 'Opće znanje', 401),
  PackInfo('b', 'Međimurje', 94),
  PackInfo('c', 'Zastave', 1),
  PackInfo('d', 'Oblici', 22),
];

LobbyState _lobby({String? pack = 'a', int host = 0}) => LobbyState(
  hostId: host,
  packs: _packs,
  selected: GameKind.quiz,
  settings: GameSettings(quizSeconds: 30, quizPackId: pack, wolfDiscussion: 60),
  players: [for (var i = 0; i < 3; i++) PlayerInfo(i, 'P$i', i, true, 0)],
);

Future<FakeConnection> _open(
  WidgetTester t, {
  int me = 0,
  double width = 390,
}) async {
  t.view.physicalSize = Size(width, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = FakeConnection();
  await t.pumpWidget(
    MaterialApp(theme: theme, home: LobbyScreen(c, _lobby(), me)),
  );
  return c;
}

void main() {
  testWidgets('the details row shows the chosen pack and its count', (t) async {
    await _open(t);
    final row = find.byKey(const ValueKey('open-packs'));
    expect(
      find.descendant(of: row, matching: find.text('Opće znanje')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('401 pitanje')),
      findsOneWidget,
    );
  });

  testWidgets('the grid shows every pack with its count, two per row', (
    t,
  ) async {
    await _open(t);
    await t.tap(find.byKey(const ValueKey('open-packs')));
    await t.pumpAndSettle();
    for (final p in _packs) {
      expect(find.text(p.title), findsOneWidget);
      expect(find.text(Strings.questions(p.questionCount)), findsOneWidget);
    }
    final a = t.getTopLeft(find.byKey(const ValueKey('pack-a')));
    final b = t.getTopLeft(find.byKey(const ValueKey('pack-b')));
    final c = t.getTopLeft(find.byKey(const ValueKey('pack-c')));
    expect(a.dy, b.dy);
    expect(b.dx, greaterThan(a.dx));
    expect(c.dy, greaterThan(a.dy));
    expect(c.dx, a.dx);
    expect(
      t.getSize(find.byKey(const ValueKey('pack-a'))).height,
      greaterThanOrEqualTo(64),
    );
  });

  test('question counts decline like the language does', () {
    expect(Strings.questions(1), '1 pitanje');
    expect(Strings.questions(2), '2 pitanja');
    expect(Strings.questions(11), '11 pitanja');
    expect(Strings.questions(21), '21 pitanje');
    expect(Strings.questions(94), '94 pitanja');
    expect(Strings.questions(401), '401 pitanje');
  });

  testWidgets('a pack tap sends the whole settings and goes back', (t) async {
    final c = await _open(t);
    await t.tap(find.byKey(const ValueKey('open-packs')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pack-b')));
    await t.pumpAndSettle();
    final s = (c.sent.last as SetSettings).settings;
    expect(s.quizPackId, 'b');
    expect((s.quizSeconds, s.wolfDiscussion), (30, 60));
    expect(find.text(Strings.play), findsOneWidget, reason: 'back on details');
    expect(find.byKey(const ValueKey('pack-b')), findsNothing);
  });

  testWidgets('the highlighted pack is the one the TV says', (t) async {
    await _open(t);
    await t.tap(find.byKey(const ValueKey('open-packs')));
    await t.pumpAndSettle();
    Color? fill(String id) => t
        .widget<Material>(
          find
              .ancestor(
                of: find.byKey(ValueKey('pack-$id')),
                matching: find.byType(Material),
              )
              .first,
        )
        .color;
    expect(fill('a'), accent);
    expect(fill('b'), surface);
  });

  testWidgets('a guest has no pack row and cannot send a pack', (t) async {
    final c = await _open(t, me: 1);
    expect(find.byKey(const ValueKey('open-packs')), findsNothing);
    expect(c.sent.whereType<SetSettings>(), isEmpty);
  });

  testWidgets('Natrag in the grid goes back without sending', (t) async {
    final c = await _open(t);
    await t.tap(find.byKey(const ValueKey('open-packs')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('packs-back')));
    await t.pumpAndSettle();
    expect(c.sent, isEmpty);
    expect(find.text(Strings.play), findsOneWidget);
  });

  testWidgets('the grid fits 360 px', (t) async {
    await _open(t, width: 360);
    await t.tap(find.byKey(const ValueKey('open-packs')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
