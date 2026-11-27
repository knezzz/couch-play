import 'dart:math';
import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../session/tenkovi_match.dart';
import '../curve/name_strip.dart';
import '../curve/winner_banner.dart';
import '../tv_theme.dart';
import 'tenkovi_text.dart';

/// Tenkovi on the TV (boards TenkoviTvAim, TenkoviTvVolley, TenkoviTvMaps,
/// TenkoviTvWinner): hills across the full width, tanks, and the volley.
///
/// PRIVACY: before the volley this reads only [TenkoviTvMatch.ready] and
/// [TenkoviTvMatch.round]'s public state. Tanks are drawn with no barrel while
/// players aim; a barrel is drawn only for a volley that has already fired
/// ([TenkoviTvMatch.volleyAims] is empty until then), and shells appear only
/// once fired.
///
/// PERFORMANCE: the sky and the ground are one cached [ui.Picture], redrawn
/// only when a crater changes [TenkoviRound.terrainVersion]; each frame draws
/// 8 tanks, the shells and a few blasts, with no per-frame text layout (names
/// are laid out once per round) and no per-frame Path building (trails grow
/// one Path per shell).
class TenkoviView extends StatefulWidget {
  const TenkoviView({required this.match, required this.players, super.key});
  final TenkoviTvMatch match;
  final List<PlayerInfo> players;

  @override
  State<TenkoviView> createState() => _TenkoviViewState();
}

class _Blast {
  _Blast(this.x, this.y, this.r);
  final double x, y, r;
  double age = 0; // seconds
}

class _Trail {
  _Trail(this.color);
  final Color color;
  final path = Path();
  final dots = <Offset>[];
  bool started = false;
  int frames = 0;
}

/// Colors per map: sky top, sky horizon, far hills, ground, ground edge.
({Color sky0, Color sky1, Color far, Color ground, Color edge}) _palette(TenkoviMap m) => switch (m) {
      TenkoviMap.earth => (
          sky0: const Color(0xFF131A33),
          sky1: const Color(0xFF2E3F78),
          far: const Color(0xFF1F2B52),
          ground: const Color(0xFF4B3A32),
          edge: const Color(0xFF6D8F4E),
        ),
      TenkoviMap.moon => (
          sky0: const Color(0xFF03040A),
          sky1: const Color(0xFF0B0D1C),
          far: const Color(0xFF1A1B2A),
          ground: const Color(0xFF7C7C8A),
          edge: const Color(0xFFB8B8C8),
        ),
      TenkoviMap.mars => (
          sky0: const Color(0xFF2B1613),
          sky1: const Color(0xFF8C4A32),
          far: const Color(0xFF9A3E26),
          ground: const Color(0xFF6B3322),
          edge: const Color(0xFFD9764F),
        ),
    };

class _TenkoviViewState extends State<TenkoviView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  Duration _last = Duration.zero;

  TenkoviRound? _round; // the round the cached pictures belong to
  int _terrainVersion = -1;
  ui.Picture? _ground;
  final _names = <int, TextPainter>{};
  final _faces = <int, ui.Picture>{}; // each commander's face, recorded once per round
  final _trails = <TenkoviShot, _Trail>{};
  List<Offset> _oldDots = const []; // the faint dots of the last volley
  final _blasts = <_Blast>[];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick); // started only while something moves
  }

  void _wake() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _ground?.dispose();
    for (final f in _faces.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final m = widget.match;
    var busy = _blasts.isNotEmpty;
    // The match flies the volley itself (so a pause or a hidden view cannot lose
    // it); the view only draws what is in the air, once a frame.
    if (m.stage == TenkoviStageTv.fly && !m.paused) {
      busy = true;
      _sampleTrails(m.round);
    }
    _drain(m);
    for (final b in _blasts) {
      b.age += dt;
    }
    _blasts.removeWhere((b) => b.age > 0.6);
    _repaint.value++;
    // Nothing in the air and no blast left: stop asking for frames (the aim can
    // last minutes; the TV must be idle then).
    if (!busy && _blasts.isEmpty) _ticker.stop();
  }

  void _sampleTrails(TenkoviRound r) {
    for (final p in r.projectiles) {
      final t = _trails[p] ??= _Trail(_colorOf(p.owner));
      final y = Tenkovi.h - p.y;
      if (!t.started) {
        t.path.moveTo(p.x, y);
        t.started = true;
      } else {
        t.path.lineTo(p.x, y);
      }
      if (++t.frames % 3 == 0) t.dots.add(Offset(p.x, y));
    }
  }

  Color _colorOf(int id) {
    final p = widget.players.where((p) => p.id == id).firstOrNull;
    return playerColors[(p?.colorIndex ?? 0) % playerColors.length];
  }

  void _drain(TenkoviTvMatch m) {
    if (m.events.isEmpty) return;
    for (final e in m.events) {
      switch (e) {
        case TkFired():
          // A new volley wipes the faint dots of the last one.
          if (_trails.isEmpty) _oldDots = const [];
        case TkBlast(:final x, :final y, :final radius):
          _blasts.add(_Blast(x, y, radius));
        case TkVolleyDone():
          _oldDots = [for (final t in _trails.values) ...t.dots];
          _trails.clear();
        default:
      }
    }
    m.events.clear();
  }

  // --- cached layers ---

  void _ensureCaches(TenkoviTvMatch m) {
    final r = m.round;
    if (!identical(r, _round)) {
      _round = r;
      _terrainVersion = -1;
      _trails.clear();
      _oldDots = const [];
      _blasts.clear();
      _names.clear();
      for (final f in _faces.values) {
        f.dispose();
      }
      _faces.clear();
      for (final t in r.tanks) {
        final p = widget.players.where((p) => p.id == t.id).firstOrNull;
        if (p != null && p.character.isNotEmpty) {
          final rec = ui.PictureRecorder();
          CharacterFace.paintOn(
            Canvas(rec),
            const Size(70, 70),
            p.character,
            playerColors[p.colorIndex % playerColors.length],
          );
          _faces[t.id] = rec.endRecording();
        }
        _names[t.id] = TextPainter(
          text: TextSpan(
            text: p?.name ?? '',
            style: TextStyle(
              fontSize: 33,
              fontWeight: FontWeight.w700,
              color: playerColors[(p?.colorIndex ?? 0) % playerColors.length],
              shadows: const [Shadow(offset: Offset(0, 2), blurRadius: 6, color: Color(0xB3000000))],
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 220);
      }
    }
    if (_terrainVersion != r.terrainVersion) {
      _terrainVersion = r.terrainVersion;
      _ground?.dispose();
      _ground = _paintGround(r);
    }
  }

  ui.Picture _paintGround(TenkoviRound r) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const w = 1600.0, h = 900.0;
    final pal = _palette(r.map);
    c.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h * 0.75), [pal.sky0, pal.sky1]),
    );
    final rnd = Random(5);
    if (r.map != TenkoviMap.mars) {
      final star = Paint()..color = Color.fromRGBO(255, 255, 255, r.map == TenkoviMap.moon ? 0.8 : 0.35);
      for (var i = 0; i < (r.map == TenkoviMap.moon ? 70 : 18); i++) {
        c.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * 420), 1.5 + rnd.nextDouble() * 1.3, star);
      }
    } else {
      // The dust storm: a few long faint streaks.
      final dust = Paint()
        ..color = const Color(0x22FFC9A0)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 26; i++) {
        final x = rnd.nextDouble() * w, y = 60 + rnd.nextDouble() * 520;
        c.drawLine(Offset(x, y), Offset(x + 90 + rnd.nextDouble() * 160, y + 8), dust);
      }
    }
    if (r.map == TenkoviMap.moon) {
      // The Earth in the sky.
      c.drawCircle(const Offset(1250, 208), 87, Paint()..color = const Color(0x245A9BFF));
      c.drawCircle(const Offset(1250, 208), 67, Paint()..color = const Color(0xFF2B6CC4));
      c.drawCircle(const Offset(1232, 196), 24, Paint()..color = const Color(0xFF4DAA5C));
      c.drawCircle(const Offset(1274, 226), 17, Paint()..color = const Color(0xFF4DAA5C));
    }
    // Far hills: a calm silhouette behind the ground.
    final far = Path()..moveTo(0, h);
    for (var x = 0; x <= Tenkovi.w; x += 20) {
      far.lineTo(x.toDouble(), 330 + 52 * sin(x / 310 + 1) + 26 * sin(x / 120) + 60);
    }
    far
      ..lineTo(w, h)
      ..close();
    c.drawPath(far, Paint()..color = pal.far);
    final top = Path()..moveTo(0, h - r.ground[0]);
    final fill = Path()..moveTo(0, h);
    fill.lineTo(0, h - r.ground[0]);
    for (var x = 4; x < Tenkovi.w; x += 4) {
      top.lineTo(x.toDouble(), h - r.ground[x]);
      fill.lineTo(x.toDouble(), h - r.ground[x]);
    }
    top.lineTo(w, h - r.ground[Tenkovi.w - 1]);
    fill
      ..lineTo(w, h - r.ground[Tenkovi.w - 1])
      ..lineTo(w, h)
      ..close();
    c.drawPath(fill, Paint()..color = pal.ground);
    c.drawPath(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeJoin = StrokeJoin.round
        ..color = pal.edge,
    );
    return rec.endRecording();
  }

  // --- widget ---

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    _ensureCaches(m);
    if ((m.stage == TenkoviStageTv.fly && !m.paused) || _blasts.isNotEmpty) _wake();
    final r = m.round;
    final byId = {for (final p in widget.players) p.id: p};
    StripName strip(int id, {int? points, int? place}) {
      final p = byId[id];
      return StripName(
        name: p?.name ?? '',
        colorIndex: p?.colorIndex ?? 0,
        character: p?.character ?? '',
        alive: r.tank(id).alive,
        points: points,
        place: place,
      );
    }

    final ending = m.stage == TenkoviStageTv.end || m.stage == TenkoviStageTv.over;
    Widget? banner;
    if (ending) {
      final pts = m.lastPoints;
      final order = [...m.ids]..sort((a, b) => (pts[b] ?? 0).compareTo(pts[a] ?? 0));
      final winner = m.lastWinner;
      var place = 0, prev = -1;
      final others = <StripName>[];
      for (final (i, id) in order.indexed) {
        if ((pts[id] ?? 0) != prev) place = i + 1;
        prev = pts[id] ?? 0;
        if (id != winner) others.add(strip(id, points: pts[id] ?? 0, place: place));
      }
      banner = WinnerBanner(
        who: winner == null
            ? [for (final id in (m.lastSurvivors.isEmpty ? m.ids : m.lastSurvivors)) strip(id)]
            : [strip(winner)],
        others: winner == null ? const [] : others,
        tie: winner == null,
      );
    }

    final living = r.living.where((t) => m.connected.contains(t.id)).length;
    final readyN = m.ready.where(m.connected.contains).length;
    final turn = r.volleys + (m.stage == TenkoviStageTv.aim ? 1 : 0);
    return Scaffold(
      backgroundColor: tvBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: _ScenePainter(this, byId), size: Size.infinite),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 1920,
                  height: 1080,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 40,
                        top: 0,
                        height: 100,
                        child: Center(
                          child: Text(
                            '${TenkoviText.round(m.roundNo, m.rounds)} · ${TenkoviText.turn(turn)}',
                            key: const ValueKey('tenkovi-header'),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFC9C9D8),
                              shadows: [Shadow(offset: Offset(0, 2), blurRadius: 6, color: Color(0xB3000000))],
                            ),
                          ),
                        ),
                      ),
                      Positioned(left: 660, top: 10, child: _WindPill(wind: r.wind)),
                      Positioned(
                        right: 40,
                        top: 0,
                        height: 100,
                        child: Center(
                          child: m.stage == TenkoviStageTv.fly
                              ? const Text(
                                  TenkoviText.volley,
                                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: tvText),
                                )
                              : m.stage == TenkoviStageTv.aim
                              ? Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(text: '✓ ', style: TextStyle(color: Color(0xFF3DDC84))),
                                      TextSpan(text: TenkoviText.ready(readyN, living)),
                                    ],
                                  ),
                                  key: const ValueKey('tenkovi-ready'),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: tvText,
                                    shadows: [Shadow(offset: Offset(0, 2), blurRadius: 6, color: Color(0xB3000000))],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (ending)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              height: 70,
              child: NameStrip(names: [for (final t in r.tanks) strip(t.id)]),
            ),
          ?banner,
        ],
      ),
    );
  }
}

/// "Vjetar" and the wind of the coming turn: an arrow and a number.
class _WindPill extends StatelessWidget {
  const _WindPill({required this.wind});
  final int wind;
  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('tenkovi-wind'),
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(color: const Color(0xB814141E), borderRadius: BorderRadius.circular(24)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(TenkoviText.wind, style: TextStyle(fontSize: 40, color: Color(0xFFC9C9D8))),
            const SizedBox(width: 22),
            if (wind != 0) ...[
              Transform.scale(
                scaleX: wind < 0 ? -1 : 1,
                child: const SizedBox(width: 120, height: 40, child: CustomPaint(painter: _ArrowPainter())),
              ),
              const SizedBox(width: 22),
              Text('${wind.abs()}', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, height: 1, color: tvText)),
            ] else
              const Text(TenkoviText.noWind, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: tvText)),
          ],
        ),
      );
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = tvText
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4, 20), const Offset(84, 20), p);
    canvas.drawPath(
      Path()
        ..moveTo(80, 2)
        ..lineTo(114, 20)
        ..lineTo(80, 38)
        ..close(),
      Paint()..color = tvText,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.s, this.byId) : super(repaint: s._repaint);
  final _TenkoviViewState s;
  final Map<int, PlayerInfo> byId;

  static final _hull = Paint()..color = const Color(0xFF262636);
  static final _wheel = Paint()..color = const Color(0xFF3A3A4C);
  static final _paint = Paint();
  static final _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..color = const Color(0x4D14141E);
  static final _shadow = Paint()..color = const Color(0x47000000);
  static final _barBack = Paint()..color = const Color(0xFF14141E);
  static final _barLine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.7
    ..color = const Color(0xFF2A2A3A);
  static final _tickBg = Paint()..color = const Color(0xFF3DDC84);
  static final _tickRing = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.3
    ..color = const Color(0xFF14141E);
  static final _tickMark = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF14141E);
  static final _dots = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round
    ..color = const Color(0x33FFFFFF);
  static final _trail = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final _head = Paint()..color = const Color(0xFFF4F4F8);
  static final _headRing = Paint()..style = PaintingStyle.stroke;
  static final _blast = Paint()..style = PaintingStyle.stroke;
  static final _blastFill = Paint();
  static final _barrelDark = Paint()
    ..strokeWidth = 15
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF14141E);
  static final _barrel = Paint()
    ..strokeWidth = 9
    ..strokeCap = StrokeCap.round;

  static final _turretPath = Path()
    ..moveTo(-35, -15)
    ..lineTo(-25, -35)
    ..lineTo(25, -35)
    ..lineTo(35, -15)
    ..close();
  static const _check = [Offset(-8, 0), Offset(-2, 7), Offset(10, -7)];

  @override
  void paint(Canvas canvas, Size size) {
    final r = s._round;
    final g = s._ground;
    if (r == null || g == null) return;
    canvas.scale(size.width / Tenkovi.w, size.height / Tenkovi.h);
    canvas.drawPicture(g);
    double fy(double y) => Tenkovi.h - y;
    final m = s.widget.match;

    if (s._oldDots.isNotEmpty) {
      canvas.drawPoints(ui.PointMode.points, s._oldDots, _dots);
    }
    // The volley in the air: each shot's trail in its player's colour.
    for (final t in s._trails.values) {
      for (final (a, w) in const [(0.18, 5.0), (0.4, 6.7), (0.9, 8.3)]) {
        _trail
          ..color = t.color.withValues(alpha: a)
          ..strokeWidth = w;
        canvas.drawPath(t.path, _trail);
      }
    }

    final aiming = m.stage == TenkoviStageTv.aim;
    final ready = m.ready;
    for (final t in r.tanks) {
      final p = byId[t.id];
      final color = playerColors[(p?.colorIndex ?? 0) % playerColors.length];
      final gy = fy(t.y);
      final tx = t.x.toDouble();
      // The hull follows the slope under it.
      final l = r.ground[max(0, t.x - 24)], rt = r.ground[min(Tenkovi.w - 1, t.x + 24)];
      final tilt = -atan2(rt - l, 48);
      canvas.drawOval(Rect.fromCenter(center: Offset(tx, gy + 2), width: 80, height: 13), _shadow);
      canvas.save();
      canvas.translate(tx, gy);
      canvas.rotate(tilt);
      if (!t.alive) {
        canvas.saveLayer(const Rect.fromLTWH(-60, -60, 120, 80), Paint()..color = const Color(0x59FFFFFF));
      }
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-40, -15, 80, 15), const Radius.circular(7.5)), _hull);
      for (final wx in const [-25.0, -8.3, 8.3, 25.0]) {
        canvas.drawCircle(Offset(wx, -7.5), 5.8, _wheel);
      }
      _paint.color = t.alive ? color : const Color(0xFF55555F);
      canvas.drawPath(_turretPath, _paint);
      canvas.drawPath(_turretPath, _outline);
      if (!t.alive) canvas.restore();
      canvas.restore();
      if (!t.alive) continue;

      // Barrel: only for a volley that has already fired.
      final a = m.volleyAims[t.id];
      if (a != null && m.stage == TenkoviStageTv.fly) {
        final rad = a.angle * pi / 180;
        final from = Offset(tx, gy - Tenkovi.turretUp);
        final to = from + Offset(cos(rad), -sin(rad)) * Tenkovi.barrel;
        canvas.drawLine(from, to, _barrelDark);
        canvas.drawLine(from, to, _barrel..color = color);
      }

      // The commander's face over the turret, the HP bar and the name.
      final face = s._faces[t.id];
      if (face != null) {
        canvas.save();
        canvas.translate(tx - 35, gy - 83);
        canvas.drawPicture(face);
        canvas.restore();
      }
      final f = t.hp / Tenkovi.maxHp;
      final bar = RRect.fromRectAndRadius(Rect.fromLTWH(tx - 53, gy - 112, 107, 17), const Radius.circular(8.5));
      canvas.drawRRect(bar, _barBack);
      canvas.save();
      canvas.clipRRect(bar);
      _paint.color = f > 0.5
          ? const Color(0xFF3DDC84)
          : f > 0.25
          ? const Color(0xFFFFB020)
          : const Color(0xFFFF4D6D);
      canvas.drawRect(Rect.fromLTWH(tx - 53, gy - 112, 107 * f, 17), _paint);
      canvas.restore();
      canvas.drawRRect(bar, _barLine);
      final np = s._names[t.id];
      if (np != null) np.paint(canvas, Offset(tx - np.width / 2, gy - 162));
      if (aiming && ready.contains(t.id)) {
        canvas.save();
        canvas.translate(tx + 55, gy - 93);
        canvas.drawCircle(Offset.zero, 20, _tickBg);
        canvas.drawCircle(Offset.zero, 20, _tickRing);
        canvas.drawPoints(ui.PointMode.polygon, _check, _tickMark);
        canvas.restore();
      }
    }

    for (final p in r.projectiles) {
      final big = p.shell == TenkoviShell.heavy;
      final small = p.shell == TenkoviShell.bomblet;
      _headRing
        ..strokeWidth = small ? 3.3 : 4.2
        ..color = s._trails[p]?.color ?? s._colorOf(p.owner);
      final c = Offset(p.x, fy(p.y));
      final rad = big ? 14.0 : small ? 8.0 : 10.0;
      canvas.drawCircle(c, rad, _head);
      canvas.drawCircle(c, rad, _headRing);
    }
    for (final b in s._blasts) {
      final k = (b.age / 0.6).clamp(0.0, 1.0);
      _blastFill.color = Color.fromRGBO(255, 190, 80, 0.55 * (1 - k));
      canvas.drawCircle(Offset(b.x, fy(b.y)), b.r * (0.6 + 0.6 * k), _blastFill);
      _blast
        ..strokeWidth = 4
        ..color = Color.fromRGBO(255, 255, 255, 0.8 * (1 - k));
      canvas.drawCircle(Offset(b.x, fy(b.y)), b.r * (0.8 + 0.8 * k), _blast);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => true;
}
