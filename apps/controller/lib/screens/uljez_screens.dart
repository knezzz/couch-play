import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';
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
  });
  final String name, word;
  final int round;

  @override
  Widget build(BuildContext context) => RoleHoldScreen(
    name: name,
    night: round,
    header: Strings.uljezRound(round),
    heading: Strings.yourWord,
    hiddenHint: Strings.wordHint,
    role: word,
    description: Strings.wordNote,
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

/// Host: the word pack, discussion time and (7-8 players) 1 or 2 impostors.
class UljezSettingsView extends StatelessWidget {
  const UljezSettingsView({
    super.key,
    required this.players,
    required this.packs,
    required this.packId,
    required this.discussSeconds,
    required this.impostors,
    required this.onPack,
    required this.onDiscuss,
    required this.onImpostors,
  });
  final int players, discussSeconds, impostors;

  /// (id, title) of the word packs.
  final List<(String, String)> packs;
  final String? packId;
  final void Function(String id) onPack;
  final void Function(int seconds) onDiscuss;
  final void Function(int count) onImpostors;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        Strings.wordPack,
        style: TextStyle(fontSize: 18, color: muted),
      ),
      const SizedBox(height: 8),
      Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: DropdownButton<String>(
          key: const ValueKey('uljez-pack'),
          isExpanded: true,
          underline: const SizedBox.shrink(),
          value: packs.any((p) => p.$1 == packId) ? packId : null,
          dropdownColor: surface,
          style: const TextStyle(fontSize: 20, color: textColor),
          items: [
            for (final p in packs)
              DropdownMenuItem(
                value: p.$1,
                child: Text(p.$2, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) onPack(v);
          },
        ),
      ),
      const SizedBox(height: 8),
      DiscussRow(seconds: discussSeconds, onChange: onDiscuss),
      if (players >= 7) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(Strings.impostorCount, style: TextStyle(fontSize: 19)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final n in const [1, 2])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: n == 1 ? 0 : 8),
                        child: ChoiceChip(
                          key: ValueKey('impostors-$n'),
                          showCheckmark: false,
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              Strings.impostors(n),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          selected: impostors == n,
                          onSelected: (_) => onImpostors(n),
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          visualDensity: const VisualDensity(vertical: 4),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
