import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../character_grid.dart';
import '../connection.dart';
import '../theme.dart';
import '../strings.dart';

const _seats = 8;

class LobbyScreen extends StatefulWidget {
  const LobbyScreen(
    this.conn,
    this.lobby,
    this.myId, {
    this.addPack,
    super.key,
  });
  final Connection conn;
  final LobbyState lobby;
  final int myId;

  /// Picks a pack file and uploads it with the host's token. Returns what the
  /// TV said, or null if nothing was picked. Null here hides the button (tests).
  final Future<String?> Function(String token)? addPack;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String? _packMessage;
  /// The TV decides what is open: a tap only asks, LobbyState.selected answers.
  void _select(GameKind? k) => widget.conn.send(SelectGame(k));

  Future<void> _addPack() async {
    final msg = await widget.addPack!(widget.conn.token);
    if (mounted) setState(() => _packMessage = msg);
  }

  /// A tap only asks. The TV answers with a LobbyState (changed) or an
  /// ErrorMsg (refused: the banner shows its reason, the old one stays).
  Future<void> _pickCharacter(PlayerInfo me, List<PlayerInfo> players) async {
    final taken = {
      for (final p in players)
        if (p.id != me.id && p.character.isNotEmpty) p.character,
    };
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      barrierColor: const Color(0xCC0A0A10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                Strings.pickCharacter,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              CharacterGrid(
                selected: me.character,
                taken: taken,
                color: playerColors[me.colorIndex % playerColors.length],
                onPick: (id) {
                  Navigator.pop(c);
                  if (id != me.character) widget.conn.send(SetCharacter(id));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmKick(PlayerInfo p) async {
    final color = playerColors[p.colorIndex % playerColors.length];
    final ok = await showModalBottomSheet<bool>(
      isScrollControlled:
          true, // the Croatian text can need more than the default 9/16 height
      context: context,
      backgroundColor: surface,
      barrierColor: const Color(0xCC0A0A10),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      Strings.removeTitle(p.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                Strings.removeBody(p.name),
                style: const TextStyle(fontSize: 18, color: muted, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D6D),
                  foregroundColor: ink,
                ),
                onPressed: () => Navigator.pop(c, true),
                child: const Text(
                  Strings.remove,
                  style: TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: raised,
                  foregroundColor: textColor,
                ),
                onPressed: () => Navigator.pop(c, false),
                child: const Text(Strings.keep, style: TextStyle(fontSize: 22)),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) widget.conn.send(Kick(p.id));
  }

  GameSettings _withPack(GameSettings s, String? id) => GameSettings(
    quizSeconds: s.quizSeconds,
    quizQuestions: s.quizQuestions,
    revealSeconds: s.revealSeconds,
    curveCountdown: s.curveCountdown,
    curveMode: s.curveMode,
    quizPackId: id,
  );

  Widget _details(GameKind kind, LobbyState l, String? packId) {
    final s = l.settings;
    void change(GameSettings n) => widget.conn.send(SetSettings(n));
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  foregroundColor: accent,
                  textStyle: const TextStyle(fontSize: 20),
                ),
                onPressed: () => _select(null),
                icon: const Icon(Icons.arrow_back, size: 28),
                label: const Text(Strings.back),
              ),
            ),
            Text(
              Strings.gameName(kind),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              Strings.gameBlurb(kind),
              style: const TextStyle(fontSize: 20, color: muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (kind == GameKind.quiz) ...[
              if (l.packs.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  Strings.quizPack,
                  style: TextStyle(fontSize: 16, color: muted),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: packId,
                      dropdownColor: surface,
                      style: const TextStyle(fontSize: 20, color: textColor),
                      items: [
                        for (final p in l.packs)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              '${p.title} (${p.questionCount})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => change(_withPack(s, v)),
                    ),
                  ),
                ),
              ],
              if (widget.addPack != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: accent,
                    side: const BorderSide(color: raised, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: _addPack,
                  child: const Text(Strings.addPack),
                ),
                if (_packMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _packMessage!,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
              ],
            ],
            _GameSettings(kind, s, onChange: change),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => widget.conn.send(StartGame(kind, null)),
              child: const Text(Strings.play),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lobby;
    final players = l.players;
    final me = players.where((p) => p.id == widget.myId).firstOrNull;
    final isHost = l.hostId == widget.myId;
    final bots = players.where((p) => p.bot).length;
    final host = players.where((p) => p.id == l.hostId).firstOrNull;
    final packId = l.packs.any((p) => p.id == l.settings.quizPackId)
        ? l.settings.quizPackId
        : l.packs.firstOrNull?.id;

    final others = [
      for (final p in players)
        if (p.id != widget.myId) p,
    ];

    final kind = l.selected;
    if (isHost && kind != null) {
      return _details(kind, l, packId);
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            if (me != null) ...[
              _MyChip(me, host: isHost),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    foregroundColor: accent,
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  onPressed: () => _pickCharacter(me, players),
                  child: const Text(Strings.changeCharacter),
                ),
              ),
            ],
            if (!isHost) ...[
              const SizedBox(height: 16),
              Text(
                l.selected == null
                    ? Strings.waitingForHost(host?.name)
                    : Strings.watching(host?.name, Strings.gameName(l.selected!)),
                style: const TextStyle(fontSize: 20, color: muted),
              ),
            ],
            if (isHost) ...[
              const SizedBox(height: 24),
              const Text(
                Strings.pickGame,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
              const SizedBox(height: 16),
              _Carousel(onPick: _select),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        Strings.bots,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _Stepper(
                      tooltip: Strings.fewerBots,
                      icon: Icons.remove,
                      onPressed: bots > 0
                          ? () => widget.conn.send(SetBots(bots - 1))
                          : null,
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '$bots',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _Stepper(
                      tooltip: Strings.moreBots,
                      icon: Icons.add,
                      onPressed: players.length < _seats
                          ? () => widget.conn.send(SetBots(bots + 1))
                          : null,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              Strings.others(others.length),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
            const SizedBox(height: 8),
            for (final p in others)
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Opacity(
                      opacity: p.connected ? 1 : 0.6,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color:
                              playerColors[p.colorIndex % playerColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${p.name}${p.connected ? '' : Strings.away}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          color: p.connected ? textColor : muted,
                        ),
                      ),
                    ),
                    if (p.bot)
                      const Text(
                        Strings.botTag,
                        style: TextStyle(fontSize: 18, color: muted),
                      )
                    else if (isHost)
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: surface,
                          foregroundColor: muted,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        onPressed: () => _confirmKick(p),
                        child: const Text(Strings.remove),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One game's settings, always shown. The host's tap only sends; the next
/// LobbyState changes the number.
class _GameSettings extends StatelessWidget {
  const _GameSettings(this.kind, this.s, {required this.onChange});
  final GameKind kind;
  final GameSettings s;
  final void Function(GameSettings) onChange;

  GameSettings _with({int? sec, int? qs, int? rev, int? cd, CurveMode? mode}) =>
      GameSettings(
        quizSeconds: sec ?? s.quizSeconds,
        quizQuestions: qs ?? s.quizQuestions,
        revealSeconds: rev ?? s.revealSeconds,
        curveCountdown: cd ?? s.curveCountdown,
        curveMode: mode ?? s.curveMode,
        quizPackId: s.quizPackId,
      );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kind == GameKind.quiz) ...[
          _row(Strings.quizSeconds, s.quizSeconds, 10, 60, 5, (v) => _with(sec: v)),
          _row(Strings.quizQuestions, s.quizQuestions, 5, 30, 5, (v) => _with(qs: v), unit: false),
          _row(Strings.revealSeconds, s.revealSeconds, 2, 15, 1, (v) => _with(rev: v)),
        ] else ...[
          _row(Strings.curveCountdown, s.curveCountdown, 1, 10, 1, (v) => _with(cd: v)),
          _modes(),
        ],
      ],
    ),
  );

  Widget _modes() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(Strings.curveModeLabel, style: TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        for (final m in CurveMode.values)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onChange(_with(mode: m)),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  Icon(
                    m == s.curveMode ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 28,
                    color: m == s.curveMode ? accent : muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      Strings.curveMode(m),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: m == s.curveMode ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _row(
    String label,
    int value,
    int min,
    int max,
    int step,
    GameSettings Function(int) make, {
    bool unit = true,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Row(
          children: [
            _Stepper(
              tooltip: Strings.lessOf(label),
              icon: Icons.remove,
              onPressed: value - step >= min ? () => onChange(make(value - step)) : null,
            ),
            Expanded(
              child: Text(
                unit ? Strings.seconds(value) : '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            _Stepper(
              tooltip: Strings.moreOf(label),
              icon: Icons.add,
              onPressed: value + step <= max ? () => onChange(make(value + step)) : null,
            ),
          ],
        ),
      ],
    ),
  );
}

/// Swipeable big cards; a tap opens that game's details.
class _Carousel extends StatelessWidget {
  const _Carousel({required this.onPick});
  final void Function(GameKind) onPick;

  static const _icons = {GameKind.quiz: Icons.quiz, GameKind.curve: Icons.timeline};

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 220,
    child: PageView(
      padEnds: false,
      controller: PageController(viewportFraction: 0.82),
      children: [
        for (final k in GameKind.values)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => onPick(k),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_icons[k], size: 56, color: accent),
                      const Spacer(),
                      Text(
                        Strings.gameName(k),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Strings.gameBlurb(k),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 56,
    child: IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: raised,
        foregroundColor: textColor,
        disabledForegroundColor: muted.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 28),
      onPressed: onPressed,
    ),
  );
}

class _MyChip extends StatelessWidget {
  const _MyChip(this.p, {required this.host});
  final PlayerInfo p;
  final bool host;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: playerColors[p.colorIndex % playerColors.length],
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        if (p.character.isNotEmpty) ...[
          KeyedSubtree(
            key: ValueKey('my-character-${p.character}'),
            child: CharacterFace(
              p.character,
              44,
              ink.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
        ),
        // The star alone marks the host: no word, so long names keep their room.
        if (host) ...[
          const SizedBox(width: 8),
          const Icon(Icons.star, size: 28, color: ink),
        ],
      ],
    ),
  );
}
