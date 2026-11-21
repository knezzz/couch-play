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
  List<PlayerInfo>? players,
}) async {
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: tvTheme(),
    home: HomeScreen(
      joinUrl: 'http://192.168.1.5:8080/',
      players: players ?? const [PlayerInfo(1, 'Ana', 0, true, 0)],
      settings: settings,
      selected: selected,
      games: GameKind.values,
      packs: const {
        GameKind.quiz: (ticked: 15, total: 16),
        GameKind.uljez: (ticked: 8, total: 9),
        GameKind.objasni: (ticked: 8, total: 9),
        GameKind.koliko: (ticked: 3, total: 4),
        GameKind.blef: (ticked: 2, total: 2),
        GameKind.tkobi: (ticked: 4, total: 4),
      },
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

const _botsChange = LobbyChange.setting(GameKind.quiz, 'bots', 0, 2, ChangeBy.phone);
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

  testWidgets('a bots change outlines the Roboti row (Kviz and Curve), and the row says how many', (t) async {
    final withBots = [
      const PlayerInfo(1, 'Ana', 0, true, 0),
      const PlayerInfo(2, 'Robot 1', 1, true, 0, bot: true),
      const PlayerInfo(3, 'Robot 2', 2, true, 0, bot: true),
    ];
    await _pump(t, hostView: HostView.settings, changed: _botsChange, players: withBots);
    final marked = find.byKey(const ValueKey('row-changed'));
    expect(marked, findsOneWidget);
    expect(find.descendant(of: marked, matching: find.textContaining('Roboti')), findsOneWidget);
    expect(find.descendant(of: marked, matching: find.textContaining('2')), findsOneWidget);
    await _pump(t, selected: GameKind.curve, hostView: HostView.settings, changed: const LobbyChange.setting(GameKind.curve, 'bots', 0, 2, ChangeBy.phone), players: withBots);
    expect(find.descendant(of: find.byKey(const ValueKey('row-changed')), matching: find.textContaining('Roboti')), findsOneWidget);
    // A game without bots has no such row.
    await _pump(t, selected: GameKind.uljez, hostView: HostView.settings, players: withBots);
    expect(find.textContaining('Roboti'), findsNothing);
  });

  testWidgets('Curve: a host change opens the settings without the power-up legend; ▼ then adds it', (t) async {
    await _pump(t, selected: GameKind.curve, hostView: HostView.settings, changed: const LobbyChange.setting(GameKind.curve, 'curveCountdown', 3, 2, ChangeBy.phone));
    expect(find.text(Strings.legendTitle), findsNothing);
    final r = t.getRect(find.byKey(const ValueKey('game-card')));
    expect(r.top, greaterThan(600), reason: 'under the title, not over it');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(find.text(Strings.legendTitle), findsOneWidget);
    // Closed and opened by the host again: no legend.
    await _pump(t, selected: GameKind.curve);
    await _pump(t, selected: GameKind.curve, hostView: HostView.settings);
    expect(find.text(Strings.legendTitle), findsNothing);
  });

  // Task 48 review: the TV panel lists every setting the phone lists (apps/controller/lib/screens/home_rows.dart),
  // so a host change of any of them outlines its row.
  const phoneKeys = {
    GameKind.quiz: ['quizOffPacks', 'quizQuestions', 'quizSeconds', 'revealSeconds', 'bots'],
    GameKind.curve: ['curveMode', 'curveCountdown', 'bots'],
    GameKind.vukodlak: ['wolfRoles', 'wolfHideRoles'],
    GameKind.uljez: ['uljezOffPacks', 'uljezImpostors'],
    GameKind.objasni: ['objasniOffPacks', 'objasniSeconds', 'objasniTarget'],
    GameKind.koliko: ['kolikoOffPacks', 'kolikoSeconds', 'kolikoQuestions'],
    GameKind.blef: ['blefOffPacks', 'blefQuestions'],
    GameKind.tkobi: ['tkobiOffPacks', 'tkobiPrompts'],
  };
  for (final e in phoneKeys.entries) {
    testWidgets('${e.key.name}: a host change of each setting (${e.value.join(', ')}) opens the panel with that row marked', (t) async {
      for (final key in e.value) {
        await _pump(t, selected: e.key, hostView: HostView.settings, changed: LobbyChange.setting(e.key, key, 0, 1, ChangeBy.phone));
        expect(find.byKey(const ValueKey('row-changed')), findsOneWidget, reason: '${e.key.name} $key');
      }
      // The panel lists as many rows as the phone, one per key.
      await _pump(t, selected: e.key, hostView: HostView.settings);
      expect(find.byKey(const ValueKey('game-card')), findsOneWidget);
    });
  }

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
