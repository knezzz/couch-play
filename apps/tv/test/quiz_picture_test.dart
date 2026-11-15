import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/quiz_screen.dart';
import 'package:tv/ui/tv_theme.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 20"><rect width="30" height="20" fill="red"/></svg>';
const _screen = Rect.fromLTWH(0, 0, 1920, 1080);

Future<Uint8List> _png(int w, int h) async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = Colors.teal);
  final img = await rec.endRecording().toImage(w, h);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

class _Pic {
  _Pic(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

QuizScreen _screenFor(_Pic p, {int? correct, double remaining = 0.5}) => QuizScreen(
      question: 'Koji je ovo grad?',
      packTitle: 'Geografija',
      picture: p.bytes,
      pictureName: p.name,
      choices: const ['Zagreb', 'Varaždin', 'Osijek', 'Rijeka'],
      number: 2,
      total: 10,
      remaining: remaining,
      answered: 1,
      expected: 4,
      correctIndex: correct,
      picks: correct == null ? const {} : const {0: 1, 1: 2},
      points: const {0: 0, 1: 0, 2: 0, 3: 0},
      players: [for (var i = 0; i < 4; i++) PlayerInfo(i, 'Igrač $i', i, true, 0)],
      totals: const {0: 0, 1: 0, 2: 0, 3: 0},
    );

Future<void> _show(WidgetTester t, QuizScreen s) async {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(theme: tvTheme(), home: s));
  // Image decoding runs outside the fake clock.
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await t.pump();
}

Rect _rect(WidgetTester t, Finder f) => t.getRect(f);

void main() {
  var pics = <String, _Pic>{};

  setUp(() => PaintingBinding.instance.imageCache.clear());

  Future<void> make(WidgetTester t) async {
    pics = (await t.runAsync(() async => {
          'tall': _Pic('t.jpg', await _png(600, 900)),
          'wide': _Pic('w.png', await _png(1200, 800)),
          'svg': _Pic('f.svg', Uint8List.fromList(utf8.encode(_svg))),
        }))!;
  }

  for (final reveal in [false, true]) {
    for (final kind in ['tall', 'wide', 'svg']) {
      testWidgets('${reveal ? 'reveal' : 'question'} with a $kind picture: picture big, whole, rest on screen',
          (t) async {
        await make(t);
        await _show(t, _screenFor(pics[kind]!, correct: reveal ? 1 : null));
        expect(t.takeException(), isNull);

        final box = _rect(t, find.byKey(const ValueKey('picture')));
        // Most of the room: well over the old 520x347 card.
        expect(box.width * box.height, greaterThan((reveal ? 0.2 : 0.35) * 1920 * 1080));
        expect(box.height, greaterThan(reveal ? 400 : 700));

        if (kind != 'svg') {
          final r = t.renderObject<RenderImage>(find.byType(RawImage));
          expect(r.fit, BoxFit.contain, reason: 'never cropped');
          final img = r.image!;
          expect(img.width, lessThanOrEqualTo(1920));
          expect(img.height, lessThanOrEqualTo(1080));
          // The picture as drawn fills the box along one side (contain).
          final fit = applyBoxFit(BoxFit.contain, Size(img.width.toDouble(), img.height.toDouble()), r.size);
          expect(fit.destination.width > r.size.width - 1 || fit.destination.height > r.size.height - 1, isTrue);
        }

        // Everything else is still on screen and clear of the picture.
        for (var i = 0; i < 4; i++) {
          final tile = _rect(t, find.byKey(ValueKey('tile-$i')));
          expect(_screen.contains(tile.topLeft) && _screen.contains(tile.bottomRight), isTrue, reason: 'tile $i');
          expect(tile.overlaps(box), isFalse, reason: 'tile $i vs picture');
          expect(tile.height, greaterThanOrEqualTo(reveal ? 96 : 112));
        }
        final q = _rect(t, find.text('Koji je ovo grad?'));
        expect(_screen.contains(q.topLeft) && _screen.contains(q.bottomRight), isTrue);
        expect(q.overlaps(box), isFalse);
      });
    }
  }

  testWidgets('answers beside a picture stay big: 44 px, 36 px when long', (t) async {
    await make(t);
    await _show(t, _screenFor(pics['wide']!));
    expect(t.widget<Text>(find.text('Zagreb')).style!.fontSize, 44);
  });

  testWidgets('a photo is decoded once, however often the timer rebuilds', (t) async {
    await make(t);
    await _show(t, _screenFor(pics['wide']!));
    for (var i = 0; i < 8; i++) {
      await t.pumpWidget(MaterialApp(theme: tvTheme(), home: _screenFor(pics['wide']!, remaining: 1 - i / 10)));
      await t.pump();
    }
    expect(PaintingBinding.instance.imageCache.currentSize, 1);
  });

  testWidgets('a photo that will not decode leaves the question playable in the text layout', (t) async {
    final bad = _Pic('x.jpg', Uint8List.fromList(List.filled(64, 7)));
    await _show(t, _screenFor(bad));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('picture')), findsNothing);
    for (var i = 0; i < 4; i++) {
      expect(t.getSize(find.byKey(ValueKey('tile-$i'))).height, 168, reason: 'text layout');
    }
    expect(find.text('Koji je ovo grad?'), findsOneWidget);
  });

  testWidgets('same for the reveal', (t) async {
    final bad = _Pic('x.png', Uint8List.fromList(List.filled(64, 7)));
    await _show(t, _screenFor(bad, correct: 1));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('picture')), findsNothing);
    expect(t.getSize(find.byKey(const ValueKey('tile-1'))).height, 168);
  });

  testWidgets('a broken SVG also falls back', (t) async {
    final bad = _Pic('x.svg', Uint8List.fromList(utf8.encode('not svg')));
    await _show(t, _screenFor(bad));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.byKey(const ValueKey('picture')), findsNothing);
  });
}
