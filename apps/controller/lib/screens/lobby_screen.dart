import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';

const _ink = Color(0xFF14141E);
const _seats = 8;

class LobbyScreen extends StatefulWidget {
  const LobbyScreen(this.conn, this.lobby, this.myId, {super.key});
  final Connection conn;
  final LobbyState lobby;
  final int myId;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String? _packId;

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

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (me != null) _Chip(me, big: true),
            const SizedBox(height: 8),
            Text(
              isHost
                  ? 'You are the host. Pick a game.'
                  : 'Waiting for ${host?.name ?? 'the host'} to start.',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 16),
            if (isHost) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Fewer bots',
                    icon: const Icon(Icons.remove),
                    onPressed: bots > 0
                        ? () => widget.conn.send(SetBots(bots - 1))
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Bots $bots',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'More bots',
                    icon: const Icon(Icons.add),
                    onPressed: players.length < _seats
                        ? () => widget.conn.send(SetBots(bots + 1))
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                ),
                onPressed: () =>
                    widget.conn.send(const StartGame(GameKind.curve, null)),
                child: const Text('Curve', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(height: 12),
              if (l.packs.isNotEmpty)
                DropdownButton<String>(
                  isExpanded: true,
                  value: packId,
                  items: [
                    for (final p in l.packs)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.title} (${p.questionCount})'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _packId = v),
                ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                ),
                onPressed: () =>
                    widget.conn.send(StartGame(GameKind.quiz, packId)),
                child: const Text('Quiz', style: TextStyle(fontSize: 24)),
              ),
            ],
            const SizedBox(height: 16),
            for (final p in players)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: _Chip(p, host: p.id == l.hostId)),
                    if (isHost && !p.bot && p.id != widget.myId)
                      IconButton(
                        tooltip: 'Remove ${p.name}',
                        icon: const Icon(Icons.person_remove),
                        onPressed: () => widget.conn.send(Kick(p.id)),
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

class _Chip extends StatelessWidget {
  const _Chip(this.p, {this.host = false, this.big = false});
  final PlayerInfo p;
  final bool host, big;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: big ? 16 : 10),
    decoration: BoxDecoration(
      color: playerColors[p.colorIndex % playerColors.length],
      borderRadius: BorderRadius.circular(32),
    ),
    child: Text(
      '${host ? '★ ' : ''}${p.name}${p.bot ? '  (bot)' : ''}${p.connected ? '' : '  (away)'}',
      style: TextStyle(
        fontSize: big ? 32 : 22,
        fontWeight: FontWeight.bold,
        color: _ink,
      ),
    ),
  );
}
