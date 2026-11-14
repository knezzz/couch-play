import 'dart:math';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection, FontWeight;

/// Runs [sim] on a fixed 60 Hz accumulator and draws trails and heads.
/// The arena is scaled to fit the screen, letterboxed.
class CurveGame extends FlameGame {
  CurveGame(this.sim, this.colors, {this.onBeforeTick, this.onEvents});

  final CurveSim sim;
  final List<Color> colors;
  /// Called before every sim tick, e.g. `bots.tick`.
  final void Function()? onBeforeTick;
  final void Function(List<CurveEvent>)? onEvents;

  // One Path per (player, width bucket); key = id * 3 + bucket (thin/normal/fat).
  final _paths = <int, Path>{};
  final _ends = <int, Offset>{}; // where each key's last segment ended
  final _names = <int, TextPainter>{}; // laid out once per player
  final _icon = Paint();
  final _trail = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _head = Paint();
  double _acc = 0;

  int debugSubpathCount(int id) =>
      [for (var b = 0; b < 3; b++) _paths[id * 3 + b]]
          .whereType<Path>()
          .fold(0, (n, p) => n + p.computeMetrics().length);

  double debugTrailLength(int id) => [for (var b = 0; b < 3; b++) _paths[id * 3 + b]]
      .whereType<Path>()
      .expand((p) => p.computeMetrics())
      .fold(0.0, (n, m) => n + m.length);

  int get debugPathCount => _paths.length;

  Color _color(int id) => colors[id % colors.length];

  int _bucket(double width) {
    final n = sim.config.lineWidth;
    return width < n * 0.75 ? 0 : (width > n * 1.5 ? 2 : 1);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _acc += dt;
    final step = 1 / sim.config.tickHz;
    // Cap catch-up so a stall doesn't spiral.
    if (_acc > 0.25) _acc = 0.25;
    while (_acc >= step) {
      _acc -= step;
      onBeforeTick?.call();
      final events = sim.tick();
      if (events.isNotEmpty) onEvents?.call(events);
    }
    // Clear first: segments drained after it are new trail.
    if (sim.takeCleared()) {
      _paths.clear();
      _ends.clear();
    }
    for (final s in sim.takeNewSegments()) {
      final key = s.id * 3 + _bucket(s.width);
      final path = _paths[key] ??= Path();
      // Continue the subpath unless a gap (or round start) broke the line.
      // Sim computes x1 as x - vx, so ends differ by float rounding: use a tolerance.
      final e = _ends[key];
      if (e == null || (e.dx - s.x1).abs() > 0.01 || (e.dy - s.y1).abs() > 0.01) {
        path.moveTo(s.x1, s.y1);
      }
      path.lineTo(s.x2, s.y2);
      _ends[key] = Offset(s.x2, s.y2);
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
    final base = sim.config.lineWidth;
    for (final e in _paths.entries) {
      _trail
        ..strokeWidth = base * const [0.5, 1.0, 2.0][e.key % 3]
        ..color = _color(e.key ~/ 3);
      canvas.drawPath(e.value, _trail);
    }
    for (final u in sim.powerUps) {
      _drawPowerUp(canvas, u, sim.config.powerUpRadius);
    }
    final counting = sim.countingDown;
    for (final hd in sim.heads) {
      if (!hd.alive) continue;
      canvas.drawCircle(Offset(hd.x, hd.y), base * (counting ? 1.6 : 0.8),
          _head..color = counting ? _color(hd.id) : const Color(0xFFFFFFFF));
      if (counting) _drawName(canvas, hd.id, hd.x, hd.y - base * 2, w);
    }
    canvas.restore();
    super.render(canvas);
  }

  // Names are in arena units: 44 units is about 53 px on a 1080p TV.
  void _drawName(Canvas canvas, int id, double x, double y, double arenaW) {
    final tp = _names[id] ??= TextPainter(
      text: TextSpan(
          text: sim.names[id] ?? 'P${id + 1}',
          style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: _color(id))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset((x - tp.width / 2).clamp(0.0, arenaW - tp.width), max(0.0, y - tp.height)));
  }

  static const _green = Color(0xFF3DDC84), _red = Color(0xFFFF4D4D), _blue = Color(0xFF4DA6FF);

  // Unit-size glyphs (radius 1), built once.
  static final Map<PowerUpKind, Path> _glyphs = {
    PowerUpKind.speed: _chevrons(1),
    PowerUpKind.slowOthers: _chevrons(-1),
    PowerUpKind.thin: Path()..addRect(const Rect.fromLTWH(-0.6, -0.05, 1.2, 0.1)),
    PowerUpKind.fatOthers: Path()..addRect(const Rect.fromLTWH(-0.6, -0.3, 1.2, 0.6)),
    PowerUpKind.ghost: Path()
      ..moveTo(-0.45, 0.5)
      ..lineTo(-0.45, -0.1)
      ..arcToPoint(const Offset(0.45, -0.1), radius: const Radius.circular(0.45))
      ..lineTo(0.45, 0.5)
      ..lineTo(0.15, 0.3)
      ..lineTo(-0.15, 0.5)
      ..close(),
    PowerUpKind.clear: Path()
      ..moveTo(-0.5, -0.5)
      ..lineTo(0.5, 0.5)
      ..moveTo(0.5, -0.5)
      ..lineTo(-0.5, 0.5),
    PowerUpKind.wrap: Path()
      ..moveTo(-0.6, 0)
      ..lineTo(0.6, 0)
      ..moveTo(-0.6, 0)
      ..relativeLineTo(0.3, -0.3)
      ..moveTo(-0.6, 0)
      ..relativeLineTo(0.3, 0.3)
      ..moveTo(0.6, 0)
      ..relativeLineTo(-0.3, -0.3)
      ..moveTo(0.6, 0)
      ..relativeLineTo(-0.3, 0.3),
  };

  static Path _chevrons(int dir) => Path()
    ..moveTo(-0.5 * dir, -0.45)
    ..lineTo(0, 0)
    ..lineTo(-0.5 * dir, 0.45)
    ..moveTo(0.05 * dir, -0.45)
    ..lineTo(0.55 * dir, 0)
    ..lineTo(0.05 * dir, 0.45);

  static Color _powerUpColor(PowerUpKind k) => switch (k) {
        PowerUpKind.speed || PowerUpKind.thin || PowerUpKind.ghost => _green,
        PowerUpKind.slowOthers || PowerUpKind.fatOthers => _red,
        PowerUpKind.clear || PowerUpKind.wrap => _blue,
      };

  void _drawPowerUp(Canvas canvas, CurvePowerUp u, double r) {
    canvas
      ..save()
      ..translate(u.x, u.y)
      ..scale(r);
    _icon
      ..style = PaintingStyle.fill
      ..color = _powerUpColor(u.kind);
    canvas.drawCircle(Offset.zero, 1, _icon);
    _icon
      ..color = const Color(0xFF14141E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final g = _glyphs[u.kind]!;
    // Solid shapes are filled, line glyphs stroked.
    if (u.kind == PowerUpKind.fatOthers || u.kind == PowerUpKind.thin || u.kind == PowerUpKind.ghost) {
      _icon.style = PaintingStyle.fill;
    }
    canvas
      ..drawPath(g, _icon)
      ..restore();
  }
}
