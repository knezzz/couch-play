import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/back_guard.dart';
import 'package:tv/ui/tv_theme.dart';

/// Task 45: Back during a game also offers "Ukloni igrača", so a stuck night can move on.
final _people = [
  for (var i = 1; i <= 8; i++) PlayerInfo(i, 'Ime$i', i - 1, i != 3, 0, character: characterIds[i - 1]),
];

Future<List<int>> _pump(WidgetTester t, {Size size = const Size(1920, 1080), bool kickable = true, List<int>? ended}) async {
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final kicked = <int>[];
  final nav = GlobalKey<NavigatorState>();
  await t.pumpWidget(MaterialApp(
    theme: tvTheme(),
    navigatorKey: nav,
    builder: (_, child) => BackGuard(
      navigatorKey: nav,
      active: () => true,
      changes: ValueNotifier(0),
      onEnd: () => ended?.add(1),
      players: kickable ? () => _people : null,
      onKick: kickable ? kicked.add : null,
      child: child!,
    ),
    home: const Scaffold(body: Center(child: Text('game'))),
  ));
  return kicked;
}

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('Back offers Ukloni igrača; it opens the list, Back closes the list and then the menu', (t) async {
    await _pump(t);
    await _back(t);
    expect(find.text(Strings.endGameTitle), findsOneWidget);
    await t.tap(find.text(Strings.kickPlayer));
    await t.pump(const Duration(milliseconds: 400));
    for (var i = 1; i <= 8; i++) {
      expect(find.textContaining('Ime$i'), findsOneWidget);
    }
    await _back(t);
    expect(find.text(Strings.kickPlayer), findsNothing, reason: 'the list is closed');
    expect(find.text('game'), findsOneWidget);
  });

  testWidgets('with the remote: pick a player, confirm, and the kick is sent', (t) async {
    final kicked = await _pump(t);
    await _back(t);
    await t.tap(find.text(Strings.kickPlayer));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.textContaining('Ime2'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text(Strings.kickConfirm('Ime2')), findsOneWidget);
    expect(kicked, isEmpty, reason: 'not before the confirmation');
    await t.tap(find.text(Strings.yes));
    await t.pump(const Duration(milliseconds: 400));
    expect(kicked, [2]);
  });

  testWidgets('the remote keys alone reach the list and the first player is focused; No at the confirmation kicks nobody', (t) async {
    final kicked = await _pump(t);
    await _back(t);
    await _key(t, LogicalKeyboardKey.arrowRight); // from No to the next button
    await _key(t, LogicalKeyboardKey.arrowRight);
    await _key(t, LogicalKeyboardKey.select);
    expect(find.textContaining('Ime1'), findsOneWidget, reason: 'the list is open');
    await _key(t, LogicalKeyboardKey.select); // the first player
    expect(find.text(Strings.kickConfirm('Ime1')), findsOneWidget);
    await _key(t, LogicalKeyboardKey.select); // No is focused first
    expect(kicked, isEmpty);
  });

  testWidgets('the list shows only names and who has no connection: nothing about roles or who is done', (t) async {
    await _pump(t);
    await _back(t);
    await t.tap(find.text(Strings.kickPlayer));
    await t.pump(const Duration(milliseconds: 400));
    final texts = [for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? w.textSpan?.toPlainText() ?? ''];
    expect(texts.where((s) => s.contains(Strings.kickOffline)), hasLength(1), reason: 'only player 3 has no connection');
    expect(texts.any((s) => s.contains('Ime3') && s.contains(Strings.kickOffline)), isTrue);
    for (final s in texts) {
      expect(s.toLowerCase(), isNot(contains('gotov')));
      expect(s.toLowerCase(), isNot(contains('uloga')));
    }
  });

  testWidgets('without a kick handler (e.g. the old tests) Back only offers to end the game', (t) async {
    await _pump(t, kickable: false);
    await _back(t);
    expect(find.text(Strings.endGameTitle), findsOneWidget);
    expect(find.text(Strings.kickPlayer), findsNothing);
  });

  testWidgets('Yes still ends the game', (t) async {
    final ended = <int>[];
    await _pump(t, ended: ended);
    await _back(t);
    await t.tap(find.text(Strings.yes));
    await t.pump(const Duration(milliseconds: 400));
    expect(ended, [1]);
  });

  for (final size in const [Size(1272, 715), Size(960, 540)]) {
    testWidgets('8 players fit at ${size.width.toInt()}x${size.height.toInt()}', (t) async {
      await _pump(t, size: size);
      await _back(t);
      expect(t.takeException(), isNull);
      await t.tap(find.text(Strings.kickPlayer));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
      expect(find.textContaining('Ime8'), findsOneWidget);
      // The list scrolls inside the dialog, so at 540 px high the last name may be below the fold.
      if (size.height >= 715) expect(t.getRect(find.textContaining('Ime8')).bottom, lessThanOrEqualTo(size.height));
    });
  }
}
