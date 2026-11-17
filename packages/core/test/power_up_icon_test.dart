import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one drawing of the power-up icons, for the TV board and the TV and phone legends.
const _green = Color(0xFF3DDC84), _red = Color(0xFFFF4D4D), _blue = Color(0xFF4DA6FF);

Future<ByteData> _pic(WidgetTester t, PowerUpKind k, double size) async {
  final key = GlobalKey();
  await t.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: RepaintBoundary(key: key, child: PowerUpIcon(k, size))),
  ));
  return (await t.runAsync(() async {
    final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    return (await img.toByteData())!;
  }))!;
}

Color _at(ByteData d, int w, int x, int y) {
  final i = (y * w + x) * 4;
  return Color.fromARGB(d.getUint8(i + 3), d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2));
}

bool _near(Color a, Color b) => (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs() < 0.05;

void main() {
  test('the disc colour says whom it acts on: green you, red the others, blue everyone', () {
    for (final k in PowerUpKind.values) {
      final want = switch (powerUpActsOn(k)) { PowerUpTarget.you => _green, PowerUpTarget.others => _red, PowerUpTarget.all => _blue };
      expect(PowerUpIcon.colorOf(k), want, reason: '$k');
    }
  });

  testWidgets('every kind draws a disc of its colour with a glyph in ink, at a size', (t) async {
    for (final k in PowerUpKind.values) {
      final d = await _pic(t, k, 100);
      expect(_near(_at(d, 100, 50, 6), PowerUpIcon.colorOf(k)), isTrue, reason: '$k: the disc near its top');
      expect(_near(_at(d, 100, 1, 1), const Color(0x00000000)) || _at(d, 100, 1, 1).a == 0, isTrue, reason: 'nothing outside the disc');
      var ink = 0;
      for (var y = 20; y < 80; y += 2) {
        for (var x = 20; x < 80; x += 2) {
          if (_near(_at(d, 100, x, y), const Color(0xFF14141E))) ink++;
        }
      }
      expect(ink, greaterThan(40), reason: '$k has a drawn glyph');
    }
  });

  testWidgets('the widget is as big as asked', (t) async {
    await t.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: Center(child: PowerUpIcon(PowerUpKind.cheese, 58))));
    expect(t.getSize(find.byType(PowerUpIcon)), const Size(58, 58));
  });

  testWidgets('paintOn draws the same picture the widget does', (t) async {
    final rec = ui.PictureRecorder();
    PowerUpIcon.paintOn(Canvas(rec), PowerUpKind.slow, const Offset(50, 50), 50);
    final img = await t.runAsync(() => rec.endRecording().toImage(100, 100));
    final board = (await t.runAsync(() => img!.toByteData()))!;
    final widget = await _pic(t, PowerUpKind.slow, 100);
    var diff = 0;
    for (var i = 0; i < board.lengthInBytes; i += 4) {
      if (!_near(Color.fromARGB(board.getUint8(i + 3), board.getUint8(i), board.getUint8(i + 1), board.getUint8(i + 2)),
          Color.fromARGB(widget.getUint8(i + 3), widget.getUint8(i), widget.getUint8(i + 1), widget.getUint8(i + 2)))) {
        diff++;
      }
    }
    expect(diff, lessThan(40), reason: 'the same icon (a few edge pixels may differ)');
  });
}
