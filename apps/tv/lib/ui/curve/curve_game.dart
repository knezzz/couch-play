import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection, FontWeight;

class _Icon {
  const _Icon({this.fill, this.line, this.lineW = 8, this.thin, this.holes = const []});
  final Path? fill, line, thin;
  final double lineW;
  final List<Offset> holes;
}

/// Runs [sim] on a fixed 60 Hz accumulator and draws trails and heads.
/// The arena is scaled to fit the screen, letterboxed.
class CurveGame extends FlameGame {
  CurveGame(this.sim, this.colors,
      {this.onBeforeTick, this.onEvents, this.holdWhen, this.characters = const {}});

  final CurveSim sim;
  final List<Color> colors;

  /// Player id -> character id; the countdown label shows it before the name.
  final Map<int, String> characters;
  /// Called before every sim tick, e.g. `bots.tick`.
  final void Function()? onBeforeTick;
  final void Function(List<CurveEvent>)? onEvents;

  /// While true the sim stands still (a player left; Session waits for them).
  final bool Function()? holdWhen;

  // One Path per (player, width bucket); key = id * 4 + bucket (line width x1 to x4: normal and up to 3 fat stacks).
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
      [for (var b = 0; b < 4; b++) _paths[id * 4 + b]]
          .whereType<Path>()
          .fold(0, (n, p) => n + p.computeMetrics().length);

  double debugTrailLength(int id) => [for (var b = 0; b < 4; b++) _paths[id * 4 + b]]
      .whereType<Path>()
      .expand((p) => p.computeMetrics())
      .fold(0.0, (n, m) => n + m.length);

  int get debugPathCount => _paths.length;

  Color _color(int id) => colors[id % colors.length];

  int _bucket(double width) {
    return (width / sim.config.lineWidth).round().clamp(1, 4) - 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (holdWhen?.call() ?? false) {
      _acc = 0;
      return;
    }
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
      final key = s.id * 4 + _bucket(s.width);
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
    _drawWrapBorder(canvas, w, h, sim.wrapLeft); // under the trails, which stay visible
    final base = sim.config.lineWidth;
    for (final e in _paths.entries) {
      _trail
        ..strokeWidth = base * (e.key % 4 + 1)
        ..color = _color(e.key ~/ 4);
      canvas.drawPath(e.value, _trail);
    }
    for (final u in sim.powerUps) {
      _drawPowerUp(canvas, u.x, u.y, u.kind, sim.config.powerUpRadius);
    }
    final counting = sim.countingDown;
    for (final hd in sim.heads) {
      if (!hd.alive) continue;
      canvas.drawCircle(Offset(hd.x, hd.y), base * (counting ? 1.6 : 0.8),
          _head..color = counting ? _color(hd.id) : const Color(0xFFFFFFFF));
      if (counting) _drawArrow(canvas, hd.x, hd.y, hd.heading, base * 8, _color(hd.id));
      if (counting) _drawName(canvas, hd.id, hd.x, hd.y, hd.heading, base * 2, w, h);
      if (!counting) _drawEffects(canvas, hd);
    }
    canvas.restore();
    super.render(canvas);
  }

  // Unit arrow along +x, starting at 0.25 (just outside the dot) to the tip at 1.
  static final _arrow = Path()
    ..moveTo(0.25, 0)
    ..lineTo(1, 0)
    ..moveTo(0.72, -0.2)
    ..lineTo(1, 0)
    ..lineTo(0.72, 0.2);

  void _drawArrow(Canvas canvas, double x, double y, double heading, double len, Color c) {
    canvas
      ..save()
      ..translate(x, y)
      ..rotate(heading)
      ..scale(len);
    _icon
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 / len
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    canvas
      ..drawPath(_arrow, _icon)
      ..restore();
  }

  // Names are in arena units: 44 units is about 53 px on a 1080p TV.
  /// Top of the name box: above the dot, or below it when the start arrow
  /// points mostly up (so they don't overlap). Kept inside the arena.
  static double nameTop(double y, double gap, double textH, double heading, double arenaH) {
    final top = sin(heading) < -0.5 ? y + gap : y - gap - textH;
    return top.clamp(0.0, max(0.0, arenaH - textH));
  }

  void _drawName(Canvas canvas, int id, double x, double y, double heading, double gap,
      double arenaW, double arenaH) {
    final tp = _names[id] ??= TextPainter(
      text: TextSpan(
          text: sim.names[id] ?? 'P${id + 1}',
          style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: _color(id))),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: arenaW / 4); // keeps clamp() below valid for any name
    final face = characters[id] ?? '';
    // The face (as tall as the text) goes before the name; the pair stays centred.
    final lead = face.isEmpty ? 0.0 : tp.height + 8;
    final left = (x - (lead + tp.width) / 2).clamp(0.0, arenaW - lead - tp.width);
    final top = nameTop(y, gap, tp.height, heading, arenaH);
    if (face.isNotEmpty) {
      canvas
        ..save()
        ..translate(left, top);
      CharacterFace.paintOn(canvas, Size.square(tp.height), face, _color(id));
      canvas.restore();
    }
    tp.paint(canvas, Offset(left + lead, top));
  }

  static const _green = Color(0xFF3DDC84), _red = Color(0xFFFF4D4D), _blue = Color(0xFF4DA6FF);

  // Pickup icons (PuIcons, version A: things), drawn on a 100 x 100 grid with the
  // disc at (50, 50) r 47. Built once. Ink on the power-up colour.
  static Path _poly(List<double> v) {
    final p = Path()..moveTo(v[0], v[1]);
    for (var i = 2; i < v.length; i += 2) {
      p.lineTo(v[i], v[i + 1]);
    }
    return p..close();
  }

  /// Open strokes: each list is one polyline.
  static Path _strokes(List<List<double>> lines) {
    final p = Path();
    for (final v in lines) {
      p.moveTo(v[0], v[1]);
      for (var i = 2; i < v.length; i += 2) {
        p.lineTo(v[i], v[i + 1]);
      }
    }
    return p;
  }

  static final Map<PowerUpKind, _Icon> _icons = {
    // Snail: shell on a body, feelers.
    PowerUpKind.slow: _Icon(
      fill: _poly([12, 78, 14, 66, 28, 62, 76, 62, 90, 68, 90, 78])..addOval(Rect.fromCircle(center: const Offset(86, 54), radius: 8)),
      line: Path()
        ..addOval(Rect.fromCircle(center: const Offset(46, 42), radius: 19))
        ..addOval(Rect.fromCircle(center: const Offset(46, 42), radius: 6))
        ..addPath(_strokes([[86, 50, 82, 30], [86, 50, 96, 34]]), Offset.zero),
      lineW: 7,
    ),
    // Ghost: a sheet with a wavy hem; the eyes are holes.
    PowerUpKind.ghost: _Icon(
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
    ),
    // Lightning bolt.
    PowerUpKind.speedOthers: _Icon(fill: _poly([60, 10, 26, 56, 47, 56, 38, 90, 74, 42, 53, 42])),
    // A thin line over a thick bar.
    PowerUpKind.fatOthers: _Icon(
      fill: _poly([16, 50, 84, 50, 84, 82, 16, 82]),
      line: _strokes([[16, 28, 84, 28]]),
      lineW: 7,
    ),
    // Two arrows the opposite way round.
    PowerUpKind.reverseOthers: _Icon(
      line: _strokes([
        [20, 34, 76, 34], [64, 22, 78, 34, 64, 46],
        [80, 66, 24, 66], [36, 54, 22, 66, 36, 78],
      ]),
      lineW: 8,
    ),
    // Broom: handle and bristles.
    PowerUpKind.clear: _Icon(
      fill: _poly([28, 52, 52, 66, 42, 88, 14, 80]),
      line: _strokes([[74, 14, 40, 58]]),
      lineW: 8,
    ),
    // An arrow through the edge: dashed walls either side of it.
    PowerUpKind.wrap: _Icon(
      line: _strokes([[8, 50, 88, 50], [74, 38, 88, 50, 74, 62]]),
      lineW: 8,
      thin: _strokes([
        for (final x in [22.0, 78.0])
          for (final y in [18.0, 38.0, 58.0, 78.0]) [x, y, x, y + 12],
      ]),
    ),
  };

  static Color _powerUpColor(PowerUpKind k) => switch (k) {
        PowerUpKind.slow || PowerUpKind.ghost => _green,
        PowerUpKind.speedOthers || PowerUpKind.fatOthers || PowerUpKind.reverseOthers => _red,
        PowerUpKind.clear || PowerUpKind.wrap => _blue,
      };

  static const _ink = Color(0xFF14141E);

  /// A pickup on the board: [kind]'s icon, ink on the colour disc, radius [r].
  void _drawPowerUp(Canvas canvas, double x, double y, PowerUpKind kind, double r) {
    final disc = _powerUpColor(kind), ic = _icons[kind]!;
    canvas
      ..save()
      ..translate(x, y)
      ..scale(r / 47)
      ..translate(-50, -50);
    _icon
      ..style = PaintingStyle.fill
      ..color = disc;
    canvas.drawCircle(const Offset(50, 50), 47, _icon);
    _icon.color = _ink;
    if (ic.fill != null) canvas.drawPath(ic.fill!, _icon);
    _icon
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (ic.line != null) {
      _icon.strokeWidth = ic.lineW;
      canvas.drawPath(ic.line!, _icon);
    }
    if (ic.thin != null) {
      _icon.strokeWidth = 5;
      canvas.drawPath(ic.thin!, _icon);
    }
    if (ic.holes.isNotEmpty) {
      _icon
        ..style = PaintingStyle.fill
        ..color = disc;
      for (final h in ic.holes) {
        canvas.drawCircle(h, 5.5, _icon);
      }
    }
    canvas.restore();
  }

  // Active effects (PuActive, option 1): a ring per effect centred on the head,
  // draining clockwise from the top. In arena units; the first ring clears a
  // x4 fat trail. Several are concentric, the one with most time left outermost.
  static const ringBase = 26.0, ringStep = 9.0, ringWidth = 5.0;

  /// Angle between the dots that count fat stacks, on the ring's bottom.
  static const stackStep = 0.42;
  static const _effectKinds = [
    PowerUpKind.slow,
    PowerUpKind.ghost,
    PowerUpKind.speedOthers,
    PowerUpKind.fatOthers,
    PowerUpKind.reverseOthers,
  ];
  final _ringKind = List<PowerUpKind>.filled(5, PowerUpKind.slow);
  final _ringLeft = Float64List(5);

  void _drawEffects(Canvas canvas, CurveHead hd) {
    var n = 0;
    for (final kind in _effectKinds) {
      final left = sim.effectLeft(hd.id, kind);
      if (left <= 0) continue;
      // Insertion sort, shortest first: at most 5, no allocation.
      var i = n++;
      while (i > 0 && _ringLeft[i - 1] > left) {
        _ringLeft[i] = _ringLeft[i - 1];
        _ringKind[i] = _ringKind[i - 1];
        i--;
      }
      _ringLeft[i] = left;
      _ringKind[i] = kind;
    }
    final c = Offset(hd.x, hd.y);
    for (var i = 0; i < n; i++) {
      final kind = _ringKind[i], radius = ringBase + i * ringStep;
      final color = _powerUpColor(kind);
      final rect = Rect.fromCircle(center: c, radius: radius);
      _icon
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.butt
        ..color = color.withValues(alpha: 0.25);
      canvas.drawCircle(c, radius, _icon);
      _icon.color = color;
      canvas.drawArc(rect, -pi / 2, 2 * pi * _ringLeft[i], false, _icon);
      if (kind == PowerUpKind.fatOthers) {
        final stacks = sim.effectStacks(hd.id, kind);
        _icon
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFFFFF);
        for (var s = 0; s < stacks; s++) {
          canvas.drawCircle(c + Offset.fromDirection(pi / 2 + (s - (stacks - 1) / 2) * stackStep, radius), 4.2, _icon);
        }
      }
    }
  }

  // Wrap border: 4 edges as one raw-points draw, filled in place.
  final _borderPts = Float32List(16);
  final _border = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeCap = StrokeCap.butt
    ..strokeWidth = borderWidth;
  static const borderWidth = 10.0;

  /// Fills [pts] with up to 4 lines (x1,y1,x2,y2 each) covering [frac] of the
  /// perimeter, clockwise from the top-left corner; the rest is zeroed. Returns the floats used.
  static int borderLines(Float32List pts, double w, double h, double frac) {
    final lo = borderWidth / 2, r = w - lo, b = h - lo;
    var remaining = (2 * (w + h)) * frac, n = 0;
    for (var e = 0; e < 4 && remaining > 0; e++) {
      // tl -> tr -> br -> bl -> tl
      final ax = e == 1 || e == 2 ? r : lo, ay = e >= 2 ? b : lo;
      final bx = e == 0 || e == 1 ? r : lo, by = e >= 1 && e <= 2 ? b : lo;
      final len = (bx - ax).abs() + (by - ay).abs();
      final t = remaining >= len ? 1.0 : remaining / len;
      pts[n++] = ax;
      pts[n++] = ay;
      pts[n++] = ax + (bx - ax) * t;
      pts[n++] = ay + (by - ay) * t;
      remaining -= len;
    }
    final used = n;
    pts.fillRange(n, pts.length, 0); // zero-length lines draw nothing
    return used;
  }

  void _drawWrapBorder(Canvas canvas, double w, double h, double left) {
    if (left <= 0) return;
    borderLines(_borderPts, w, h, left);
    canvas.drawRawPoints(PointMode.lines, _borderPts, _border);
  }
}
