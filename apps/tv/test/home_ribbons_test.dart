import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/home_screen.dart';

/// Curve's rule: a line that crosses or touches another dies. The art for Curve on the
/// home must obey it: no two ribbons touch or cross (and none crosses itself).
List<Offset> _samples(Path p, {double step = 6}) {
  final out = <Offset>[];
  for (final m in p.computeMetrics()) {
    for (var d = 0.0; d <= m.length; d += step) {
      out.add(m.getTangentForOffset(d)!.position);
    }
  }
  return out;
}

double _minDistance(List<Offset> a, List<Offset> b) {
  var best = double.infinity;
  for (final p in a) {
    for (final q in b) {
      final d = (p - q).distance;
      if (d < best) best = d;
    }
  }
  return best;
}

/// The smallest distance between two points of one ribbon that are far apart along it
/// (a ribbon folding back on itself would touch).
double _selfTouch(Path p, {double apart = 200, double step = 6}) {
  var best = double.infinity;
  final pts = _samples(p, step: step);
  final skip = (apart / step).ceil();
  for (var i = 0; i < pts.length; i++) {
    for (var j = i + skip; j < pts.length; j++) {
      final d = (pts[i] - pts[j]).distance;
      if (d < best) best = d;
    }
  }
  return best;
}

void main() {
  test('the checker catches ribbons that cross (the old home art did)', () {
    // The ribbons of the first home art (6e6d673 and before): red and green cross.
    final red = Path()
      ..moveTo(-40, 900)
      ..cubicTo(300, 300, 640, 1000, 980, 420)
      ..cubicTo(1320, -160, 1600, 80, 1980, 520);
    final green = Path()
      ..moveTo(-40, 160)
      ..cubicTo(420, 520, 820, 40, 1300, 300)
      ..cubicTo(1780, 560, 1800, 820, 1980, 700);
    expect(_minDistance(_samples(red), _samples(green)), lessThan(44), reason: 'they cross or touch: the checker must see it');
  });

  test('no two ribbons of the Curve art touch or cross: their centre lines stay a stroke and a gap apart', () {
    final ribbons = homeCurveRibbons;
    expect(ribbons.length, greaterThanOrEqualTo(3));
    for (var i = 0; i < ribbons.length; i++) {
      for (var j = i + 1; j < ribbons.length; j++) {
        final gap = ribbons[i].width / 2 + ribbons[j].width / 2 + 8; // strokes plus air
        final d = _minDistance(_samples(ribbons[i].path), _samples(ribbons[j].path));
        expect(d, greaterThanOrEqualTo(gap), reason: 'ribbon $i and $j come within ${d.toStringAsFixed(0)} px (need $gap)');
      }
    }
  });

  test('no ribbon crosses or touches itself', () {
    for (final (i, r) in homeCurveRibbons.indexed) {
      expect(_selfTouch(r.path), greaterThan(r.width + 8), reason: 'ribbon $i folds onto itself');
    }
  });

  test('the ribbons are the canvas\' (V2Home 031034e): green, red, blue, and a dashed amber one', () {
    final colors = homeCurveRibbons.map((r) => r.color.toARGB32() & 0xFFFFFF).toList();
    expect(colors, [0x2ECC71, 0xFF4D6D, 0x22B8F0, 0xFFB020]);
    expect(homeCurveRibbons.last.dashed, isTrue);
    expect(homeCurveRibbons.every((r) => r.width == 44), isTrue);
    // Every ribbon is on screen at least in part.
    for (final r in homeCurveRibbons) {
      final b = r.path.getBounds();
      expect(b.overlaps(const Rect.fromLTWH(0, 0, 1920, 1080)), isTrue);
    }
    expect(sqrt(1), 1); // keep dart:math used
  });
}
