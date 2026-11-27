import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import '../strings.dart';
import '../theme.dart';

/// Sumo's controls (Task 55; boards SumoPhone and SumoPhoneSmall). A floating joystick on the left
/// half (the base appears where the thumb lands; 16 directions, 3 force steps, sent only when one
/// changes) and the Dash button on the right half, with a ring that drains while it recharges.
/// Each half tracks its own pointer, so two thumbs work.
class SumoScreen extends StatefulWidget {
  const SumoScreen(
    this.conn, {
    this.alive = true,
    this.name = '',
    this.character = '',
    this.colorIndex = 0,
    this.score = 0,
    this.round,
    this.end,
    super.key,
  });
  final Connection conn;

  /// For the header: who this phone is and its score in the match.
  final String name, character;
  final int colorIndex, score;

  /// 1-based; null from an older TV.
  final int? round;

  /// False once out of the ring: the controls are inert until the next round.
  final bool alive;

  /// Set when the round is over: the controls are inert and a card says how it ended.
  final RoundEnd? end;

  @override
  State<SumoScreen> createState() => _SumoScreenState();
}

/// How far the thumb must travel before it pushes, and the pull (in dp) that counts as full force.
const _deadZone = 12.0, _stickRadius = 56.0;

/// The dash recharge, as the TV counts it.
const _recharge = Duration(seconds: 2);

class _SumoScreenState extends State<SumoScreen> with SingleTickerProviderStateMixin {
  Timer? _ping;
  late final AnimationController _cd = AnimationController(vsync: this, duration: _recharge);
  int _dir = 0, _force = 0; // what the TV was last told
  int? _stick; // the pointer on the stick
  Offset _origin = Offset.zero, _pos = Offset.zero;

  bool get _inert => !widget.alive || widget.end != null;

  @override
  void initState() {
    super.initState();
    // 20 Hz like Curve: sparse traffic lets the TV's Wi-Fi sleep, and this keeps the radio warm for pushing.
    _ping = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => widget.conn.send(Ping(DateTime.now().millisecondsSinceEpoch)),
    );
  }

  @override
  void didUpdateWidget(SumoScreen old) {
    super.didUpdateWidget(old);
    if (_inert && !(old.alive == widget.alive && old.end == widget.end)) _letGo();
  }

  @override
  void dispose() {
    _ping?.cancel();
    _cd.dispose();
    super.dispose();
  }

  void _send(int dir, int force) {
    _dir = dir;
    _force = force;
    widget.conn.send(SumoMove(dir, force));
  }

  /// The stick is let go (the thumb lifted, or the round ended under it).
  void _letGo() {
    if (_force != 0) _send(_dir, 0);
    if (_stick != null) setState(() => _stick = null);
  }

  void _down(PointerDownEvent e) {
    if (_stick != null || _inert) return;
    setState(() {
      _stick = e.pointer;
      _origin = _pos = e.localPosition;
    });
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _stick || _inert) return;
    setState(() => _pos = e.localPosition);
    final v = _pos - _origin, d = v.distance;
    if (d < _deadZone) {
      if (_force != 0) _send(_dir, 0);
      return;
    }
    final f = d / _stickRadius;
    final force = f < 0.4 ? 1 : (f < 0.75 ? 2 : 3);
    final q = atan2(-v.dy, v.dx) / (pi / 8); // the direction in steps of 22.5 degrees
    // Hysteresis: once moving, stay on the current step until the thumb is 4.5 degrees past its edge,
    // so a thumb on the line between two steps does not flip back and forth.
    var off = (q - _dir) % 16;
    if (off > 8) off -= 16;
    final dir = _force != 0 && off.abs() < 0.7 ? _dir : q.round() & 15;
    if (dir != _dir || force != _force) _send(dir, force);
  }

  void _up(PointerEvent e) {
    if (e.pointer != _stick) return;
    _letGo();
  }

  void _dash() {
    if (_inert || _cd.isAnimating) return;
    _cd.forward(from: 0);
    widget.conn.send(const SumoDash());
  }

  @override
  Widget build(BuildContext context) {
    final color = playerColors[widget.colorIndex % playerColors.length];
    final big = MediaQuery.sizeOf(context).height > 700;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(big ? 16 : 12, big ? 12 : 8, big ? 16 : 12, big ? 16 : 12),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    if (widget.character.isNotEmpty) ...[
                      CharacterFace(widget.character, 40, color),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        widget.name,
                        key: const ValueKey('sumo-name'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      widget.round == null ? Strings.curveScore(widget.score) : Strings.curveRoundScore(widget.round!, widget.score),
                      key: const ValueKey('sumo-score'),
                      style: const TextStyle(fontSize: 14, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _stickZone(color, big)),
                        const SizedBox(width: 12),
                        Expanded(child: _dashZone(color, big)),
                      ],
                    ),
                    if (_inert) _card(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                Strings.sumoHint,
                key: const ValueKey('sumo-hint'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: big ? 15 : 14, color: muted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, bool big) => Padding(
        padding: EdgeInsets.only(top: big ? 28 : 18),
        child: Text(text, style: TextStyle(fontSize: big ? 18 : 15, fontWeight: FontWeight.w700, color: muted)),
      );

  Widget _stickZone(Color color, bool big) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: Semantics(
        label: Strings.sumoDragHint,
        child: Container(
          key: const ValueKey('sumo-stick'),
          decoration: BoxDecoration(
            color: const Color(0xFF181824),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: raised, width: 2),
          ),
          child: LayoutBuilder(
            builder: (_, box) => Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _StickPainter(
                      color,
                      // At rest the faint base sits low in the zone, where a thumb rests; mid-drag it is under the thumb.
                      _stick == null ? Offset(box.maxWidth / 2, box.maxHeight * 0.58) : _origin,
                      _stick == null ? null : _pos,
                      big ? 62 : 54,
                    ),
                  ),
                ),
                Align(alignment: Alignment.topCenter, child: _label(Strings.sumoDragHint, big)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashZone(Color color, bool big) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _dash(),
      child: Semantics(
        button: true,
        label: Strings.sumoDash,
        child: Container(
          key: const ValueKey('sumo-dash'),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: raised, width: 2),
          ),
          child: AnimatedBuilder(
            animation: _cd,
            builder: (_, _) {
              final left = _cd.isAnimating ? 1 - _cd.value : 0.0; // 1 just after a dash, 0 when ready
              return LayoutBuilder(
                builder: (_, box) => Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _DashPainter(color, left, big ? 70 : 62))),
                    Align(alignment: Alignment.topCenter, child: _label(Strings.sumoDash, big)),
                    if (left > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: box.maxHeight * 0.58 + (big ? 70 : 62) + (big ? 26 : 20),
                        child: Text(
                          Strings.sumoRecharge(left * _recharge.inMilliseconds / 1000),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: big ? 20 : 17, fontWeight: FontWeight.w900, color: color),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _card() => Center(
        child: DecoratedBox(
          decoration: BoxDecoration(color: const Color(0xF2000000), borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  switch (widget.end) {
                    RoundEnd.won => Strings.roundWon,
                    RoundEnd.tie => Strings.roundTie,
                    RoundEnd.over => Strings.roundOver,
                    null => Strings.sumoOut,
                  },
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                if (widget.end != null) ...[
                  const SizedBox(height: 12),
                  const Text(Strings.nextRoundSoon, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: muted)),
                ],
              ],
            ),
          ),
        ),
      );
}

/// The joystick: a base with 16 notches, a line and a knob pushed toward the thumb (SumoPhone board).
class _StickPainter extends CustomPainter {
  _StickPainter(this.color, this.origin, this.thumb, this.baseRadius);
  final Color color;
  final Offset origin;

  /// Null while nobody touches it.
  final Offset? thumb;
  final double baseRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final active = thumb != null;
    canvas.drawCircle(
      origin,
      baseRadius,
      Paint()..color = const Color(0xFF2A2A3A).withValues(alpha: active ? 0.6 : 0.35),
    );
    canvas.drawCircle(
      origin,
      baseRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = muted.withValues(alpha: active ? 0.45 : 0.25),
    );
    final tick = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = muted.withValues(alpha: active ? 0.5 : 0.25);
    for (var k = 0; k < 16; k++) {
      final a = k * pi / 8;
      canvas.drawLine(
        origin + Offset(cos(a), sin(a)) * (baseRadius + 8),
        origin + Offset(cos(a), sin(a)) * (baseRadius + 16),
        tick,
      );
    }
    final t = thumb;
    if (t == null) return;
    var v = t - origin;
    if (v.distance > baseRadius) v = v / v.distance * baseRadius; // the knob stays on the base
    canvas.drawLine(
      origin,
      origin + v,
      Paint()
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.6),
    );
    canvas.drawCircle(origin + v, baseRadius * 0.55, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StickPainter old) =>
      old.origin != origin || old.thumb != thumb || old.color != color || old.baseRadius != baseRadius;
}

/// Dash: a ring round a double chevron. Full and coloured when ready; while recharging the coloured
/// arc drains clockwise from the top ([left] 1 down to 0).
class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.left, this.radius);
  final Color color;
  final double left, radius;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.58);
    final ready = left <= 0;
    final w = radius > 66 ? 14.0 : 12.0;
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = raised,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      -pi / 2,
      2 * pi * (ready ? 1 : left),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.drawCircle(c, radius - w, Paint()..color = ready ? color : raised);
    final glyph = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ready ? ink : textColor.withValues(alpha: 0.55);
    for (final dx in [-12.0, 12.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + dx - 10, c.dy - 20)
          ..lineTo(c.dx + dx + 12, c.dy)
          ..lineTo(c.dx + dx - 10, c.dy + 20),
        glyph,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.left != left || old.color != color || old.radius != radius;
}
