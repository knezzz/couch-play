import 'package:flutter/widgets.dart';

/// ▲ ◆ ● ■ (index 0-3) drawn, not typed: the shapes are the colour-blind
/// channel, so they must not depend on which symbol fonts a screen has (a TV,
/// or an offline phone that cannot fetch a fallback font).
class ShapeMark extends StatelessWidget {
  const ShapeMark(this.index, this.size, this.color, {super.key});
  final int index;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ShapePainter(index, color));
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.index, this.color);
  final int index;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color;
    final w = s.width, h = s.height;
    switch (index) {
      case 0:
        canvas.drawPath(Path()..moveTo(w / 2, 0)..lineTo(w, h)..lineTo(0, h)..close(), p);
      case 1:
        canvas.drawPath(Path()..moveTo(w / 2, 0)..lineTo(w, h / 2)..lineTo(w / 2, h)..lineTo(0, h / 2)..close(), p);
      case 2:
        canvas.drawOval(Offset.zero & s, p);
      default:
        canvas.drawRect(Offset.zero & s, p);
    }
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.index != index || old.color != color;
}
