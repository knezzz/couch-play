import 'package:core/core.dart';
import 'package:flutter/material.dart';

const _bg = Color(0xFF14141E);
const _ink = Color(0xFF14141E);

/// Shown for 8 s after a game: the placements and the session scoreboard.
/// Reads only [Placement]s and [PlayerInfo]s, so Curve and the quiz share it.
/// Designed on 1920x1080 and scaled to fit, like the lobby.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({required this.placements, required this.players, super.key});
  final List<Placement> placements;
  final List<PlayerInfo> players;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame, never during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) EffectLayer.play(context, EffectName.confetti);
    });
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final p in widget.players) p.id: p};
    final byScore = [...widget.players]
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
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Results',
                        style: TextStyle(fontSize: 64, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      for (final pl in widget.placements) _PlaceRow(pl, byId[pl.playerId]),
                    ],
                  ),
                ),
                const SizedBox(width: 64),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scoreboard',
                        style: TextStyle(fontSize: 44, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      for (final p in byScore) _ScoreRow(p),
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
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow(this.pl, this.p);
  final Placement pl;
  final PlayerInfo? p;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('place-${pl.playerId}'),
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '${pl.place}',
            style: const TextStyle(fontSize: 60, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            decoration: BoxDecoration(
              color: playerColors[(p?.colorIndex ?? 0) % playerColors.length],
              borderRadius: BorderRadius.circular(48),
            ),
            child: Text(
              p?.name ?? 'Player',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: _ink),
            ),
          ),
        ),
        const SizedBox(width: 32),
        Text(
          '+${pl.sessionPoints}',
          style: const TextStyle(fontSize: 52, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.p);
  final PlayerInfo p;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: playerColors[p.colorIndex % playerColors.length],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 40, color: Colors.white),
          ),
        ),
        Text(
          '${p.sessionScore}',
          style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
