import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _shapes = ['▲', '◆', '●', '■'];
const _tileColors = [Color(0xFFFF4D6D), Color(0xFF22B8F0), Color(0xFFFFB020), Color(0xFF2ECC71)];
const _ink = Color(0xFF14141E);

/// One quiz question on a 1920x1080 canvas, scaled to fit. Pure: [Session]
/// rebuilds it on each tick. [correctIndex] is null while asking.
class QuizScreen extends StatelessWidget {
  const QuizScreen({
    required this.question,
    required this.choices,
    required this.number,
    required this.total,
    required this.remaining,
    required this.answered,
    required this.expected,
    required this.players,
    this.svg,
    this.correctIndex,
    this.picks = const {},
    this.totals = const {},
    super.key,
  });

  final String question;
  final Uint8List? svg;
  final List<String> choices;
  final int number, total, answered, expected;

  /// Countdown, 1 down to 0.
  final double remaining;
  final int? correctIndex;

  /// Player id -> shown choice index. Only used at the reveal.
  final Map<int, int> picks;
  final List<PlayerInfo> players;
  final Map<int, int> totals;

  Color _color(PlayerInfo p) => playerColors[p.colorIndex % playerColors.length];

  @override
  Widget build(BuildContext context) {
    final reveal = correctIndex != null;
    final byScore = [...players]..sort((a, b) => (totals[b.id] ?? 0).compareTo(totals[a.id] ?? 0));
    return Scaffold(
      backgroundColor: _ink,
      body: FittedBox(
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('Question $number of $total',
                        style: const TextStyle(fontSize: 40, color: Colors.white70)),
                    const Spacer(),
                    if (!reveal)
                      Text('$answered of $expected answered',
                          style: const TextStyle(
                              fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: reveal ? 0 : remaining.clamp(0.0, 1.0),
                    minHeight: 16,
                    backgroundColor: Colors.white12,
                    color: remaining < 0.25 ? Colors.redAccent : Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 260,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(question,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 60, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      if (svg != null) ...[
                        const SizedBox(width: 32),
                        Container(
                          width: 360,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: SvgPicture.memory(svg!),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Column(
                    children: [
                      for (var r = 0; r < 2; r++) ...[
                        if (r == 1) const SizedBox(height: 24),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var c = 0; c < 2; c++) ...[
                                if (c == 1) const SizedBox(width: 24),
                                Expanded(child: _tile(r * 2 + c)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (reveal) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 32,
                    runSpacing: 8,
                    children: [
                      for (final p in byScore)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(color: _color(p), shape: BoxShape.circle)),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 34, color: Colors.white)),
                              ),
                              const SizedBox(width: 12),
                              Text('${totals[p.id] ?? 0}',
                                  style: const TextStyle(
                                      fontSize: 34, color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(int i) {
    final reveal = correctIndex != null;
    final dim = reveal && correctIndex != i;
    final voters = [
      for (final p in players)
        if (reveal && picks[p.id] == i) p,
    ];
    return Opacity(
      opacity: dim ? 0.3 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: _tileColors[i],
          borderRadius: BorderRadius.circular(32),
          border: reveal && !dim ? Border.all(color: Colors.white, width: 10) : null,
        ),
        child: Row(
          children: [
            Text(_shapes[i], style: const TextStyle(fontSize: 72, color: _ink)),
            const SizedBox(width: 24),
            Expanded(
              child: Text(choices[i],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: _ink)),
            ),
            if (voters.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in voters)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _color(p),
                        shape: BoxShape.circle,
                        border: Border.all(color: _ink, width: 4),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
