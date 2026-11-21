import 'package:controller/screens/home_rows.dart';
import 'package:controller/screens/lobby_screen.dart';
import 'package:controller/strings.dart';
import 'package:controller/theme.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

// Task 48: the phone home, live with the TV.

const _packs = [
  PackInfo('a', 'Opće znanje', 401),
  PackInfo('b', 'Zastave', 46, pictures: true),
  PackInfo('c', 'Povijest', 111),
];

LobbyState _lobby({
  GameKind selected = GameKind.quiz,
  GameSettings settings = const GameSettings(),
  List<LobbyChange> changes = const [],
  LobbyChange? changed,
  HostView view = HostView.home,
  int players = 4,
}) => LobbyState(
  hostId: 0,
  packs: _packs,
  uljezPacks: const [PackInfo('u', 'Sport', 40)],
  selected: selected,
  settings: settings,
  changes: changes,
  changed: changed,
  hostView: view,
  players: [
    for (var i = 0; i < players; i++)
      PlayerInfo(i, i == 0 ? 'Ana' : 'Gost $i', i, true, 0),
  ],
);

Future<FakeConnection> _show(
  WidgetTester t,
  LobbyState l,
  int me, {
  double width = 390,
  double height = 1800,
}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = FakeConnection();
  await t.pumpWidget(MaterialApp(theme: theme, home: LobbyScreen(c, l, me)));
  return c;
}

Color? _outline(WidgetTester t, String key) {
  final box =
      t.widget<Container>(find.byKey(ValueKey('row-$key'))).decoration!
          as BoxDecoration;
  final side = (box.border! as Border).top;
  return side.color;
}

void main() {
  const secs = LobbyChange.setting(
    GameKind.quiz,
    'quizSeconds',
    20,
    30,
    ChangeBy.phone,
  );
  final withSecs = _lobby(
    settings: const GameSettings(quizSeconds: 30),
    changed: secs,
    changes: const [secs],
  );

  group('the guest, read-only', () {
    testWidgets('the changed row is outlined, the old value struck through', (
      t,
    ) async {
      await _show(t, withSecs, 1);
      expect(_outline(t, 'quizSeconds'), accent);
      expect(_outline(t, 'quizQuestions'), Colors.transparent);
      final old = t.widget<Text>(find.byKey(const ValueKey('old-value')));
      expect(old.data, Strings.seconds(20));
      expect(old.style?.decoration, TextDecoration.lineThrough);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('val-quizSeconds'))).data,
        Strings.seconds(30),
      );
      expect(find.byKey(const ValueKey('old-value')), findsOneWidget);
    });

    testWidgets('no steppers, no play button, no way to send', (t) async {
      final c = await _show(t, withSecs, 1);
      expect(find.byKey(const ValueKey('inc-quizSeconds')), findsNothing);
      expect(find.byKey(const ValueKey('play')), findsNothing);
      expect(find.byKey(const ValueKey('game-next')), findsNothing);
      await t.tap(find.byKey(const ValueKey('game-banner')));
      await t.fling(
        find.byKey(const ValueKey('game-banner')),
        const Offset(-300, 0),
        1000,
      );
      expect(c.sent, isEmpty);
    });

    testWidgets('a change in another game is not outlined here', (t) async {
      await _show(
        t,
        _lobby(selected: GameKind.curve, changed: secs, changes: const [secs]),
        1,
      );
      expect(find.byKey(const ValueKey('old-value')), findsNothing);
      expect(_outline(t, 'curveCountdown'), Colors.transparent);
    });

    testWidgets('bots exist in two games: only the one it was changed in', (
      t,
    ) async {
      const bots = LobbyChange.setting(
        GameKind.quiz,
        'bots',
        0,
        1,
        ChangeBy.phone,
      );
      await _show(
        t,
        _lobby(selected: GameKind.curve, changed: bots, changes: const [bots]),
        1,
      );
      expect(_outline(t, 'bots'), Colors.transparent);
      await _show(
        t,
        _lobby(selected: GameKind.quiz, changed: bots, changes: const [bots]),
        1,
      );
      expect(_outline(t, 'bots'), accent);
    });

    testWidgets('a pack change shows the old and new count', (t) async {
      const packs = LobbyChange.setting(GameKind.quiz, 'quizOffPacks', [], [
        'a',
      ], ChangeBy.remote);
      await _show(
        t,
        _lobby(
          settings: const GameSettings(quizOffPacks: {'a'}),
          changed: packs,
          changes: const [packs],
        ),
        1,
      );
      expect(_outline(t, 'quizOffPacks'), accent);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('old-value'))).data,
        Strings.allPacks,
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('val-quizOffPacks'))).data,
        '2 paketa',
      );
    });

    testWidgets('the host is named in the pill, the feed and the footer', (
      t,
    ) async {
      await _show(t, _lobby(), 1);
      expect(find.text(Strings.watches('Ana')), findsOneWidget);
      expect(find.text(Strings.startedBy('Ana')), findsOneWidget);
      expect(find.text(Strings.changesEmpty('Ana')), findsOneWidget);
    });

    testWidgets('an empty feed says so; promijeni lik stays', (t) async {
      await _show(t, _lobby(), 1);
      expect(find.byKey(const ValueKey('feed-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('feed-line')), findsNothing);
      expect(find.byKey(const ValueKey('change-character')), findsOneWidget);
    });

    testWidgets('a key that is not in its game never prints raw', (t) async {
      const stray = LobbyChange.setting(GameKind.curve, 'quizOffPacks', [], [
        'hr-fizika',
      ], ChangeBy.phone);
      const noGame = LobbyChange.setting(null, 'x', 1, 2, ChangeBy.phone);
      await _show(t, _lobby(changes: const [stray, noGame, secs]), 1);
      final lines = find.byKey(const ValueKey('feed-line'));
      expect(lines, findsNWidgets(2)); // the one with no game is skipped
      expect(
        find.descendant(
          of: lines.first,
          matching: find.text(Strings.changedSettings(Strings.curve)),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('quizOffPacks'), findsNothing);
      expect(find.textContaining('hr-fizika'), findsNothing);
      expect(find.textContaining('['), findsNothing);
    });

    testWidgets('the feed: newest first, at most 5, phone or remote', (
      t,
    ) async {
      const game = LobbyChange.game(GameKind.curve, ChangeBy.remote);
      const settings = LobbyChange.settings(GameKind.curve, ChangeBy.remote);
      const packs = LobbyChange.packs(GameKind.quiz, ChangeBy.phone);
      final changes = [
        secs,
        game,
        settings,
        packs,
        secs,
        game, // a sixth one: the screen shows only five
      ];
      await _show(t, _lobby(changes: changes), 1);
      final lines = find.byKey(const ValueKey('feed-line'));
      expect(lines, findsNWidgets(5));
      String text(int i) => t
          .widgetList<Text>(
            find.descendant(of: lines.at(i), matching: find.byType(Text)),
          )
          .map((w) => w.data)
          .join('|');
      expect(
        text(0),
        '${Strings.changedSetting(Strings.quiz, Strings.quizSeconds, '20 s', '30 s')}|${Strings.byPhone}',
      );
      expect(
        text(1),
        '${Strings.changedGame(Strings.curve)}|${Strings.byRemote}',
      );
      expect(
        text(2),
        '${Strings.changedSettings(Strings.curve)}|${Strings.byRemote}',
      );
      expect(
        text(3),
        '${Strings.changedPacks(Strings.quiz)}|${Strings.byPhone}',
      );
    });

    testWidgets('hostView settings and packs change the pill', (t) async {
      await _show(t, _lobby(view: HostView.settings), 1);
      expect(
        find.text('${Strings.watches('Ana')}${Strings.watchesSettings}'),
        findsOneWidget,
      );
      await _show(t, _lobby(view: HostView.packs), 1);
      expect(
        find.text('${Strings.watches('Ana')}${Strings.watchesPacks}'),
        findsOneWidget,
      );
    });

    testWidgets('while the host is in the packs, the checklist is read-only', (
      t,
    ) async {
      final c = await _show(
        t,
        _lobby(
          view: HostView.packs,
          settings: const GameSettings(quizOffPacks: {'b'}),
        ),
        1,
      );
      expect(find.text(Strings.picksPacks('Ana')), findsOneWidget);
      for (final p in _packs) {
        expect(find.text(p.title), findsOneWidget);
      }
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
      expect([fill('a'), fill('b'), fill('c')], [accent, surface, accent]);
      await t.tap(find.byKey(const ValueKey('pack-b')));
      await t.pump();
      expect(c.sent, isEmpty);
      expect(find.byKey(const ValueKey('packs-back')), findsNothing);
      expect(find.byKey(const ValueKey('add-pack')), findsNothing);
      // The host leaves the screen: the home is back.
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: LobbyScreen(c, _lobby(view: HostView.home), 1),
        ),
      );
      expect(find.byKey(const ValueKey('pack-b')), findsNothing);
      expect(find.byKey(const ValueKey('game-banner')), findsOneWidget);
    });

    testWidgets('a guest who joins mid-change gets the whole picture', (
      t,
    ) async {
      // One LobbyState carries the game, the value, the outline and the feed.
      await _show(
        t,
        _lobby(
          selected: GameKind.curve,
          settings: const GameSettings(curveCountdown: 5),
          changed: const LobbyChange.setting(
            GameKind.curve,
            'curveCountdown',
            2,
            5,
            ChangeBy.remote,
          ),
          changes: const [
            LobbyChange.setting(
              GameKind.curve,
              'curveCountdown',
              2,
              5,
              ChangeBy.remote,
            ),
            LobbyChange.game(GameKind.curve, ChangeBy.phone),
          ],
          view: HostView.settings,
        ),
        3,
      );
      expect(_outline(t, 'curveCountdown'), accent);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('old-value'))).data,
        Strings.seconds(2),
      );
      expect(find.byKey(const ValueKey('feed-line')), findsNWidgets(2));
    });
  });

  group('the host', () {
    testWidgets('the changed row is outlined on the host phone too', (t) async {
      await _show(t, withSecs, 0);
      expect(_outline(t, 'quizSeconds'), accent);
      expect(_outline(t, 'quizQuestions'), Colors.transparent);
      expect(find.byKey(const ValueKey('old-value')), findsNothing);
    });

    testWidgets('the pack row opens the pack screen and tells the TV', (
      t,
    ) async {
      final c = await _show(t, _lobby(), 0);
      await t.tap(find.byKey(const ValueKey('open-quizOffPacks')));
      await t.pumpAndSettle();
      expect(c.sent.last, const PackScreen(true));
      await t.tap(find.byKey(const ValueKey('packs-back')));
      await t.pumpAndSettle();
      expect(c.sent.last, const PackScreen(false));
    });

    testWidgets('Android back closes the pack screen and still tells the TV', (
      t,
    ) async {
      final c = await _show(t, _lobby(), 0);
      await t.tap(find.byKey(const ValueKey('open-quizOffPacks')));
      await t.pumpAndSettle();
      await t.binding.handlePopRoute(); // the system back button
      await t.pumpAndSettle();
      expect(c.sent.last, const PackScreen(false));
    });

    testWidgets('a game change from the remote closes the pack screen', (
      t,
    ) async {
      final c = await _show(t, _lobby(), 0);
      await t.tap(find.byKey(const ValueKey('open-quizOffPacks')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pack-a')), findsOneWidget);
      // The same game again (a setting changed by the guests' side): stays.
      c.inbox.add(_lobby(view: HostView.packs));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pack-a')), findsOneWidget);
      c.inbox.add(_lobby(selected: GameKind.curve));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pack-a')), findsNothing);
      expect(find.byKey(const ValueKey('game-banner')), findsOneWidget);
      expect(c.sent.last, const PackScreen(false));
      expect(c.sent.where((m) => m == const PackScreen(false)).length, 1);
    });

    for (final k in GameKind.values) {
      for (final w in [360.0, 390.0]) {
        testWidgets(
          '${k.name} rows fit at ${w.toInt()} px: two label lines, no overflow',
          (t) async {
            final l = _lobby(selected: k, players: 8);
            await _show(t, l, 0, width: w, height: 1200);
            for (final r in homeRows(k, l)) {
              final h = t.getSize(find.byKey(ValueKey('row-${r.key}'))).height;
              expect(h, inInclusiveRange(64, 80), reason: r.key);
            }
            expect(t.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('the guest fits at 360 px with 8 players and a full feed', (
      t,
    ) async {
      final changes = [
        for (var i = 0; i < 5; i++)
          LobbyChange.setting(
            GameKind.quiz,
            'quizSeconds',
            20,
            30,
            i.isEven ? ChangeBy.phone : ChangeBy.remote,
          ),
      ];
      await _show(
        t,
        _lobby(players: 8, changes: changes, changed: changes.first),
        3,
        width: 360,
        height: 640,
      );
      expect(t.takeException(), isNull);
    });
  });
}
