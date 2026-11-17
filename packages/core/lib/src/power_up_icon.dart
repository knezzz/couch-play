import 'dart:math';

import 'package:flutter/widgets.dart';

import 'curve_sim.dart';

// The Curve power-up icons (docs/design/couchplay-screens/PuIcons.dc.html, version A, redrawn
// bolder for the board): ink on a disc whose colour says whom it acts on (green you, red everyone
// else, blue everyone). Drawn in code on a 100 x 100 grid with the disc at (50, 50), r 47. One
// drawing for the TV board, the TV's legend and the phone's legend.

class _Icon {
  const _Icon({this.fill, this.line, this.lineW = 8, this.holes = const [], this.holeR = 5.5, this.cut, this.cutW = 6});
  final Path? fill, line;
  final double lineW;
  final List<Offset> holes;
  final double holeR;

  /// Lines drawn in the disc's colour over the ink: a spiral, the gaps between bristles.
  final Path? cut;
  final double cutW;
}

const _green = Color(0xFF3DDC84), _red = Color(0xFFFF4D4D), _blue = Color(0xFF4DA6FF);

// Pickup icons (PuIcons, version A: things), drawn on a 100 x 100 grid with the
// disc at (50, 50) r 47. Built once. Ink on the power-up colour.
Path _poly(List<double> v) {
  final p = Path()..moveTo(v[0], v[1]);
  for (var i = 2; i < v.length; i += 2) {
    p.lineTo(v[i], v[i + 1]);
  }
  return p..close();
}

/// Open strokes: each list is one polyline.
Path _strokes(List<List<double>> lines) {
  final p = Path();
  for (final v in lines) {
    p.moveTo(v[0], v[1]);
    for (var i = 2; i < v.length; i += 2) {
      p.lineTo(v[i], v[i + 1]);
    }
  }
  return p;
}

/// A spiral from the middle out, about two turns, for the snail's shell.
Path _spiral(double cx, double cy) {
  final p = Path()..moveTo(cx, cy);
  for (var i = 1; i <= 40; i++) {
    final a = i * pi / 10; // 2 turns in 40 steps
    final r = 1.6 * a;
    p.lineTo(cx + r * cos(a), cy + r * sin(a));
  }
  return p;
}

// The snail and the lightning serve both the green (you) and the red (others) kinds.
final _Icon _snail = _Icon(
    fill: Path()
      ..addOval(Rect.fromCircle(center: const Offset(44, 40), radius: 25))
      ..addRRect(RRect.fromLTRBR(20, 64, 80, 82, const Radius.circular(9)))
      ..addOval(Rect.fromCircle(center: const Offset(72, 56), radius: 10)),
    line: _strokes([
      [74, 50, 80, 32],
    ]),
    lineW: 7,
    cut: _spiral(44, 40),
    cutW: 6,
);
final _Icon _bolt = _Icon(fill: _poly([60, 10, 26, 56, 47, 56, 38, 90, 74, 42, 53, 42]));

final _Icon _ghost = _Icon(
  fill: Path()
    ..moveTo(26, 84)
    ..lineTo(26, 46)
    ..arcToPoint(const Offset(74, 46), radius: const Radius.circular(24))
    ..lineTo(74, 84)
    ..lineTo(65, 74)
    ..lineTo(57, 84)
    ..lineTo(50, 74)
    ..lineTo(43, 84)
    ..lineTo(35, 74)
    ..close(),
  holes: const [Offset(40, 46), Offset(60, 46)],
);
final _Icon _reverse = _Icon(
  line: _strokes([
    [20, 34, 76, 34], [64, 22, 78, 34, 64, 46],
    [80, 66, 24, 66], [36, 54, 22, 66, 36, 78],
  ]),
  lineW: 8,
);

final Map<PowerUpKind, _Icon> _icons = {
  PowerUpKind.slow: _snail,
  PowerUpKind.slowOthers: _snail,
  PowerUpKind.speed: _bolt,
  PowerUpKind.speedOthers: _bolt,
  // Cheese: a wedge with holes (ink wedge, the holes in the disc's colour).
  PowerUpKind.cheese: _Icon(
    fill: _poly([18, 74, 82, 74, 82, 34, 18, 50]),
    holes: const [Offset(34, 65), Offset(55, 61), Offset(71, 66)],
    holeR: 6.5,
  ),
  // Square turns: a right-angle arrow, along and then straight up.
  PowerUpKind.squareOthers: _Icon(
    line: _strokes([
      [22, 72, 58, 72, 58, 32],
      [45, 44, 58, 30, 71, 44],
    ]),
    lineW: 10,
  ),
  // Ghost: a sheet with a wavy hem; the eyes are holes.
  PowerUpKind.ghost: _ghost,
  // A thin trail beside a thick one: two solid diagonal bars (a rectangle read as a door).
  PowerUpKind.fatOthers: _Icon(
    fill: _poly([22.8, 70.6, 29.2, 73.5, 49.2, 29.5, 42.8, 26.6]),
    line: _strokes([
      [54, 72, 72, 30],
    ]),
    lineW: 20,
  ),
  // Two arrows the opposite way round.
  PowerUpKind.reverseOthers: _reverse,
  // Broom: a long handle and a head whose bristles fan out.
  PowerUpKind.clear: _Icon(
    fill: _poly([40, 52, 62, 52, 76, 82, 26, 82]),
    line: _strokes([
      [51, 52, 69, 18],
    ]),
    lineW: 10,
    cut: _strokes([
      [46, 64, 40, 82],
      [51, 64, 51, 82],
      [56, 64, 62, 82],
    ]),
    cutW: 4,
  ),
  // Out of one edge and in at the other: an arrow runs into the right wall, another
  // starts at the left wall.
  PowerUpKind.wrap: _Icon(
    line: _strokes([
      [18, 34, 18, 66], // left wall
      [82, 34, 82, 66], // right wall
      [24, 50, 44, 50], [34, 40, 44, 50, 34, 60], // the arrow coming in at the left
      [54, 50, 74, 50], [64, 40, 74, 50, 64, 60], // the arrow running out at the right
    ]),
    lineW: 8,
  ),
};

Color _powerUpColor(PowerUpKind k) => switch (k) {
      PowerUpKind.speed || PowerUpKind.slow || PowerUpKind.ghost || PowerUpKind.cheese => _green,
      PowerUpKind.speedOthers ||
      PowerUpKind.slowOthers ||
      PowerUpKind.fatOthers ||
      PowerUpKind.reverseOthers ||
      PowerUpKind.squareOthers =>
        _red,
      PowerUpKind.clear || PowerUpKind.wrap => _blue,
    };


const _ink = Color(0xFF14141E);
final _scratch = Paint();

/// Paints [kind]'s icon (disc and glyph) centred on [c] with radius [r].
void _paint(Canvas canvas, PowerUpKind kind, Offset c, double r) {
  final disc = _powerUpColor(kind), ic = _icons[kind]!;
  canvas
    ..save()
    ..translate(c.dx, c.dy)
    ..scale(r / 47)
    ..translate(-50, -50);
  _scratch
    ..style = PaintingStyle.fill
    ..color = disc;
  canvas.drawCircle(const Offset(50, 50), 47, _scratch);
  _scratch.color = _ink;
  if (ic.fill != null) canvas.drawPath(ic.fill!, _scratch);
  _scratch
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  if (ic.line != null) {
    _scratch.strokeWidth = ic.lineW;
    canvas.drawPath(ic.line!, _scratch);
  }
  if (ic.cut != null) {
    _scratch
      ..color = disc
      ..strokeWidth = ic.cutW;
    canvas.drawPath(ic.cut!, _scratch);
  }
  if (ic.holes.isNotEmpty) {
    _scratch
      ..style = PaintingStyle.fill
      ..color = disc;
    for (final h in ic.holes) {
      canvas.drawCircle(h, ic.holeR, _scratch);
    }
  }
  canvas.restore();
}

/// A power-up's icon at [size] px: for legends and cards. The board draws the same icons with
/// [paintOn].
class PowerUpIcon extends StatelessWidget {
  const PowerUpIcon(this.kind, this.size, {super.key});
  final PowerUpKind kind;
  final double size;

  /// The disc colour of [kind]: green you, red everyone else, blue everyone.
  static Color colorOf(PowerUpKind kind) => _powerUpColor(kind);

  /// Paints the icon straight onto a canvas, centred on [center], radius [radius].
  static void paintOn(Canvas canvas, PowerUpKind kind, Offset center, double radius) => _paint(canvas, kind, center, radius);

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _IconPainter(kind),
        isComplex: false,
      );
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.kind);
  final PowerUpKind kind;

  @override
  void paint(Canvas canvas, Size size) => _paint(canvas, kind, size.center(Offset.zero), size.width / 2);

  @override
  bool shouldRepaint(_IconPainter old) => old.kind != kind;
}
