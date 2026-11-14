import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';

const _tiles = [
  ('▲', Color(0xFFFF4D6D)),
  ('◆', Color(0xFF22B8F0)),
  ('●', Color(0xFFFFB020)),
  ('■', Color(0xFF2ECC71)),
];

/// Four full-screen tiles. The first tap sends the answer; later taps do nothing.
/// Give each question its own key so the lock resets.
class QuizScreen extends StatefulWidget {
  const QuizScreen(this.conn, this.question, this.reveal, {super.key});
  final Connection conn;
  final QuizQuestion question;
  final QuizReveal? reveal;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final r = widget.reveal;
    if (r != null) {
      final hit = r.yourPoints > 0;
      return Scaffold(
        backgroundColor: hit ? const Color(0xFF1B5E3A) : const Color(0xFF3A1B1B),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hit ? '+${r.yourPoints}' : 'Not this time',
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Total ${r.yourTotal}', style: const TextStyle(fontSize: 32)),
            ],
          ),
        ),
      );
    }
    final c = widget.question.choices;
    return Scaffold(
      body: Column(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Material(
                color: _picked == null || _picked == i ? _tiles[i].$2 : _tiles[i].$2.withValues(alpha: 0.25),
                child: InkWell(
                  onTap: () {
                    if (_picked != null) return;
                    setState(() => _picked = i);
                    widget.conn.send(Answer(i));
                  },
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_picked == i ? 'Locked in' : _tiles[i].$1,
                            style: const TextStyle(fontSize: 40, color: Colors.black87)),
                        Text(c[i],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
