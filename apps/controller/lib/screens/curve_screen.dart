import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import '../strings.dart';
import '../theme.dart';

/// Two big buttons in the player's colour; holding one steers. Each button
/// tracks its own pointers so two thumbs work.
class CurveScreen extends StatefulWidget {
  const CurveScreen(
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

  /// 1-based; null from an older TV, then the header shows the score only.
  final int? round;

  /// False after a crash: steering is inert until the next round.
  final bool alive;

  /// Set when the round is over: the buttons are inert and a card says how it ended.
  final RoundEnd? end;

  @override
  State<CurveScreen> createState() => _CurveScreenState();
}

class _CurveScreenState extends State<CurveScreen> {
  bool _left = false, _right = false;
  // Pointer ids per side live here, not in build(): the 1 s Pong rebuild must not reset them.
  // Ids, not a counter: a release the crash already cleared must not go below zero.
  final _held = [<int>{}, <int>{}];
  Timer? _ping;

  @override
  void initState() {
    super.initState();
    // 20 Hz, not 1 Hz: sparse traffic lets the TV's Wi-Fi sleep (p95 ~114 ms
    // at 1 Hz vs ~19 ms at 10 Hz on the Mac), and this keeps the radio warm for steering.
    _ping = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => widget.conn.send(Ping(DateTime.now().millisecondsSinceEpoch)),
    );
  }

  @override
  void didUpdateWidget(CurveScreen old) {
    super.didUpdateWidget(old);
    if ((old.alive && !widget.alive) || (old.end == null && widget.end != null)) {
      // Ignored pointers never send their release, so release for them or the
      // TV keeps turning this player.
      final held = _left || _right;
      _held[0].clear();
      _held[1].clear();
      if (held) _set(left: false, right: false);
    }
  }

  @override
  void dispose() {
    _ping?.cancel();
    super.dispose();
  }

  void _set({bool? left, bool? right}) {
    _left = left ?? _left;
    _right = right ?? _right;
    widget.conn.send(Steer(left: _left, right: _right));
  }

  void _release(int side, int pointer, void Function(bool) set) {
    if (_held[side].remove(pointer) && _held[side].isEmpty) set(false);
  }

  Widget _half(int side, bool left, void Function(bool) set, Color color) {
    return Expanded(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (_held[side].add(e.pointer) && _held[side].length == 1) set(true);
        },
        onPointerUp: (e) => _release(side, e.pointer, set),
        onPointerCancel: (e) => _release(side, e.pointer, set),
        child: Semantics(
          button: true,
          label: left ? Strings.steerLeft : Strings.steerRight,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(28),
            ),
            alignment: Alignment.center,
            // Drawn: the glyphs fall back to an emoji font on some phones.
            child: CustomPaint(
              key: ValueKey(left ? 'steer-left' : 'steer-right'),
              size: const Size(96, 96),
              painter: _ChevronPainter(left),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = playerColors[widget.colorIndex % playerColors.length];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                        key: const ValueKey('curve-name'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      widget.round == null
                          ? Strings.curveScore(widget.score)
                          : Strings.curveRoundScore(
                              widget.round!,
                              widget.score,
                            ),
                      key: const ValueKey('curve-score'),
                      style: const TextStyle(fontSize: 18, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Stack(
                  children: [
                    IgnorePointer(
                      ignoring: !widget.alive || widget.end != null,
                      child: Row(
                        children: [
                          _half(0, true, (v) => _set(left: v), color),
                          const SizedBox(width: 12),
                          _half(1, false, (v) => _set(right: v), color),
                        ],
                      ),
                    ),
                    if (!widget.alive || widget.end != null)
                      Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xF2000000),
                            borderRadius: BorderRadius.circular(24),
                          ),
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
                                    null => Strings.crashed,
                                  },
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (widget.end != null) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    Strings.nextRoundSoon,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 20, color: muted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                Strings.curveHint,
                key: ValueKey('curve-hint'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: muted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.left);
  final bool left;

  @override
  void paint(Canvas canvas, Size s) {
    // The board's 64-unit chevron, scaled to the box.
    final k = s.width / 64;
    Offset p(double x, double y) => Offset((left ? x : 64 - x) * k, y * k);
    canvas.drawPath(
      Path()
        ..moveTo(p(40, 12).dx, p(40, 12).dy)
        ..lineTo(p(20, 32).dx, p(20, 32).dy)
        ..lineTo(p(40, 52).dx, p(40, 52).dy),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.left != left;
}
