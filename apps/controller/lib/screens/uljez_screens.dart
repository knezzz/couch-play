import 'package:flutter/material.dart';

import '../strings.dart';
import 'wolf_screens.dart';

// Uljez on the phone. Built from the Vukodlak pieces: the word is the hold
// card, the vote and the guess are the night list. Plain values and callbacks;
// the impostor's phone differs from the others only in the word it shows.

/// The word card: hidden until a finger is down.
class UljezWordScreen extends StatelessWidget {
  const UljezWordScreen({
    super.key,
    required this.name,
    required this.round,
    required this.word,
    this.stage = '',
    this.bottom,
  });
  final Widget? bottom;
  final String name, word;

  /// 'clues': shown top right (Tragovi).
  final String stage;
  final int round;

  @override
  Widget build(BuildContext context) => RoleHoldScreen(
    name: Strings.uljezRound(round),
    night: round,
    header: Strings.uljezStage(stage),
    heading: Strings.yourWord,
    hiddenHint: Strings.wordHint,
    role: word,
    description: Strings.wordNote,
    bottom: bottom,
  );
}

/// "Tko je uljez?": pick one player, Glasaj.
class UljezVoteScreen extends StatelessWidget {
  const UljezVoteScreen({
    super.key,
    required this.targets,
    required this.onVote,
    this.picked,
  });
  final int? picked;
  final List<NightItem> targets;
  final void Function(int target) onVote;

  @override
  Widget build(BuildContext context) => NightScreen(
    night: 0,
    header: Strings.uljezVoteHeader,
    title: Strings.whoIsImpostor,
    confirmLabel: Strings.vote,
    hint: '',
    showSpecial: false,
    picked: picked,
    targets: targets,
    onConfirm: (t, _, _) => onVote(t),
  );
}

/// The caught impostor's guess: the village's word from the options.
class UljezGuessScreen extends StatelessWidget {
  const UljezGuessScreen({
    super.key,
    required this.word,
    required this.options,
    required this.onGuess,
  });
  final String word;
  final List<NightItem> options;
  final void Function(int option) onGuess;

  @override
  Widget build(BuildContext context) => NightScreen(
    night: 0,
    header: Strings.guessHeader,
    title: Strings.caught,
    hint: Strings.caughtHint(word),
    showSpecial: false,
    targets: options,
    onConfirm: (t, _, _) => onGuess(t),
  );
}

