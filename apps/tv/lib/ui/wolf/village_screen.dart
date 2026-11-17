import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../tv_theme.dart';

/// One player's house on the village: just what the square may show. There is
/// deliberately no role here.
class VillagePlayer {
  const VillagePlayer({
    required this.id,
    required this.name,
    required this.colorIndex,
    this.character = '',
    this.out = false,
    this.lit = false,
  });
  final int id;
  final String name;
  final int colorIndex;
  final String character;

  /// Out of the game: the house is closed up, with blood around it and a crow.
  final bool out;

  /// At night: still deciding, so the window is lit.
  final bool lit;
}

/// Where each house stands: round the square, the first at the top, then clockwise.
List<Offset> villageSpots(int n) => [
      for (var i = 0; i < n; i++)
        Offset(
          (960 + 560 * cos(-pi / 2 + i * 2 * pi / n)).roundToDouble(),
          (590 + 330 * sin(-pi / 2 + i * 2 * pi / n)).roundToDouble(),
        ),
    ];

/// The village (docs/design/couchplay-screens/Village.dc.html), drawn in code on a
/// 1920x1080 canvas scaled to fit: each player's house round the square, the
/// story and the clock in the middle. [night]: dark with lit windows; else daylight.
///
/// Two layers keep it cheap on the TV: the still scene is painted once and only
/// again when the players or the time of day change; a light animation layer
/// (smoke, flickering windows, stars, fireflies, clouds, swaying trees, crows)
/// repaints each frame without allocating, and stands still with reduced motion.
class VillageScreen extends StatefulWidget {
  const VillageScreen({
    required this.players,
    required this.night,
    required this.kicker,
    required this.story,
    required this.clock,
    super.key,
  });
  final List<VillagePlayer> players;
  final bool night;
  final String kicker, story, clock;

  @override
  State<VillageScreen> createState() => _VillageScreenState();
}

class _VillageScreenState extends State<VillageScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _time = AnimationController(vsync: this, duration: const Duration(seconds: 60));
  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    if (reduced) {
      _time.stop();
    } else {
      _time.repeat();
    }
  }

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final night = widget.night, spots = villageSpots(widget.players.length);
    final pal = _Scene(night);
    return Scaffold(
      backgroundColor: pal.skyBottom,
      body: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: pal.sky,
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _StillPainter(widget.players, spots, night)),
                ),
              ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _LivePainter(widget.players, spots, night, _time)),
                ),
              ),
              for (var i = 0; i < widget.players.length; i++) _label(widget.players[i], spots[i], i, night),
              Positioned(
                left: 660,
                top: 505,
                width: 600,
                height: 330,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(widget.kicker,
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 4, color: night ? const Color(0xFF8FA0D8) : const Color(0xFF7A3A2A))),
                    const SizedBox(height: 8),
                    // A long story scales down to fit the square.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 170, maxWidth: 600),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 600,
                          child: Text(widget.story,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 34,
                                height: 1.3,
                                color: night ? tvText : const Color(0xFF2A1E2E),
                                shadows: night ? const [Shadow(blurRadius: 8, offset: Offset(0, 2))] : null,
                              )),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.clock,
                        style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: night ? tvText : const Color(0xFF2A1E2E))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(VillagePlayer p, Offset spot, int i, bool night) {
    final angle = -pi / 2 + i * 2 * pi / widget.players.length;
    final below = sin(angle) > 0.2;
    final color = p.out ? const Color(0xFF6E6E7A) : playerColors[p.colorIndex % playerColors.length];
    Widget row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (p.character.isNotEmpty) ...[PlayerDot(color, size: 52, character: p.character), const SizedBox(width: 10)],
        Flexible(
          child: Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              decoration: p.out ? TextDecoration.lineThrough : TextDecoration.none,
              color: p.out ? const Color(0xFF8A8A96) : (night ? const Color(0xFFE3E8FA) : const Color(0xFF2A1E2E)),
              shadows: night && !p.out ? const [Shadow(blurRadius: 6, offset: Offset(0, 2))] : null,
            ),
          ),
        ),
      ],
    );
    if (p.out) row = Opacity(opacity: 0.55, child: row);
    return Positioned(
      key: ValueKey('house-${p.id}'),
      left: spot.dx - 130,
      top: below ? spot.dy + 92 : spot.dy - 156,
      width: 260,
      child: row,
    );
  }
}

// ---------------------------------------------------------------------------

Color _c(int rgb, [double alpha = 1]) => Color(0xFF000000 | rgb).withValues(alpha: alpha);

/// The day or night colours of everything that is not a house.
class _Scene {
  _Scene(this.night)
      : sky = night ? [_c(0x05060F), _c(0x0C1430), _c(0x101A3A)] : [_c(0x9FD3F0), _c(0xE8F3F8), _c(0xF6E2B8)],
        hill = _c(night ? 0x0B1226 : 0x8DBF6A),
        grassTop = _c(night ? 0x13203A : 0x9ACB72),
        grassBottom = _c(night ? 0x0C152A : 0x7CB35A),
        square = _c(night ? 0x232C48 : 0xE2D0A8),
        squareEdge = _c(night ? 0x323C5E : 0xC7AF82),
        trunk = _c(night ? 0x3A2E2A : 0x7A5236),
        leaf = _c(night ? 0x16302A : 0x4E9A4A),
        well = _c(night ? 0x3A4262 : 0xB9B3A8),
        wellTop = _c(night ? 0x1A2038 : 0x5A6A7A),
        wellRoof = _c(night ? 0x5A2E36 : 0xC2563E);
  final bool night;
  final List<Color> sky;
  Color get skyBottom => sky.last;
  final Color hill, grassTop, grassBottom, square, squareEdge, trunk, leaf, well, wellTop, wellRoof;
}

/// One house's colours.
class _House {
  _House(bool night, this.out, bool lit)
      : wall = _c(out ? 0x55505A : (night ? 0x3B4466 : 0xF5ECDA)),
        wallShade = _c(out ? 0x48434C : (night ? 0x323A58 : 0xE6D9BF)),
        roof = _c(out ? 0x3A3036 : (night ? 0x5A2E36 : 0xC2563E)),
        roofLine = _c(out ? 0x2E262B : (night ? 0x4A262D : 0xA9472F)),
        roofEdge = _c(out ? 0x2E262B : (night ? 0x40222A : 0x8F3A26)),
        chimney = _c(out ? 0x3A3036 : (night ? 0x4A3A40 : 0x9A6B55)),
        door = _c(out ? 0x2A2024 : (night ? 0x2A2238 : 0x7A4A2E)),
        knob = _c(out ? 0x2A2024 : 0xE7B36A),
        win = _c(out ? 0x2A2024 : (night ? (lit ? 0xF7D774 : 0x1A1E34) : 0xA9D4F0)),
        frame = _c(out ? 0x2A2024 : (night ? 0xC9A64A : 0xFFFFFF)),
        shutter = _c(out ? 0x3A2E26 : (night ? 0x2E5A46 : 0x3E7A5C));
  final bool out;
  final Color wall, wallShade, roof, roofLine, roofEdge, chimney, door, knob, win, frame, shutter;
}

/// The scene that only changes when a house changes or day turns to night.
class _StillPainter extends CustomPainter {
  _StillPainter(this.players, this.spots, this.night)
      : sig = '$night|${[for (final p in players) '${p.id}${p.out ? 1 : 0}${p.lit ? 1 : 0}'].join(',')}';
  final List<VillagePlayer> players;
  final List<Offset> spots;
  final bool night;
  final String sig;

  final _fill = Paint();
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1920, size.height / 1080);
    final s = _Scene(night);
    if (night) {
      canvas.drawCircle(
          const Offset(1700, 150),
          200,
          _fill
            ..shader = const RadialGradient(colors: [Color(0x40F2E9C9), Color(0x00F2E9C9)], stops: [0.6, 1])
                .createShader(Rect.fromCircle(center: const Offset(1700, 150), radius: 200)));
      _fill.shader = null;
      canvas.drawCircle(const Offset(1700, 150), 70, _fill..color = _c(0xF2E9C9));
      _fill.color = _c(0xE2D7B0);
      canvas.drawCircle(const Offset(1724, 128), 12, _fill);
      canvas.drawCircle(const Offset(1680, 176), 8, _fill);
    } else {
      canvas.drawCircle(const Offset(260, 150), 80, _fill..color = _c(0xFFE7A3));
    }
    canvas.drawPath(
        Path()
          ..moveTo(0, 330)
          ..quadraticBezierTo(480, 250, 960, 300)
          ..quadraticBezierTo(1440, 350, 1920, 320)
          ..lineTo(1920, 1080)
          ..lineTo(0, 1080)
          ..close(),
        _fill..color = s.hill);
    final grass = Rect.fromCenter(center: const Offset(960, 590), width: 1800, height: 940);
    canvas.drawOval(
        grass,
        _fill
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [s.grassTop, s.grassBottom])
              .createShader(grass));
    _fill.shader = null;
    final sq = Rect.fromCenter(center: const Offset(960, 590), width: 640, height: 440);
    canvas.drawOval(sq, _fill..color = s.square);
    canvas.drawOval(sq, _line..color = s.squareEdge..strokeWidth = 10);
    canvas.drawOval(Rect.fromCenter(center: const Offset(960, 590), width: 560, height: 372),
        _line..color = s.squareEdge.withValues(alpha: 0.5)..strokeWidth = 3);
    for (var i = 0; i < players.length; i++) {
      _house(canvas, spots[i], _House(night, players[i].out, night && players[i].lit && !players[i].out));
    }
    // The well, at the top of the square so the story has the rest.
    canvas
      ..save()
      ..translate(960, 462);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-34, -30, 68, 44), const Radius.circular(6)), _fill..color = s.well);
    canvas.drawOval(const Rect.fromLTWH(-34, -40, 68, 20), _fill..color = s.wellTop);
    canvas.drawPath(
        Path()
          ..moveTo(-28, -30)
          ..lineTo(-28, -70)
          ..lineTo(28, -70)
          ..lineTo(28, -30),
        _line..color = s.trunk..strokeWidth = 6);
    canvas.drawPath(
        Path()
          ..moveTo(-40, -66)
          ..lineTo(0, -90)
          ..lineTo(40, -66)
          ..close(),
        _fill..color = s.wellRoof);
    canvas.restore();
    canvas.restore();
  }

  void _house(Canvas canvas, Offset at, _House h) {
    canvas
      ..save()
      ..translate(at.dx, at.dy);
    canvas.drawOval(const Rect.fromLTWH(-104, 60, 208, 36), _fill..color = const Color(0x2E000000));
    if (h.out) {
      _fill.color = _c(0x9E1B1B);
      for (final b in const [Rect.fromLTWH(-116, 24, 24, 16), Rect.fromLTWH(86, 62, 22, 16), Rect.fromLTWH(-72, 84, 24, 20), Rect.fromLTWH(38, 90, 26, 20), Rect.fromLTWH(-134, 0, 18, 14), Rect.fromLTWH(112, -10, 16, 12)]) {
        canvas.drawOval(b, _fill);
      }
      for (final d in const [(Offset(-34, 104), 8.0), (Offset(74, 36), 6.0), (Offset(-90, 70), 5.0), (Offset(10, 118), 4.0)]) {
        canvas.drawCircle(d.$1, d.$2, _fill);
      }
    }
    canvas.drawRect(const Rect.fromLTWH(38, -96, 20, 40), _fill..color = h.chimney);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-72, -14, 144, 90), const Radius.circular(4)), _fill..color = h.wall);
    canvas.drawRect(const Rect.fromLTWH(-72, -14, 144, 12), _fill..color = h.wallShade);
    final roof = Path()
      ..moveTo(-90, -6)
      ..lineTo(0, -86)
      ..lineTo(90, -6);
    canvas.drawPath(roof..close(), _fill..color = h.roof);
    _line
      ..color = h.roofLine
      ..strokeWidth = 4;
    canvas.drawPath(
        Path()
          ..moveTo(-70, -24)
          ..lineTo(70, -24)
          ..moveTo(-50, -42)
          ..lineTo(50, -42)
          ..moveTo(-30, -60)
          ..lineTo(30, -60),
        _line);
    canvas.drawPath(
        Path()
          ..moveTo(-90, -6)
          ..lineTo(0, -86)
          ..lineTo(90, -6),
        _line
          ..color = h.roofEdge
          ..strokeWidth = 8);
    canvas.drawRRect(RRect.fromLTRBAndCorners(-20, 22, 20, 76, topLeft: const Radius.circular(20), topRight: const Radius.circular(20)), _fill..color = h.door);
    canvas.drawCircle(const Offset(10, 52), 3, _fill..color = h.knob);
    _fill.color = h.win;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-58, 8, 28, 26), const Radius.circular(3)), _fill);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, 8, 28, 26), const Radius.circular(3)), _fill);
    _line
      ..color = h.frame
      ..strokeWidth = 3;
    canvas.drawPath(
        Path()
          ..moveTo(-44, 8)
          ..lineTo(-44, 34)
          ..moveTo(-58, 21)
          ..lineTo(-30, 21)
          ..moveTo(44, 8)
          ..lineTo(44, 34)
          ..moveTo(30, 21)
          ..lineTo(58, 21),
        _line);
    _fill.color = h.shutter;
    for (final x in const [-66.0, -28.0, 22.0, 60.0]) {
      canvas.drawRect(Rect.fromLTWH(x, 6, 6, 30), _fill);
    }
    if (h.out) {
      _line
        ..color = _c(0x5A3E28)
        ..strokeWidth = 8;
      canvas.drawPath(
          Path()
            ..moveTo(-62, 4)
            ..lineTo(-26, 36)
            ..moveTo(-26, 4)
            ..lineTo(-62, 36)
            ..moveTo(26, 4)
            ..lineTo(62, 36)
            ..moveTo(62, 4)
            ..lineTo(26, 36),
          _line);
      canvas.drawPath(
          Path()
            ..moveTo(-26, 34)
            ..lineTo(26, 54)
            ..moveTo(-26, 56)
            ..lineTo(26, 72),
          _line..strokeWidth = 9);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StillPainter old) => old.sig != sig;
}

/// The light animation. [time] runs 0..1 over 60 s; every motion is a simple
/// function of the seconds, so nothing is stored or allocated per frame.
class _LivePainter extends CustomPainter {
  _LivePainter(this.players, this.spots, this.night, this.time) : super(repaint: time);
  final List<VillagePlayer> players;
  final List<Offset> spots;
  final bool night;
  final Animation<double> time;

  final _p = Paint();
  Shader? _glow;

  static const _trees = [Offset(130, 520), Offset(1790, 540), Offset(380, 960), Offset(1560, 980), Offset(700, 230), Offset(1240, 230)];

  // Pseudo-random but fixed, like the sketch's: stars and fireflies.
  static double _rnd(int i, double m) => ((i * 9301 + 49297) % 233280) / 233280 * m;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1920, size.height / 1080);
    final t = time.value * 60;
    final s = _Scene(night);
    double wave(double period, [double delay = 0]) => 0.5 + 0.5 * sin(2 * pi * (t + delay) / period);

    if (night) {
      for (var i = 0; i < 22; i++) {
        _p.color = Color.fromRGBO(255, 255, 255, 0.25 + 0.75 * wave(2.6, (i % 7) * 0.4));
        canvas.drawCircle(Offset(_rnd(i + 1, 1920).roundToDouble(), _rnd(i + 50, 260).roundToDouble()), 1.5 + (i % 3), _p);
      }
    } else {
      _cloud(canvas, 120, 60, (t / 60) % 1);
      _cloud(canvas, 220, 70, (t / 60 + 0.5) % 1);
    }
    // Trees sway.
    for (var i = 0; i < _trees.length; i++) {
      canvas
        ..save()
        ..translate(_trees[i].dx, _trees[i].dy)
        ..rotate((wave(5, i * 0.7) * 4 - 2) * pi / 180);
      _p.color = s.trunk;
      canvas.drawRect(const Rect.fromLTWH(-6, -10, 12, 40), _p);
      _p.color = s.leaf;
      canvas.drawCircle(const Offset(0, -36), 34, _p);
      canvas.drawCircle(const Offset(-20, -18), 24, _p);
      canvas.drawCircle(const Offset(20, -18), 24, _p);
      canvas.restore();
    }
    for (var i = 0; i < players.length; i++) {
      canvas
        ..save()
        ..translate(spots[i].dx, spots[i].dy);
      if (players[i].out) {
        // The crow bobs on the roof.
        _p.color = _c(0x14141E);
        final bob = -3 * wave(1.4);
        canvas.drawOval(Rect.fromLTWH(-30, -88 + bob, 34, 14), _p);
        canvas.drawCircle(Offset(2, -90 + bob), 6, _p);
        _p.color = _c(0xFFB020);
        canvas.drawCircle(Offset(4, -91 + bob), 1.6, _p);
      } else {
        if (night && players[i].lit) {
          _glow ??= const RadialGradient(colors: [Color(0x8CFFD98A), Color(0x00FFD98A)])
              .createShader(const Rect.fromLTWH(-140, -50, 280, 180));
          final flick = 0.78 + 0.22 * wave(3.2, i * 0.5);
          canvas.drawOval(const Rect.fromLTWH(-140, -50, 280, 180), _p..shader = _glow..color = Color.fromRGBO(255, 255, 255, flick));
          _p.shader = null;
        }
        for (var k = 0; k < 3; k++) {
          final q = (t / 4 + k * 0.325 + i * 0.13) % 1;
          final a = q < 0.2 ? 0.55 * q / 0.2 : 0.55 * (1 - q) / 0.8;
          _p.color = (night ? _c(0x8A93B8) : const Color(0xFFFFFFFF)).withValues(alpha: a);
          canvas.drawCircle(Offset(48 + 14 * q, -104 - 70 * q), 10 * (0.6 + q), _p);
        }
      }
      canvas.restore();
    }
    if (night) {
      for (var i = 0; i < 9; i++) {
        final x = 300 + _rnd(i + 9, 1320) + 12 * sin(2 * pi * (t + i) / 3) - 6 * cos(2 * pi * (t + i) / 6);
        final y = 380 + _rnd(i + 30, 560) - 14 * wave(3, i * 0.6);
        _p.color = Color.fromRGBO(247, 229, 138, 0.25 + 0.75 * wave(2.6, (i % 5) * 0.6));
        canvas.drawCircle(Offset(x, y), 3, _p);
      }
    }
    canvas.restore();
  }

  void _cloud(Canvas canvas, double y, double scale, double q) {
    final x = -300 + 2500 * q;
    _p.color = const Color(0xCCFFFFFF);
    canvas.drawOval(Rect.fromCenter(center: Offset(x + 60, y), width: 190, height: 44), _p);
    canvas.drawOval(Rect.fromCenter(center: Offset(x + 40, y - 18), width: 90, height: 40), _p);
    canvas.drawOval(Rect.fromCenter(center: Offset(x + 100, y - 14), width: 80, height: 36), _p);
  }

  @override
  bool shouldRepaint(_LivePainter old) =>
      old.night != night || old.players.length != players.length || !_same(old.players);

  bool _same(List<VillagePlayer> o) {
    for (var i = 0; i < o.length; i++) {
      if (o[i].out != players[i].out || o[i].lit != players[i].lit) return false;
    }
    return true;
  }
}
