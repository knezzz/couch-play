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
    home: LobbyScreen(joinUrl: url, players: _players, hostId: 0),
  ),
);

void main() {
  testWidgets('shows the QR code and the URL as text', (t) async {
    await _pump(t);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('http://192.168.1.5:8080/'), findsOneWidget);
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

  testWidgets('with nobody joined it says how to join', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: LobbyScreen(joinUrl: 'http://x/', players: [], hostId: null),
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
            players: [
              for (var i = 0; i < 8; i++)
                PlayerInfo(i, name, i, true, i, bot: i > 5),
            ],
          ),
        ),
      );
      expect(t.takeException(), isNull);
      // Text keeps a couch-readable size; long names are cut, not shrunk.
      for (final text in t.widgetList<Text>(find.byType(Text))) {
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
