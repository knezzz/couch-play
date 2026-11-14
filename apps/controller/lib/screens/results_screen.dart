import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// Plain results for this phone. Task 7 polishes it.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen(this.placements, this.myId, {super.key});
  final List<Placement> placements;
  final int myId;

  static String ordinal(int n) {
    final tens = n % 100;
    if (tens >= 11 && tens <= 13) return '${n}th';
    return '$n${const {1: 'st', 2: 'nd', 3: 'rd'}[n % 10] ?? 'th'}';
  }

  @override
  Widget build(BuildContext context) {
    final mine = placements.where((p) => p.playerId == myId).firstOrNull;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: mine == null
              ? const Text('The game is over.', style: TextStyle(fontSize: 32))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'You placed ${ordinal(mine.place)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '+${mine.sessionPoints} session points',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
