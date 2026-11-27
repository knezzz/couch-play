import 'package:controller/screens/game_cards.dart';
import 'package:controller/screens/lobby_screen.dart';
import 'package:controller/strings.dart';
import 'package:controller/theme.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_connection.dart';

const _packs = [
  PackInfo('a', 'Opće znanje', 401),
  PackInfo('b', 'Zastave', 46),
];

LobbyState _lobby({
  GameKind? selected,
  GameSettings settings = const GameSettings(),
  int host = 0,
}) => LobbyState(
  hostId: host,
  packs: _packs,
  selected: selected,
  settings: settings,
  players: [
    PlayerInfo(0, 'Luka', 0, true, 0, character: characterIds[0]),
    PlayerInfo(1, 'Ana', 1, true, 0, character: characterIds[1]),
    PlayerInfo(2, 'Marko', 2, true, 0, character: characterIds[2]),
    PlayerInfo(
      10,
      'Robot 1',
      3,
      true,
      0,
      bot: true,
      character: characterIds[3],
    ),
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

void main() {
  group('the game card and dots', () {
    testWidgets('the banner line follows the TV: players, then each setting', (
      t,
    ) async {
      await _show(t, _lobby(), 0);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('banner-meta'))).data,
        '1–8 igrača · Svi paketi · 10 · 20 s · 4 s · 1 rob.',
      );
      await _show(
        t,
        _lobby(
          settings: const GameSettings(
            quizOffPacks: {'a', 'c'},
            quizQuestions: 15,
            quizSeconds: 30,
          ),
        ),
        0,
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('banner-meta'))).data,
        '1–8 igrača · 1 paket · 15 · 30 s · 4 s · 1 rob.',
      );
      await _show(t, _lobby(selected: GameKind.vukodlak), 0);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('banner-meta'))).data,
        '5–8 igrača · Da · bez robota',
      );
    });

    testWidgets('the edges name the neighbours, wrapping round', (t) async {
      await _show(t, _lobby(selected: GameKind.quiz), 0);
      expect(find.text('‹\n${Strings.gameName(GameKind.sumo)}'), findsOneWidget);
      expect(find.text('›\n${Strings.curve}'), findsOneWidget);
    });

    testWidgets('page dots: one wide dot, it follows the selected game', (
      t,
    ) async {
      await _show(t, _lobby(), 0);
      final dots = find.descendant(
        of: find.byKey(const ValueKey('dots')),
        matching: find.byType(AnimatedContainer),
      );
      expect(dots, findsNWidgets(supportedGames.length));
      expect(supportedGames.length, GameKind.values.length);
      double w(int i) => t.getSize(dots.at(i)).width;
      expect(w(0), 24 + 6); // 24 + the 3 px margins
      expect(w(1), 8 + 6);
      await _show(t, _lobby(selected: GameKind.curve), 0);
      await t.pumpAndSettle(); // the dots slide
      expect(w(0), 8 + 6);
      expect(w(1), 24 + 6);
    });
  });

  group('lobby lists', () {
    testWidgets('the host sees faces for the others and no host tag', (
      t,
    ) async {
      await _show(t, _lobby(), 0);
      expect(find.text(Strings.others(3)), findsOneWidget);
      // own chip face + 3 others
      expect(find.byType(CharacterFace), findsNWidgets(4));
      expect(find.text(Strings.hostTag), findsNothing);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('a guest sees everybody: (ti), the host tag, the footer', (
      t,
    ) async {
      await _show(t, _lobby(), 1);
      expect(find.text(Strings.players(4)), findsOneWidget);
      expect(find.text('Ana${Strings.youSuffix}'), findsOneWidget);
      expect(find.text(Strings.hostTag), findsOneWidget);
      expect(find.text(Strings.botTag), findsOneWidget);
      expect(find.text(Strings.startedBy('Luka')), findsOneWidget);
      expect(find.byType(CharacterFace), findsNWidgets(5));
    });

    testWidgets('the guest changes the character from the header', (t) async {
      await _show(t, _lobby(), 1);
      final chip = find.byKey(const ValueKey('change-character'));
      expect(chip, findsOneWidget);
      expect(t.getSize(chip).height, greaterThanOrEqualTo(44));
      await t.tap(chip);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('char-fox')), findsOneWidget);
    });

    testWidgets('the host has Promijeni lik in the header too', (t) async {
      await _show(t, _lobby(), 0);
      expect(find.byKey(const ValueKey('change-character')), findsOneWidget);
    });
  });

  group('what a guest sees of the open game', () {
    testWidgets('the card, its pill and settings as the TV says', (t) async {
      await _show(
        t,
        _lobby(
          selected: GameKind.curve,
          settings: const GameSettings(curveMode: CurveMode.chaos),
        ),
        1,
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('banner-title'))).data,
        Strings.curve,
      );
      expect(find.text(Strings.watches('Luka')), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('val-curveMode'))).data,
        Strings.curveMode(CurveMode.chaos),
      );
      expect(find.byKey(const ValueKey('inc-curveMode')), findsNothing);
    });
  });

  group('the host home', () {
    Future<FakeConnection> open(
      WidgetTester t,
      GameKind k, {
      double width = 390,
      double height = 1000,
    }) => _show(
      t,
      _lobby(selected: k),
      0,
      width: width,
      height: height,
    );

    testWidgets('the card has the name and the blurb', (t) async {
      await open(t, GameKind.quiz);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('banner-title'))).data,
        Strings.quiz,
      );
      expect(find.text(Strings.gameBlurb(GameKind.quiz)), findsOneWidget);
    });

    testWidgets('Igraj is pinned, 64 px, named for the game, in view', (
      t,
    ) async {
      await open(t, GameKind.curve, width: 360, height: 640);
      final b = find.byKey(const ValueKey('play'));
      expect(t.getSize(b).height, 64);
      expect(t.getBottomLeft(b).dy, lessThanOrEqualTo(640));
      expect(find.text(Strings.playGame(Strings.curve)), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Curve: ‹ › on the mode sends the whole settings', (t) async {
      final c = await open(t, GameKind.curve);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('val-curveMode'))).data,
        Strings.curveMode(CurveMode.balanced),
      );
      await t.tap(find.byKey(const ValueKey('dec-curveMode')));
      expect((c.sent.last as SetSettings).settings.curveMode, CurveMode.chaos);
    });

    testWidgets('each setting is its own row with the name beside - and +', (
      t,
    ) async {
      await open(t, GameKind.quiz);
      final label = t.getCenter(find.text(Strings.quizSeconds));
      final less = t.getCenter(
        find.byTooltip(Strings.lessOf(Strings.quizSeconds)),
      );
      expect((label.dy - less.dy).abs(), lessThan(20));
    });
  });

  group('the power-up legend in the Curve details', () {
    Future<void> openLegend(WidgetTester t, {double width = 390}) async {
      await _show(
        t,
        _lobby(selected: GameKind.curve),
        0,
        width: width,
        height: 2600,
      );
    }

    testWidgets('shut by default; opens to every power-up from core', (
      t,
    ) async {
      await openLegend(t);
      expect(find.byKey(const ValueKey('pu-speed')), findsNothing);
      expect(
        t.getSize(find.byKey(const ValueKey('legend-toggle'))).height,
        greaterThanOrEqualTo(56),
      );
      await t.tap(find.byKey(const ValueKey('legend-toggle')));
      await t.pumpAndSettle();
      for (final k in PowerUpKind.values) {
        final row = find.byKey(ValueKey('pu-${k.name}'));
        expect(row, findsOneWidget, reason: k.name);
        final text = powerUpTexts[k]!;
        for (final s in [text.name, text.what, text.time]) {
          expect(
            find.descendant(of: row, matching: find.text(s)),
            findsOneWidget,
            reason: '${k.name}: $s',
          );
        }
        expect(
          find.descendant(of: row, matching: find.byType(PowerUpIcon)),
          findsOneWidget,
        );
      }
      await t.tap(find.byKey(const ValueKey('legend-toggle')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('pu-speed')), findsNothing);
    });

    testWidgets('grouped by whom they act on: you, the others, all', (t) async {
      await openLegend(t);
      await t.tap(find.byKey(const ValueKey('legend-toggle')));
      await t.pumpAndSettle();
      double y(PowerUpKind k) =>
          t.getTopLeft(find.byKey(ValueKey('pu-${k.name}'))).dy;
      expect(y(PowerUpKind.cheese), lessThan(y(PowerUpKind.speedOthers)));
      expect(y(PowerUpKind.squareOthers), lessThan(y(PowerUpKind.clear)));
      expect(find.text(Strings.puYou), findsOneWidget);
      expect(find.text(Strings.puOthers), findsOneWidget);
      expect(find.text(Strings.puAll), findsOneWidget);
    });

    testWidgets('fits 360 px with the longest line open', (t) async {
      await openLegend(t, width: 360);
      await t.tap(find.byKey(const ValueKey('legend-toggle')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('the Kviz details have no legend', (t) async {
      await _show(t, _lobby(selected: GameKind.quiz), 0);
      expect(find.byKey(const ValueKey('legend-toggle')), findsNothing);
    });
  });
}
