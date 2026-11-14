import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _bg = Color(0xFF14141E);
const _ink = Color(0xFF14141E);

/// Designed on a 1920x1080 canvas and scaled to fit, so type stays readable
/// from the couch on any TV.
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({
    required this.joinUrl,
    required this.players,
    required this.hostId,
    super.key,
  });

  /// `http://<ip>:<port>/`, or null when the TV has no LAN address.
  final String? joinUrl;
  final List<PlayerInfo> players;
  final int? hostId;

  @override
  Widget build(BuildContext context) {
    final byScore = [...players]..sort((a, b) => b.sessionScore.compareTo(a.sessionScore));
    return Scaffold(
      backgroundColor: _bg,
      body: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Padding(
            padding: const EdgeInsets.all(64),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 640, child: _Join(joinUrl)),
              const SizedBox(width: 64),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (players.isEmpty)
                    const Text('Scan the code with your phone to join.',
                        style: TextStyle(fontSize: 56, color: Colors.white))
                  else
                    Wrap(spacing: 24, runSpacing: 24, children: [
                      for (final p in players) _Chip(p, host: p.id == hostId),
                    ]),
                  const Spacer(),
                  if (players.isNotEmpty) ...[
                    const Text('Scoreboard',
                        style: TextStyle(fontSize: 44, color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    for (final p in byScore) _ScoreRow(p),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Join extends StatelessWidget {
  const _Join(this.url);
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return const Center(
        child: Text('Connect the TV to Wi-Fi to play.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 64, color: Colors.white)),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40)),
        child: QrImageView(data: url!, size: 512, backgroundColor: Colors.white),
      ),
      const SizedBox(height: 32),
      const Text('Scan to join', style: TextStyle(fontSize: 44, color: Colors.white70)),
      Text(url!, style: const TextStyle(fontSize: 52, color: Colors.white, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.p, {required this.host});
  final PlayerInfo p;
  final bool host;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: p.connected ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
          decoration: BoxDecoration(
            color: playerColors[p.colorIndex % playerColors.length],
            borderRadius: BorderRadius.circular(56),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${host ? '★ ' : ''}${p.name}',
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: _ink)),
            if (p.bot) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(12)),
                child: const Text('bot', style: TextStyle(fontSize: 28, color: Colors.white)),
              ),
            ],
          ]),
        ),
      );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.p);
  final PlayerInfo p;

  @override
  Widget build(BuildContext context) => Padding(
        key: ValueKey('score-${p.name}'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: playerColors[p.colorIndex % playerColors.length], shape: BoxShape.circle),
          ),
          const SizedBox(width: 20),
          Expanded(child: Text(p.name, style: const TextStyle(fontSize: 40, color: Colors.white))),
          Text('${p.sessionScore}',
              style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      );
}
