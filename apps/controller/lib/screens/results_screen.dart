import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../strings.dart';

/// Plain results for this phone. Task 7 polishes it.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen(this.placements, this.myId, {super.key});
  final List<Placement> placements;
  final int myId;

  @override
  Widget build(BuildContext context) {
    final mine = placements.where((p) => p.playerId == myId).firstOrNull;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: mine == null
              ? const Text(Strings.gameOver, style: TextStyle(fontSize: 32))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Strings.placed(mine.place),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      Strings.sessionPoints(mine.sessionPoints),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
