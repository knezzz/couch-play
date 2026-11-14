import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/results_screen.dart';

void bigScreen(WidgetTester t) {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget app(List<Placement> placements, List<PlayerInfo> players) => MaterialApp(
      builder: (_, child) => EffectLayer(child: child!),
      home: ResultsScreen(placements: placements, players: players),
    );

void main() {
  testWidgets('8 long names at 1920x1080: no overflow, placements in order', (t) async {
    bigScreen(t);
    const name = 'WWWWWWWWWWWWWWWW';
    final players = [
      for (var i = 0; i < 8; i++) PlayerInfo(i, '$name$i', i, true, 10 - i, bot: i > 5),
    ];
    // Placements arrive in place order; ids deliberately not 0..7 in order.
    final order = [5, 2, 7, 0, 3, 1, 6, 4];
    final placements = [
      for (var i = 0; i < 8; i++) Placement(order[i], i + 1, 80 - i * 5, 8 - i),
    ];
    await t.pumpWidget(app(placements, players));
    expect(t.takeException(), isNull);
    double y(int id) => t.getTopLeft(find.byKey(ValueKey('place-$id'))).dy;
    for (var i = 0; i < 7; i++) {
      expect(y(order[i]), lessThan(y(order[i + 1])), reason: 'place ${i + 1}');
    }
    for (final text in t.widgetList<Text>(find.byType(Text))) {
      expect(text.style!.fontSize, greaterThanOrEqualTo(28), reason: text.data);
    }
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('ties share a place number and show the points', (t) async {
    bigScreen(t);
    final players = [
      const PlayerInfo(0, 'Ana', 0, true, 3),
      const PlayerInfo(1, 'Bea', 1, true, 3),
      const PlayerInfo(2, 'Cy', 2, true, 1),
    ];
    await t.pumpWidget(app(const [
      Placement(0, 1, 9, 3),
      Placement(1, 1, 9, 3),
      Placement(2, 3, 5, 1),
    ], players));
    void row(int id, String place, String points) {
      final r = find.byKey(ValueKey('place-$id'));
      expect(find.descendant(of: r, matching: find.text(place)), findsOneWidget);
      expect(find.descendant(of: r, matching: find.text(points)), findsOneWidget);
    }

    row(0, '1', '+3');
    row(1, '1', '+3');
    row(2, '3', '+1');
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('confetti plays once on entering, then clears', (t) async {
    bigScreen(t);
    await t.pumpWidget(app(const [Placement(0, 1, 9, 1)], const [PlayerInfo(0, 'Ana', 0, true, 1)]));
    await t.pump();
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await t.pump(const Duration(seconds: 3));
    expect(t.binding.transientCallbackCount, 0);
  });

  testWidgets('scoreboard: 44 px header, 40 px rows', (t) async {
    bigScreen(t);
    await t.pumpWidget(app(const [Placement(0, 1, 9, 3)], const [PlayerInfo(0, 'Ana', 0, true, 3)]));
    expect(t.widget<Text>(find.text('Scoreboard')).style!.fontSize, 44);
    expect(t.widgetList<Text>(find.text('Ana')).map((x) => x.style!.fontSize), contains(40));
    expect(t.widget<Text>(find.text('3')).style!.fontSize, 40);
    await t.pump(const Duration(seconds: 3));
  });
}
