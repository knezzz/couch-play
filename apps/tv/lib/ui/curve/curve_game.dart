import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection, TextAlign, FontWeight;

import '../../strings.dart';

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
  double _time = 0; // seconds the game has run: the reverse ring turns with it
  var _cdTicks = 0; // ticks of the countdown that have run

  /// The whole seconds of the countdown that are left: 3, 2, 1, then 0 once the round runs.
  int get countdownSeconds {
    if (!sim.countingDown) return 0;
    final total = (sim.config.countdown * sim.config.tickHz).round();
    return ((total - _cdTicks) / sim.config.tickHz).ceil().clamp(0, 99);
  }

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
    _time += dt;
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
      _cdTicks = sim.countingDown ? _cdTicks + 1 : 0;
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
    if (counting) _drawCountdownNumber(canvas, w, h);
    for (final hd in sim.heads) {
      if (!hd.alive) continue;
      canvas.drawCircle(Offset(hd.x, hd.y), base * (counting ? 1.6 : 0.8),
          _head..color = counting ? _color(hd.id) : (sim.effectLeft(hd.id, PowerUpKind.ghost) > 0 ? const Color(0x59FFFFFF) : const Color(0xFFFFFFFF)));
      if (counting) _drawArrow(canvas, hd.x, hd.y, hd.heading, base * 8, _color(hd.id));
      if (counting) _drawName(canvas, hd.id, hd.x, hd.y, hd.heading, base * 2, w, h);
      if (!counting) _drawEffects(canvas, hd);
    }
    if (counting) _drawHint(canvas, w, h);
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

  /// The big faint number in the middle (TvCountdown).
  final _digits = <int, TextPainter>{};
  void _drawCountdownNumber(Canvas canvas, double w, double h) {
    final n = countdownSeconds;
    if (n <= 0) return;
    final tp = _digits[n] ??= TextPainter(
      text: TextSpan(text: '$n', style: const TextStyle(fontSize: 200, fontWeight: FontWeight.w900, color: Color(0xFF2A2A3A))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.47 - tp.height / 2));
  }

  /// What to do, at the bottom (TvCountdown).
  TextPainter? _hint;
  void _drawHint(Canvas canvas, double w, double h) {
    final tp = _hint ??= TextPainter(
      text: const TextSpan(text: Strings.curveCountdownHint, style: TextStyle(fontSize: 30, color: Color(0xFFA9A9BC))),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: w - 80);
    tp.paint(canvas, Offset((w - tp.width) / 2, h - 36 - tp.height));
  }

  /// A name on a dark pill with the player's face in it (TvCountdown: 64 px face, 44 px white
  /// name on a 1080p screen; in arena units a little less). Above the head, or below it when
  /// the start arrow points mostly up; kept inside the arena.
  void _drawName(Canvas canvas, int id, double x, double y, double heading, double gap,
      double arenaW, double arenaH) {
    final tp = _names[id] ??= TextPainter(
      text: TextSpan(
          text: sim.names[id] ?? 'P${id + 1}',
          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700, color: Color(0xFFF4F4F8))),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: arenaW / 4); // keeps clamp() below valid for any name
    final face = characters[id] ?? '';
    const pad = 6.0, tail = 20.0, faceSize = 56.0, between = 10.0;
    final chipH = faceSize + 2 * pad;
    final lead = face.isEmpty ? 0.0 : faceSize + between;
    final chipW = pad + lead + tp.width + tail;
    final left = (x - chipW / 2).clamp(0.0, max(0.0, arenaW - chipW)).toDouble();
    final top = nameTop(y, gap, chipH, heading, arenaH);
    canvas.drawRRect(RRect.fromLTRBR(left, top, left + chipW, top + chipH, Radius.circular(chipH / 2)),
        _icon..style = PaintingStyle.fill..color = const Color(0xFF1F1F2C));
    if (face.isNotEmpty) {
      canvas
        ..save()
        ..translate(left + pad, top + pad);
      CharacterFace.paintOn(canvas, const Size.square(faceSize), face, _color(id));
      canvas.restore();
    }
    tp.paint(canvas, Offset(left + pad + lead, top + (chipH - tp.height) / 2));
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

  /// A spiral from the middle out, about two turns, for the snail's shell.
  static Path _spiral(double cx, double cy) {
    final p = Path()..moveTo(cx, cy);
    for (var i = 1; i <= 40; i++) {
      final a = i * pi / 10; // 2 turns in 40 steps
      final r = 1.6 * a;
      p.lineTo(cx + r * cos(a), cy + r * sin(a));
    }
    return p;
  }

  // The snail and the lightning serve both the green (you) and the red (others) kinds.
  static final _Icon _snail = _Icon(
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
  static final _Icon _bolt = _Icon(fill: _poly([60, 10, 26, 56, 47, 56, 38, 90, 74, 42, 53, 42]));

  static final _Icon _ghost = _Icon(
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
  static final _Icon _reverse = _Icon(
    line: _strokes([
      [20, 34, 76, 34], [64, 22, 78, 34, 64, 46],
      [80, 66, 24, 66], [36, 54, 22, 66, 36, 78],
    ]),
    lineW: 8,
  );

  static final Map<PowerUpKind, _Icon> _icons = {
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

  static Color _powerUpColor(PowerUpKind k) => switch (k) {
        PowerUpKind.speed || PowerUpKind.slow || PowerUpKind.ghost || PowerUpKind.cheese => _green,
        PowerUpKind.speedOthers ||
        PowerUpKind.slowOthers ||
        PowerUpKind.fatOthers ||
        PowerUpKind.reverseOthers ||
        PowerUpKind.squareOthers =>
          _red,
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
    if (ic.cut != null) {
      _icon
        ..color = disc
        ..strokeWidth = ic.cutW;
      canvas.drawPath(ic.cut!, _icon);
    }
    if (ic.holes.isNotEmpty) {
      _icon
        ..style = PaintingStyle.fill
        ..color = disc;
      for (final h in ic.holes) {
        canvas.drawCircle(h, ic.holeR, _icon);
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
    PowerUpKind.speed,
    PowerUpKind.slow,
    PowerUpKind.ghost,
    PowerUpKind.cheese,
    PowerUpKind.speedOthers,
    PowerUpKind.slowOthers,
    PowerUpKind.fatOthers,
    PowerUpKind.reverseOthers,
    PowerUpKind.squareOthers,
  ];
  final _ringKind = List<PowerUpKind>.filled(_effectKinds.length, PowerUpKind.slow);
  final _ringLeft = Float64List(_effectKinds.length); // fraction left: the arc
  final _ringTime = Float64List(_effectKinds.length); // seconds-ish left: the order

  void _drawEffects(Canvas canvas, CurveHead hd) {
    var n = 0;
    for (final kind in _effectKinds) {
      final left = sim.effectLeft(hd.id, kind);
      if (left <= 0) continue;
      // Insertion sort by time left, shortest first: at most 5, no allocation.
      // Fat lasts 1.5x as long (the sim's _longFactor), so compare time, not fraction.
      final time = left * (kind == PowerUpKind.fatOthers ? 1.5 : 1.0);
      var i = n++;
      while (i > 0 && _ringTime[i - 1] > time) {
        _ringLeft[i] = _ringLeft[i - 1];
        _ringTime[i] = _ringTime[i - 1];
        _ringKind[i] = _ringKind[i - 1];
        i--;
      }
      _ringLeft[i] = left;
      _ringTime[i] = time;
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
      // Reversed steering: the ring slowly turns the other way round, one turn in 4 s.
      final start = -pi / 2 - (kind == PowerUpKind.reverseOthers ? _time * pi / 2 : 0);
      canvas.drawArc(rect, start, 2 * pi * _ringLeft[i], false, _icon);
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
