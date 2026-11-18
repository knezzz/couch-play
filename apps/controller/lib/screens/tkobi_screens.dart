import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';
import 'settings_widgets.dart';

/// A player on the vote or the result.
class TkobiPlayer {
  const TkobiPlayer(this.id, this.name, this.character, this.colorIndex);
  final int id;
  final String name, character;
  final int colorIndex;
}

Widget _face(TkobiPlayer p, double size) => CharacterFace(
  p.character.isEmpty ? characterIds.first : p.character,
  size,
  playerColors[p.colorIndex % playerColors.length],
);

/// The prompt and every player to vote for, yourself included. One tap, final.
class TkobiAskScreen extends StatefulWidget {
  const TkobiAskScreen({
    super.key,
    required this.number,
    required this.total,
    required this.seconds,
    required this.text,
    required this.players,
    required this.onVote,
    this.picked,
  });
  final int number, total, seconds;
  final String text;
  final List<TkobiPlayer> players;
  final int? picked;
  final void Function(int id) onVote;

  @override
  State<TkobiAskScreen> createState() => _AskState();
}

class _AskState extends State<TkobiAskScreen> {
  late int _left = widget.seconds;
  late int? _picked = widget.picked;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left > 0) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool get _open => _picked == null && _left > 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Strings.questionOf(widget.number, widget.total),
                    style: const TextStyle(fontSize: 18, color: muted),
                  ),
                ),
                Text(
                  Strings.minutes(_left),
                  key: const ValueKey('tkobi-clock'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.text,
              key: const ValueKey('tkobi-text'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final p in widget.players)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: _picked == p.id
                            ? accent.withValues(alpha: 0.25)
                            : surface,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          key: ValueKey('vote-${p.id}'),
                          borderRadius: BorderRadius.circular(16),
                          // Checked when tapped, not when built: two quick taps
                          // must not send two votes.
                          onTap: () {
                            if (!_open) return;
                            setState(() => _picked = p.id);
                            widget.onVote(p.id);
                          },
                          child: Container(
                            height: 64,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _picked == p.id
                                    ? accent
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: Row(
                              children: [
                                _face(p, 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
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
              ),
            ),
            if (_picked != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  Strings.tkobiVoted,
                  key: ValueKey('tkobi-voted'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: muted),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// After the reveal: the votes each player got (public), who is crowned, and
/// whether your own vote went to the winner. Nobody's vote is shown.
class TkobiResultScreen extends StatelessWidget {
  const TkobiResultScreen({
    super.key,
    required this.players,
    required this.counts,
    required this.crowned,
    required this.votedRight,
    required this.points,
    required this.total,
  });
  final List<TkobiPlayer> players;
  final Map<int, int> counts;
  final List<int> crowned;
  final bool votedRight;
  final int points, total;

  @override
  Widget build(BuildContext context) {
    final most = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    for (final p in players)
                      Container(
                        key: ValueKey('row-${p.id}'),
                        height: 56,
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            _face(p, 40),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 96,
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: crowned.contains(p.id)
                                      ? FontWeight.w900
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (_, c) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    height: 24,
                                    width: most == 0
                                        ? 0
                                        : c.maxWidth *
                                              (counts[p.id] ?? 0) /
                                              most,
                                    decoration: BoxDecoration(
                                      color: crowned.contains(p.id)
                                          ? const Color(0xFFFFD54D)
                                          : raised,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${counts[p.id] ?? 0}',
                                key: ValueKey('count-${p.id}'),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (crowned.contains(p.id))
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.workspace_premium,
                                  key: ValueKey('crown'),
                                  size: 28,
                                  color: Color(0xFFFFD54D),
                                ),
                              )
                            else
                              const SizedBox(width: 34),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                votedRight ? Strings.tkobiRight : Strings.tkobiWrong,
                key: const ValueKey('voted-right'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${Strings.plusPoints(points)} · ${Strings.totalScore(total)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The host's settings for Tko bi?: the number of prompts and the pack.
class TkobiSettingsView extends StatelessWidget {
  const TkobiSettingsView({
    super.key,
    required this.prompts,
    required this.packs,
    required this.ticked,
    required this.onPrompts,
    required this.onTogglePack,
  });
  final int prompts;
  final List<PackInfo> packs;
  final Set<String> ticked;
  final void Function(int) onPrompts;
  final void Function(String id) onTogglePack;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ChoiceRow(
        label: Strings.quizQuestions,
        keyPrefix: 'tkobi-prompts',
        values: const [5, 10, 15],
        value: prompts,
        text: (n) => '$n',
        onPick: onPrompts,
      ),
      const SizedBox(height: 8),
      PackChecklist(
        key: const ValueKey('tkobi-packs'),
        title: Strings.packsTitle,
        packs: packs,
        ticked: ticked,
        onToggle: onTogglePack,
      ),
    ],
  );
}
