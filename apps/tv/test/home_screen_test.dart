import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/home_screen.dart';
import 'package:tv/ui/tv_theme.dart';

final _four = [
  for (var i = 0; i < 4; i++)
    PlayerInfo(i, 'P$i', i, true, 0, character: characterIds[i]),
];

class _Probe {
  final selected = <GameKind>[];
  final played = <GameKind>[];
}

Future<_Probe> _pump(
  WidgetTester t, {
  GameKind? selected,
  String? url = 'http://192.168.1.5:8080/',
  List<PlayerInfo>? players,
  GameSettings settings = const GameSettings(),
  Map<GameKind, ({int ticked, int total})> packs = const {},
  int quizPacks = 0,
  int quizQuestions = 0,
  String? notice,
  bool reduceMotion = false,
  List<GameKind> games = const [GameKind.curve, GameKind.quiz],
}) async {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final probe = _Probe();
  t.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await t.pumpWidget(
    MaterialApp(
      theme: tvTheme(),
      home: HomeScreen(
        joinUrl: url,
        players: players ?? _four,
        settings: settings,
        selected: selected,
        packs: packs,
        quizPacks: quizPacks,
        quizQuestions: quizQuestions,
        notice: notice,
        games: games,
        onSelect: probe.selected.add,
        onPlay: probe.played.add,
      ),
    ),
  );
  await t.pump(); // autofocus
  return probe;
}

Finder _title(String s) => find.byKey(ValueKey('title-$s'));
double _fs(WidgetTester t, Finder f) => t.widget<Text>(f).style!.fontSize!;
Finder _face(String id) =>
    find.byWidgetPredicate((w) => w is CharacterFace && w.id == id);

// build-core drops GameKind.kaosvi in Task 47 stage 2; then this is GameKind.values.
final _games = GameKind.values.where((g) => g != GameKind.kaosvi).toList();

void main() {
  testWidgets('the blurbs are the canvas\'s (V2Home); Kviz says how much there is to play', (t) async {
    await _pump(t, selected: GameKind.curve);
    expect(find.text('Vozi svoju krivulju i ne udari ni u koga.'), findsOneWidget);
    await _pump(t, selected: GameKind.quiz, quizPacks: 16, quizQuestions: 2000);
    expect(find.text('16 paketa, 2\u00A0000 pitanja. Odgovaraš na mobitelu.'), findsOneWidget);
    await _pump(t, selected: GameKind.quiz);
    expect(find.text('Pitanja s četiri odgovora. Odgovaraš na mobitelu.'), findsOneWidget, reason: 'counts not known yet');
  });

  test('Croatian counts: 1 paket, 2 paketa, 5 paketa, 21 paket, 12 paketa; 1 pitanje, 2 pitanja, 21 pitanje', () {
    expect([1, 2, 4, 5, 11, 12, 21, 22, 100].map(Strings.packsWord), ['1 paket', '2 paketa', '4 paketa', '5 paketa', '11 paketa', '12 paketa', '21 paket', '22 paketa', '100 paketa']);
    expect([1, 2, 5, 11, 21].map(Strings.questionsWord), ['1 pitanje', '2 pitanja', '5 pitanja', '11 pitanja', '21 pitanje']);
  });

  testWidgets(
    'with nothing selected the first game fills the screen: big title, one-line description, settings',
    (t) async {
      await _pump(t, settings: const GameSettings(curveCountdown: 2));
      expect(find.text(Strings.gameName(GameKind.curve)), findsWidgets);
      expect(_fs(t, _title('Curve')), 200);
      expect(find.text(Strings.gameBlurb(GameKind.curve)), findsOneWidget);
      expect(
        find.textContaining(
          Strings.curveModeName(const GameSettings().curveMode),
        ),
        findsOneWidget,
        reason: 'the current mode, in the settings line',
      );
      expect(find.textContaining('2 s'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'the selected game is the one shown (the host\'s phone picked it)',
    (t) async {
      await _pump(
        t,
        selected: GameKind.quiz,
        packs: const {GameKind.quiz: (ticked: 3, total: 9)},
      );
      expect(_title('Kviz'), findsOneWidget);
      expect(_title('Curve'), findsNothing);
      expect(find.textContaining('3 od 9 paketa'), findsOneWidget);
      expect(find.textContaining('10 pitanja'), findsOneWidget);
    },
  );

  testWidgets('the previous and next games peek at the edges', (t) async {
    await _pump(t, selected: GameKind.quiz);
    final prev = t.getRect(find.byKey(const ValueKey('prev')));
    final next = t.getRect(find.byKey(const ValueKey('next')));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('prev')),
        matching: find.text('Curve'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('next')),
        matching: find.text('Curve'),
      ),
      findsOneWidget,
      reason: 'two games: both neighbours are the other one',
    );
    expect(prev.left, lessThan(0), reason: 'peeks from the left edge');
    expect(next.right, greaterThan(1920), reason: 'peeks from the right edge');
  });

  testWidgets(
    'right and left change the game, wrap around, and tell the session',
    (t) async {
      final p = await _pump(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(
        _title('Kviz'),
        findsOneWidget,
        reason: 'shown at once, before the session answers',
      );
      expect(p.selected, [GameKind.quiz]);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(_title('Curve'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pump();
      expect(_title('Kviz'), findsOneWidget);
      expect(p.selected, [GameKind.quiz, GameKind.curve, GameKind.quiz]);
    },
  );

  testWidgets('with three games right goes forward and left goes back, both wrapping', (t) async {
    const three = [GameKind.curve, GameKind.quiz, GameKind.vukodlak];
    final p = await _pump(t, games: three);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(p.selected, [
      GameKind.quiz, GameKind.vukodlak, GameKind.curve, // forward, wrapping at the end
      GameKind.vukodlak, GameKind.quiz, GameKind.curve, GameKind.vukodlak, // back, wrapping at the start
    ]);
  });

  testWidgets('OK plays the game on screen', (t) async {
    final p = await _pump(t, selected: GameKind.quiz);
    await t.sendKeyEvent(LogicalKeyboardKey.select);
    await t.pump();
    expect(p.played, [GameKind.quiz]);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(p.played, [GameKind.quiz, GameKind.curve]);
  });

  testWidgets('the phone\'s selection moves the TV', (t) async {
    await _pump(t, selected: GameKind.quiz);
    expect(_title('Kviz'), findsOneWidget);
    await t.pumpWidget(
      MaterialApp(
        theme: tvTheme(),
        home: HomeScreen(
          joinUrl: null,
          players: _four,
          settings: const GameSettings(),
          selected: GameKind.curve,
          onSelect: (_) {},
          onPlay: (_) {},
        ),
      ),
    );
    await t.pump();
    expect(_title('Curve'), findsOneWidget);
  });

  testWidgets('down opens the game\'s settings, up closes them', (t) async {
    await _pump(
      t,
      selected: GameKind.quiz,
      packs: const {GameKind.quiz: (ticked: 3, total: 9)},
      settings: const GameSettings(quizQuestions: 12, quizSeconds: 30),
    );
    expect(find.byKey(const ValueKey('game-card')), findsNothing);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    final card = find.byKey(const ValueKey('game-card'));
    expect(card, findsOneWidget);
    for (final s in ['3 od 9 paketa', '12', '30 s']) {
      expect(
        find.descendant(of: card, matching: find.textContaining(s)),
        findsWidgets,
        reason: s,
      );
    }
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump();
    expect(card, findsNothing);
  });

  testWidgets('the settings of a Curve show its mode and countdown', (t) async {
    await _pump(
      t,
      selected: GameKind.curve,
      settings: const GameSettings(
        curveMode: CurveMode.peaceful,
        curveCountdown: 3,
      ),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    final card = find.byKey(const ValueKey('game-card'));
    expect(
      find.descendant(of: card, matching: find.textContaining('Mirno')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('3 s')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Back closes the settings first; with them closed it is left to the system (exit)',
    (t) async {
      await _pump(t, selected: GameKind.quiz);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      expect(find.byKey(const ValueKey('game-card')), findsOneWidget);
      expect(
        await t.binding.handlePopRoute(),
        isTrue,
        reason: 'handled: the panel closes',
      );
      await t.pump();
      expect(find.byKey(const ValueKey('game-card')), findsNothing);
      expect(
        await t.binding.handlePopRoute(),
        isFalse,
        reason: 'not handled: the app exits',
      );
    },
  );

  testWidgets('Escape does what Back does', (t) async {
    await _pump(t, selected: GameKind.quiz);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(find.byKey(const ValueKey('game-card')), findsNothing);
  });

  testWidgets('QR and the address are top left', (t) async {
    await _pump(t);
    final qr = find.byType(QrImageView);
    expect(qr, findsOneWidget);
    final r = t.getRect(qr);
    expect(r.left, lessThan(300));
    expect(r.top, lessThan(200));
    expect(find.text('192.168.1.5:8080'), findsOneWidget);
    expect(r.width, greaterThanOrEqualTo(160));
  });

  testWidgets('no network: says so instead of the QR', (t) async {
    await _pump(t, url: null);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text(Strings.noWifi), findsOneWidget);
  });

  testWidgets('the players\' characters are top right', (t) async {
    await _pump(t);
    for (var i = 0; i < 4; i++) {
      final r = t.getRect(_face(characterIds[i]));
      expect(r.right, lessThanOrEqualTo(1920), reason: 'player $i');
      expect(r.top, lessThan(150));
      expect(r.left, greaterThan(960));
    }
    expect(find.text(Strings.playerCount(4)), findsOneWidget);
  });

  testWidgets(
    '8 players with characters: every face on screen, left of nothing else, no overflow',
    (t) async {
      final eight = [
        for (var i = 0; i < 8; i++)
          PlayerInfo(
            i,
            'Abcdefghijklmnop',
            i,
            true,
            0,
            bot: i > 5,
            character: characterIds[i],
          ),
      ];
      await _pump(
        t,
        players: eight,
        selected: GameKind.quiz,
        packs: const {GameKind.quiz: (ticked: 3, total: 9)},
      );
      expect(t.takeException(), isNull);
      final qrPanel = t.getRect(find.byKey(const ValueKey('join-panel')));
      for (var i = 0; i < 8; i++) {
        final r = t.getRect(_face(characterIds[i]));
        expect(r.right, lessThanOrEqualTo(1920));
        expect(
          r.left,
          greaterThan(qrPanel.right),
          reason: 'face $i clear of the QR panel',
        );
      }
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      expect(t.takeException(), isNull, reason: 'with the settings open too');
    },
  );

  testWidgets('a notice (e.g. nobody has joined) shows above the help line', (
    t,
  ) async {
    await _pump(t, notice: Strings.homeNeedPlayers);
    expect(find.text(Strings.homeNeedPlayers), findsOneWidget);
  });

  testWidgets('the help line names the four keys', (t) async {
    await _pump(t);
    for (final s in [
      Strings.homeHelpMove,
      Strings.homeHelpPlay,
      Strings.homeHelpSettings,
      Strings.homeHelpBack,
    ]) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
  });

  testWidgets('the background is still: the picture never changes by itself, with or without reduced motion', (t) async {
    final key = GlobalKey();
    Future<List<int>> picture(bool reduce, {int afterSeconds = 0}) async {
      t.view
        ..physicalSize = const Size(1920, 1080)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      t.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduce);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await t.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: tvTheme(),
          home: HomeScreen(joinUrl: null, players: const [], settings: const GameSettings(), selected: GameKind.curve, onSelect: (_) {}, onPlay: (_) {}),
        ),
      ));
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(Duration(seconds: afterSeconds));
      final d = await t.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
        return (await img.toByteData())!;
      });
      return [for (var i = 0; i < d!.lengthInBytes; i += 97) d.getUint8(i)];
    }

    int diff(List<int> a, List<int> b) {
      var n = 0;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) n++;
      }
      return n;
    }

    final first = await picture(false);
    final later = await picture(false, afterSeconds: 6);
    expect(diff(first, later), 0, reason: 'nothing drifts: an idle home must not ask for frames');
    final still = await picture(true);
    final stillLater = await picture(true, afterSeconds: 6);
    expect(diff(still, stillLater), 0, reason: 'reduced motion keeps it still');
  });

  testWidgets('the background is not redrawn every frame: no per-frame animation is running', (t) async {
    await _pump(t);
    await t.pump(const Duration(milliseconds: 100));
    expect(t.binding.transientCallbackCount, 0, reason: 'a 60 fps ticker is what made the idle home cost 17 ms of raster a frame');
  });

  testWidgets('every text is 28 px or more', (t) async {
    await _pump(
      t,
      selected: GameKind.quiz,
      packs: const {GameKind.quiz: (ticked: 3, total: 9)},
    );
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    for (final r in t.widgetList<RichText>(find.byType(RichText))) {
      final size = r.text.style?.fontSize;
      if (size != null) {
        expect(size, greaterThanOrEqualTo(28), reason: r.text.toPlainText());
      }
    }
  });

  testWidgets('Vukodlak and Uljez have settings rows too, not an empty panel', (t) async {
    await _pump(t, selected: GameKind.vukodlak, games: homeGames, settings: const GameSettings(wolfHideRoles: true));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    final card = find.byKey(const ValueKey('game-card'));
    expect(find.descendant(of: card, matching: find.text('Vrijeme razgovora')), findsNothing, reason: 'no discussion time: nothing is timed');
    expect(find.descendant(of: card, matching: find.textContaining(Strings.settingHideRoles)), findsOneWidget);
    await _pump(t, selected: GameKind.uljez, games: homeGames, settings: const GameSettings(uljezImpostors: 2));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    expect(find.descendant(of: card, matching: find.text('Vrijeme razgovora')), findsNothing);
    expect(find.descendant(of: card, matching: find.textContaining(Strings.settingImpostors)), findsOneWidget);
  });

  group('pack line (Task 46)', () {
    testWidgets('all ticked reads Svi paketi, else the count; per game, in the settings panel', (t) async {
      const all = (ticked: 9, total: 9);
      await _pump(t, selected: GameKind.uljez, games: homeGames, packs: const {GameKind.uljez: all, GameKind.blef: (ticked: 3, total: 9)});
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      final card = find.byKey(const ValueKey('game-card'));
      expect(find.descendant(of: card, matching: find.textContaining(Strings.packsAll)), findsOneWidget);
      await _pump(t, selected: GameKind.blef, games: homeGames, packs: const {GameKind.uljez: all, GameKind.blef: (ticked: 3, total: 9)});
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      expect(find.descendant(of: card, matching: find.textContaining('3 od 9 paketa')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining(Strings.packsAll)), findsNothing);
    });

    testWidgets('games without packs (Curve, Vukodlak) show no pack line', (t) async {
      await _pump(t, selected: GameKind.vukodlak, games: homeGames, packs: const {GameKind.quiz: (ticked: 1, total: 2)});
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      expect(find.textContaining('paket'), findsNothing);
    });

    // QA fail: the card's meta line (panel closed) must carry the selection for every pack game.
    for (final g in const [GameKind.uljez, GameKind.objasni, GameKind.koliko, GameKind.blef, GameKind.tkobi]) {
      for (final size in const [Size(1272, 715), Size(960, 540)]) {
        testWidgets('${g.name}: the card meta says the packs, panel closed, whole at ${size.width.toInt()}x${size.height.toInt()}', (t) async {
          t.view
            ..physicalSize = size
            ..devicePixelRatio = 1;
          addTearDown(t.view.reset);
          for (final c in const [(ticked: 9, total: 9), (ticked: 3, total: 9)]) {
            await t.pumpWidget(MaterialApp(
              theme: tvTheme(),
              home: HomeScreen(
                joinUrl: 'http://192.168.1.5:8080/',
                players: _four,
                settings: const GameSettings(),
                selected: g,
                games: homeGames,
                packs: {g: c},
                onSelect: (_) {},
                onPlay: (_) {},
              ),
            ));
            await t.pump();
            final line = Strings.packsLine(c.ticked, c.total);
            final meta = find.textContaining('$line · bez robota');
            expect(meta, findsOneWidget, reason: '${g.name} $line');
            // Whole: scaled to fit, so it lies inside the screen.
            final r = t.getRect(meta);
            expect(r.left, greaterThanOrEqualTo(0), reason: '${g.name} $line');
            expect(r.right, lessThanOrEqualTo(size.width), reason: '${g.name} $line');
          }
          expect(t.takeException(), isNull);
        });
      }
    }

    for (final size in const [Size(1272, 715), Size(960, 540)]) {
      testWidgets('the pack line fits at ${size.width.toInt()}x${size.height.toInt()}', (t) async {
        t.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(MaterialApp(
          theme: tvTheme(),
          home: HomeScreen(
            joinUrl: 'http://192.168.1.5:8080/',
            players: _four,
            settings: const GameSettings(),
            selected: GameKind.tkobi,
            games: homeGames,
            packs: const {GameKind.tkobi: (ticked: 12, total: 14)},
            onSelect: (_) {},
            onPlay: (_) {},
          ),
        ));
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.pump();
        expect(find.textContaining('12 od 14 paketa'), findsWidgets); // card meta and panel row
        expect(t.takeException(), isNull);
      });
    }
  });

  group('the power-up legend (▼ on the Curve card)', () {
    testWidgets('lists every power-up with its icon, name, time and one line, below the settings', (t) async {
      await _pump(t, selected: GameKind.curve);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      for (final k in PowerUpKind.values) {
        final e = find.byKey(ValueKey('legend-${k.name}'));
        expect(e, findsOneWidget, reason: '$k');
        final info = powerUpTexts[k]!;
        expect(find.descendant(of: e, matching: find.textContaining(info.name, findRichText: true)), findsWidgets, reason: '${k.name} name');
        expect(find.descendant(of: e, matching: find.text(info.what)), findsOneWidget, reason: '${k.name} line');
        expect(find.descendant(of: e, matching: find.textContaining(info.time, findRichText: true)), findsWidgets, reason: '${k.name} time');
        expect(t.widget<PowerUpIcon>(find.descendant(of: e, matching: find.byType(PowerUpIcon))).kind, k);
      }
      expect(find.descendant(of: find.byKey(const ValueKey('game-card')), matching: find.textContaining(Strings.settingMode)), findsOneWidget, reason: 'the settings are still there');
    });

    testWidgets('it fits: everything between the top and 1030 px, texts 28 px or more, no overflow', (t) async {
      await _pump(t, selected: GameKind.curve);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      expect(t.takeException(), isNull);
      final card = t.getRect(find.byKey(const ValueKey('game-card')));
      expect(card.bottom, lessThanOrEqualTo(1030));
      expect(card.top, greaterThanOrEqualTo(0));
      for (final k in PowerUpKind.values) {
        final r = t.getRect(find.byKey(ValueKey('legend-${k.name}')));
        expect(r.right, lessThanOrEqualTo(1920), reason: '${k.name}');
        expect(r.bottom, lessThanOrEqualTo(card.bottom));
      }
      for (final w in t.widgetList<Text>(find.descendant(of: find.byKey(const ValueKey('game-card')), matching: find.byType(Text)))) {
        final size = w.style?.fontSize ?? 28;
        expect(size, greaterThanOrEqualTo(28), reason: w.data ?? w.textSpan?.toPlainText());
      }
    });

    testWidgets('the other games\' panels have no legend', (t) async {
      await _pump(t, selected: GameKind.quiz);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      expect(find.byKey(ValueKey('legend-${PowerUpKind.speed.name}')), findsNothing);
    });
  });

  group('Večeras (tonight\'s totals)', () {
    final scored = [
      for (var i = 0; i < 4; i++) PlayerInfo(i, ['Ana', 'Luka', 'Marko', 'Ivana'][i], i, true, [2, 5, 0, 3][i], character: characterIds[i]),
    ];

    testWidgets('after the first game a small strip along the bottom: each player\'s total, leader first', (t) async {
      await _pump(t, players: scored);
      final strip = find.byKey(const ValueKey('tonight'));
      expect(strip, findsOneWidget);
      expect(find.descendant(of: strip, matching: find.text(Strings.tonight)), findsOneWidget);
      double x(String name) => t.getTopLeft(find.descendant(of: strip, matching: find.text(name))).dx;
      expect(x('Luka'), lessThan(x('Ivana')));
      expect(x('Ivana'), lessThan(x('Ana')));
      expect(x('Ana'), lessThan(x('Marko')));
      expect(find.descendant(of: strip, matching: find.text('5')), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.descendant(of: strip, matching: find.byWidgetPredicate((w) => w is CharacterFace && w.id == characterIds[i])), findsOneWidget);
      }
      expect(t.getRect(strip).bottom, lessThanOrEqualTo(1030), reason: 'clear of the overscan');
      expect(t.takeException(), isNull);
    });

    testWidgets('no strip before anyone has points (the first game has not been played)', (t) async {
      await _pump(t);
      expect(find.byKey(const ValueKey('tonight')), findsNothing);
    });

    testWidgets('the settings panel hides it', (t) async {
      await _pump(t, players: scored, selected: GameKind.quiz);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      expect(find.byKey(const ValueKey('tonight')), findsNothing);
    });

    testWidgets('8 players with long names still fit on one line, on screen', (t) async {
      final eight = [for (var i = 0; i < 8; i++) PlayerInfo(i, 'Abcdefghijklmnop', i, true, 40 - i, character: characterIds[i])];
      await _pump(t, players: eight);
      expect(t.takeException(), isNull);
      final r = t.getRect(find.byKey(const ValueKey('tonight')));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(1920));
    });
  });

  group('each game has its own background art', () {
    final key = GlobalKey();
    Future<ByteData> shot(WidgetTester t, GameKind g) async {
      t.view
        ..physicalSize = const Size(1920, 1080)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await t.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: tvTheme(),
          home: HomeScreen(joinUrl: null, players: const [], settings: const GameSettings(), selected: g, onSelect: (_) {}, onPlay: (_) {}),
        ),
      ));
      await t.pump(const Duration(milliseconds: 400));
      return (await t.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
        return (await img.toByteData())!;
      }))!;
    }

    Color at(ByteData d, int x, int y) {
      final i = (y * 1920 + x) * 4;
      return Color.fromARGB(d.getUint8(i + 3), d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2));
    }

    double lum(Color c) => c.computeLuminance();

    testWidgets('Vukodlak: a pale moon on the right and a dark ridge along the bottom', (t) async {
      final d = await shot(t, GameKind.vukodlak);
      expect(lum(at(d, 1460, 250)), greaterThan(0.05), reason: 'moon (under the vignette)');
      expect(lum(at(d, 300, 1000)), lessThan(0.02), reason: 'ridge');
      expect(lum(at(d, 100, 700)), lessThan(0.05), reason: 'night sky left of the moon');
    });

    testWidgets('Uljez: a purple table in the middle, lighter than the backdrop', (t) async {
      final d = await shot(t, GameKind.uljez);
      final table = at(d, 700, 620);
      expect(table.b, greaterThan(table.g), reason: 'purple');
      expect(lum(table), greaterThan(lum(at(d, 40, 1040))), reason: 'table against the dark corner');
    });

    testWidgets('the four backgrounds differ', (t) async {
      final px = <GameKind, List<Color>>{};
      for (final g in _games) {
        final d = await shot(t, g);
        px[g] = [for (final p in const [(300, 300), (960, 700), (1460, 250), (300, 1000), (1600, 900)]) at(d, p.$1, p.$2)];
      }
      for (final a in _games) {
        for (final b in _games) {
          if (a.index >= b.index) continue;
          var diff = 0;
          for (var i = 0; i < 5; i++) {
            if ((px[a]![i].r - px[b]![i].r).abs() + (px[a]![i].g - px[b]![i].g).abs() + (px[a]![i].b - px[b]![i].b).abs() > 0.05) diff++;
          }
          expect(diff, greaterThan(0), reason: '$a and $b look the same');
        }
      }
    });
  });
}
