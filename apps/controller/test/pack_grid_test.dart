import 'package:controller/app.dart';
import 'package:controller/screens/lobby_screen.dart';
import 'package:controller/strings.dart';
import 'package:controller/theme.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

const _packs = [
  PackInfo('a', 'Opće znanje', 401),
  PackInfo('b', 'Međimurje', 94, pictures: true),
  PackInfo('c', 'Zastave', 1),
  PackInfo('d', 'Oblici', 22, pictures: true, isNew: true),
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
      expect(find.text(Strings.packMeta(p)), findsOneWidget);
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

  test('the tags follow the pack: slike, novo', () {
    expect(Strings.packMeta(_packs[0]), '401 pitanje');
    expect(Strings.packMeta(_packs[1]), '94 pitanja · slike');
    expect(Strings.packMeta(_packs[3]), '22 pitanja · slike · novo');
    expect(
      Strings.packMeta(const PackInfo('x', 'X', 5, isNew: true)),
      '5 pitanja · novo',
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
  group('a game starting from the TV while a screen is open', () {
    Future<FakeConnection> app(WidgetTester t) async {
      t.view.physicalSize = const Size(390, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final c = FakeConnection();
      await t.pumpWidget(App(c));
      for (final m in [const Welcome(0, 0, 'test'), _lobby()]) {
        c.inbox.add(m);
        await t.pump();
        await t.pump();
      }
      return c;
    }

    Future<void> send(WidgetTester t, FakeConnection c, Message m) async {
      c.inbox.add(m);
      await t.pump();
      await t.pump();
      await t.pumpAndSettle();
    }

    testWidgets('the open pack grid is closed and the answers can be tapped', (
      t,
    ) async {
      final c = await app(t);
      await t.tap(find.byKey(const ValueKey('open-packs')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pack-a')), findsOneWidget);
      await send(
        t,
        c,
        const QuizQuestion(1, 10, ['Ana', 'Ivo', 'Eva', 'Tin'], 20),
      );
      expect(find.byKey(const ValueKey('pack-a')), findsNothing);
      await t.tap(find.text('Ivo'));
      expect(c.sent.last, const Answer(1));
    });

    testWidgets('the roles list and the character sheet are closed too', (
      t,
    ) async {
      final c = await app(t);
      await send(
        t,
        c,
        LobbyState(
          hostId: 0,
          packs: _packs,
          selected: GameKind.vukodlak,
          players: _lobby().players,
        ),
      );
      await t.tap(find.byKey(const ValueKey('open-roles-info')));
      await t.pumpAndSettle();
      expect(find.text(Strings.rolesInThisGame), findsWidgets);
      await send(t, c, const CurveStatus(alive: true, score: 0, target: 30));
      expect(find.text(Strings.rolesInThisGame), findsNothing);
    });
  });

  testWidgets('with no packs the details row asks to pick one', (t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final l = LobbyState(
      hostId: 0,
      packs: const [],
      selected: GameKind.quiz,
      players: _lobby().players,
    );
    await t.pumpWidget(
      MaterialApp(
        theme: theme,
        home: LobbyScreen(FakeConnection(), l, 0, addPack: (_) async => null),
      ),
    );
    final row = find.byKey(const ValueKey('open-packs'));
    expect(
      find.descendant(of: row, matching: find.text(Strings.pickPack)),
      findsOneWidget,
    );
  });

  testWidgets('the Curve round from the TV reaches the phone header', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = FakeConnection();
    await t.pumpWidget(App(c));
    for (final m in <Message>[
      const Welcome(0, 0, 'test'),
      _lobby(),
      const CurveStatus(alive: true, score: 7, target: 30, round: 4),
    ]) {
      c.inbox.add(m);
      await t.pump();
      await t.pump();
    }
    expect(find.text('Runda 4 · 7 bodova'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
