import 'package:flutter/material.dart';

import '../strings.dart';
import 'sent_hold.dart';
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
class UljezVoteScreen extends StatefulWidget {
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
  State<UljezVoteScreen> createState() => _VoteState();
}

class _VoteState extends State<UljezVoteScreen> {
  late int? _sent = widget.picked; // a reload restores a sent vote

  @override
  Widget build(BuildContext context) {
    final who = widget.targets.where((t) => t.id == _sent).firstOrNull;
    if (who != null) {
      return SentHoldScreen(
        key: const ValueKey('uljez-vote-sent'),
        title: Strings.uljezVoteHeader,
        label: Strings.yourVoteCaps,
        answer: who.label,
      );
    }
    return NightScreen(
      night: 0,
      header: Strings.uljezVoteHeader,
      title: Strings.whoIsImpostor,
      confirmLabel: Strings.vote,
      hint: '',
      showSpecial: false,
      targets: widget.targets,
      onConfirm: (t, _, _) {
        setState(() => _sent = t);
        widget.onVote(t);
      },
    );
  }
}

/// The caught impostor's guess: the village's word from the options.
class UljezGuessScreen extends StatefulWidget {
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
  State<UljezGuessScreen> createState() => _GuessState();
}

class _GuessState extends State<UljezGuessScreen> {
  int? _sent;

  @override
  Widget build(BuildContext context) {
    final w = widget.options.where((o) => o.id == _sent).firstOrNull;
    if (w != null) {
      return SentHoldScreen(
        key: const ValueKey('uljez-guess-sent'),
        title: Strings.guessHeader,
        label: Strings.yourAnswerCaps,
        answer: w.label,
      );
    }
    return NightScreen(
      night: 0,
      header: Strings.guessHeader,
      title: Strings.caught,
      hint: Strings.caughtHint(widget.word),
      showSpecial: false,
      targets: widget.options,
      onConfirm: (t, _, _) {
        setState(() => _sent = t);
        widget.onGuess(t);
      },
    );
  }
}

