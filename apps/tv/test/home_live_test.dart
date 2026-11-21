import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/home_screen.dart';
import 'package:tv/ui/tv_theme.dart';

/// Task 48: the TV home shows where the host is (the session says it): the settings panel
/// opens by itself with the changed row outlined, the pack grid shows in the pack screen.

final _tiles = [
  (id: 'a', title: 'Opće znanje', count: 401, pictures: 0, on: true),
  (id: 'b', title: 'Zastave', count: 46, pictures: 46, on: false),
  (id: 'c', title: 'Hrvatska – kultura i sport', count: 122, pictures: 8, on: true),
  for (var i = 0; i < 13; i++) (id: 'x$i', title: 'Paket $i', count: 100, pictures: 0, on: true),
];

Future<void> _pump(
  WidgetTester t, {
  GameKind selected = GameKind.quiz,
  HostView hostView = HostView.home,
  LobbyChange? changed,
  List<PackTile>? grid,
  GameSettings settings = const GameSettings(),
  Size size = const Size(1920, 1080),
  VoidCallback? onOpen,
  VoidCallback? onClose,
}) async {
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: tvTheme(),
    home: HomeScreen(
      joinUrl: 'http://192.168.1.5:8080/',
      players: const [PlayerInfo(1, 'Ana', 0, true, 0)],
      settings: settings,
      selected: selected,
      games: const [GameKind.curve, GameKind.quiz, GameKind.uljez, GameKind.vukodlak],
      packs: const {GameKind.quiz: (ticked: 15, total: 16), GameKind.uljez: (ticked: 8, total: 9)},
      hostView: hostView,
      changed: changed,
      packGrid: grid,
      onOpenSettings: onOpen ?? () {},
      onCloseSettings: onClose ?? () {},
      onSelect: (_) {},
      onPlay: (_) {},
    ),
  ));
  await t.pump();
}

const _qChange = LobbyChange.setting(GameKind.quiz, 'quizQuestions', 10, 12, ChangeBy.phone);

void main() {
  testWidgets('hostView settings opens the panel by itself, with no key press', (t) async {
    await _pump(t);
    expect(find.byKey(const ValueKey('game-card')), findsNothing);
    await _pump(t, hostView: HostView.settings);
    expect(find.byKey(const ValueKey('game-card')), findsOneWidget);
    expect(find.textContaining(Strings.settingQuestions), findsOneWidget);
  });

  testWidgets('it closes when the host goes back to home (a game change, Natrag on the phone)', (t) async {
    await _pump(t, hostView: HostView.settings);
    expect(find.byKey(const ValueKey('game-card')), findsOneWidget);
    await _pump(t);
    expect(find.byKey(const ValueKey('game-card')), findsNothing);
  });

  testWidgets('the page dots hide while the panel is open', (t) async {
    await _pump(t);
    final dots = find.byKey(const ValueKey('page-dots'));
    expect(dots, findsOneWidget);
    await _pump(t, hostView: HostView.settings);
    expect(dots, findsNothing);
  });

  testWidgets('the changed row is outlined in the accent; the others are not', (t) async {
    await _pump(t, hostView: HostView.settings, changed: _qChange, settings: const GameSettings(quizQuestions: 12));
    final marked = find.byKey(const ValueKey('row-changed'));
    expect(marked, findsOneWidget);
    expect(find.descendant(of: marked, matching: find.textContaining(Strings.settingQuestions)), findsOneWidget);
    final box = t.widget<Container>(marked).decoration as BoxDecoration;
    expect((box.border as Border).top.color, tvAccent);
    // Nothing changed: no outline.
    await _pump(t, hostView: HostView.settings);
    expect(find.byKey(const ValueKey('row-changed')), findsNothing);
  });

  testWidgets('a change to another game is not outlined here', (t) async {
    await _pump(t, hostView: HostView.settings, changed: const LobbyChange.setting(GameKind.uljez, 'uljezImpostors', 1, 2, ChangeBy.phone));
    expect(find.byKey(const ValueKey('row-changed')), findsNothing);
  });

  testWidgets('a pack change outlines the pack row', (t) async {
    await _pump(t, selected: GameKind.uljez, hostView: HostView.settings, changed: const LobbyChange.setting(GameKind.uljez, 'uljezOffPacks', <String>[], ['x'], ChangeBy.phone));
    final marked = find.byKey(const ValueKey('row-changed'));
    expect(marked, findsOneWidget);
    expect(find.descendant(of: marked, matching: find.textContaining(Strings.settingPack)), findsOneWidget);
  });

  testWidgets('▼ asks the session to open the panel; Natrag asks it to close it', (t) async {
    var opened = 0, closed = 0;
    await _pump(t, onOpen: () => opened++, onClose: () => closed++);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(opened, 1);
    expect(find.byKey(const ValueKey('game-card')), findsNothing, reason: 'the session opens it, via hostView');
    await _pump(t, hostView: HostView.settings, onOpen: () => opened++, onClose: () => closed++);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump();
    expect(closed, 1);
  });

  testWidgets('the pack grid shows in hostView packs: every pack, on and off, with the count line', (t) async {
    await _pump(t, hostView: HostView.packs, grid: _tiles);
    expect(find.byKey(const ValueKey('pack-grid')), findsOneWidget);
    for (final p in _tiles) {
      expect(find.byKey(ValueKey(p.on ? 'pack-tile-${p.id}' : 'pack-off-${p.id}')), findsOneWidget, reason: p.title);
    }
    expect(find.byKey(const ValueKey('pack-off-b')), findsOneWidget, reason: 'Zastave is off');
    expect(find.byKey(const ValueKey('pack-off-a')), findsNothing);
    expect(find.textContaining('15 od 16 uključeno'), findsOneWidget);
    expect(find.textContaining('sa slikom'), findsWidgets);
    await _pump(t);
    expect(find.byKey(const ValueKey('pack-grid')), findsNothing);
  });

  for (final size in const [Size(1272, 715), Size(960, 540)]) {
    testWidgets('panel and pack grid fit at ${size.width.toInt()}x${size.height.toInt()}', (t) async {
      await _pump(t, hostView: HostView.settings, changed: _qChange, size: size);
      expect(t.takeException(), isNull);
      var r = t.getRect(find.byKey(const ValueKey('game-card')));
      expect(r.bottom, lessThanOrEqualTo(size.height * 1030 / 1080 + 0.5));
      await _pump(t, hostView: HostView.packs, grid: _tiles, size: size);
      expect(t.takeException(), isNull);
      for (final p in _tiles) {
        r = t.getRect(find.byKey(ValueKey(p.on ? 'pack-tile-${p.id}' : 'pack-off-${p.id}')));
        expect(r.top, greaterThanOrEqualTo(0), reason: p.title);
        expect(r.bottom, lessThanOrEqualTo(size.height * 1030 / 1080 + 0.5), reason: p.title);
        expect(r.right, lessThanOrEqualTo(size.width), reason: p.title);
      }
    });
  }
}
