import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/results_screen.dart';
import 'package:tv/ui/tv_theme.dart';

void bigScreen(WidgetTester t) {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget app(List<Placement> placements, List<PlayerInfo> players, {String? label}) => MaterialApp(
      theme: tvTheme(),
      builder: (_, child) => EffectLayer(child: child!),
      home: ResultsScreen(placements: placements, players: players, label: label ?? Strings.gameQuiz('World Flags')),
    );

double fs(WidgetTester t, Finder f) => t.widget<Text>(f).style!.fontSize!;

const _four = [
  PlayerInfo(0, 'Ana', 1, true, 13),
  PlayerInfo(1, 'Luka', 0, true, 10),
  PlayerInfo(2, 'Ivana', 4, true, 8),
  PlayerInfo(3, 'Marko', 3, true, 3),
];
const _fourPlaces = [
  Placement(0, 1, 8420, 4),
  Placement(1, 2, 7910, 3),
  Placement(2, 3, 5200, 2),
  Placement(3, 4, 2960, 1),
];

void main() {
  testWidgets('headline names the winner; label beside it', (t) async {
    bigScreen(t);
    await t.pumpWidget(app(_fourPlaces, _four));
    expect(find.text(Strings.wins(['Ana'])), findsOneWidget);
    expect(fs(t, find.text(Strings.wins(['Ana']))), 96);
    expect(find.text(Strings.gameQuiz('World Flags')), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('a tie for first shares the headline and both rows are winner rows', (t) async {
    bigScreen(t);
    await t.pumpWidget(app(const [
      Placement(0, 1, 9, 3),
      Placement(1, 1, 9, 3),
      Placement(2, 3, 5, 1),
    ], const [
      PlayerInfo(0, 'Ana', 0, true, 3),
      PlayerInfo(1, 'Bea', 1, true, 3),
      PlayerInfo(2, 'Cy', 2, true, 1),
    ]));
    expect(find.text(Strings.wins(['Ana', 'Bea'])), findsOneWidget);
    void row(int id, String place, String points) {
      final r = find.byKey(ValueKey('place-$id'));
      expect(find.descendant(of: r, matching: find.text(place)), findsOneWidget);
      expect(find.descendant(of: r, matching: find.text(points)), findsOneWidget);
    }

    row(0, Strings.place(1), '+3');
    row(1, Strings.place(1), '+3');
    row(2, Strings.place(3), '+1');
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('winner row is in their colour; the others sit on surface rows', (t) async {
    bigScreen(t);
    await t.pumpWidget(app(_fourPlaces, _four));
    Color fill(int id) {
      return (t.widget<Container>(find.byKey(ValueKey('place-$id'))).decoration! as BoxDecoration).color!;
    }

    expect(fill(0), playerColors[1]); // Ana has colorIndex 1
    expect(fill(1), tvSurface);
    expect(fill(3), tvSurface);
    // place number, game score and session points on a row
    final r = find.byKey(const ValueKey('place-1'));
    expect(find.descendant(of: r, matching: find.text(Strings.place(2))), findsOneWidget);
    expect(find.descendant(of: r, matching: find.text('7 910')), findsOneWidget);
    final plus = find.descendant(of: r, matching: find.text('+3'));
    expect(t.widget<Text>(plus).style!.color, const Color(0xFF2ECC71));
    final winnerPlus = find.descendant(of: find.byKey(const ValueKey('place-0')), matching: find.text('+4'));
    expect(winnerPlus, findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('Tonight panel lists the session scores, highest first', (t) async {
    bigScreen(t);
    await t.pumpWidget(app(_fourPlaces, _four));
    expect(find.text(Strings.tonight), findsOneWidget);
    expect(fs(t, find.text(Strings.tonight)), 44);
    final panel = find.byKey(const ValueKey('tonight'));
    double y(String name) => t.getTopLeft(find.descendant(of: panel, matching: find.text(name))).dy;
    expect(y('Ana'), lessThan(y('Luka')));
    expect(y('Luka'), lessThan(y('Marko')));
    expect(fs(t, find.descendant(of: panel, matching: find.text('Ana'))), 40);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('a 3-way tie of 16-character names: the Croatian headline stays on one line', (t) async {
    bigScreen(t);
    const names = ['WWWWWWWWWWWWWWWW', 'Abcdefghijklmnop', 'MMMMMMMMMMMMMMMM'];
    await t.pumpWidget(app([
      for (var i = 0; i < 3; i++) Placement(i, 1, 100, 3),
    ], [
      for (var i = 0; i < 3; i++) PlayerInfo(i, names[i], i, true, 3),
    ]));
    expect(t.takeException(), isNull);
    final head = find.text(Strings.wins(names));
    expect(head, findsOneWidget);
    expect(t.getSize(head).height, lessThan(96 * 1.8), reason: 'one line');
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('place labels (1st, 2nd) never wrap', (t) async {
    bigScreen(t);
    await t.pumpWidget(app(_fourPlaces, _four));
    for (final label in [for (var i = 1; i <= 4; i++) Strings.place(i)]) {
      expect(t.getSize(find.text(label)).height, lessThan(1.8 * 48), reason: label); // two lines would be ~2.8x
    }
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('countdown bar and text count down to the lobby', (t) async {
    bigScreen(t);
    await t.pumpWidget(app(_fourPlaces, _four));
    expect(find.text(Strings.backToLobby(8)), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    expect(find.text(Strings.backToLobby(5)), findsOneWidget);
    final bar = t.widget<FractionallySizedBox>(find.byKey(const ValueKey('countdown-bar')));
    expect(bar.widthFactor, closeTo(3 / 8, 0.05));
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('8 long names at 1920x1080: no overflow, placements in order', (t) async {
    bigScreen(t);
    const name = 'WWWWWWWWWWWWWWWW';
    final players = [
      for (var i = 0; i < 8; i++) PlayerInfo(i, '$name$i', i, true, 10 - i, bot: i > 5),
    ];
    final order = [5, 2, 7, 0, 3, 1, 6, 4];
    final placements = [
      for (var i = 0; i < 8; i++) Placement(order[i], i + 1, 80000 - i * 5, 8 - i),
    ];
    await t.pumpWidget(app(placements, players));
    expect(t.takeException(), isNull);
    double y(int id) => t.getTopLeft(find.byKey(ValueKey('place-$id'))).dy;
    for (var i = 0; i < 7; i++) {
      expect(y(order[i]), lessThan(y(order[i + 1])), reason: 'place ${i + 1}');
    }
    // The size each Text actually resolves to, theme and DefaultTextStyle included.
    for (final r in t.widgetList<RichText>(find.byType(RichText))) {
      expect(r.text.style!.fontSize, greaterThanOrEqualTo(28), reason: r.text.toPlainText());
    }
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('confetti plays once on entering, then clears', (t) async {
    bigScreen(t);
    await t.pumpWidget(app(const [Placement(0, 1, 9, 1)], const [PlayerInfo(0, 'Ana', 0, true, 1)]));
    await t.pump();
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await t.pump(const Duration(seconds: 3));
    expect(t.binding.transientCallbackCount, 0);
    await t.pump(const Duration(seconds: 6));
  });
}
