import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tv/ui/lobby_screen.dart';

const _players = [
  PlayerInfo(0, 'Ana', 0, true, 3),
  PlayerInfo(1, 'Luka', 1, true, 9),
  PlayerInfo(2, 'Bot 1', 2, true, 5, bot: true),
];

Future<void> _pump(
  WidgetTester t, {
  String? url = 'http://192.168.1.5:8080/',
}) => t.pumpWidget(
  MaterialApp(
    home: LobbyScreen(joinUrl: url, players: _players, hostId: 0, onQuit: () {}),
  ),
);

void _noop() {}

void main() {
  testWidgets('shows the QR code and the URL as text', (t) async {
    await _pump(t);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('192.168.1.5:8080/'), findsOneWidget, reason: 'no http:// on screen');
  });

  testWidgets('without a LAN address it asks for Wi-Fi instead of a QR', (
    t,
  ) async {
    await _pump(t, url: null);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Connect the TV to Wi-Fi to play.'), findsOneWidget);
  });

  testWidgets('chips mark the host with a star and bots with "bot"', (t) async {
    await _pump(t);
    expect(find.textContaining('★ Ana'), findsOneWidget);
    expect(find.textContaining('Luka'), findsWidgets);
    expect(find.text('bot'), findsOneWidget);
  });

  testWidgets('scoreboard is sorted by score, highest first', (t) async {
    await _pump(t);
    double y(String name) =>
        t.getTopLeft(find.byKey(ValueKey('score-$name'))).dy;
    expect(y('Luka'), lessThan(y('Bot 1')));
    expect(y('Bot 1'), lessThan(y('Ana')));
  });


  void big(WidgetTester t) {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('the join URL stays on one line, even a long one', (t) async {
    big(t);
    await _pump(t, url: 'http://192.168.100.100:65535/');
    final f = find.text('192.168.100.100:65535/');
    expect(t.getSize(f).height, lessThan(52 * 1.5));
  });

  testWidgets('an away player is dimmed to 0.6 and badged "away"', (t) async {
    big(t);
    await t.pumpWidget(MaterialApp(
      home: LobbyScreen(
        joinUrl: 'http://x/',
        hostId: 0,
        onQuit: _noop,
        players: const [
          PlayerInfo(0, 'Ana', 0, true, 0),
          PlayerInfo(1, 'Ben', 1, false, 0),
        ],
      ),
    ));
    expect(find.text('away'), findsOneWidget);
    final op = t.widget<Opacity>(find.ancestor(of: find.text('Ben'), matching: find.byType(Opacity)).first);
    expect(op.opacity, 0.6);
  });

  testWidgets('scoreboard dots are 40 px, rows 40 px, header 44 px', (t) async {
    big(t);
    await _pump(t);
    expect(t.widget<Text>(find.text('Scoreboard')).style!.fontSize, 44);
    expect(t.widget<Text>(find.descendant(of: find.byKey(const ValueKey('score-Luka')), matching: find.text('Luka'))).style!.fontSize, 40);
    final dot = find.descendant(of: find.byKey(const ValueKey('score-Luka')), matching: find.byType(Container)).first;
    expect(t.getSize(dot), const Size(40, 40));
  });

  testWidgets('scoreboard stays hidden until someone has scored', (t) async {
    big(t);
    await t.pumpWidget(MaterialApp(
      home: LobbyScreen(
        joinUrl: 'http://x/',
        hostId: 0,
        onQuit: _noop,
        players: const [PlayerInfo(0, 'Ana', 0, true, 0)],
      ),
    ));
    expect(find.text('Scoreboard'), findsNothing);
    await _pump(t);
    expect(find.text('Scoreboard'), findsOneWidget);
  });

  testWidgets('with nobody joined it says how to join', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: LobbyScreen(joinUrl: 'http://x/', players: [], hostId: null, onQuit: _noop),
      ),
    );
    expect(find.text('Scan the code with your phone to join.'), findsOneWidget);
  });

  for (final name in ['Abcdefghijklmnop', 'WWWWWWWWWWWWWWWW']) {
    testWidgets('8 players with 16-character names ($name) fit at 1920x1080', (
      t,
    ) async {
      t.view
        ..physicalSize = const Size(1920, 1080)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          home: LobbyScreen(
            joinUrl: 'http://192.168.1.5:8080/',
            hostId: 0,
            onQuit: () {},
            players: [
              for (var i = 0; i < 8; i++)
                PlayerInfo(i, name, i, true, i, bot: i > 5),
            ],
          ),
        ),
      );
      expect(t.takeException(), isNull);
      // Text keeps a couch-readable size; long names are cut, not shrunk.
      // Button labels take their 36 px from the TV theme, which this test skips.
      final labels = find.descendant(of: find.byType(FilledButton), matching: find.byType(Text));
      final plain = find.byType(Text).evaluate().toSet().difference(labels.evaluate().toSet());
      for (final text in plain.map((e) => e.widget as Text)) {
        expect(
          text.style!.fontSize,
          greaterThanOrEqualTo(28),
          reason: text.data,
        );
      }
      final names = t.widgetList<Text>(
        find.textContaining(name.substring(0, 4)),
      );
      expect(names, isNotEmpty);
      for (final n in names.where((n) => n.maxLines != null)) {
        expect(n.overflow, TextOverflow.ellipsis);
      }
      // Not scaled down: on screen each name is as tall as its font size.
      for (final f in find.textContaining(name.substring(0, 4)).evaluate()) {
        final fin = find.byWidget(f.widget);
        final h = t.getBottomRight(fin).dy - t.getTopLeft(fin).dy;
        // >= because the ellipsis glyph falls back to a taller font in tests.
        expect(
          h,
          greaterThanOrEqualTo((f.widget as Text).style!.fontSize! - 1),
        );
      }
    });
  }
}
