import 'dart:ui' show Canvas, Size;

import 'package:flutter/widgets.dart';

/// A player's animal, drawn (like [ShapeMark]) rather than typed or loaded: it
/// needs no font, asset or SVG package, so the TV and the phone's web build both
/// draw it the same. Bold flat shapes on a 100 x 100 grid, in [color] with dark
/// features, so it reads at 32 px. [id] is one of the character ids (fox, owl,
/// ...); an unknown id draws a plain disc.
class CharacterFace extends StatelessWidget {
  const CharacterFace(this.id, this.size, this.color, {super.key});
  final String id;
  final double size;
  final Color color;

  /// Ids that have art. The protocol's `characterIds` must all be in here.
  static const artIds = {
    'fox', 'owl', 'frog', 'bear', 'cat', 'dog', 'rabbit', 'penguin', //
    'lion', 'panda', 'pig', 'koala', 'mouse', 'tiger', 'duck', 'monkey',
  };

  static bool hasArt(String id) => artIds.contains(id);

  /// Paints the face straight onto a canvas (the Flame arena has no widgets).
  static void paintOn(Canvas canvas, Size size, String id, Color color) =>
      _FacePainter(id, color).paint(canvas, size);

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _FacePainter(id, color),
        isComplex: false,
      );
}

const _ink = Color(0xFF14141E);

class _FacePainter extends CustomPainter {
  _FacePainter(this.id, this.color);
  final String id;
  final Color color;

  late Canvas _c;
  late double _k;
  late final Paint _col = Paint()..color = color;
  late final Paint _lite = Paint()..color = Color.lerp(color, const Color(0xFFFFFFFF), 0.7)!;
  late final Paint _dark = Paint()..color = Color.lerp(color, _ink, 0.45)!;
  final Paint _inkP = Paint()..color = _ink;
  // Panda ears: black on a dark TV would vanish, so a deep tint with an outline.
  late final Paint _deep = Paint()..color = Color.lerp(color, _ink, 0.7)!;
  late final Paint _line = Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void _o(double cx, double cy, double rx, double ry, Paint p) => _c.drawOval(
      Rect.fromCenter(center: Offset(cx * _k, cy * _k), width: 2 * rx * _k, height: 2 * ry * _k), p);
  void _d(double cx, double cy, double r, Paint p) => _o(cx, cy, r, r, p);

  /// Flat list x1,y1,x2,y2,... closed polygon.
  void _poly(List<double> v, Paint p) {
    final path = Path()..moveTo(v[0] * _k, v[1] * _k);
    for (var i = 2; i < v.length; i += 2) {
      path.lineTo(v[i] * _k, v[i + 1] * _k);
    }
    _c.drawPath(path..close(), p);
  }

  /// The same polygon mirrored across the vertical centre line.
  void _poly2(List<double> v, Paint p) {
    _poly(v, p);
    _poly([for (var i = 0; i < v.length; i += 2) ...[100 - v[i], v[i + 1]]], p);
  }

  void _o2(double cx, double cy, double rx, double ry, Paint p) {
    _o(cx, cy, rx, ry, p);
    _o(100 - cx, cy, rx, ry, p);
  }

  void _d2(double cx, double cy, double r, Paint p) => _o2(cx, cy, r, r, p);

  void _ln(double x1, double y1, double x2, double y2, double w) {
    _line.strokeWidth = w * _k;
    _c.drawLine(Offset(x1 * _k, y1 * _k), Offset(x2 * _k, y2 * _k), _line);
  }

  void _ln2(double x1, double y1, double x2, double y2, double w) {
    _ln(x1, y1, x2, y2, w);
    _ln(100 - x1, y1, 100 - x2, y2, w);
  }

  void _smile(double x1, double y, double x2, double dip, double w) {
    _line.strokeWidth = w * _k;
    _c.drawPath(
        Path()
          ..moveTo(x1 * _k, y * _k)
          ..quadraticBezierTo(50 * _k, (y + dip) * _k, x2 * _k, y * _k),
        _line);
  }

  @override
  void paint(Canvas canvas, Size s) {
    _c = canvas;
    _k = s.width / 100;
    switch (id) {
      case 'fox':
        _poly2([8, 6, 40, 30, 12, 54], _col);
        _poly2([15, 17, 32, 32, 17, 46], _dark);
        _poly([10, 42, 50, 30, 90, 42, 86, 66, 50, 94, 14, 66], _col);
        _poly([28, 64, 50, 50, 72, 64, 50, 94], _lite);
        _d(50, 86, 5.5, _inkP);
        _o2(34, 55, 4, 5.5, _inkP);
      case 'owl':
        _poly2([14, 10, 38, 24, 18, 38], _col);
        _d(50, 54, 42, _col);
        _d2(32, 46, 17, _lite);
        _d2(32, 46, 8, _inkP);
        _poly([43, 60, 57, 60, 50, 78], _dark);
      case 'frog':
        _o(50, 62, 46, 32, _col);
        _d2(28, 34, 17, _col);
        _d2(28, 34, 10, _lite);
        _d2(28, 34, 5, _inkP);
        _smile(20, 66, 80, 20, 4);
        _d2(44, 54, 2.6, _inkP);
      case 'bear':
        _d2(20, 20, 16, _col);
        _d2(20, 20, 8, _dark);
        _d(50, 56, 40, _col);
        _o(50, 70, 18, 14, _lite);
        _o(50, 63, 7.5, 5.5, _inkP);
        _ln(50, 68, 50, 75, 3);
        _d2(35, 46, 4.5, _inkP);
      case 'cat':
        _poly2([13, 6, 44, 28, 10, 52], _col);
        _poly2([20, 19, 35, 30, 19, 42], _dark);
        _o(50, 60, 42, 35, _col);
        _o2(35, 56, 4.5, 8, _inkP);
        _poly([44, 66, 56, 66, 50, 73], _dark);
        _ln2(8, 64, 30, 68, 2.6);
        _ln2(8, 76, 30, 73, 2.6);
      case 'dog':
        _o2(12, 54, 12, 28, _dark);
        _o(50, 52, 35, 38, _col);
        _o(50, 71, 21, 17, _lite);
        _o(50, 62, 9, 6.5, _inkP);
        _ln(50, 68, 50, 76, 3);
        _d2(36, 44, 4.5, _inkP);
      case 'rabbit':
        _o2(34, 24, 11, 25, _col);
        _o2(34, 26, 5.5, 17, _lite);
        _o(50, 68, 36, 29, _col);
        _d(50, 72, 4.5, _dark);
        _ln(50, 74, 50, 80, 3);
        _d2(37, 63, 5.5, _inkP);
        _c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(45 * _k, 80 * _k, 10 * _k, 11 * _k), Radius.circular(2.5 * _k)),
            _lite);
      case 'penguin':
        _o2(7, 60, 7, 18, _dark);
        _o(50, 52, 42, 44, _col);
        _o(50, 56, 31, 33, _lite);
        _d2(36, 48, 4.5, _inkP);
        _poly([42, 58, 58, 58, 50, 72], _inkP);
      case 'lion':
        _d(50, 52, 48, _dark);
        _d2(24, 20, 10, _col);
        _d(50, 54, 31, _col);
        _o(50, 66, 16, 12, _lite);
        _poly([43, 57, 57, 57, 50, 65], _inkP);
        _ln(50, 65, 50, 72, 3);
        _d2(38, 47, 4.2, _inkP);
      case 'panda':
        _d2(20, 20, 15, _deep);
        _d(50, 56, 40, _col);
        _o2(33, 51, 10, 13, _inkP);
        _d2(34, 50, 3.6, _lite);
        _o(50, 68, 7, 5, _inkP);
        _ln(50, 72, 50, 79, 3);
      case 'pig':
        _poly2([10, 20, 40, 20, 22, 48], _col);
        _poly2([16, 26, 33, 27, 24, 40], _dark);
        _d(50, 54, 39, _col);
        _o(50, 66, 20, 15, _lite);
        _o2(42, 66, 3.4, 5.5, _inkP);
        _d2(33, 44, 4.5, _inkP);
      case 'koala':
        _d2(13, 38, 18, _col);
        _d2(13, 38, 9.5, _lite);
        _o(50, 57, 35, 35, _col);
        _o(50, 59, 9.5, 14, _inkP);
        _d2(34, 47, 4.2, _inkP);
      case 'mouse':
        _d2(20, 28, 20, _col);
        _d2(20, 28, 11, _lite);
        _o(50, 62, 31, 33, _col);
        _d(50, 86, 5.5, _dark);
        _d2(38, 58, 4.2, _inkP);
        _ln2(10, 72, 34, 74, 2.6);
        _ln2(12, 84, 34, 80, 2.6);
      case 'tiger':
        _d2(20, 22, 13, _col);
        _d2(20, 22, 6.5, _dark);
        _d(50, 56, 40, _col);
        _poly([46, 18, 54, 18, 52, 38, 48, 38], _dark);
        _poly2([9, 46, 25, 50, 11, 58], _dark);
        _poly2([13, 64, 27, 63, 17, 74], _dark);
        _o(50, 71, 19, 13, _lite);
        _poly([43, 62, 57, 62, 50, 70], _inkP);
        _d2(35, 46, 4.5, _inkP);
      case 'duck':
        _o(50, 14, 5, 11, _col);
        _d(50, 48, 36, _col);
        _o(50, 70, 31, 14, _dark);
        _ln(22, 70, 78, 70, 2.6);
        _d2(44, 64, 2.2, _inkP);
        _d2(36, 40, 4.6, _inkP);
      case 'monkey':
        _d2(10, 52, 13, _col);
        _d2(10, 52, 7, _lite);
        _d(50, 46, 36, _col);
        _d2(38, 49, 15, _lite);
        _o(50, 68, 25, 22, _lite);
        _d2(40, 49, 4, _inkP);
        _d2(46, 64, 2.6, _inkP);
        _smile(40, 76, 60, 8, 3);
      default:
        _d(50, 50, 44, _col);
    }
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.id != id || old.color != color;
}
