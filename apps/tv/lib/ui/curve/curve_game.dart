import 'dart:ui';

import 'package:core/core.dart';
import 'package:flame/game.dart';

/// Runs [sim] on a fixed 60 Hz accumulator and draws trails and heads.
/// The arena is scaled to fit the screen, letterboxed.
class CurveGame extends FlameGame {
  CurveGame(this.sim, this.colors, {this.onEvents});

  final CurveSim sim;
  final List<Color> colors;
  final void Function(List<CurveEvent>)? onEvents;

  final _paths = <int, Path>{};
  final _trail = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _head = Paint();
  double _acc = 0;

  Color _color(int id) => colors[id % colors.length];

  @override
  void update(double dt) {
    super.update(dt);
    _acc += dt;
    final step = 1 / sim.config.tickHz;
    // Cap catch-up so a stall doesn't spiral.
    if (_acc > 0.25) _acc = 0.25;
    while (_acc >= step) {
      _acc -= step;
      final events = sim.tick();
      if (events.isNotEmpty) onEvents?.call(events);
    }
    for (final s in sim.takeNewSegments()) {
      (_paths[s.id] ??= Path())
        ..moveTo(s.x1, s.y1)
        ..lineTo(s.x2, s.y2);
    }
  }

  @override
  void render(Canvas canvas) {
    final w = sim.config.arenaW.toDouble(), h = sim.config.arenaH.toDouble();
    final k = size.x / w < size.y / h ? size.x / w : size.y / h;
    canvas
      ..save()
      ..translate((size.x - w * k) / 2, (size.y - h * k) / 2)
      ..scale(k)
      ..drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF14141E))
      ..clipRect(Rect.fromLTWH(0, 0, w, h));
    _trail.strokeWidth = sim.config.lineWidth;
    for (final e in _paths.entries) {
      canvas.drawPath(e.value, _trail..color = _color(e.key));
    }
    for (final hd in sim.heads) {
      if (hd.alive) {
        canvas.drawCircle(Offset(hd.x, hd.y), sim.config.lineWidth * 0.8,
            _head..color = const Color(0xFFFFFFFF));
      }
    }
    canvas.restore();
    super.render(canvas);
  }
}
