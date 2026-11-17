import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/tv_theme.dart';
import 'package:tv/ui/wolf/village_screen.dart';

final _key = GlobalKey();

List<VillagePlayer> _people(int n, {Set<int> out = const {}, Set<int> lit = const {}}) => [
      for (var i = 0; i < n; i++)
        VillagePlayer(
          id: i + 1,
          name: 'Ime${i + 1}',
          colorIndex: i,
          character: characterIds[i],
          out: out.contains(i + 1),
          lit: lit.contains(i + 1),
        ),
    ];

Future<void> _pump(
  WidgetTester t,
  List<VillagePlayer> players, {
  bool night = false,
  String kicker = 'JUTRO 3',
  String story = 'Priča sela.',
  String clock = '1:40',
  bool reduceMotion = false,
}) async {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  t.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await t.pumpWidget(RepaintBoundary(
    key: _key,
    child: MaterialApp(
      theme: tvTheme(),
      home: VillageScreen(players: players, night: night, kicker: kicker, story: story, clock: clock),
    ),
  ));
  await t.pump();
}

Future<ByteData> _pixels(WidgetTester t) async => (await t.runAsync(() async {
      final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage();
      return (await img.toByteData())!;
    }))!;

Color _at(ByteData d, num x, num y) {
  final i = (y.round() * 1920 + x.round()) * 4;
  return Color.fromARGB(d.getUint8(i + 3), d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2));
}

bool _is(Color a, int rgb) {
  final b = Color(0xFF000000 | rgb);
  return (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs() < 0.06;
}

Finder _face(String id) => find.byWidgetPredicate((w) => w is CharacterFace && w.id == id);

void main() {
  for (final n in [5, 6, 7, 8]) {
    testWidgets('$n players: a house for each, with the character and the name, nothing overflows', (t) async {
      await _pump(t, _people(n));
      expect(t.takeException(), isNull);
      for (var i = 0; i < n; i++) {
        expect(find.byKey(ValueKey('house-${i + 1}')), findsOneWidget, reason: 'house ${i + 1}');
        expect(find.text('Ime${i + 1}'), findsOneWidget);
        expect(_face(characterIds[i]), findsOneWidget);
        final r = t.getRect(find.byKey(ValueKey('house-${i + 1}')));
        expect(r.left, greaterThanOrEqualTo(0), reason: 'house ${i + 1} label on screen');
        expect(r.right, lessThanOrEqualTo(1920));
        expect(r.top, greaterThanOrEqualTo(0));
        expect(r.bottom, lessThanOrEqualTo(1080));
      }
    });
  }

  test('the houses are spread round the square: the first at the top, evenly after, none on the square', () {
    for (final n in [5, 8]) {
      final spots = villageSpots(n);
      expect(spots, hasLength(n));
      expect(spots.first.dx, closeTo(960, 1));
      expect(spots.first.dy, lessThan(590));
      for (final s in spots) {
        expect(((s.dx - 960) / 560) * ((s.dx - 960) / 560) + ((s.dy - 590) / 330) * ((s.dy - 590) / 330), closeTo(1, 0.01));
      }
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          expect((spots[i] - spots[j]).distance, greaterThan(200), reason: 'houses $i and $j');
        }
      }
    }
  });

  testWidgets('an out player: name struck through and greyed; the others are not', (t) async {
    await _pump(t, _people(5, out: {3}));
    TextStyle style(int id) => t.widget<Text>(find.text('Ime$id')).style!;
    expect(style(3).decoration, TextDecoration.lineThrough);
    expect(style(2).decoration, isNot(TextDecoration.lineThrough));
    expect(t.widget<Opacity>(find.descendant(of: find.byKey(const ValueKey('house-3')), matching: find.byType(Opacity)).first).opacity, lessThan(1));
  });

  testWidgets('an out player\'s house is closed up: grey wall, blood round it', (t) async {
    await _pump(t, _people(5, out: {1}));
    final d = await _pixels(t);
    final spots = villageSpots(5);
    final out = spots[0], alive = spots[1];
    expect(_is(_at(d, out.dx - 62, out.dy + 50), 0x55505A), isTrue, reason: 'grey wall of the closed house');
    expect(_is(_at(d, alive.dx - 62, alive.dy + 50), 0xF5ECDA), isTrue, reason: 'daylight wall of the open one');
    expect(_is(_at(d, out.dx - 34, out.dy + 104), 0x9E1B1B), isTrue, reason: 'blood on the ground');
    expect(_is(_at(d, alive.dx - 34, alive.dy + 104), 0x9E1B1B), isFalse, reason: 'no blood at an open house');
  });

  testWidgets('night is dark with a moon, day is light with a sun', (t) async {
    await _pump(t, _people(5), night: true, kicker: 'NOĆ 2');
    var d = await _pixels(t);
    expect(_at(d, 100, 40).computeLuminance(), lessThan(0.05), reason: 'night sky');
    expect(_is(_at(d, 1700, 150), 0xF2E9C9), isTrue, reason: 'moon');
    await _pump(t, _people(5), night: false);
    d = await _pixels(t);
    expect(_at(d, 100, 40).computeLuminance(), greaterThan(0.4), reason: 'day sky');
    expect(_is(_at(d, 260, 150), 0xFFE7A3), isTrue, reason: 'sun');
  });

  testWidgets('at night only the lit houses have a lit window; out houses never', (t) async {
    await _pump(t, _people(5, out: {4}, lit: {1, 3}), night: true);
    final d = await _pixels(t);
    final s = villageSpots(5);
    bool lit(int i) => _is(_at(d, s[i].dx - 52, s[i].dy + 14), 0xF7D774);
    expect(lit(0), isTrue, reason: 'player 1 lit');
    expect(lit(2), isTrue, reason: 'player 3 lit');
    expect(lit(1), isFalse, reason: 'player 2 is done: dark window');
    expect(lit(3), isFalse, reason: 'player 4 is out: dark window');
    expect(_is(_at(d, s[1].dx - 52, s[1].dy + 14), 0x1A1E34), isTrue);
  });

  testWidgets('by day no window is lit', (t) async {
    await _pump(t, _people(5, lit: {1, 2}), night: false);
    final d = await _pixels(t);
    final s = villageSpots(5);
    expect(_is(_at(d, s[0].dx - 52, s[0].dy + 14), 0xF7D774), isFalse);
    expect(_is(_at(d, s[0].dx - 52, s[0].dy + 14), 0xA9D4F0), isTrue, reason: 'day window glass');
  });

  testWidgets('the kicker, the story and the clock are in the square', (t) async {
    await _pump(t, _people(5), kicker: 'JUTRO 3', story: 'Gavran sjeda na krov.', clock: '1:40');
    expect(find.text('JUTRO 3'), findsOneWidget);
    expect(find.text('Gavran sjeda na krov.'), findsOneWidget);
    expect(find.text('1:40'), findsOneWidget);
    final story = t.getRect(find.text('Gavran sjeda na krov.'));
    expect(story.center.dx, closeTo(960, 40));
    expect(story.top, greaterThan(500));
    expect(story.bottom, lessThan(850));
  });

  testWidgets('light animation, off with reduced motion', (t) async {
    await _pump(t, _people(5), night: true);
    await t.pump(const Duration(milliseconds: 100));
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await _pump(t, _people(5), night: true, reduceMotion: true);
    await t.pump(const Duration(milliseconds: 100));
    expect(t.binding.transientCallbackCount, 0);
  });

  testWidgets('a long story stays inside the square (scaled, not cut or overflowing)', (t) async {
    await _pump(t, _people(8), story: 'Jutro je. Seljani nalaze zatvorena vrata: Ime1 više nije s nama. ' * 4);
    expect(t.takeException(), isNull);
    expect(t.getRect(find.textContaining('Jutro je.')).bottom, lessThan(870));
  });
}
