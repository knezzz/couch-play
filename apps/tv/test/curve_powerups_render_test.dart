import 'dart:typed_data';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/curve/curve_game.dart';

/// A sim whose time-left values are set by hand.
class _Fx extends CurveSim {
  _Fx() : super([0], config: const CurveConfig(countdown: 0, powerUps: false));
  double wrap = 0;
  final fx = <PowerUpKind, double>{};
  @override
  double get wrapLeft => wrap;
  @override
  double effectLeft(int playerId, PowerUpKind kind) =>
      kind == PowerUpKind.wrap ? wrap : fx[kind] ?? 0;
}

// Arena 1600x900 drawn 1:1, so arena units are pixels.
Future<ByteData> _render(_Fx sim) async {
  final game = CurveGame(sim, const [Color(0xFFFF0000)])..onGameResize(Vector2(1600, 900));
  final rec = PictureRecorder();
  game.render(Canvas(rec));
  final img = await rec.endRecording().toImage(1600, 900);
  return (await img.toByteData())!;
}

Color _at(ByteData d, num x, num y) {
  final i = (y.round() * 1600 + x.round()) * 4;
  return Color.fromARGB(d.getUint8(i + 3), d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2));
}

bool _near(Color a, Color b) =>
    (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs() < 0.25;

const _white = Color(0xFFFFFFFF), _green = Color(0xFF3DDC84), _bg = Color(0xFF14141E);

void main() {
  test('border covers the asked part of the perimeter, clockwise from top-left', () {
    final pts = Float32List(16);
    double covered(double f) {
      CurveGame.borderLines(pts, 1600, 900, f);
      var sum = 0.0;
      for (var i = 0; i < 16; i += 4) {
        sum += (pts[i + 2] - pts[i]).abs() + (pts[i + 3] - pts[i + 1]).abs();
      }
      return sum;
    }

    final full = covered(1);
    expect(full, closeTo(2 * (1600 + 900) - 4 * CurveGame.borderWidth, 1));
    expect(covered(0.5), closeTo(2 * (1600 + 900) * 0.5, 1));
    expect(covered(0), 0);
    expect(CurveGame.borderLines(pts, 1600, 900, 0.1), 4); // still on the top edge
  });

  test('effect icons sit beside or behind the head, never ahead, side by side', () {
    for (final heading in [0.0, 1.0, 2.5, -2.0, 4.0]) {
      final ps = [for (var i = 0; i < 3; i++) CurveGame.effectIconPos(800, 450, heading, i, 1600, 900)];
      final dx = Offset.fromDirection(heading).dx, dy = Offset.fromDirection(heading).dy;
      for (final p in ps) {
        expect((p.dx - 800) * dx + (p.dy - 450) * dy, lessThanOrEqualTo(0.001));
      }
      expect((ps[0] - ps[1]).distance, greaterThan(CurveGame.effectIconRadius * 2));
    }
    // Near a wall they stay inside the arena.
    final p = CurveGame.effectIconPos(2, 2, -1.57, 0, 1600, 900);
    expect(p.dx, inInclusiveRange(0, 1600));
    expect(p.dy, inInclusiveRange(0, 900));
  });

  testWidgets('wrap border is drawn white and shrinks with the time left', (tester) async {
    await tester.runAsync(() async {
      final sim = _Fx();
      sim.place(0, 800, 450, 0);
      var d = await _render(sim);
      expect(_near(_at(d, 800, 5), _bg), isTrue, reason: 'no wrap, no border');

      sim.wrap = 1;
      d = await _render(sim);
      expect(_near(_at(d, 800, 5), _white), isTrue);
      expect(_near(_at(d, 1595, 450), _white), isTrue);
      expect(_near(_at(d, 800, 895), _white), isTrue);
      expect(_near(_at(d, 5, 450), _white), isTrue);

      sim.wrap = 0.1; // 500 px of 5000: the top edge up to x = 500
      d = await _render(sim);
      expect(_near(_at(d, 300, 5), _white), isTrue);
      expect(_near(_at(d, 800, 5), _bg), isTrue);
      expect(_near(_at(d, 1595, 450), _bg), isTrue);
    });
  });

  testWidgets('effect icon has a ring that drains and shows two effects side by side', (tester) async {
    await tester.runAsync(() async {
      final sim = _Fx();
      sim.place(0, 800, 450, 0); // heading 0: icons at y = 410, going left
      sim.fx[PowerUpKind.speed] = 1;
      var d = await _render(sim);
      const ring = 18 * 1.35;
      expect(_near(_at(d, 800, 410 - ring), _green), isTrue, reason: 'ring top');
      expect(_near(_at(d, 800 - ring, 410), _green), isTrue, reason: 'ring left, full');

      sim.fx[PowerUpKind.speed] = 0.5; // right half left
      d = await _render(sim);
      expect(_near(_at(d, 800 + ring, 410), _green), isTrue, reason: 'right half stays');
      expect(_near(_at(d, 800 - ring, 410), _bg), isTrue, reason: 'left half drained');

      sim.fx[PowerUpKind.thin] = 1; // second icon, one step further back
      d = await _render(sim);
      expect(_near(_at(d, 750, 410 - ring), _green), isTrue);
      expect(_near(_at(d, 800, 410 - ring), _green), isTrue);

      sim.fx
        ..clear()
        ..[PowerUpKind.fatOthers] = 1;
      d = await _render(sim);
      expect(_near(_at(d, 800, 410 - ring), const Color(0xFFFF4D4D)), isTrue, reason: 'red = others');
    });
  });
}
