import 'dart:ui';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/curve/curve_game.dart';

const _red = Color(0xFFFF0000);

/// Pixels just left of a one-letter name (test font: 44 px wide) that are the player colour, with the
/// 2 s countdown still running (names are shown). Head at (800,450) heading right.
Future<int> _redNearLabelStart(Map<int, String> characters) async {
  final sim = CurveSim([0, 1], names: const {0: 'A', 1: 'B'});
  sim.place(0, 800, 450, 0);
  sim.place(1, 100, 100, 0);
  final game = CurveGame(sim, const [_red, Color(0xFF00FF00)], characters: characters)
    ..onGameResize(Vector2(1600, 900));
  expect(sim.countingDown, isTrue);
  final rec = PictureRecorder();
  game.render(Canvas(rec));
  final d = (await (await rec.endRecording().toImage(1600, 900)).toByteData())!;
  var n = 0;
  for (var y = 386; y < 440; y++) {
    for (var x = 745; x < 775; x++) {
      final i = (y * 1600 + x) * 4;
      if (d.getUint8(i) > 200 && d.getUint8(i + 1) < 60 && d.getUint8(i + 2) < 60) n++;
    }
  }
  return n;
}

void main() {
  testWidgets('the countdown name label carries the player\'s character', (t) async {
    await t.runAsync(() async {
      expect(await _redNearLabelStart(const {}), 0, reason: 'a name only');
      expect(await _redNearLabelStart(const {0: 'fox'}), greaterThan(200), reason: 'the face, left of the name');
      expect(await _redNearLabelStart(const {1: 'owl'}), 0, reason: 'someone else\'s character');
    });
  });
}
