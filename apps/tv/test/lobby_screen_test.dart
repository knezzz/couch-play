import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tv/ui/lobby_screen.dart';
import 'package:tv/ui/tv_theme.dart';

const _players = [
  PlayerInfo(0, 'Ana', 0, true, 3),
  PlayerInfo(1, 'Luka', 1, true, 9),
  PlayerInfo(2, 'Bot 1', 2, true, 5, bot: true),
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
}) {
  _big(t);
  return t.pumpWidget(MaterialApp(
    theme: tvTheme(),
    home: LobbyScreen(joinUrl: url, players: players, hostId: hostId, onQuit: _noop),
  ));
}

double _fs(WidgetTester t, Finder f) => t.widget<Text>(f).style!.fontSize!;

void main() {
  testWidgets('title, QR on a 560 px white card, caption and one-line URL', (t) async {
    await _pump(t);
    expect(find.text('CouchPlay'), findsOneWidget);
    expect(_fs(t, find.text('CouchPlay')), 72);
    expect(find.byType(QrImageView), findsOneWidget);
    final card = find.ancestor(of: find.byType(QrImageView), matching: find.byType(Container)).first;
    expect(t.getSize(card), const Size(560, 560));
    expect((t.widget<Container>(card).decoration! as BoxDecoration).color, Colors.white);
    expect(find.text('Scan, or open in your browser:'), findsOneWidget);
    expect(find.text('192.168.1.5:8080/'), findsOneWidget, reason: 'no http:// on screen');
  });

  testWidgets('the join URL stays on one line, even a long one', (t) async {
    await _pump(t, url: 'http://192.168.100.100:65535/');
    expect(t.getSize(find.text('192.168.100.100:65535/')).height, lessThan(52 * 1.5));
  });

  testWidgets('without a LAN address it asks for Wi-Fi instead of a QR', (t) async {
    await _pump(t, url: null);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Connect the TV to Wi-Fi to play.'), findsOneWidget);
  });

  testWidgets('players header, HOST and BOT pills, host star', (t) async {
    await _pump(t);
    expect(find.text('Players · 3 of 8'), findsOneWidget);
    expect(find.text('HOST'), findsOneWidget);
    expect(find.text('BOT'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.text('AWAY'), findsNothing);
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
    expect(find.text('AWAY'), findsOneWidget);
    final op = t.widget<Opacity>(find.ancestor(of: find.text('Ben'), matching: find.byType(Opacity)).first);
    expect(op.opacity, 0.6);
  });

  testWidgets('scoreboard card: ranked, sorted, 44 px header, 40 px rows and dots', (t) async {
    await _pump(t);
    expect(_fs(t, find.text('Scoreboard')), 44);
    double y(String name) => t.getTopLeft(find.byKey(ValueKey('score-$name'))).dy;
    expect(y('Luka'), lessThan(y('Bot 1')));
    expect(y('Bot 1'), lessThan(y('Ana')));
    final row = find.byKey(const ValueKey('score-Luka'));
    expect(_fs(t, find.descendant(of: row, matching: find.text('Luka'))), 40);
    expect(find.descendant(of: row, matching: find.text('1')), findsOneWidget, reason: 'rank');
    final dot = find.descendant(of: row, matching: find.byType(PlayerDot));
    expect(t.getSize(dot), const Size(40, 40));
    final card = find.ancestor(of: find.text('Scoreboard'), matching: find.byType(Container)).first;
    expect((t.widget<Container>(card).decoration! as BoxDecoration).color, tvSurface);
  });

  testWidgets('before the first game the card says scores come later', (t) async {
    await _pump(t, players: const [PlayerInfo(0, 'Ana', 0, true, 0)]);
    expect(find.text('Scores appear after the first game.'), findsOneWidget);
    expect(find.byKey(const ValueKey('score-Ana')), findsNothing);
    await _pump(t);
    expect(find.text('Scores appear after the first game.'), findsNothing);
  });

  testWidgets('says who picks the game', (t) async {
    await _pump(t);
    expect(find.text('Waiting for Ana to pick a game.'), findsOneWidget);
  });

  testWidgets('with nobody joined it says how to join', (t) async {
    await _pump(t, players: const [], hostId: null);
    expect(find.text('Scan the code with your phone to join.'), findsOneWidget);
    expect(find.textContaining('Waiting for'), findsNothing);
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
