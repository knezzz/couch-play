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

/// Smallest distance between two sampled paths.
double _gap(Path a, Path b) {
  List<Offset> pts(Path p) => [
    for (final m in p.computeMetrics())
      for (var d = 0.0; d <= m.length; d += 1)
        m.getTangentForOffset(d)!.position,
  ];
  final pa = pts(a), pb = pts(b);
  var best = double.infinity;
  for (final x in pa) {
    for (final y in pb) {
      final d = (x - y).distance;
      if (d < best) best = d;
    }
  }
  return best;
}

void main() {
  group('the carousel', () {
    testWidgets('each game has its own card with its settings line', (t) async {
      await _show(t, _lobby(), 0);
      final quiz = t.widget<Text>(find.byKey(const ValueKey('line-quiz')));
      expect(quiz.data, 'Opće znanje · 10 pitanja · 20 s');
      for (final k in [GameKind.quiz, GameKind.curve]) {
        expect(find.byKey(ValueKey('card-${k.name}')), findsOneWidget);
      }
      expect(
        Strings.settingsLine(
          GameKind.curve,
          const GameSettings(),
          const [],
          const [],
        ),
        'Način igre: Uravnoteženo · Pauza prije runde: 2 s',
      );
    });

    testWidgets('the settings line follows the TV', (t) async {
      await _show(
        t,
        _lobby(
          settings: const GameSettings(
            quizPackId: 'b',
            quizQuestions: 15,
            quizSeconds: 30,
          ),
        ),
        0,
      );
      expect(
        t.widget<Text>(find.byKey(const ValueKey('line-quiz'))).data,
        'Zastave · 15 pitanja · 30 s',
      );
    });

    testWidgets('page dots: one wide dot, it moves when the page does', (
      t,
    ) async {
      await _show(t, _lobby(), 0);
      final dots = find.descendant(
        of: find.byKey(const ValueKey('dots')),
        matching: find.byType(AnimatedContainer),
      );
      expect(dots, findsNWidgets(supportedGames.length));
      expect(supportedGames, isNot(contains(GameKind.objasni)));
      double w(int i) => t.getSize(dots.at(i)).width;
      expect(w(0), 32); // 24 + the 4 px margins
      expect(w(1), 16);
      await t.drag(find.byType(PageView), const Offset(-300, 0));
      await t.pumpAndSettle();
      expect(w(0), 16);
      expect(w(1), 32);
    });

    testWidgets(
      'the cards draw their art: Curve the ribbons, Kviz four tiles',
      (t) async {
        await _show(t, _lobby(), 0);
        final curve = find.byKey(const ValueKey('card-curve'));
        await t.drag(find.byType(PageView), const Offset(-300, 0));
        await t.pumpAndSettle();
        final paints = find.descendant(
          of: curve,
          matching: find.byType(CustomPaint),
        );
        expect(
          paints.evaluate().where(
            (e) => (e.widget as CustomPaint).painter != null,
          ),
          isNotEmpty,
          reason: 'the ribbons',
        );
        await t.drag(find.byType(PageView), const Offset(300, 0));
        await t.pumpAndSettle();
        final quiz = find.byKey(const ValueKey('card-quiz'));
        expect(
          find.descendant(of: quiz, matching: find.byType(Icon)),
          findsNWidgets(4),
        );
      },
    );

    test('the Curve card art never crosses or touches: gap > stroke width', () {
      final r = curveRibbons();
      expect(_gap(r.red, r.green), greaterThan(8 + 8));
    });

    test('the check can fail: a crossing pair is caught', () {
      final a = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 100);
      final b = Path()
        ..moveTo(0, 100)
        ..lineTo(100, 0);
      expect(_gap(a, b), lessThan(1));
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
      expect(find.text(Strings.startsWhen('Luka')), findsOneWidget);
      expect(find.byType(CharacterFace), findsNWidgets(5));
    });

    testWidgets('the guest changes the character from inside the chip', (
      t,
    ) async {
      await _show(t, _lobby(), 1);
      final chip = find.byKey(const ValueKey('change-character'));
      expect(chip, findsOneWidget);
      expect(t.getSize(chip).height, greaterThanOrEqualTo(56));
      await t.tap(chip);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('char-fox')), findsOneWidget);
    });

    testWidgets('the host keeps Promijeni lik below the chip', (t) async {
      await _show(t, _lobby(), 0);
      expect(find.byKey(const ValueKey('change-character')), findsNothing);
      expect(find.text(Strings.changeCharacter), findsOneWidget);
    });
  });

  group('what a guest sees of the open game', () {
    testWidgets('the watching card shows the game and its settings', (t) async {
      await _show(
        t,
        _lobby(
          selected: GameKind.curve,
          settings: const GameSettings(curveMode: CurveMode.chaos),
        ),
        1,
      );
      final card = find.byKey(const ValueKey('watching-card'));
      for (final s in [
        Strings.watchingLabel('Luka'),
        Strings.curve,
        'Način igre: Kaos · Pauza prije runde: 2 s',
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(s)),
          findsOneWidget,
          reason: s,
        );
      }
    });
  });

  group('the host details', () {
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

    testWidgets('a coloured header card with the name and blurb', (t) async {
      await open(t, GameKind.quiz);
      final h = find.byKey(const ValueKey('game-header'));
      expect(
        find.descendant(of: h, matching: find.text(Strings.quiz)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: h,
          matching: find.text(Strings.gameBlurb(GameKind.quiz)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Vukodlak shows the player count under the title', (t) async {
      await open(t, GameKind.vukodlak);
      expect(find.text(Strings.playerCount(4)), findsOneWidget);
    });

    testWidgets('Igraj is pinned and 72 px, in view without scrolling', (
      t,
    ) async {
      await open(t, GameKind.curve, width: 360, height: 640);
      final b = find.widgetWithText(FilledButton, Strings.play);
      expect(t.getSize(b).height, 72);
      expect(t.getBottomLeft(b).dy, lessThanOrEqualTo(640));
      expect(t.takeException(), isNull);
    });

    testWidgets('Curve: four mode cards, 2 x 2, above the pause, with blurbs', (
      t,
    ) async {
      final c = await open(t, GameKind.curve);
      final tl = {
        for (final m in CurveMode.values)
          m: t.getTopLeft(find.byKey(ValueKey('mode-${m.name}'))),
      };
      expect(tl[CurveMode.chaos]!.dy, tl[CurveMode.balanced]!.dy);
      expect(tl[CurveMode.peaceful]!.dy, greaterThan(tl[CurveMode.chaos]!.dy));
      expect(tl[CurveMode.peaceful]!.dx, tl[CurveMode.chaos]!.dx);
      final pause = t.getTopLeft(find.text(Strings.curveCountdown));
      expect(pause.dy, greaterThan(tl[CurveMode.peaceful]!.dy));
      for (final m in CurveMode.values) {
        expect(find.text(Strings.curveModeBlurb[m]!), findsOneWidget);
      }
      await t.tap(find.byKey(const ValueKey('mode-chaos')));
      expect((c.sent.last as SetSettings).settings.curveMode, CurveMode.chaos);
    });

    testWidgets('the chosen mode is the filled card, as the TV says', (
      t,
    ) async {
      await _show(
        t,
        _lobby(
          selected: GameKind.curve,
          settings: const GameSettings(curveMode: CurveMode.peaceful),
        ),
        0,
      );
      Color? fill(CurveMode m) => t
          .widget<Material>(
            find
                .ancestor(
                  of: find.byKey(ValueKey('mode-${m.name}')),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;
      expect(fill(CurveMode.peaceful), accent);
      expect(fill(CurveMode.chaos), surface);
    });

    testWidgets('each setting is its own card with the name beside - and +', (
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
}
