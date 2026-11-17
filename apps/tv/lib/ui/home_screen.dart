import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../strings.dart';
import 'tv_theme.dart';

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
    this.packTitle,
    this.notice,
    this.games = const [GameKind.curve, GameKind.quiz],
    super.key,
  });

  /// `http://<ip>:<port>/`, or null when the TV has no LAN address.
  final String? joinUrl;
  final List<PlayerInfo> players;
  final GameSettings settings;
  final GameKind? selected;

  /// Title of the pack Igraj would start (Kviz).
  final String? packTitle;

  /// A line above the help, e.g. why OK did nothing.
  final String? notice;
  final List<GameKind> games;
  final ValueChanged<GameKind> onSelect;
  final ValueChanged<GameKind> onPlay;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late int _i = max(
    0,
    widget.games.indexOf(widget.selected ?? widget.games.first),
  );
  var _settingsOpen = false;
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  bool? _reduced;

  GameKind get _game => widget.games[_i];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    if (reduced) {
      _drift.stop();
    } else {
      _drift.repeat();
    }
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    final s = widget.selected;
    final k = s == null ? -1 : widget.games.indexOf(s);
    if (k >= 0 && s != old.selected) _i = k;
    if (_i >= widget.games.length) _i = 0;
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
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
                        child: _Backdrop(
                          g,
                          _drift,
                          key: ValueKey('backdrop-$g'),
                        ),
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
                            Strings.gameBlurb(g),
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
                            child: Text(
                              Strings.homeMeta(
                                g,
                                widget.settings,
                                widget.packTitle,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 34,
                                color: Color(0xFFC9C9D8),
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
                        top: 716,
                        child: Center(
                          child: _SettingsPanel(
                            g,
                            widget.settings,
                            widget.packTitle,
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

/// The game's current settings (the host sets them on the phone).
class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel(this.kind, this.settings, this.packTitle);
  final GameKind kind;
  final GameSettings settings;
  final String? packTitle;

  @override
  Widget build(BuildContext context) {
    // Rows of one or two items; the pack name is long, so it gets a row of its own.
    final rows = switch (kind) {
      GameKind.quiz => [
        [(Strings.settingPack, packTitle ?? '–')],
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
      GameKind.vukodlak || GameKind.uljez => <List<(String, String)>>[],
    };
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
      width: 1360,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xE61F1F2C),
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
        ],
      ),
    );
  }
}

/// Each game's own background, drawn in code. [drift] loops 0..1 and moves the
/// shapes a little; it stands still with reduced motion.
class _Backdrop extends StatelessWidget {
  const _Backdrop(this.kind, this.drift, {super.key});
  final GameKind kind;
  final Animation<double> drift;

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
        },
      ),
    ),
    child: CustomPaint(painter: _ArtPainter(kind, drift), size: Size.infinite),
  );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.kind, this.drift) : super(repaint: drift);
  final GameKind kind;
  final Animation<double> drift;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1920, size.height / 1080);
    final a = sin(drift.value * 2 * pi);
    final b = cos(drift.value * 2 * pi);
    switch (kind) {
      case GameKind.curve:
        void ribbon(Color c, double o, Path p, double dx, double dy) {
          canvas.save();
          canvas.translate(dx, dy);
          canvas.drawPath(
            p,
            Paint()
              ..color = c.withValues(alpha: o)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 44
              ..strokeCap = StrokeCap.round,
          );
          canvas.restore();
        }
        ribbon(
          const Color(0xFFFF4D6D),
          0.55,
          Path()
            ..moveTo(-40, 900)
            ..cubicTo(300, 300, 640, 1000, 980, 420)
            ..cubicTo(1320, -160, 1600, 80, 1980, 520),
          30 * a,
          14 * b,
        );
        ribbon(
          const Color(0xFF2ECC71),
          0.45,
          Path()
            ..moveTo(-40, 160)
            ..cubicTo(420, 520, 820, 40, 1300, 300)
            ..cubicTo(1780, 560, 1800, 820, 1980, 700),
          -26 * b,
          18 * a,
        );
        ribbon(
          const Color(0xFF22B8F0),
          0.4,
          Path()
            ..moveTo(200, 1120)
            ..cubicTo(500, 760, 900, 980, 1240, 760),
          20 * a,
          -16 * b,
        );
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
      case GameKind.vukodlak || GameKind.uljez:
        break; // Tasks 33 and 35
    }
    canvas.restore();
    // A shade that pulls the eye to the middle.
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
  bool shouldRepaint(_ArtPainter old) => old.kind != kind;
}
