import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import '../theme.dart';

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

  Future<void> _addPack() async {
    final msg = await widget.addPack!(widget.conn.token);
    if (mounted) setState(() => _packMessage = msg);
  }

  Future<void> _confirmKick(PlayerInfo p) async {
    final color = playerColors[p.colorIndex % playerColors.length];
    final ok = await showModalBottomSheet<bool>(
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
                      'Remove ${p.name}?',
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
                '${p.name} leaves the game. They can join again from their phone.',
                style: const TextStyle(fontSize: 18, color: muted, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D6D),
                  foregroundColor: ink,
                ),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Remove', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: raised,
                  foregroundColor: textColor,
                ),
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep', style: TextStyle(fontSize: 22)),
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
                'Waiting for ${host?.name ?? 'the host'} to start.',
                style: const TextStyle(fontSize: 20, color: muted),
              ),
            ],
            if (isHost) ...[
              const SizedBox(height: 24),
              const Text(
                'Pick a game',
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
                      child: const Text('Quiz'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: textColor),
                      onPressed: () => widget.conn.send(
                        const StartGame(GameKind.curve, null),
                      ),
                      child: const Text('Curve'),
                    ),
                  ),
                ],
              ),
              if (l.packs.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Quiz pack',
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
                  child: const Text('Add quiz pack…'),
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
                        'Bots',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _Stepper(
                      tooltip: 'Fewer bots',
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
                      tooltip: 'More bots',
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
              'Others · ${others.length}',
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
                        '${p.name}${p.connected ? '' : ' (away)'}',
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
                        'BOT',
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
                        child: const Text('Remove'),
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
        if (host)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '★ HOST',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
      ],
    ),
  );
}
