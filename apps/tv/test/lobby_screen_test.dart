import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/lobby_screen.dart';
import 'package:tv/ui/tv_theme.dart';

const _players = [
  PlayerInfo(0, 'Ana', 0, true, 3),
  PlayerInfo(1, 'Luka', 1, true, 9),
  PlayerInfo(2, 'Robot 1', 2, true, 5, bot: true),
];

void _noop() {}

void _big(WidgetTester t) {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _pump(
  WidgetTester t, {
  String? url = 'http://192.168.1.5:8080/',
  List<PlayerInfo> players = _players,
  int? hostId = 0,
  GameSettings settings = const GameSettings(),
  GameKind? selected,
  String? packTitle,
}) {
  _big(t);
  return t.pumpWidget(MaterialApp(
    theme: tvTheme(),
    home: LobbyScreen(joinUrl: url, players: players, hostId: hostId, settings: settings, selected: selected, packTitle: packTitle, onQuit: _noop),
  ));
}

double _fs(WidgetTester t, Finder f) => t.widget<Text>(f).style!.fontSize!;

Finder _face(String id) => find.byWidgetPredicate((w) => w is CharacterFace && w.id == id);

void main() {
  group('characters', () {
    final withChars = [
      for (var i = 0; i < 3; i++) PlayerInfo(i, 'P$i', i, true, 5 - i, character: characterIds[i]),
    ];

    testWidgets('each chip and scoreboard row shows the player\'s character, in a ring on the chip', (t) async {
      await _pump(t, players: withChars);
      for (var i = 0; i < 3; i++) {
        expect(_face(characterIds[i]), findsNWidgets(2), reason: 'chip + scoreboard row of P$i');
      }
      final chip = find.ancestor(of: find.text('P0'), matching: find.byType(Container)).first;
      expect(find.descendant(of: chip, matching: _face(characterIds[0])), findsOneWidget);
      expect(t.widget<CharacterFace>(find.descendant(of: chip, matching: _face(characterIds[0]))).size,
          greaterThanOrEqualTo(48), reason: 'big enough from the couch');
    });

    testWidgets('a player without a character keeps the colour dot', (t) async {
      await _pump(t, players: const [PlayerInfo(0, 'Ana', 0, true, 3), PlayerInfo(1, 'Luka', 1, true, 1)]);
      expect(find.byType(CharacterFace), findsNothing);
    });

    testWidgets('8 players with 16-character names and characters still fit, every face on screen', (t) async {
      final eight = [
        for (var i = 0; i < 8; i++)
          PlayerInfo(i, 'Abcdefghijklmnop', i, true, 9 - i, bot: i > 5, character: characterIds[i]),
      ];
      await _pump(t, players: eight);
      expect(t.takeException(), isNull);
      for (var i = 0; i < 8; i++) {
        final f = _face(characterIds[i]);
        expect(f, findsNWidgets(2));
        final r = t.getRect(f.first);
        expect(r.right, lessThanOrEqualTo(1920));
        expect(r.bottom, lessThanOrEqualTo(1080));
      }
    });
  });

  group('the host\'s game card', () {
    final card = find.byKey(const ValueKey('game-card'));
    String text(WidgetTester t) => t
        .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
        .map((w) => w.data ?? w.textSpan!.toPlainText())
        .join(' | ');

    testWidgets('no selection: no card, the plain lobby with the settings line and scores', (t) async {
      await _pump(t);
      expect(card, findsNothing);
      expect(find.textContaining('Kviz:'), findsOneWidget);
      expect(find.text(Strings.scoreboard), findsOneWidget);
    });

    testWidgets('Kviz selected: name, description, pack and its settings, players and QR still there', (t) async {
      await _pump(t,
          selected: GameKind.quiz,
          packTitle: 'Međimurje',
          settings: const GameSettings(quizQuestions: 15, quizSeconds: 25, revealSeconds: 6));
      expect(card, findsOneWidget);
      final s = text(t);
      expect(s, contains('Kviz'));
      expect(s, contains(Strings.gameBlurb(GameKind.quiz)));
      expect(s, contains('Paket pitanja: Međimurje'));
      expect(s, contains('Broj pitanja: 15'));
      expect(s, contains('Vrijeme za odgovor: 25 s'));
      expect(s, contains('Pauza između pitanja: 6 s'));
      expect(s, isNot(contains('Način igre')));
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Luka'), findsWidgets);
      expect(find.textContaining('Kviz:'), findsNothing, reason: 'the card replaces the settings line');
      expect(find.text(Strings.scoreboard), findsNothing);
    });

    testWidgets('while a card is up the waiting line says what the host is looking at', (t) async {
      await _pump(t, selected: GameKind.quiz, packTitle: 'A');
      expect(find.text('Ana gleda: Kviz'), findsOneWidget);
      expect(find.text(Strings.waitingForHost('Ana')), findsNothing);
      await _pump(t, selected: GameKind.curve);
      expect(find.text('Ana gleda: Curve'), findsOneWidget);
      await _pump(t);
      expect(find.text(Strings.waitingForHost('Ana')), findsOneWidget);
      expect(find.textContaining('gleda'), findsNothing);
    });

    testWidgets('the pack gets its own full-width row, above the other settings', (t) async {
      await _pump(t, selected: GameKind.quiz, packTitle: 'Hrvatska - kultura i sport');
      Finder item(String label) => find.descendant(of: card, matching: find.textContaining(label));
      final pack = t.getRect(item('Paket pitanja'));
      final inner = t.getRect(card);
      expect(pack.width, greaterThan((inner.width - 96) * 0.9), reason: 'the whole row, not half of it');
      for (final other in ['Broj pitanja', 'Vrijeme za odgovor', 'Pauza između pitanja']) {
        expect(t.getRect(item(other)).top, greaterThanOrEqualTo(pack.bottom), reason: other);
      }
    });

    testWidgets('Curve selected: mode and pause before each round only', (t) async {
      await _pump(t,
          selected: GameKind.curve, settings: const GameSettings(curveMode: CurveMode.chaos, curveCountdown: 7));
      final s = text(t);
      expect(s, contains(Strings.gameBlurb(GameKind.curve)));
      expect(s, contains('Način igre: Kaos'));
      expect(s, contains('Pauza prije runde: 7 s'));
      expect(s, isNot(contains('Paket pitanja')));
      expect(s, isNot(contains('Broj pitanja')));
    });

    testWidgets('a settings change shows at once; going back removes the card', (t) async {
      await _pump(t, selected: GameKind.curve, settings: const GameSettings(curveCountdown: 2));
      expect(text(t), contains('Pauza prije runde: 2 s'));
      await _pump(t, selected: GameKind.curve, settings: const GameSettings(curveCountdown: 9));
      expect(text(t), contains('Pauza prije runde: 9 s'));
      await _pump(t, selected: GameKind.quiz, packTitle: 'A', settings: const GameSettings());
      expect(text(t), contains('Paket pitanja: A'));
      await _pump(t);
      expect(card, findsNothing);
    });

    testWidgets('8 players with long names and a long pack title fit, and the buttons keep focus', (t) async {
      final many = [
        for (var i = 0; i < 8; i++) PlayerInfo(i, 'Abcdefghijklmnop', i, true, i, bot: i > 5),
      ];
      await _pump(t,
          players: many,
          selected: GameKind.quiz,
          packTitle: 'Zemljopis svijeta za naprednije igrače, težak paket',
          settings: const GameSettings(quizQuestions: 30, quizSeconds: 60, revealSeconds: 15));
      expect(t.takeException(), isNull);
      final r = t.getRect(card);
      expect(r.bottom, lessThanOrEqualTo(1080 - 56));
      expect(r.right, lessThanOrEqualTo(1920 - 96));
      expect(r.height, greaterThan(150));
      final waiting = t.getRect(find.textContaining('gleda:'));
      expect(r.bottom, lessThanOrEqualTo(waiting.top));
      // D-pad: the first button still has focus and Right moves to Quit.
      final focus = FocusManager.instance.primaryFocus!.context!;
      expect(find.descendant(of: find.byWidget(focus.widget), matching: find.text(Strings.howToJoin)),
          findsOneWidget);
    });
  });

  testWidgets('one muted line shows the host settings and follows changes', (t) async {
    await _pump(t);
    const quiz = 'Kviz: 10 pitanja · odgovor 20 s · pauza 4 s';
    const curve = 'Curve: Uravnoteženo · pauza prije runde 2 s';
    final line = find.text('$quiz     $curve');
    expect(line, findsOneWidget);
    expect(t.widget<Text>(line).style!.color, tvMuted);
    expect(t.widget<Text>(line).style!.fontSize, lessThanOrEqualTo(32));
    expect(t.getSize(line).height, lessThan(32 * 1.5), reason: 'one line');
    expect(t.getRect(line).right, lessThanOrEqualTo(1920 - 96));

    await _pump(t,
        settings: const GameSettings(
            quizQuestions: 25, quizSeconds: 45, revealSeconds: 7, curveCountdown: 5, curveMode: CurveMode.onlyYou));
    expect(find.text('Kviz: 25 pitanja · odgovor 45 s · pauza 7 s     Curve: Samo za tebe · pauza prije runde 5 s'),
        findsOneWidget);
    expect(line, findsNothing);
  });

  testWidgets('every Curve mode has its name on the line', (t) async {
    for (final m in CurveMode.values) {
      await _pump(t, settings: GameSettings(curveMode: m));
      expect(find.textContaining(Strings.curveModeName(m)), findsOneWidget);
    }
    expect(CurveMode.values.map(Strings.curveModeName), ['Kaos', 'Uravnoteženo', 'Mirno', 'Samo za tebe']);
  });

  testWidgets('no settings line while nobody has joined', (t) async {
    await _pump(t, players: const []);
    expect(find.textContaining('Kviz:'), findsNothing);
  });

  testWidgets('title, QR on a 560 px white card, caption and one-line URL', (t) async {
    await _pump(t);
    expect(find.text('CouchPlay'), findsOneWidget);
    expect(_fs(t, find.text('CouchPlay')), 72);
    expect(find.byType(QrImageView), findsOneWidget);
    final card = find.ancestor(of: find.byType(QrImageView), matching: find.byType(Container)).first;
    expect(t.getSize(card), const Size(560, 560));
    expect((t.widget<Container>(card).decoration! as BoxDecoration).color, Colors.white);
    expect(find.text(Strings.scanCaption), findsOneWidget);
    expect(find.text('192.168.1.5:8080/'), findsOneWidget, reason: 'no http:// on screen');
  });

  testWidgets('the join URL stays on one line, even a long one', (t) async {
    await _pump(t, url: 'http://192.168.100.100:65535/');
    expect(t.getSize(find.text('192.168.100.100:65535/')).height, lessThan(52 * 1.5));
  });

  testWidgets('without a LAN address it asks for Wi-Fi instead of a QR', (t) async {
    await _pump(t, url: null);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text(Strings.noWifi), findsOneWidget);
    expect(t.takeException(), isNull, reason: 'the Croatian text fits beside no QR code');
  });

  testWidgets('players header, BOT pill, host star (no HOST word)', (t) async {
    await _pump(t);
    expect(find.text(Strings.players(3)), findsOneWidget);
    expect(find.text(Strings.badgeBot), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.text(Strings.badgeAway), findsNothing);
  });

  testWidgets('chips are a 2-column grid', (t) async {
    await _pump(t, players: [for (var i = 0; i < 4; i++) PlayerInfo(i, 'P$i', i, true, 0)]);
    Offset at(String n) => t.getTopLeft(find.ancestor(of: find.text(n), matching: find.byType(Opacity)).first);
    expect(at('P0').dy, at('P1').dy);
    expect(at('P0').dx, lessThan(at('P1').dx));
    expect(at('P2').dy, greaterThan(at('P0').dy));
    expect(at('P2').dx, at('P0').dx);
  });

  testWidgets('an away player is dimmed to 0.6 and badged AWAY', (t) async {
    await _pump(t, players: const [
      PlayerInfo(0, 'Ana', 0, true, 0),
      PlayerInfo(1, 'Ben', 1, false, 0),
    ]);
    expect(find.text(Strings.badgeAway), findsOneWidget);
    final op = t.widget<Opacity>(find.ancestor(of: find.text('Ben'), matching: find.byType(Opacity)).first);
    expect(op.opacity, 0.6);
  });

  testWidgets('scoreboard card: ranked, sorted, 44 px header, 40 px rows and dots', (t) async {
    await _pump(t);
    expect(_fs(t, find.text(Strings.scoreboard)), 44);
    double y(String name) => t.getTopLeft(find.byKey(ValueKey('score-$name'))).dy;
    expect(y('Luka'), lessThan(y('Robot 1')));
    expect(y('Robot 1'), lessThan(y('Ana')));
    final row = find.byKey(const ValueKey('score-Luka'));
    expect(_fs(t, find.descendant(of: row, matching: find.text('Luka'))), 40);
    expect(find.descendant(of: row, matching: find.text('1')), findsOneWidget, reason: 'rank');
    final dot = find.descendant(of: row, matching: find.byType(PlayerDot));
    expect(t.getSize(dot), const Size(40, 40));
    final card = find.ancestor(of: find.text(Strings.scoreboard), matching: find.byType(Container)).first;
    expect((t.widget<Container>(card).decoration! as BoxDecoration).color, tvSurface);
  });

  testWidgets('before the first game the card says scores come later', (t) async {
    await _pump(t, players: const [PlayerInfo(0, 'Ana', 0, true, 0)]);
    expect(find.text(Strings.scoreboardEmpty), findsOneWidget);
    expect(find.byKey(const ValueKey('score-Ana')), findsNothing);
    await _pump(t);
    expect(find.text(Strings.scoreboardEmpty), findsNothing);
  });

  testWidgets('says who picks the game', (t) async {
    await _pump(t);
    expect(find.text(Strings.waitingForHost('Ana')), findsOneWidget);
  });

  testWidgets('the longest Croatian lobby texts fit: 16-character host name, all badges', (t) async {
    await _pump(t, players: [
      const PlayerInfo(0, 'WWWWWWWWWWWWWWWW', 0, true, 12480),
      const PlayerInfo(1, 'Abcdefghijklmnop', 1, false, 3),
      for (var i = 2; i < 8; i++) PlayerInfo(i, 'Robot ${i - 1}', i, true, 0, bot: true),
    ]);
    expect(t.takeException(), isNull);
    expect(find.text(Strings.waitingForHost('WWWWWWWWWWWWWWWW')), findsOneWidget);
    expect(find.text(Strings.badgeAway), findsOneWidget);
  });

  testWidgets('a 16-character host name shows in full, whatever the width', (t) async {
    for (final name in ['WWWWWWWWWWWWWWWW', 'Čedo Šćepanović-K']) {
      await _pump(t, players: [
        PlayerInfo(0, name, 0, true, 0),
        for (var i = 1; i < 8; i++) PlayerInfo(i, 'Igrač $i', i, true, 0),
      ]);
      expect(t.takeException(), isNull, reason: name);
      final para = t.renderObject<RenderParagraph>(find.descendant(
          of: find.ancestor(of: find.byIcon(Icons.star), matching: find.byType(Row)).first,
          matching: find.text(name)));
      expect(para.didExceedMaxLines, isFalse, reason: '$name is cut');
    }
  });

  testWidgets('with nobody joined it says how to join', (t) async {
    await _pump(t, players: const [], hostId: null);
    expect(find.text(Strings.scanToJoin), findsOneWidget);
    expect(find.textContaining('Čekamo da'), findsNothing);
  });

  for (final count in [5, 6, 8]) {
    for (final name in ['Abcdefghijklmnop', 'WWWWWWWWWWWWWWWW']) {
      testWidgets('$count players with 16-character names ($name) fit at 1920x1080', (t) async {
        await _pump(t, players: [
          for (var i = 0; i < count; i++) PlayerInfo(i, name, i, i != 2, i + 1, bot: i > 5),
        ]);
        expect(t.takeException(), isNull);
        // Button labels take their size from the TV theme.
        final labels = find.descendant(of: find.byType(FilledButton), matching: find.byType(Text));
        final plain = find.byType(Text).evaluate().toSet().difference(labels.evaluate().toSet());
        for (final text in plain.map((e) => e.widget as Text)) {
          expect(text.style!.fontSize, greaterThanOrEqualTo(28), reason: text.data);
        }
        final names = t.widgetList<Text>(find.textContaining(name.substring(0, 4)));
        expect(names, isNotEmpty);
        for (final n in names.where((n) => n.maxLines != null)) {
          expect(n.overflow, TextOverflow.ellipsis);
        }
      });
    }
  }
}
