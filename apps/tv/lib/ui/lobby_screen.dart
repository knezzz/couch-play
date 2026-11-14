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
    required this.onQuit,
    super.key,
  });

  /// `http://<ip>:<port>/`, or null when the TV has no LAN address.
  final String? joinUrl;
  final List<PlayerInfo> players;
  final int? hostId;

  /// The Quit item: exits the app.
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final byScore = [...players]
      ..sort((a, b) => b.sessionScore.compareTo(a.sessionScore));
    return Scaffold(
      backgroundColor: _bg,
      body: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Padding(
            padding: const EdgeInsets.all(64),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 640,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _Join(joinUrl)),
                      const SizedBox(height: 24),
                      FocusTraversalGroup(
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 16,
                          children: [
                            FilledButton(
                              autofocus: true,
                              onPressed: () => _howToJoin(context),
                              child: const Text('How to join'),
                            ),
                            FilledButton(
                              onPressed: onQuit,
                              child: const Text('Quit'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 64),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (players.isEmpty)
                        const Text(
                          'Scan the code with your phone to join.',
                          style: TextStyle(fontSize: 56, color: Colors.white),
                        )
                      else
                        // 5+ players: two fixed-width columns with smaller type.
                        // Long names are cut with an ellipsis, never scaled down.
                        Wrap(
                          spacing: 24,
                          runSpacing: 16,
                          children: [
                            for (final p in players)
                              _Chip(
                                p,
                                host: p.id == hostId,
                                compact: players.length > 4,
                              ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      // Nothing to rank before the first game.
                      if (byScore.isNotEmpty &&
                          byScore.first.sessionScore > 0) ...[
                        const Text(
                          'Scoreboard',
                          style: TextStyle(
                            fontSize: 44,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final p in byScore) _ScoreRow(p),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _howToJoin(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('How to join', style: TextStyle(fontSize: 44)),
      content: const Text(
        '1. Connect your phone to the same Wi-Fi as this TV.\n'
        '2. Scan the code, or type the address into your phone\'s browser.\n'
        '3. Type a name and tap Join.',
        style: TextStyle(fontSize: 36, height: 1.4),
      ),
      actions: [
        Builder(
          builder: (c) => FilledButton(
            autofocus: true,
            onPressed: () => Navigator.pop(c),
            child: const Text('Got it'),
          ),
        ),
      ],
    ),
  );
}

class _Join extends StatelessWidget {
  const _Join(this.url);
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return const Center(
        child: Text(
          'Connect the TV to Wi-Fi to play.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 64, color: Colors.white),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
          ),
          child: QrImageView(
            data: url!,
            size: 512,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Scan to join',
          style: TextStyle(fontSize: 44, color: Colors.white70),
        ),
        // The QR keeps the full URL; the text drops "http://" and never wraps.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            url!.replaceFirst('http://', ''),
            maxLines: 1,
            style: const TextStyle(
              fontSize: 52,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.p, {required this.host, required this.compact});
  final PlayerInfo p;
  final bool host, compact;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: p.connected ? 1 : 0.6,
    child: Container(
      // Never wider than the chip area, even for a 16-wide-letter name.
      constraints: BoxConstraints(maxWidth: compact ? 532 : 1088),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 28 : 36,
        vertical: compact ? 10 : 20,
      ),
      decoration: BoxDecoration(
        color: playerColors[p.colorIndex % playerColors.length],
        borderRadius: BorderRadius.circular(56),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '${host ? '★ ' : ''}${p.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 40 : 56,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
          ),
          if (p.bot) ...[const SizedBox(width: 16), const _Badge('bot')],
          if (!p.connected) ...[
            const SizedBox(width: 16),
            const _Badge('away'),
          ],
        ],
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: _ink,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 28, color: Colors.white),
    ),
  );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.p);
  final PlayerInfo p;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('score-${p.name}'),
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: playerColors[p.colorIndex % playerColors.length],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            p.name,
            style: const TextStyle(fontSize: 40, color: Colors.white),
          ),
        ),
        Text(
          '${p.sessionScore}',
          style: const TextStyle(
            fontSize: 40,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
