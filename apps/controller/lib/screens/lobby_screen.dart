import 'package:core/core.dart';
import 'package:flutter/material.dart';

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
  String? _packId;
  String? _packMessage;
  bool _settingsOpen = false;

  Future<void> _addPack() async {
    final msg = await widget.addPack!(widget.conn.token);
    if (mounted) setState(() => _packMessage = msg);
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

  @override
  Widget build(BuildContext context) {
    final l = widget.lobby;
    final players = l.players;
    final me = players.where((p) => p.id == widget.myId).firstOrNull;
    final isHost = l.hostId == widget.myId;
    final bots = players.where((p) => p.bot).length;
    final host = players.where((p) => p.id == l.hostId).firstOrNull;
    final packId = l.packs.any((p) => p.id == _packId)
        ? _packId
        : l.packs.firstOrNull?.id;

    final others = [
      for (final p in players)
        if (p.id != widget.myId) p,
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            if (me != null) _MyChip(me, host: isHost),
            if (!isHost) ...[
              const SizedBox(height: 16),
              Text(
                Strings.waitingForHost(host?.name),
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
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          widget.conn.send(StartGame(GameKind.quiz, packId)),
                      child: const Text(Strings.quiz),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: textColor),
                      onPressed: () => widget.conn.send(
                        const StartGame(GameKind.curve, null),
                      ),
                      child: const Text(Strings.curve),
                    ),
                  ),
                ],
              ),
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
                      onChanged: (v) => setState(() => _packId = v),
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
            const SizedBox(height: 16),
            _Settings(
              l.settings,
              open: _settingsOpen,
              editable: isHost,
              onToggle: () => setState(() => _settingsOpen = !_settingsOpen),
              onChange: (s) => widget.conn.send(SetSettings(s)),
            ),
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

/// Collapsed by default so it does not crowd the host lobby. Shows what the TV
/// last sent; a tap only sends, the next LobbyState changes the number.
class _Settings extends StatelessWidget {
  const _Settings(
    this.s, {
    required this.open,
    required this.editable,
    required this.onToggle,
    required this.onChange,
  });
  final GameSettings s;
  final bool open, editable;
  final VoidCallback onToggle;
  final void Function(GameSettings) onChange;

  GameSettings _with({int? sec, int? qs, int? rev, int? cd}) => GameSettings(
    quizSeconds: sec ?? s.quizSeconds,
    quizQuestions: qs ?? s.quizQuestions,
    revealSeconds: rev ?? s.revealSeconds,
    curveCountdown: cd ?? s.curveCountdown,
  );

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onToggle,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      Strings.settings,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more, size: 28),
                ],
              ),
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _group(Strings.quiz),
                _row(Strings.quizSeconds, s.quizSeconds, 10, 60, 5, (v) => _with(sec: v)),
                _row(Strings.quizQuestions, s.quizQuestions, 5, 30, 5, (v) => _with(qs: v), unit: false),
                _row(Strings.revealSeconds, s.revealSeconds, 2, 15, 1, (v) => _with(rev: v)),
                _group(Strings.curve),
                _row(Strings.curveCountdown, s.curveCountdown, 1, 10, 1, (v) => _with(cd: v)),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _group(String t) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Text(
      t,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: muted),
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
            if (editable)
              _Stepper(
                tooltip: Strings.lessOf(label),
                icon: Icons.remove,
                onPressed: value - step >= min ? () => onChange(make(value - step)) : null,
              ),
            Expanded(
              child: Text(
                unit ? Strings.seconds(value) : '$value',
                textAlign: editable ? TextAlign.center : TextAlign.start,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            if (editable)
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
