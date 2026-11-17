import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/pause_card.dart';
import 'package:tv/ui/tv_theme.dart';

/// TvPause (docs/design/couchplay-screens/TvPause.dc.html): a card with the missing player's
/// face, who we wait for, how long is left, and a bar that empties.
Future<void> _pump(WidgetTester t, PauseCard c) {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  return t.pumpWidget(MaterialApp(theme: tvTheme(), home: c));
}

const _ana = PlayerInfo(1, 'Ana', 1, false, 0, character: 'owl');

void main() {
  testWidgets('who we wait for: her face, the title, the seconds left, a bar at that fraction', (t) async {
    await _pump(t, PauseCard(who: _ana, remaining: () => const Duration(seconds: 22)));
    expect(find.text(Strings.waitingForReturn('Ana')), findsOneWidget);
    expect(find.text(Strings.pauseSub(22)), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is CharacterFace && w.id == 'owl' && w.size == 160), findsOneWidget);
    expect(t.getSize(find.byKey(const ValueKey('pause-card'))).width, 1040);
    final track = t.getSize(find.byKey(const ValueKey('pause-track'))).width;
    final fill = t.getSize(find.byKey(const ValueKey('pause-fill'))).width;
    expect(fill / track, closeTo(22 / 30, 0.01));
  });

  testWidgets('the seconds tick down by themselves and the bar empties', (t) async {
    var left = const Duration(seconds: 12);
    await _pump(t, PauseCard(who: _ana, remaining: () => left));
    expect(find.text(Strings.pauseSub(12)), findsOneWidget);
    left = const Duration(seconds: 11);
    await t.pump(const Duration(seconds: 1));
    expect(find.text(Strings.pauseSub(11)), findsOneWidget);
    final fill = t.getSize(find.byKey(const ValueKey('pause-fill'))).width;
    final track = t.getSize(find.byKey(const ValueKey('pause-track'))).width;
    expect(fill / track, closeTo(11 / 30, 0.01));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('everybody away: no face, the group title', (t) async {
    await _pump(t, PauseCard(who: null, remaining: () => const Duration(seconds: 30)));
    expect(find.text(Strings.waitingForPlayers), findsOneWidget);
    expect(find.byType(CharacterFace), findsNothing);
    final fill = t.getSize(find.byKey(const ValueKey('pause-fill'))).width;
    final track = t.getSize(find.byKey(const ValueKey('pause-track'))).width;
    expect(fill, track, reason: 'full at the start');
  });

  testWidgets('no face when the player has no character; time at zero does not break the bar', (t) async {
    await _pump(t, PauseCard(who: const PlayerInfo(2, 'Ben', 2, false, 0), remaining: () => Duration.zero));
    expect(find.text(Strings.waitingForReturn('Ben')), findsOneWidget);
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(const ValueKey('pause-fill'))).width, 0);
  });
}
