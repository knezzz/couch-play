import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../strings.dart';
import '../tv_theme.dart';
import 'village_screen.dart';

/// The day vote (V2WolfVote). It shows who is in the vote, how many have voted
/// ("Glasalo 4 od 5") and, when the vote is over, who is out. No tallies, no
/// voters under a card, no arrows: the mayor's double vote is secret and the
/// person chose it so. [result] is the line for the banner (null while the
/// vote runs); [outId] marks the card of whoever the village threw out.
class WolfVoteScreen extends StatelessWidget {
  const WolfVoteScreen({
    required this.players,
    required this.day,
    required this.voted,
    required this.expected,
    required this.clock,
    this.outId,
    this.result,
    this.extra,
    super.key,
  });
  final List<VillagePlayer> players;
  final int day, voted, expected;
  final String clock;
  final int? outId;
  final String? result, extra;

  @override
  Widget build(BuildContext context) {
    final n = players.length;
    final big = n <= 5;
    final cols = big ? n : 4;
    final face = big ? 160.0 : 112.0;
    return Scaffold(
      backgroundColor: const Color(0xFF14141E),
      body: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          width: 1920,
          height: 1080,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A1E2E), Color(0xFF14141E)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 96,
                top: 72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.wolfVoteHeader(day),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: Color(0xFFE7B36A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      Strings.wolfVoteQuestion,
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        color: tvText,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 96,
                top: 96,
                child: Text(
                  clock.isEmpty ? Strings.wolfVoted(voted, expected) : '${Strings.wolfVoted(voted, expected)} · $clock',
                  style: const TextStyle(fontSize: 40, color: tvMuted),
                ),
              ),
              Positioned(
                left: 96,
                right: 96,
                top: big ? 300 : 260,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 28,
                  runSpacing: 28,
                  children: [
                    for (final p in players)
                      _card(p, face, (1728 - 28 * (cols - 1)) / cols),
                  ],
                ),
              ),
              if (result != null)
                Positioned(
                  left: 96,
                  right: 96,
                  bottom: 48,
                  child: Container(
                    key: const ValueKey('result'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x24FF4D6D),
                      border: Border.all(
                        color: const Color(0xFFFF4D6D),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            result!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: tvText,
                            ),
                          ),
                        ),
                        if (extra != null) ...[
                          const SizedBox(width: 32),
                          Flexible(
                            child: Text(
                              extra!,
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 34,
                                color: tvMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(VillagePlayer p, double face, double width) {
    final isOut = p.id == outId;
    final gone = p.out;
    final color = gone
        ? const Color(0xFF6E6E7A)
        : playerColors[p.colorIndex % playerColors.length];
    return SizedBox(
      key: ValueKey('vote-card-${p.id}'),
      width: width,
      child: Container(
        key: isOut ? const ValueKey('out-card') : null,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          color: isOut ? const Color(0x1FFF4D6D) : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(32),
          border: isOut
              ? Border.all(color: const Color(0xFFFF4D6D), width: 4)
              : null,
        ),
        child: Opacity(
          opacity: gone && !isOut ? 0.45 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerDot(color, size: face, character: p.character),
              const SizedBox(height: 12),
              Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: tvText,
                  decoration: gone ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
