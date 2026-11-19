import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../strings.dart';
import 'tv_theme.dart';

/// The games on the home, in the order of the design.
const homeGames = [
  GameKind.curve,
  GameKind.quiz,
  GameKind.vukodlak,
  GameKind.uljez,
  GameKind.objasni,
  GameKind.koliko,
  GameKind.blef,
  GameKind.tkobi,
];

/// The console home (docs/design/couchplay-screens/V2Home.dc.html), on a 1920x1080
/// canvas scaled to fit: one game fills the screen with its own background, its
/// name big in the middle with a line about it and its settings; the games
/// before and after peek in from the edges. Left/right change the game, OK
/// plays it, down shows its settings, Back closes them or leaves the app.
///
/// [selected] is the game the session says is chosen (the host's phone moves
/// it too); the screen shows that one, and tells [onSelect] when the remote
/// moves. [onPlay] is OK.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.joinUrl,
    required this.players,
    required this.settings,
    required this.onSelect,
    required this.onPlay,
    this.selected,
    this.packs = const {},
    this.quizPacks = 0,
    this.quizQuestions = 0,
    this.notice,
    this.games = homeGames,
    super.key,
  });

  /// `http://<ip>:<port>/`, or null when the TV has no LAN address.
  final String? joinUrl;
  final List<PlayerInfo> players;
  final GameSettings settings;
  final GameKind? selected;

  /// Per game with packs: how many are ticked of how many there are (Task 46).
  final Map<GameKind, PackCount> packs;

  String? _packsLine(GameKind k) {
    final c = packs[k];
    return c == null ? null : Strings.packsLine(c.ticked, c.total);
  }

  /// How many packs and questions the Kviz has, for its line (0: not known).
  final int quizPacks, quizQuestions;

  /// A line above the help, e.g. why OK did nothing.
  final String? notice;
  final List<GameKind> games;
  final ValueChanged<GameKind> onSelect;
  final ValueChanged<GameKind> onPlay;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _i = max(
    0,
    widget.games.indexOf(widget.selected ?? widget.games.first),
  );
  var _settingsOpen = false;
  // The background is still: drawn once, so an idle home asks for no frames at all (the
  // BRAVIA logged 60 frames a second there). Only the change of game fades.
  bool? _reduced;

  GameKind get _game => widget.games[_i];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    final s = widget.selected;
    final k = s == null ? -1 : widget.games.indexOf(s);
    if (k >= 0 && s != old.selected) _i = k;
    if (_i >= widget.games.length) _i = 0;
  }

  void _move(int by) {
    final n = widget.games.length;
    setState(() => _i = (_i + by + n) % n);
    widget.onSelect(_game);
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft) {
      _move(-1);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _move(1);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _settingsOpen = true);
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.escape) {
      if (k == LogicalKeyboardKey.escape && !_settingsOpen) {
        return KeyEventResult.ignored;
      }
      setState(() => _settingsOpen = false);
    } else if (e is KeyDownEvent &&
        (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.gameButtonA)) {
      widget.onPlay(_game);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final g = _game, n = widget.games.length;
    final prev = widget.games[(_i + n - 1) % n],
        next = widget.games[(_i + 1) % n];
    return PopScope(
      // Back closes the settings first; with them closed the system takes it (exit).
      canPop: !_settingsOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _settingsOpen = false);
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _key,
        child: Scaffold(
          backgroundColor: tvBg,
          body: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1920,
              height: 1080,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: _reduced == true
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        child: _Backdrop(g, key: ValueKey('backdrop-$g')),
                      ),
                    ),
                    _Edge(const ValueKey('prev'), prev, left: true),
                    _Edge(const ValueKey('next'), next, left: false),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 360,
                      child: Column(
                        children: [
                          Text(
                            Strings.gameName(g),
                            key: ValueKey('title-${Strings.gameName(g)}'),
                            style: const TextStyle(
                              fontSize: 200,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -4,
                              height: 1,
                              color: tvText,
                              shadows: [
                                Shadow(
                                  blurRadius: 40,
                                  offset: Offset(0, 8),
                                  color: Color(0x99000000),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            Strings.gameBlurb(g, packs: widget.quizPacks, questions: widget.quizQuestions),
                            style: const TextStyle(
                              fontSize: 44,
                              color: Color(0xFFE6E6F0),
                              shadows: [
                                Shadow(
                                  blurRadius: 12,
                                  offset: Offset(0, 2),
                                  color: Color(0xB3000000),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 200,
                            ),
                            // Scales down instead of cutting the packs off (the longest line, Objasni, does not fit at 34).
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                Strings.homeMeta(
                                  g,
                                  widget.settings,
                                  widget._packsLine(g),
                                ),
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 34,
                                  color: Color(0xFFC9C9D8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_settingsOpen)
                      Positioned(
                        left: 0,
                        right: 0,
                        // Curve's panel also holds the power-up legend, so it starts higher.
                        top: g == GameKind.curve ? 272 : 716,
                        child: Center(
                          child: _SettingsPanel(
                            g,
                            widget.settings,
                            widget._packsLine(g),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 820,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var k = 0; k < n; k++)
                              Container(
                                width: k == _i ? 40 : 14,
                                height: 14,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: k == _i
                                      ? tvText
                                      : const Color(0x59FFFFFF),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (!_settingsOpen && widget.players.any((p) => p.sessionScore > 0))
                      Positioned(left: 0, right: 0, bottom: 108, child: Center(child: _Tonight(widget.players))),
                    Positioned(
                      left: 48,
                      top: 40,
                      child: _JoinPanel(widget.joinUrl),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 52,
                      child: Center(
                        child: Text(
                          'CouchPlay',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Color(0xBFF4F4F8),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 72,
                      top: 48,
                      child: _Players(widget.players),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 44,
                      child: _Help(widget.notice),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A neighbouring game, half off the screen.
class _Edge extends StatelessWidget {
  const _Edge(Key key, this.kind, {required this.left}) : super(key: key);
  final GameKind kind;
  final bool left;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left ? -80 : null,
    right: left ? null : -80,
    top: 440,
    width: 300,
    height: 200,
    child: Container(
      alignment: left ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.only(left: left ? 0 : 112, right: left ? 112 : 0),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Opacity(
        opacity: 0.5,
        child: Text(
          Strings.gameName(kind),
          maxLines: 1,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: tvText,
          ),
        ),
      ),
    ),
  );
}

/// QR and the address, top left.
class _JoinPanel extends StatelessWidget {
  const _JoinPanel(this.url);
  final String? url;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('join-panel'),
    padding: const EdgeInsets.fromLTRB(14, 14, 28, 14),
    decoration: BoxDecoration(
      color: const Color(0x80000000),
      borderRadius: BorderRadius.circular(24),
    ),
    child: url == null
        ? const SizedBox(
            width: 520,
            child: Text(
              Strings.noWifi,
              style: TextStyle(fontSize: 34, color: tvText),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 4 modules of quiet zone around a version-3 code, a bit bigger than the sketch:
              // it is read from the couch.
              Container(
                width: 208,
                height: 208,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: QrImageView(
                  data: url!,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    Strings.homeJoin,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: tvText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    Strings.homeJoinOr,
                    style: TextStyle(fontSize: 28, color: Color(0xFFC9C9D8)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    url!
                        .replaceFirst('http://', '')
                        .replaceFirst(RegExp(r'/$'), ''),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: tvText,
                    ),
                  ),
                ],
              ),
            ],
          ),
  );
}

/// The players' characters, top right.
class _Players extends StatelessWidget {
  const _Players(this.players);
  final List<PlayerInfo> players;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final p in players)
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Opacity(
            opacity: p.connected ? 1 : 0.5,
            child: PlayerDot(
              playerColors[p.colorIndex % playerColors.length],
              size: 52,
              character: p.character,
            ),
          ),
        ),
      Text(
        players.isEmpty
            ? Strings.homeNoPlayers
            : Strings.playerCount(players.length),
        style: const TextStyle(fontSize: 30, color: Color(0xFFC9C9D8)),
      ),
    ],
  );
}

class _Help extends StatelessWidget {
  const _Help(this.notice);
  final String? notice;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 30, color: Color(0xFFC9C9D8));
    const key = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      color: tvText,
    );
    Widget icon(IconData d) => Icon(d, size: 40, color: tvText);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              notice!,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: tvAccent,
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon(Icons.arrow_left),
            icon(Icons.arrow_right),
            const SizedBox(width: 8),
            const Text(Strings.homeHelpMove, style: muted),
            const SizedBox(width: 48),
            const Text(Strings.homeKeyOk, style: key),
            const SizedBox(width: 10),
            const Text(Strings.homeHelpPlay, style: muted),
            const SizedBox(width: 48),
            icon(Icons.arrow_drop_down),
            const Text(Strings.homeHelpSettings, style: muted),
            const SizedBox(width: 48),
            const Text(Strings.homeKeyBack, style: key),
            const SizedBox(width: 10),
            const Text(Strings.homeHelpBack, style: muted),
          ],
        ),
      ],
    );
  }
}

/// How many of a game's packs are ticked, of how many there are.
typedef PackCount = ({int ticked, int total});

/// The game's current settings (the host sets them on the phone).
class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel(this.kind, this.settings, this.packsLine);
  final GameKind kind;
  final GameSettings settings;
  final String? packsLine;

  @override
  Widget build(BuildContext context) {
    // Rows of one or two items; the pack name is long, so it gets a row of its own.
    final rows = <List<(String, String)>>[
      if (packsLine != null && kind != GameKind.quiz) [(Strings.settingPack, packsLine!)],
      ...switch (kind) {
      GameKind.quiz => [
        [(Strings.settingPack, packsLine ?? '–')],
        [
          (Strings.settingQuestions, '${settings.quizQuestions}'),
          (Strings.settingAnswerTime, '${settings.quizSeconds} s'),
        ],
        [(Strings.settingReveal, '${settings.revealSeconds} s')],
      ],
      GameKind.curve => [
        [
          (Strings.settingMode, Strings.curveModeName(settings.curveMode)),
          (Strings.settingCountdown, '${settings.curveCountdown} s'),
        ],
      ],
      GameKind.vukodlak => [
          [
            (Strings.settingHideRoles, settings.wolfHideRoles ? Strings.yes : Strings.no),
          ],
        ],
      GameKind.uljez => [
          [
            (Strings.settingImpostors, '${settings.uljezImpostors}'),
          ],
        ],
      // The other party games have no settings on the TV yet.
      GameKind.objasni || GameKind.koliko || GameKind.blef || GameKind.tkobi => <List<(String, String)>>[],
      },
    ];
    Widget item((String, String) it) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${it.$1}: ',
            style: const TextStyle(color: tvMuted),
          ),
          TextSpan(
            text: it.$2,
            style: const TextStyle(color: tvText, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 34),
    );
    return Container(
      key: const ValueKey('game-card'),
      width: kind == GameKind.curve ? 1640 : 1360,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
      decoration: BoxDecoration(
        color: kind == GameKind.curve ? const Color(0xFA1F1F2C) : const Color(0xE61F1F2C),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: tvAccent, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: item(row[0])),
                  if (row.length > 1) ...[
                    const SizedBox(width: 32),
                    Expanded(child: item(row[1])),
                  ],
                ],
              ),
            ),
          if (kind == GameKind.curve) ...[
            const SizedBox(height: 10),
            const Text(Strings.legendTitle, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: tvText)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 36,
              runSpacing: 6,
              children: [for (final k in PowerUpKind.values) _LegendEntry(k)],
            ),
          ],
        ],
      ),
    );
  }
}

/// One power-up in the legend: its icon, its name and time, and what it does in one line.
class _LegendEntry extends StatelessWidget {
  const _LegendEntry(this.kind);
  final PowerUpKind kind;

  @override
  Widget build(BuildContext context) {
    final info = powerUpTexts[kind]!;
    return SizedBox(
      key: ValueKey('legend-${kind.name}'),
      width: 480,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PowerUpIcon(kind, 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: info.name, style: TextStyle(fontWeight: FontWeight.w700, color: PowerUpIcon.colorOf(kind))),
                    TextSpan(text: ' · ${info.time}', style: const TextStyle(color: tvMuted)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 30),
                ),
                Text(info.what, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 28, color: tvMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One ribbon of the Curve card's art (docs/design/couchplay-screens/V2Home.dc.html).
class HomeRibbon {
  HomeRibbon(this.path, this.color, this.alpha, {this.dashed = false});
  final Path path;
  final Color color;
  final double alpha;
  final bool dashed;
  final double width = 44;
}

/// Curve's art follows Curve's rule: lines never cross or touch (crossing is death), so the
/// four ribbons run side by side with gaps. Same shapes as the canvas (031034e).
final homeCurveRibbons = <HomeRibbon>[
  HomeRibbon(
    Path()
      ..moveTo(-40, 180)
      ..cubicTo(300, 120, 520, 300, 820, 220)
      ..cubicTo(1120, 140, 1320, 80, 1560, 200)
      ..lineTo(1640, 240),
    const Color(0xFF2ECC71),
    0.45,
  ),
  HomeRibbon(
    Path()
      ..moveTo(-40, 760)
      ..cubicTo(260, 640, 520, 860, 820, 740)
      ..cubicTo(1120, 620, 1300, 600, 1560, 720),
    const Color(0xFFFF4D6D),
    0.55,
  ),
  HomeRibbon(
    Path()
      ..moveTo(1700, 1120)
      ..cubicTo(1760, 900, 1660, 760, 1820, 560)
      ..cubicTo(1980, 360, 1960, 360, 1880, 300),
    const Color(0xFF22B8F0),
    0.4,
  ),
  HomeRibbon(
    Path()
      ..moveTo(-40, 1000)
      ..cubicTo(200, 940, 420, 1040, 640, 960),
    const Color(0xFFFFB020),
    0.4,
    dashed: true,
  ),
];

/// Each game's own background, drawn in code, once (it does not move).
/// shapes a little; it stands still with reduced motion.
class _Backdrop extends StatelessWidget {
  const _Backdrop(this.kind, {super.key});
  final GameKind kind;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: const Alignment(-0.3, -1),
        end: const Alignment(0.3, 1),
        colors: switch (kind) {
          GameKind.curve => const [Color(0xFF0B0B18), Color(0xFF1A1236)],
          GameKind.quiz => const [Color(0xFF0E1A2E), Color(0xFF132744)],
          GameKind.vukodlak => const [Color(0xFF05060F), Color(0xFF101A3A)],
              GameKind.uljez => const [Color(0xFF1A0E2E), Color(0xFF2A1646)],
          GameKind.objasni => const [Color(0xFF2A1410), Color(0xFF14283A)],
          GameKind.koliko => const [Color(0xFF0B1F1A), Color(0xFF12304A)],
          GameKind.blef => const [Color(0xFF3A2008), Color(0xFF2A0E0E)],
          GameKind.tkobi => const [Color(0xFF2A1030), Color(0xFF3A1430)],
        },
      ),
    ),
    // Two layers: the moving shapes (redrawn with the drift) and the vignette, which never
    // changes, so the engine keeps it as a picture instead of drawing a full-screen
    // gradient 8 times a second.
    child: Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: CustomPaint(painter: _ArtPainter(kind), isComplex: true, size: Size.infinite)),
        const RepaintBoundary(child: CustomPaint(painter: _Vignette(), isComplex: true, size: Size.infinite)),
      ],
    ),
  );
}

class _ArtPainter extends CustomPainter {
  const _ArtPainter(this.kind);
  final GameKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1920, size.height / 1080);
    const a = 0.0, b = 1.0; // where the shapes rest
    switch (kind) {
      case GameKind.curve:
        for (final r in homeCurveRibbons) {
          final paint = Paint()
            ..color = r.color.withValues(alpha: r.alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r.width
            ..strokeCap = StrokeCap.round;
          if (!r.dashed) {
            canvas.drawPath(r.path, paint);
          } else {
            // 260 on, 70 off, along the line (the canvas's stroke-dasharray).
            for (final m in r.path.computeMetrics()) {
              for (var d = 0.0; d < m.length; d += 330) {
                canvas.drawPath(m.extractPath(d, min(d + 260, m.length)), paint);
              }
            }
          }
        }
      case GameKind.quiz:
        void tile(
          double x,
          double y,
          double deg,
          Color c,
          double o,
          double wobble,
        ) {
          canvas.save();
          canvas.translate(x + 210, y + 210);
          canvas.rotate((deg + wobble) * pi / 180);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-210, -210, 420, 420),
              const Radius.circular(60),
            ),
            Paint()..color = c.withValues(alpha: o),
          );
          canvas.restore();
        }
        tile(120, 120, -12, const Color(0xFFFF4D6D), 0.45, 2 * a);
        tile(1380, 80, 10, const Color(0xFF22B8F0), 0.45, -2 * b);
        tile(1360, 620, -8, const Color(0xFF2ECC71), 0.4, 2 * b);
        tile(140, 620, 14, const Color(0xFFFFB020), 0.4, -2 * a);
      case GameKind.vukodlak:
        // A big moon over a dark ridge; the stars twinkle.
        canvas.drawCircle(const Offset(1460, 300), 220, Paint()..color = const Color(0xD9F2E9C9));
        for (var i = 0; i < 18; i++) {
          final tw = 0.25 + 0.75 * (0.5 + 0.5 * sin(i * 1.7));
          canvas.drawCircle(Offset(80.0 + (i * 211) % 1300, 60.0 + (i * 97) % 380), 1.5 + i % 3, Paint()..color = Color.fromRGBO(255, 255, 255, tw));
        }
        const xs = <double>[160, 260, 380, 520, 680, 820, 980, 1140, 1300, 1460, 1620, 1780, 1920];
        const ys = <double>[720, 780, 680, 770, 700, 790, 690, 780, 700, 790, 720, 780, 720];
        final ridge = Path()..moveTo(0, 820);
        for (var i = 0; i < xs.length; i++) {
          ridge.lineTo(xs[i], ys[i]);
        }
        canvas.drawPath(ridge..lineTo(1920, 1080)..lineTo(0, 1080)..close(), Paint()..color = const Color(0xFF05060F));
      case GameKind.uljez:
        // A purple table with the players' seats round it, swaying a little.
        canvas.drawOval(Rect.fromCenter(center: const Offset(960, 650), width: 1100, height: 520), Paint()..color = const Color(0x8C3A2A55));
        canvas.drawOval(Rect.fromCenter(center: const Offset(960, 640), width: 1040, height: 490), Paint()..color = const Color(0x8C4A3670));
        for (var i = 0; i < 6; i++) {
          final a = -pi / 2 + i * 2 * pi / 6;
          canvas.drawCircle(Offset(960 + 700 * cos(a), 640 + 360 * sin(a)), 64, Paint()..color = playerColors[i].withValues(alpha: 0.45));
        }
      case GameKind.objasni:
        // Two teams, one on each side, and a speech bubble between them.
        canvas.drawCircle(const Offset(300, 640), 330, Paint()..color = const Color(0x40FF4D6D));
        canvas.drawCircle(const Offset(1620, 640), 330, Paint()..color = const Color(0x4022B8F0));
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(700, 760, 520, 190), const Radius.circular(70)), Paint()..color = const Color(0x24FFFFFF));
      case GameKind.koliko:
        // A number line with its ticks and a marker on it.
        final line = Paint()..color = const Color(0x55FFFFFF)..strokeWidth = 8..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(160, 800), const Offset(1760, 800), line);
        for (var i = 0; i <= 10; i++) {
          canvas.drawLine(Offset(160 + i * 160.0, 770), Offset(160 + i * 160.0, 830), line);
        }
        canvas.drawCircle(const Offset(1020, 800), 38, Paint()..color = const Color(0xAA2ECC71));
      case GameKind.blef:
        // Three cards, one of them is not what it says.
        for (var i = 0; i < 3; i++) {
          canvas.save();
          canvas.translate(560.0 + i * 400, 720);
          canvas.rotate((i - 1) * 0.18);
          canvas.drawRRect(
              RRect.fromRectAndRadius(const Rect.fromLTWH(-150, -190, 300, 380), const Radius.circular(36)),
              Paint()..color = [const Color(0x38FF4D6D), const Color(0x38F5E94B), const Color(0x389B5CFF)][i]);
          canvas.restore();
        }
      case GameKind.tkobi:
        // Everybody in the room, round a ring.
        for (var i = 0; i < 8; i++) {
          final a = -pi / 2 + i * 2 * pi / 8;
          canvas.drawCircle(Offset(960 + 760 * cos(a), 640 + 380 * sin(a)), 56, Paint()..color = playerColors[i].withValues(alpha: 0.4));
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.kind != kind;
}

/// A shade that pulls the eye to the middle. Never changes.
class _Vignette extends CustomPainter {
  const _Vignette();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.7,
          colors: [Color(0x26000000), Color(0xBF000000)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_Vignette old) => false;
}

/// Tonight's totals along the bottom, once a game has been played: a small strip, leader first.
class _Tonight extends StatelessWidget {
  const _Tonight(this.players);
  final List<PlayerInfo> players;

  @override
  Widget build(BuildContext context) {
    final sorted = [...players]..sort((a, b) => b.sessionScore.compareTo(a.sessionScore)); // stable: ties keep join order
    return Container(
      key: const ValueKey('tonight'),
      constraints: const BoxConstraints(maxWidth: 1800),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      decoration: BoxDecoration(color: const Color(0x80000000), borderRadius: BorderRadius.circular(999)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(Strings.tonight, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: tvMuted)),
            for (final p in sorted) ...[
              const SizedBox(width: 36),
              PlayerDot(playerColors[p.colorIndex % playerColors.length], size: 40, character: p.character),
              const SizedBox(width: 10),
              Text(p.name, maxLines: 1, style: const TextStyle(fontSize: 30, color: tvText)),
              const SizedBox(width: 10),
              Text('${p.sessionScore}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: tvText)),
            ],
          ],
        ),
      ),
    );
  }
}
