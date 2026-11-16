import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _tint = Color(0xFFFF4D6A);

/// The face painted at [px] x [px] on a transparent background (RGBA bytes).
Future<Uint8List> _paint(
  WidgetTester t,
  String id,
  int px, [
  Color color = _tint,
]) async {
  final key = GlobalKey();
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: CharacterFace(id, px.toDouble(), color),
        ),
      ),
    ),
  );
  return (await t.runAsync(() async {
    final img =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    return (await img.toByteData())!.buffer.asUint8List();
  }))!;
}

int _count(Uint8List d, bool Function(int r, int g, int b, int a) f) {
  var n = 0;
  for (var i = 0; i < d.length; i += 4) {
    if (f(d[i], d[i + 1], d[i + 2], d[i + 3])) n++;
  }
  return n;
}

void main() {
  test('every character id has art', () {
    for (final id in characterIds) {
      expect(CharacterFace.hasArt(id), isTrue, reason: id);
    }
    expect(CharacterFace.artIds.length, characterIds.length);
  });

  testWidgets(
    'every face draws, in the player colour with dark features, and no two look the same',
    (t) async {
      {
        final seen = <String, String>{};
        for (final id in characterIds) {
          final d = await _paint(t, id, 96);
          final opaque = _count(d, (r, g, b, a) => a > 200);
          expect(
            opaque,
            inInclusiveRange(96 * 96 * 0.35, 96 * 96 * 0.95),
            reason: '$id fills a sensible part',
          );
          final tint = _count(
            d,
            (r, g, b, a) =>
                a > 200 &&
                (r - 0xFF).abs() < 6 &&
                (g - 0x4D).abs() < 6 &&
                (b - 0x6A).abs() < 6,
          );
          expect(
            tint,
            greaterThan(96 * 96 * 0.12),
            reason: '$id is tinted with the colour',
          );
          final dark = _count(
            d,
            (r, g, b, a) => a > 200 && r < 0x30 && g < 0x30 && b < 0x40,
          );
          expect(dark, greaterThan(40), reason: '$id has dark features (eyes)');
          final key = d.join(',').hashCode.toString();
          expect(
            seen[key],
            isNull,
            reason: '$id looks the same as ${seen[key]}',
          );
          seen[key] = id;
        }
      }
    },
  );

  testWidgets('a face keeps its features at 32 px', (t) async {
    {
      for (final id in characterIds) {
        final d = await _paint(t, id, 32);
        final dark = _count(
          d,
          (r, g, b, a) => a > 200 && r < 0x50 && g < 0x50 && b < 0x60,
        );
        expect(dark, greaterThan(8), reason: '$id eyes survive at 32 px');
      }
    }
  });

  testWidgets(
    'another colour tints it differently; an unknown id is a plain disc',
    (t) async {
      {
        final a = await _paint(t, 'fox', 64);
        final b = await _paint(t, 'fox', 64, const Color(0xFF3DDC84));
        expect(a, isNot(equals(b)));
        expect(CharacterFace.hasArt('dragon'), isFalse);
        final d = await _paint(t, 'dragon', 64);
        expect(
          _count(d, (r, g, b, a) => a > 200 && r < 0x30),
          0,
          reason: 'no features',
        );
      }
    },
  );
}
