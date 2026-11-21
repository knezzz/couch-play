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
    this.hostView = HostView.home,
    this.changed,
    this.packGrid,
    this.onOpenSettings,
    this.onCloseSettings,
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

  /// Where the host is (the session says it): the settings panel opens by itself in
  /// [HostView.settings], and the pack screen shows [packGrid] in [HostView.packs] (Task 48).
  final HostView hostView;

  /// The setting change to outline in the panel (cleared by a game change).
  final LobbyChange? changed;

  /// The shown game's packs, on and off, for the pack screen.
  final List<PackTile>? packGrid;

  /// ▼ and Natrag, told to the session, which owns the panel. Without them the home
  /// opens and closes its own panel (no session: tests, previews).
  final VoidCallback? onOpenSettings, onCloseSettings;

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
  var _localOpen = false;

  // Curve's power-up legend shows when the remote's ▼ opened the panel, not when the host's change did (it would cover the title).
  var _legend = false;

  bool get _settingsOpen =>
      widget.onOpenSettings != null ? widget.hostView == HostView.settings : _localOpen;

  void _openSettings() {
    if (widget.onOpenSettings != null) {
      widget.onOpenSettings!();
    } else {
      setState(() => _localOpen = true);
    }
  }

  void _closeSettings() {
    _legend = false;
    if (widget.onCloseSettings != null) {
      widget.onCloseSettings!();
    } else {
      setState(() => _localOpen = false);
    }
  }
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
    if (old.hostView == HostView.settings && widget.hostView != HostView.settings) _legend = false;
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
      setState(() => _legend = true);
      _openSettings();
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.escape) {
      if (k == LogicalKeyboardKey.escape && !_settingsOpen) {
        return KeyEventResult.ignored;
      }
      _closeSettings();
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
        if (!didPop) _closeSettings();
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
                        top: g == GameKind.curve && _legend ? 272 : 716,
                        child: Center(
                          child: _SettingsPanel(
                            g,
                            widget.settings,
                            widget._packsLine(g),
                            changed: widget.changed?.game == g ? widget.changed?.key : null,
                            legend: _legend,
                            bots: widget.players.where((p) => p.bot).length,
                          ),
                        ),
                      )
                    else
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 820,
                        child: Row(
                          key: const ValueKey('page-dots'),
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
                    if (widget.hostView == HostView.packs && widget.packGrid != null)
                      Positioned.fill(child: _PackGrid(g, widget.packGrid!)),
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

/// One pack on the pack screen: how many questions (words, prompts), how many with a
/// picture, and whether the host has it on.
typedef PackTile = ({String id, String title, int count, int pictures, bool on});

/// The pack screen on the TV while the host is in it on the phone: every pack of the
/// shown game, the ones that are off dimmed, with the count line (Task 48).
class _PackGrid extends StatelessWidget {
  const _PackGrid(this.kind, this.tiles);
  final GameKind kind;
  final List<PackTile> tiles;

  @override
  Widget build(BuildContext context) {
    final on = tiles.where((t) => t.on).toList();
    final questions = on.fold<int>(0, (a, t) => a + t.count);
    final pictures = on.fold<int>(0, (a, t) => a + t.pictures);
    return Container(
      key: const ValueKey('pack-grid'),
      color: tvBg, // opaque: the QR and the game edges behind it ghosted through
      padding: const EdgeInsets.fromLTRB(96, 150, 96, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Strings.packGridTitle(kind), style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: tvText)),
          const SizedBox(height: 8),
          Text(Strings.packGridSummary(on.length, tiles.length, questions, pictures), style: const TextStyle(fontSize: 40, color: Color(0xFFC9C9D8))),
          const SizedBox(height: 28),
          Expanded(
            child: LayoutBuilder(
              builder: (_, box) {
                // As many columns as the packs need to fit the height: 4, or 5 when there are many.
                final cols = tiles.length > 16 ? 5 : 4;
                final rows = (tiles.length / cols).ceil().clamp(1, 99);
                const gap = 16.0;
                final w = (box.maxWidth - gap * (cols - 1)) / cols;
                final h = ((box.maxHeight - gap * (rows - 1)) / rows).clamp(0.0, 130.0);
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [for (final t in tiles) _tile(t, w, h)],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(PackTile t, double w, double h) => Opacity(
        key: ValueKey(t.on ? 'pack-tile-${t.id}' : 'pack-off-${t.id}'),
        opacity: t.on ? 1 : 0.4,
        child: Container(
          width: w,
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: t.on ? const Color(0xFF2A2A3A) : const Color(0xFF1F1F2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.on ? tvAccent : const Color(0xFF55556A), width: 3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(t.title, maxLines: 1, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: tvText)),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(Strings.packTileLine(t.count, t.pictures), maxLines: 1, style: const TextStyle(fontSize: 30, color: Color(0xFFC9C9D8))),
              ),
            ],
          ),
        ),
      );
}

/// How many of a game's packs are ticked, of how many there are.
typedef PackCount = ({int ticked, int total});

/// The game's current settings (the host sets them on the phone).
class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel(this.kind, this.settings, this.packsLine, {this.changed, this.legend = false, this.bots = 0});
  final GameKind kind;
  final GameSettings settings;
  final String? packsLine;

  /// The GameSettings key of the row the host just changed (outlined).
  final String? changed;

  /// Curve: the power-up legend under the rows (only after ▼).
  final bool legend;

  /// How many robots are in (Kviz and Curve have a robots setting).
  final int bots;

  @override
  Widget build(BuildContext context) {
    final wide = kind == GameKind.curve && legend;
    // Rows of one or two items; the pack name is long, so it gets a row of its own.
    final rows = <List<(String, String, String)>>[
      if (packsLine != null && kind != GameKind.quiz) [(Strings.settingPack, packsLine!, '${kind.name}OffPacks')],
      ...switch (kind) {
      GameKind.quiz => [
        [(Strings.settingPack, packsLine ?? '–', 'quizOffPacks')],
        [
          (Strings.settingQuestions, '${settings.quizQuestions}', 'quizQuestions'),
          (Strings.settingAnswerTime, '${settings.quizSeconds} s', 'quizSeconds'),
        ],
        [(Strings.settingReveal, '${settings.revealSeconds} s', 'revealSeconds'), (Strings.settingBots, '$bots', 'bots')],
      ],
      GameKind.curve => [
        // With the legend the card is wide: all three on one row, to keep it short.
        if (wide)
          [
            (Strings.settingMode, Strings.curveModeName(settings.curveMode), 'curveMode'),
            (Strings.settingCountdown, '${settings.curveCountdown} s', 'curveCountdown'),
            (Strings.settingBots, '$bots', 'bots'),
          ]
        else ...[
          [
            (Strings.settingMode, Strings.curveModeName(settings.curveMode), 'curveMode'),
            (Strings.settingCountdown, '${settings.curveCountdown} s', 'curveCountdown'),
          ],
          [(Strings.settingBots, '$bots', 'bots')],
        ],
      ],
      GameKind.vukodlak => [
          [
            (Strings.settingRoles, Strings.rolesCount(settings.wolfRoles.length), 'wolfRoles'),
            (Strings.settingHideRoles, settings.wolfHideRoles ? Strings.yes : Strings.no, 'wolfHideRoles'),
          ],
        ],
      GameKind.uljez => [
          [
            (Strings.settingImpostors, '${settings.uljezImpostors}', 'uljezImpostors'),
          ],
        ],
      GameKind.objasni => [
          [
            (Strings.settingTurn, '${settings.objasniSeconds} s', 'objasniSeconds'),
            (Strings.settingTarget, '${settings.objasniTarget}', 'objasniTarget'),
          ],
        ],
      GameKind.koliko => [
          [
            (Strings.settingAnswerTime, '${settings.kolikoSeconds} s', 'kolikoSeconds'),
            (Strings.settingQuestions, '${settings.kolikoQuestions}', 'kolikoQuestions'),
          ],
        ],
      GameKind.blef => [
          [(Strings.settingQuestions, '${settings.blefQuestions}', 'blefQuestions')],
        ],
      GameKind.tkobi => [
          [(Strings.settingQuestions, '${settings.tkobiPrompts}', 'tkobiPrompts')],
        ],
      },
    ];
    Widget item((String, String, String) it) {
      final text = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${it.$1}: ',
              style: const TextStyle(color: tvMuted),
            ),
            TextSpan(
              text: it.$2,
              style: TextStyle(color: it.$3 == changed ? tvAccent : tvText, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 34),
      );
      if (it.$3 != changed) return text;
      // The row the host just changed: outlined in the accent (still, no animation).
      return Container(
        key: const ValueKey('row-changed'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(border: Border.all(color: tvAccent, width: 3), borderRadius: BorderRadius.circular(14)),
        child: text,
      );
    }
    return Container(
      key: const ValueKey('game-card'),
      width: wide ? 1640 : 1360,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
      decoration: BoxDecoration(
        color: wide ? const Color(0xFA1F1F2C) : const Color(0xE61F1F2C),
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
                  for (var j = 0; j < row.length; j++) ...[
                    if (j > 0) const SizedBox(width: 32),
                    Expanded(child: item(row[j])),
                  ],
                ],
              ),
            ),
          if (wide) ...[
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
