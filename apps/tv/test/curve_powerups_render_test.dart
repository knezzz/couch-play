import 'dart:math';
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
  int stacks = 0;
  List<TrailSegment> segs = [];
  @override
  double get wrapLeft => wrap;
  @override
  double effectLeft(int playerId, PowerUpKind kind) =>
      kind == PowerUpKind.wrap ? wrap : fx[kind] ?? 0;
  @override
  int effectStacks(int playerId, PowerUpKind kind) => kind == PowerUpKind.fatOthers ? stacks : 0;
  @override
  List<TrailSegment> takeNewSegments() {
    if (segs.isEmpty) return super.takeNewSegments();
    final out = segs;
    segs = [];
    return out;
  }
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

  // Effects are rings centred on the head: the shortest-lived innermost.
  const red = Color(0xFFFF4D4D), r0 = CurveGame.ringBase, r1 = CurveGame.ringBase + CurveGame.ringStep;

  testWidgets('an active effect is a ring centred on the head, with no icon beside it', (tester) async {
    await tester.runAsync(() async {
      final sim = _Fx();
      sim.place(0, 800, 450, 0);
      sim.fx[PowerUpKind.slow] = 1;
      final d = await _render(sim);
      expect(_near(_at(d, 800, 450 - r0), _green), isTrue, reason: 'ring top');
      expect(_near(_at(d, 800 + r0, 450), _green), isTrue, reason: 'ring right');
      expect(_near(_at(d, 800, 450 + r0), _green), isTrue, reason: 'ring bottom');
      expect(_near(_at(d, 800 - r0, 450), _green), isTrue, reason: 'ring left');
      expect(_near(_at(d, 800, 450), _white), isTrue, reason: 'the head, in the middle');
      // Where the old icon sat (40 beside the line) there is nothing but background.
      for (final p in [const Offset(800, 410), const Offset(800, 490), const Offset(750, 410)]) {
        expect(_near(_at(d, p.dx, p.dy), _bg), isTrue, reason: 'nothing at $p');
      }
    });
  });

  testWidgets('the ring drains clockwise from the top as the time runs out', (tester) async {
    await tester.runAsync(() async {
      final sim = _Fx();
      sim.place(0, 800, 450, 0);
      sim.fx[PowerUpKind.slow] = 0.5; // top and right half stay
      var d = await _render(sim);
      expect(_near(_at(d, 800 + r0, 450), _green), isTrue, reason: 'right half stays');
      expect(_near(_at(d, 800 - r0, 450), _green), isFalse, reason: 'left half drained');
      sim.fx[PowerUpKind.slow] = 0.1; // only a little past the top
      d = await _render(sim);
      expect(_near(_at(d, 800, 450 - r0), _green), isTrue);
      expect(_near(_at(d, 800 + r0, 450), _green), isFalse);
    });
  });

  testWidgets('several effects are concentric: the one with the most time left is outermost', (tester) async {
    await tester.runAsync(() async {
      final sim = _Fx();
      sim.place(0, 800, 450, 0);
      sim.fx
        ..[PowerUpKind.slow] = 0.9 // green, long
        ..[PowerUpKind.speedOthers] = 0.3; // red, short
      var d = await _render(sim);
      expect(_near(_at(d, 800, 450 - r0), red), isTrue, reason: 'short-lived red inside');
      expect(_near(_at(d, 800, 450 - r1), _green), isTrue, reason: 'long-lived green outside');
      sim.fx
        ..[PowerUpKind.slow] = 0.3
        ..[PowerUpKind.speedOthers] = 0.9;
      d = await _render(sim);
      expect(_near(_at(d, 800, 450 - r0), _green), isTrue, reason: 'now green is the short one');
      expect(_near(_at(d, 800, 450 - r1), red), isTrue);
    });
  });

  testWidgets('green rings are on you, red are from others, in the power-up colours', (tester) async {
    await tester.runAsync(() async {
      for (final (kind, color) in [
        (PowerUpKind.slow, _green),
        (PowerUpKind.ghost, _green),
        (PowerUpKind.speedOthers, red),
        (PowerUpKind.fatOthers, red),
        (PowerUpKind.reverseOthers, red),
      ]) {
        final sim = _Fx();
        sim.place(0, 800, 450, 0);
        sim.fx[kind] = 1;
        final d = await _render(sim);
        expect(_near(_at(d, 800, 450 - r0), color), isTrue, reason: '$kind');
      }
    });
  });

  testWidgets('fat shows one white dot per stack on its ring', (tester) async {
    await tester.runAsync(() async {
      final sim = _Fx();
      sim.place(0, 800, 450, 0);
      sim.fx[PowerUpKind.fatOthers] = 0.2; // the bottom of the ring has drained
      for (final n in [0, 1, 2, 3]) {
        sim.stacks = n;
        final d = await _render(sim);
        final dots = [
          for (var i = 0; i < n; i++)
            Offset.fromDirection(pi / 2 + (i - (n - 1) / 2) * CurveGame.stackStep, r0) + const Offset(800, 450),
        ];
        for (final p in dots) {
          expect(_near(_at(d, p.dx, p.dy), _white), isTrue, reason: '$n stacks: dot at $p');
        }
        // Walk the bottom of the ring: as many separate white runs as stacks.
        var runs = 0, inRun = false;
        for (var a = pi / 2 - 0.9; a <= pi / 2 + 0.9; a += 0.02) {
          final p = Offset.fromDirection(a, r0) + const Offset(800, 450);
          final white = _near(_at(d, p.dx, p.dy), _white);
          if (white && !inRun) runs++;
          inRun = white;
        }
        expect(runs, n, reason: '$n stacks');
      }
    });
  });

  testWidgets('the seven pickup icons are drawn on the power-up colour disc, each its own picture', (tester) async {
    await tester.runAsync(() async {
      final pics = <PowerUpKind, List<bool>>{};
      for (final kind in PowerUpKind.values) {
        final sim = _Fx();
        sim.place(0, 100, 100, 0); // out of the way
        sim.placePowerUp(kind, 800, 450);
        final d = await _render(sim);
        final disc = switch (kind) {
          PowerUpKind.slow || PowerUpKind.ghost => _green,
          PowerUpKind.speedOthers || PowerUpKind.fatOthers || PowerUpKind.reverseOthers => red,
          _ => const Color(0xFF4DA6FF),
        };
        expect(_near(_at(d, 800, 430), disc), isTrue, reason: '$kind disc');
        // The glyph's shape only (ink or not), so a disc colour cannot tell two icons apart.
        pics[kind] = [
          for (var y = 426; y < 474; y += 2)
            for (var x = 776; x < 824; x += 2) _near(_at(d, x, y), _bg),
        ];
        expect(pics[kind]!.where((ink) => ink).length, greaterThan(40), reason: '$kind has a drawn glyph');
      }
      for (final a in PowerUpKind.values) {
        for (final b in PowerUpKind.values) {
          if (a.index >= b.index) continue;
          var diff = 0;
          for (var i = 0; i < pics[a]!.length; i++) {
            if (pics[a]![i] != pics[b]![i]) diff++;
          }
          expect(diff, greaterThan(30), reason: '$a and $b look alike');
        }
      }
    });
  });

  testWidgets('a trail is as wide as the stacks it was painted with (x1 to x4)', (tester) async {
    await tester.runAsync(() async {
      for (final mult in [1, 2, 3, 4]) {
        final sim = _Fx()..place(0, 1500, 800, 0);
        sim.segs = [TrailSegment(0, 100, 100, 300, 100, 6.0 * mult)];
        final game = CurveGame(sim, const [Color(0xFFFF0000)])..onGameResize(Vector2(1600, 900));
        game.update(1 / 60);
        final rec = PictureRecorder();
        game.render(Canvas(rec));
        final d = (await (await rec.endRecording().toImage(1600, 900)).toByteData())!;
        final half = 3.0 * mult;
        expect(_near(_at(d, 200, 100 + half - 1), const Color(0xFFFF0000)), isTrue, reason: 'x$mult inside');
        expect(_near(_at(d, 200, 100 + half + 2), _bg), isTrue, reason: 'x$mult outside');
      }
    });
  });

  testWidgets('a trail next to the wall stays visible while wrap runs', (tester) async {
    await tester.runAsync(() async {
      final sim = _Fx()..wrap = 1;
      sim.place(0, 4, 800, -1.5708); // up the left wall, 4 units in
      final game = CurveGame(sim, const [Color(0xFFFF0000)])..onGameResize(Vector2(1600, 900));
      sim.fx.clear();
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
      }
      final rec = PictureRecorder();
      game.render(Canvas(rec));
      final d = (await (await rec.endRecording().toImage(1600, 900)).toByteData())!;
      // The head moved up from y=800; the trail is on x=4, inside the 10-wide border.
      expect(_near(_at(d, 4, 780), const Color(0xFFFF0000)), isTrue);
      expect(_near(_at(d, 800, 5), _white), isTrue, reason: 'border still drawn elsewhere');
    });
  });
}
