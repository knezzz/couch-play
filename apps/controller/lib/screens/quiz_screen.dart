import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import '../theme.dart';
import '../strings.dart';

// Shapes are drawn (ShapeMark), not typed glyphs: no font fallback needed offline.
const _tiles = [
  Color(0xFFFF4D6D),
  Color(0xFF22B8F0),
  Color(0xFFFFB020),
  Color(0xFF2ECC71),
];

/// Four full-screen tiles. The first tap sends the answer; later taps do nothing.
/// Give each question its own key so the lock resets. [total] is your running score.
class QuizScreen extends StatefulWidget {
  const QuizScreen(
    this.conn,
    this.question,
    this.reveal, {
    this.total = 0,
    super.key,
  });
  final Connection conn;
  final QuizQuestion? question; // null after a reconnect mid-reveal
  final QuizReveal? reveal;
  final int total;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int? _picked;

  Widget _reveal(QuizReveal r) {
    final hit = r.yourPoints > 0;
    final c = widget.question?.choices;
    final right = c != null && r.correctIndex >= 0 && r.correctIndex < 4
        ? c[r.correctIndex]
        : null;
    return Scaffold(
      backgroundColor: hit ? const Color(0xFF1B5E3A) : const Color(0xFF3A1B1B),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hit ? Strings.correct : Strings.notThisTime,
                  style: TextStyle(
                    fontSize: hit ? 20 : 40,
                    fontWeight: hit ? FontWeight.w500 : FontWeight.w900,
                    color: hit
                        ? const Color(0xFFCFEFDC)
                        : const Color(0xFFEFCFCF),
                  ),
                ),
                const SizedBox(height: 16),
                if (hit)
                  Text(
                    '+${r.yourPoints}',
                    style: const TextStyle(
                      fontSize: 96,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                  ),
                if (right != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x5914141E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShapeMark(r.correctIndex, 28, _tiles[r.correctIndex]),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                const Text(Strings.yourTotal, style: TextStyle(fontSize: 22)),
                Text(
                  '${r.yourTotal}',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reveal;
    if (r != null) return _reveal(r);
    final q = widget.question;
    // One neutral screen, the same whatever was picked, so nobody can read the answer off it.
    if (_picked != null) {
      return const Scaffold(
        backgroundColor: surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                Strings.locked,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      );
    }
    final c = q?.choices ?? const ['', '', '', ''];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              SizedBox(
                height: 32,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        q == null
                            ? ''
                            : Strings.questionHeader(q.number, q.total),
                        style: const TextStyle(fontSize: 16, color: muted),
                      ),
                    ),
                    Text(
                      '${widget.total}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < 4; i++) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: Material(
                    color: _tiles[i],
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        if (_picked != null) return;
                        setState(() => _picked = i);
                        widget.conn.send(Answer(i));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            ShapeMark(i, 32, ink),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                c[i],
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: c[i].length > 28 ? 20 : 24,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                  color: ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
