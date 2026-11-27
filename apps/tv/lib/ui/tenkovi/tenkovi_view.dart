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

/// Tenkovi on the TV: hills across the full width, tanks, and the volley.
///
/// PRIVACY: before the volley this reads only [TenkoviTvMatch.ready] (who has
/// pressed Pucaj). Tanks are drawn with no barrel at all, so nothing here can
/// show an angle; shells appear only once the match has fired them.
///
/// PERFORMANCE: the sky and the ground are one cached [ui.Picture], redrawn
/// only when a crater changes [TenkoviRound.terrainVersion]; each frame draws
/// 8 tanks, the shells and a few blasts, with no per-frame text layout.
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

class _TenkoviViewState extends State<TenkoviView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _acc = 0;

  TenkoviRound? _round; // the round the cached pictures belong to
  int _terrainVersion = -1;
  ui.Picture? _ground;
  final _names = <int, TextPainter>{};
  final _trails = <TenkoviShot, List<Offset>>{};
  Path? _oldPath; // the faint trails of the last volley, built once when it ended
  final _blasts = <_Blast>[];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _ground?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final m = widget.match;
    var busy = _blasts.isNotEmpty;
    if (m.stage == TenkoviStageTv.fly) {
      busy = true;
      _acc += dt.clamp(0, 0.1);
      var steps = 0;
      const step = 1 / Tenkovi.tickHz;
      while (_acc >= step && steps < 6) {
        _acc -= step;
        steps++;
        m.tick();
        _sampleTrails(m.round);
        if (m.stage != TenkoviStageTv.fly) break;
      }
      _drain(m);
    } else {
      _acc = 0;
      _drain(m);
    }
    for (final b in _blasts) {
      b.age += dt;
    }
    _blasts.removeWhere((b) => b.age > 0.6);
    if (busy || _blasts.isNotEmpty) _repaint.value++;
  }

  void _sampleTrails(TenkoviRound r) {
    for (final p in r.projectiles) {
      if (p.age % 3 != 0) continue;
      (_trails[p] ??= []).add(Offset(p.x, p.y));
    }
  }

  void _drain(TenkoviTvMatch m) {
    if (m.events.isEmpty) return;
    for (final e in m.events) {
      switch (e) {
        case TkFired():
          // A new volley wipes the faint trails of the last one.
          if (_trails.isEmpty) _oldPath = null;
        case TkBlast(:final x, :final y, :final radius):
          _blasts.add(_Blast(x, y, radius));
        case TkVolleyDone():
          final path = Path();
          for (final t in _trails.values) {
            if (t.length < 2) continue;
            path.moveTo(t.first.dx, Tenkovi.h - t.first.dy);
            for (var i = 1; i < t.length; i++) {
              path.lineTo(t[i].dx, Tenkovi.h - t[i].dy);
            }
          }
          _oldPath = path;
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
      _oldPath = null;
      _blasts.clear();
      _names.clear();
      for (final t in r.tanks) {
        final p = widget.players.where((p) => p.id == t.id).firstOrNull;
        _names[t.id] = TextPainter(
          text: TextSpan(
            text: p?.name ?? '',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: playerColors[(p?.colorIndex ?? 0) % playerColors.length],
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: 190);
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
    final (sky0, sky1, g0, g1) = switch (r.map) {
      TenkoviMap.earth => (const Color(0xFF1B3A66), const Color(0xFF7FB8E8), const Color(0xFF3FA05A), const Color(0xFF1F5A34)),
      TenkoviMap.moon => (const Color(0xFF05060F), const Color(0xFF14183A), const Color(0xFF9A9AA8), const Color(0xFF4A4A58)),
      TenkoviMap.mars => (const Color(0xFF3A1A14), const Color(0xFFD08050), const Color(0xFFC0482C), const Color(0xFF6A2418)),
    };
    c.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, h), [sky0, sky1]),
    );
    if (r.map == TenkoviMap.moon) {
      final star = Paint()..color = const Color(0xCCFFFFFF);
      final rnd = Random(5);
      for (var i = 0; i < 70; i++) {
        c.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * 500), 1 + rnd.nextDouble() * 1.6, star);
      }
      // The Earth, small and blue, over the horizon.
      c.drawCircle(const Offset(1280, 150), 58, Paint()..color = const Color(0xFF3F7FD8));
      c.drawCircle(const Offset(1262, 140), 26, Paint()..color = const Color(0xFF4FB070));
    }
    final path = Path()..moveTo(0, h);
    for (var x = 0; x < Tenkovi.w; x += 4) {
      path.lineTo(x.toDouble(), h - r.ground[x]);
    }
    path
      ..lineTo(w, h - r.ground[Tenkovi.w - 1])
      ..lineTo(w, h)
      ..close();
    c.drawPath(
      path,
      Paint()..shader = ui.Gradient.linear(Offset(0, h - 560), const Offset(0, h), [g0, g1]),
    );
    return rec.endRecording();
  }

  // --- widget ---

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    _ensureCaches(m);
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

    Widget? banner;
    if (m.stage == TenkoviStageTv.end || m.stage == TenkoviStageTv.over) {
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
        who: winner == null ? [for (final id in m.ids) strip(id)] : [strip(winner)],
        others: winner == null ? const [] : others,
        tie: winner == null,
      );
    }

    final living = r.living.where((t) => m.connected.contains(t.id)).length;
    final wind = r.wind;
    return Scaffold(
      backgroundColor: tvBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _ScenePainter(this, byId),
              size: Size.infinite,
            ),
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
                        left: 48,
                        top: 32,
                        child: _Hud(
                          line1: TenkoviText.round(m.roundNo, m.rounds),
                          line2: TenkoviText.map(r.map),
                        ),
                      ),
                      Positioned(
                        right: 48,
                        top: 32,
                        child: _WindHud(wind: wind),
                      ),
                      if (m.stage == TenkoviStageTv.aim)
                        Positioned(
                          top: 40,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              '${TenkoviText.aimKicker} · ${TenkoviText.ready(m.ready.where(m.connected.contains).length, living)}',
                              key: const ValueKey('tenkovi-ready'),
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: tvText),
                            ),
                          ),
                        ),
                      if (m.stage == TenkoviStageTv.fly)
                        const Positioned(
                          top: 40,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              TenkoviText.volley,
                              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: tvText),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

class _Hud extends StatelessWidget {
  const _Hud({required this.line1, required this.line2});
  final String line1, line2;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line1, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: tvText)),
          Text(line2, style: const TextStyle(fontSize: 30, color: tvMuted)),
        ],
      );
}

/// The wind of the coming turn: an arrow and a number.
class _WindHud extends StatelessWidget {
  const _WindHud({required this.wind});
  final int wind;
  @override
  Widget build(BuildContext context) => Column(
        key: const ValueKey('tenkovi-wind'),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(TenkoviText.wind, style: TextStyle(fontSize: 30, color: tvMuted)),
          Text(
            wind == 0 ? TenkoviText.noWind : '${wind < 0 ? '←' : '→'} ${wind.abs()}',
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: tvText),
          ),
        ],
      );
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.s, this.byId) : super(repaint: s._repaint);
  final _TenkoviViewState s;
  final Map<int, PlayerInfo> byId;

  static final _shot = Paint()..color = const Color(0xFFFFFFFF);
  static final _trail = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0x40FFFFFF);
  static final _trailNew = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0x99FFFFFF);
  static final _body = Paint();
  static final _barBack = Paint()..color = const Color(0xAA000000);
  static final _bar = Paint();
  static final _tick = Paint()..color = const Color(0xFF7FD8A8);
  static final _blast = Paint()..style = PaintingStyle.stroke;
  static final _blastFill = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final r = s._round;
    final g = s._ground;
    if (r == null || g == null) return;
    canvas.scale(size.width / Tenkovi.w, size.height / Tenkovi.h);
    canvas.drawPicture(g);
    double fy(double y) => Tenkovi.h - y;

    // Faint trails of the last volley, then the one in the air.
    if (s._oldPath != null) canvas.drawPath(s._oldPath!, _trail);
    for (final t in s._trails.values) {
      _line(canvas, t, _trailNew, fy);
    }

    final aiming = s.widget.match.stage == TenkoviStageTv.aim;
    final ready = s.widget.match.ready;
    for (final t in r.tanks) {
      final p = byId[t.id];
      final color = playerColors[(p?.colorIndex ?? 0) % playerColors.length];
      final gy = fy(t.y);
      canvas.save();
      canvas.translate(t.x.toDouble(), gy);
      if (!t.alive) {
        _body.color = const Color(0xFF55555F);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-24, -14, 48, 14), const Radius.circular(6)), _body);
        canvas.restore();
        continue;
      }
      // A tank has no barrel: nothing here can show an angle.
      _body.color = color;
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-24, -14, 48, 14), const Radius.circular(6)), _body);
      canvas.drawCircle(const Offset(0, -16), 15, _body);
      if (p != null && p.character.isNotEmpty) {
        canvas.save();
        canvas.translate(-13, -29);
        CharacterFace.paintOn(canvas, const Size(26, 26), p.character, color);
        canvas.restore();
      }
      // HP bar and name.
      final f = t.hp / Tenkovi.maxHp;
      canvas.drawRect(const Rect.fromLTWH(-32, -50, 64, 9), _barBack);
      _bar.color = Color.lerp(const Color(0xFFFF4D6D), const Color(0xFF7FD8A8), f)!;
      canvas.drawRect(Rect.fromLTWH(-30, -48, 60 * f, 5), _bar);
      final np = s._names[t.id];
      if (np != null) np.paint(canvas, Offset(-np.width / 2, -84));
      if (aiming && ready.contains(t.id)) {
        canvas.drawCircle(const Offset(40, -34), 11, _tick);
        canvas.drawLine(const Offset(34, -34), const Offset(39, -29), _tickMark);
        canvas.drawLine(const Offset(39, -29), const Offset(47, -40), _tickMark);
      }
      canvas.restore();
    }

    for (final p in r.projectiles) {
      canvas.drawCircle(
        Offset(p.x, fy(p.y)),
        switch (p.shell) {
          TenkoviShell.heavy => 8,
          TenkoviShell.bomblet => 3.5,
          _ => 5,
        },
        _shot,
      );
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

  static final _tickMark = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF14141E);

  void _line(Canvas c, List<Offset> pts, Paint paint, double Function(double) fy) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, fy(pts.first.dy));
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, fy(pts[i].dy));
    }
    c.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ScenePainter old) => true;
}
