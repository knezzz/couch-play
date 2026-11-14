import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum EffectName {
  confetti,
  colorPulse,
  scorePop,

  /// A glow along the screen border only, so a death on the TV doesn't hide
  /// the playfield. Glows playing together share a ~25% opacity cap.
  edgeGlow,
}

/// The most opaque the border can get, however many glows stack.
const _glowCap = 0.25;

const _duration = {
  EffectName.confetti: Duration(milliseconds: 2500),
  EffectName.colorPulse: Duration(milliseconds: 600),
  EffectName.scorePop: Duration(milliseconds: 1000),
  EffectName.edgeGlow: Duration(milliseconds: 600),
};

// With disableAnimations the effect is one still frame held this long.
const _stillFor = Duration(milliseconds: 1000);
const _stillAt = 0.35;

/// Plays short effects over [child]. Call [play] with any context below it.
/// Effects never take touches. Each one owns a single AnimationController.
class EffectLayer extends StatefulWidget {
  const EffectLayer({super.key, required this.child});
  final Widget child;

  static void play(BuildContext context, EffectName name, {Color? color, String? text}) =>
      context.findAncestorStateOfType<_EffectLayerState>()?._add(name, color, text);

  @override
  State<EffectLayer> createState() => _EffectLayerState();
}

class _Live {
  _Live(this.id, this.name, this.color, this.text);
  final int id;
  final EffectName name;
  final Color? color;
  final String? text;
}

class _EffectLayerState extends State<EffectLayer> {
  final _live = <_Live>[];
  // How many edge glows are live; each one's opacity depends on it.
  final _glows = ValueNotifier<int>(1);
  var _next = 0;

  void _count() =>
      _glows.value = max(1, _live.where((e) => e.name == EffectName.edgeGlow).length);

  void _add(EffectName name, Color? color, String? text) => setState(() {
        _live.add(_Live(_next++, name, color, text));
        _count();
      });

  void _remove(int id) {
    if (!mounted) return;
    setState(() {
      _live.removeWhere((e) => e.id == id);
      _count();
    });
  }

  @override
  void dispose() {
    _glows.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      fit: StackFit.passthrough,
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        for (final e in _live)
          Positioned.fill(
            key: ValueKey(e.id),
            child: IgnorePointer(
              // Own layer: the effect repaints every frame, the child must not.
              child: RepaintBoundary(
                child: _Effect(e, _glows, reduced: reduced, onDone: () => _remove(e.id)),
              ),
            ),
          ),
      ],
    );
  }
}

class _Effect extends StatefulWidget {
  const _Effect(this.live, this.glows, {required this.reduced, required this.onDone});
  final _Live live;
  final ValueListenable<int> glows;
  final bool reduced;
  final VoidCallback onDone;

  @override
  State<_Effect> createState() => _EffectState();
}

class _EffectState extends State<_Effect> with SingleTickerProviderStateMixin {
  AnimationController? _c; // null when motion is off: no ticker at all
  Timer? _hold;
  late final Animation<double> _t;
  late final CustomPainter _painter;

  @override
  void initState() {
    super.initState();
    final l = widget.live;
    if (widget.reduced) {
      _t = const AlwaysStoppedAnimation(_stillAt);
      _hold = Timer(_stillFor, widget.onDone);
    } else {
      final c = _c = AnimationController(vsync: this, duration: _duration[l.name]);
      _t = c;
      c.forward().whenComplete(widget.onDone);
    }
    _painter = switch (l.name) {
      EffectName.confetti => _ConfettiPainter(_t),
      EffectName.colorPulse => _PulsePainter(_t, l.color ?? const Color(0xFFFF4D4D)),
      EffectName.scorePop => _PopPainter(_t, l.text ?? '', l.color ?? const Color(0xFFFFD23F)),
      EffectName.edgeGlow => _GlowPainter(_t, widget.glows, l.color ?? const Color(0xFFFF4D4D)),
    };
  }

  @override
  void dispose() {
    _hold?.cancel();
    _c?.dispose();
    final p = _painter;
    if (p is _PopPainter) p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _painter, size: Size.infinite);
}

// Bold flat colors.
const _colors = [
  Color(0xFFFF4D4D), Color(0xFFFFD23F), Color(0xFF3DDC84),
  Color(0xFF3FA7FF), Color(0xFFB36BFF), Color(0xFFFF8A3D),
];

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  // Fixed particles, built once: painting allocates nothing per frame but
  // the Offsets passed to the canvas.
  static const _n = 60;
  static final _x0 = List<double>.filled(_n, 0), _dx = List<double>.filled(_n, 0);
  static final _vy = List<double>.filled(_n, 0), _spin = List<double>.filled(_n, 0);
  static final _size = List<double>.filled(_n, 0);
  static final _ready = () {
    final r = Random(7);
    for (var i = 0; i < _n; i++) {
      _x0[i] = r.nextDouble();
      _dx[i] = (r.nextDouble() - .5) * .3;
      _vy[i] = .35 + r.nextDouble() * .35; // >= .35 so all are off screen at t=1
      _spin[i] = (r.nextDouble() - .5) * 14;
      _size[i] = 5 + r.nextDouble() * 5;
    }
    return true;
  }();

  final _paint = Paint()..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size s) {
    assert(_ready);
    final v = t.value;
    // Sized for the screen: ~2x the base size on a 1080p TV, smaller on a phone.
    final k = 2 * s.shortestSide / 1080;
    for (var i = 0; i < _n; i++) {
      final size = _size[i] * k;
      final x = s.width * (_x0[i] + _dx[i] * v);
      final y = s.height * (-.1 + _vy[i] * v + v * v);
      _paint.color = _colors[i % _colors.length];
      if (i.isEven) {
        canvas.drawCircle(Offset(x, y), size, _paint);
      } else {
        // A rounded bar, turning as it falls.
        final a = _spin[i] * v, dx = cos(a) * size * 1.5, dy = sin(a) * size * 1.5;
        _paint.strokeWidth = size;
        canvas.drawLine(Offset(x - dx, y - dy), Offset(x + dx, y + dy), _paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.t, this.color) : super(repaint: t);
  final Animation<double> t;
  final Color color;
  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size s) {
    _paint.color = color.withAlpha((sin(t.value * pi) * 120).round());
    canvas.drawRect(Offset.zero & s, _paint);
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.t != t || old.color != color;
}

class _PopPainter extends CustomPainter {
  _PopPainter(this.t, String text, Color color)
      : _text = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(color: color, fontSize: 96, fontWeight: FontWeight.w900),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
        super(repaint: t);
  final Animation<double> t;
  final TextPainter _text; // laid out once

  @override
  void paint(Canvas canvas, Size s) {
    final v = t.value;
    // Pops in with a little overshoot, rises, then shrinks away.
    final scale = (v < .25 ? Curves.easeOutBack.transform(v / .25) : 1.0) *
        (v > .8 ? (1 - v) / .2 : 1.0);
    canvas
      ..save()
      ..translate(s.width / 2, s.height * (.5 - .1 * v))
      ..scale(scale)
      ..translate(-_text.width / 2, -_text.height / 2);
    _text.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void dispose() => _text.dispose();

  @override
  bool shouldRepaint(_PopPainter old) => old.t != t;
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.t, this.glows, this.color) : super(repaint: Listenable.merge([t, glows]));
  final Animation<double> t;
  final ValueListenable<int> glows;
  final Color color;
  final _paint = Paint()..style = PaintingStyle.stroke;

  static const _bands = 6;
  static const _band = 14.0;

  @override
  void paint(Canvas canvas, Size s) {
    // n glows stacked on the same pixels composite to 1 - (1 - a)^n, so each
    // takes the share that keeps the total at the cap.
    final peak = 1 - pow(1 - _glowCap, 1 / glows.value);
    final a = peak * sin(t.value * pi);
    _paint.strokeWidth = _band;
    for (var i = 0; i < _bands; i++) {
      // Brightest at the very edge, fading inwards in flat steps.
      _paint.color = color.withAlpha((255 * a * (1 - i / _bands)).round());
      canvas.drawRect((Offset.zero & s).deflate(i * _band + _band / 2), _paint);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.t != t || old.glows != glows || old.color != color;
}
