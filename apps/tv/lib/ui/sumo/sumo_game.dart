import 'dart:math';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection, TextAlign, FontWeight;

import '../../strings.dart';
import '../curve/curve_game.dart' show CurveGame;

/// Sumo on the TV (Task 55; boards SumoTv, SumoTvIce): runs [sim] on a fixed 60 Hz accumulator and
/// draws the ring, the wrestlers (their faces), the power-ups and the effect rings. The ring is
/// centred and scaled to fit above the names strip, exactly like [CurveGame] leaves room for it.
class SumoGame extends FlameGame {
  SumoGame(this.sim, this.colors,
      {this.onBeforeTick, this.onEvents, this.holdWhen, this.characters = const {}, this.bottomBand = 0});

  final SumoSim sim;
  final List<Color> colors;

  /// Player id -> character id (the face on the wrestler).
  final Map<int, String> characters;
  final void Function()? onBeforeTick;
  final void Function(List<CurveEvent>)? onEvents;

  /// While true the sim stands still (a player left, or the winner shows).
  final bool Function()? holdWhen;

  /// The share of the screen height kept free under the ring for the names strip.
  final double bottomBand;

  /// Wrestlers to ring in white while the winner moment holds the field.
  Set<int> ring = const {};

  double _acc = 0;
  var _cdTicks = 0;

  /// The whole seconds of the countdown left: 2, 1, then 0 once the round runs.
  int get countdownSeconds {
    if (!sim.countingDown) return 0;
    final total = (sim.config.countdown * sim.config.tickHz).round();
    return ((total - _cdTicks) / sim.config.tickHz).ceil().clamp(0, 99);
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
    if (_acc > 0.25) _acc = 0.25; // a stall must not spiral
    while (_acc >= step) {
      _acc -= step;
      onBeforeTick?.call();
      final events = sim.tick();
      _cdTicks = sim.countingDown ? _cdTicks + 1 : 0;
      if (events.isNotEmpty) onEvents?.call(events);
    }
  }

  static const _ink = Color(0xFF14141E);
  static const _green = Color(0xFF3DDC84);
  final _fill = Paint();
  final _stroke = Paint()..style = PaintingStyle.stroke;

  Color _color(int id) => colors[id % colors.length];

  @override
  void render(Canvas canvas) {
    final free = size.y * (1 - bottomBand);
    // Under the top bar and over the names strip, with the countdown hint's room kept under the ring.
    final avail = free - topBar - hintRoom;
    final r0 = sim.config.arenaRadius;
    final k = min(size.x, avail) / (2 * r0 * 1.02);
    _drawTopBar(canvas);
    canvas
      ..save()
      ..translate(size.x / 2, topBar + avail / 2)
      ..scale(k);
    _drawFloor(canvas, r0);
    for (final p in sim.powerUps) {
      _drawPowerUp(canvas, p);
    }
    final counting = sim.countingDown;
    for (final h in sim.heads) {
      if (!h.alive) continue;
      _drawWrestler(canvas, h, counting);
    }
    if (counting) _drawCountdown(canvas);
    canvas.restore();
    if (counting) _drawHint(canvas, free);
    super.render(canvas);
  }

  /// Screen pixels kept free under the ring for the countdown hint (a 40 px line and air).
  static const hintRoom = 64.0;

  /// The height of the bar on top (SumoTv board: round and target, each player's face and score, the map).
  static const topBar = 88.0;

  // The top bar is laid out once (the scores change only between rounds, and every round is a new game)
  // and kept as one picture. It is redone only if the screen size changes.
  Picture? _bar;

  /// For the test: the recorded bar (the same object frame after frame).
  Picture? get debugBar => _bar;

  /// For the test: how many face pictures are recorded (one per wrestler, kept for the game).
  int get debugFaces => _faces.length;
  double _barWidth = 0;
  void _drawTopBar(Canvas canvas) {
    if (_bar == null || _barWidth != size.x) {
      _bar?.dispose();
      _barWidth = size.x;
      final rec = PictureRecorder();
      final c = Canvas(rec);
      TextPainter text(String t, FontWeight w, Color color) => TextPainter(
            text: TextSpan(text: t, style: TextStyle(fontFamily: CurveGame.fontFamily, fontSize: 40, fontWeight: w, color: color)),
            textDirection: TextDirection.ltr,
          )..layout();
      void put(TextPainter tp, double x) => tp.paint(c, Offset(x, (topBar - tp.height) / 2));
      var x = 40.0;
      final head = text(Strings.sumoRoundHead(sim.round, sim.target), FontWeight.w700, const Color(0xFFA9A9BC));
      put(head, x);
      x += head.width + 30;
      for (final h in sim.heads) {
        c
          ..save()
          ..translate(x, (topBar - 52) / 2);
        CharacterFace.paintOn(c, const Size.square(52), characters[h.id] ?? '', _color(h.id));
        c.restore();
        final score = text('${sim.scores[h.id] ?? 0}', FontWeight.w900, const Color(0xFFF4F4F8));
        put(score, x + 52 + 10);
        x += 52 + 10 + score.width + 30;
      }
      final map = text(sim.ice ? Strings.sumoMapName(SumoMap.ice) : Strings.sumoMapName(SumoMap.classic), FontWeight.w400, const Color(0xFFA9A9BC));
      put(map, size.x - 40 - map.width);
      _bar = rec.endRecording();
    }
    canvas.drawPicture(_bar!);
  }

  // The old edge: a dashed circle at the full radius, recorded once (72 arcs are not worth redrawing at 60 Hz).
  late final Picture _oldEdge = () {
    final rec = PictureRecorder();
    final c = Canvas(rec);
    final path = Path();
    final r = sim.config.arenaRadius;
    const dashes = 72;
    for (var i = 0; i < dashes; i++) {
      path.addArc(Rect.fromCircle(center: Offset.zero, radius: r), i * 2 * pi / dashes, pi / dashes * 0.9);
    }
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = const Color(0x38FFFFFF));
    return rec.endRecording();
  }();

  void _drawFloor(Canvas canvas, double r0) {
    final r = sim.radius;
    final ice = sim.ice;
    // What the shrinking ring left behind: dark floor with the old edge faint.
    canvas.drawCircle(Offset.zero, r0, _fill..color = const Color(0xFF0F0F17));
    if (r < r0) canvas.drawPicture(_oldEdge);
    if (r <= 0) return;
    if (ice) {
      canvas.drawCircle(Offset.zero, r + 26, _fill..color = const Color(0x1F8FD8FF));
      canvas.drawCircle(Offset.zero, r, _fill..color = const Color(0xFF3B6489));
      canvas.drawCircle(Offset(-r * 0.12, -r * 0.16), r * 0.62, _fill..color = const Color(0x2EFFFFFF));
      canvas.drawLine(Offset(-r * 0.57, -r * 0.57), Offset(-r * 0.2, -r * 0.86),
          _stroke..strokeWidth = 14..strokeCap = StrokeCap.round..color = const Color(0x66FFFFFF));
      canvas.drawCircle(Offset.zero, r, _stroke..strokeWidth = 10..color = const Color(0xFFD8F3FF));
    } else {
      canvas.drawCircle(Offset.zero, r, _fill..color = const Color(0xFF262638));
      canvas.drawCircle(Offset.zero, r * 0.62, _stroke..strokeWidth = 3..color = const Color(0x0FFFFFFF));
      canvas.drawCircle(Offset.zero, r * 0.28, _stroke..strokeWidth = 3..color = const Color(0x14FFFFFF));
      canvas.drawLine(const Offset(-40, 0), const Offset(40, 0), _stroke..strokeWidth = 3..color = const Color(0x1AFFFFFF));
      canvas.drawLine(const Offset(0, -40), const Offset(0, 40), _stroke);
      canvas.drawCircle(Offset.zero, r, _stroke..strokeWidth = 10..color = const Color(0xFFF4F4F8));
    }
  }

  void _drawWrestler(Canvas canvas, SumoHead h, bool counting) {
    final c = Offset(h.x, h.y), r = h.r;
    if (sim.ice && !counting) {
      if (h.vx * h.vx + h.vy * h.vy > 150 * 150) {
        canvas.drawLine(c, Offset(h.x - h.vx * 0.18, h.y - h.vy * 0.18),
            _stroke..strokeWidth = r * 1.5..strokeCap = StrokeCap.round..color = _streak(h.id));
      }
    }
    canvas.drawCircle(Offset(h.x, h.y + 12), r + 6, _fill..color = const Color(0x59000000));
    canvas.drawCircle(c, r + 6, _fill..color = _ink);
    // The face is recorded once at the normal size and scaled (Velik is bigger).
    final box = r / 0.36, k = r / sim.config.wrestlerRadius;
    canvas
      ..save()
      ..translate(h.x - box / 2, h.y - box / 2)
      ..scale(k);
    canvas.drawPicture(_face(h.id));
    canvas.restore();
    if (ring.contains(h.id)) {
      canvas.drawCircle(c, r + 22, _stroke..strokeWidth = 8..color = const Color(0xFFFFFFFF));
    }
    if (!counting) _drawEffects(canvas, h);
  }

  // Active effects: a green ring that drains clockwise from the top round the wrestler, the icon on it.
  void _drawEffects(Canvas canvas, SumoHead h) {
    var n = 0;
    for (final kind in SumoPower.values) {
      final left = sim.effectLeft(h.id, kind);
      if (left <= 0) continue;
      final radius = h.r + 36 + n * 12, c = Offset(h.x, h.y);
      canvas.drawCircle(c, radius, _stroke..strokeWidth = 9..strokeCap = StrokeCap.butt..color = const Color(0x40FFFFFF));
      canvas.drawArc(Rect.fromCircle(center: c, radius: radius), -pi / 2, 2 * pi * left, false, _stroke..color = _green);
      _icon(canvas, kind, Offset(h.x, h.y - radius - 4), 28);
      n++;
    }
  }

  void _drawPowerUp(Canvas canvas, SumoPowerUp p) {
    final at = Offset(p.x, p.y);
    canvas.drawCircle(at, 60, _stroke..strokeWidth = 3..color = const Color(0x733DDC84));
    _icon(canvas, p.kind, at, 42);
    final tp = _labels[p.kind] ??= TextPainter(
      text: TextSpan(text: Strings.sumoPowerLabels[p.kind], style: TextStyle(fontFamily: CurveGame.fontFamily, fontSize: 34, fontWeight: FontWeight.w900, color: _ink)),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 24;
    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(p.x, p.y + 88), width: w, height: 44), const Radius.circular(10));
    canvas.drawRRect(rect, _fill..color = _green);
    tp.paint(canvas, Offset(p.x - tp.width / 2, p.y + 88 - tp.height / 2));
  }

  final _labels = <SumoPower, TextPainter>{};
  final _faces = <int, Picture>{};
  final _streaks = <int, Color>{};

  Picture _face(int id) => _faces[id] ??= () {
        final rec = PictureRecorder();
        CharacterFace.paintOn(Canvas(rec), Size.square(sim.config.wrestlerRadius / 0.36), characters[id] ?? '', _color(id));
        return rec.endRecording();
      }();

  Color _streak(int id) => _streaks[id] ??= _color(id).withValues(alpha: 0.3);

  static final _kettle = Path()
    ..moveTo(-18, 16)
    ..lineTo(-12, -4)
    ..lineTo(12, -4)
    ..lineTo(18, 16)
    ..close();
  static final _grow = Path()
    ..moveTo(6, -6)
    ..lineTo(18, -18)
    ..moveTo(8, -18)
    ..lineTo(18, -18)
    ..lineTo(18, -8)
    ..moveTo(-6, 6)
    ..lineTo(-18, 18)
    ..moveTo(-18, 8)
    ..lineTo(-18, 18)
    ..lineTo(-8, 18);
  static final _bolt = Path()
    ..moveTo(6, -22)
    ..lineTo(-12, 2)
    ..lineTo(-1, 2)
    ..lineTo(-6, 22)
    ..lineTo(14, -4)
    ..lineTo(3, -4)
    ..close();

  /// The power-up's round green icon (the Curve style: ink glyph on the colour disc).
  void _icon(Canvas canvas, SumoPower kind, Offset at, double r) {
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(r / 40);
    canvas.drawCircle(Offset.zero, 40, _fill..color = _green);
    canvas.drawCircle(Offset.zero, 40, _stroke..strokeWidth = 2..color = const Color(0x4014141E));
    canvas.scale(1.1);
    switch (kind) {
      case SumoPower.heavy:
        canvas.drawPath(_kettle, _fill..color = _ink);
        canvas.drawArc(Rect.fromCircle(center: const Offset(0, -4), radius: 8), pi, pi, false,
            _stroke..strokeWidth = 5..strokeCap = StrokeCap.round..color = _ink);
      case SumoPower.big:
        canvas.drawPath(_grow, _stroke..strokeWidth = 5.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = _ink);
        canvas.drawCircle(Offset.zero, 5, _fill..color = _ink);
      case SumoPower.fast:
        canvas.drawPath(_bolt, _fill..color = _ink);
    }
    canvas.restore();
  }

  final _digits = <int, TextPainter>{};
  void _drawCountdown(Canvas canvas) {
    final n = countdownSeconds;
    if (n <= 0) return;
    final tp = _digits[n] ??= TextPainter(
      text: TextSpan(text: '$n', style: TextStyle(fontFamily: CurveGame.fontFamily, fontSize: 200, fontWeight: FontWeight.w900, color: CurveGame.countdownColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }

  TextPainter? _hint;
  // Screen pixels, not ring units: 40 px, the sofa minimum, whatever the scale.
  void _drawHint(Canvas canvas, double free) {
    final tp = _hint ??= TextPainter(
      text: TextSpan(text: Strings.sumoCountdownHint, style: TextStyle(fontFamily: CurveGame.fontFamily, fontSize: 40, color: const Color(0xFFA9A9BC))),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.x - 80);
    tp.paint(canvas, Offset((size.x - tp.width) / 2, free - 12 - tp.height));
  }
}
