import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../session/objasni_match.dart' show ObjasniStageTv;
import '../../strings.dart';
import '../tv_theme.dart';

const _amber = Color(0xFFFFB020), _red = Color(0xFFFF4D6D), _green = Color(0xFF2ECC71);

/// What the TV needs of one Objasni game, as plain data (the word being explained is never in it).
class ObjasniBoard {
  const ObjasniBoard({
    required this.stage,
    required this.teams,
    required this.scores,
    required this.target,
    required this.turnTeam,
    required this.explainer,
    required this.words,
    required this.secondsLeft,
    required this.turnSeconds,
    required this.summarySeconds,
    required this.winnerTeam,
    required this.pausedSeconds,
  });
  final ObjasniStageTv stage;
  final List<List<PlayerInfo>> teams; // two lists
  final List<int> scores;
  final int target;
  final int turnTeam;
  final PlayerInfo? explainer;
  final List<ObjasniMarked> words;
  final int secondsLeft, turnSeconds, summarySeconds;
  final int? winnerTeam;
  final int? pausedSeconds; // non-null while waiting for a team to come back
}

/// Objasni on the TV: teams, whose turn it is, the clock, both scores and the words done this turn.
/// The word itself stays on the phones.
class ObjasniScreen extends StatelessWidget {
  const ObjasniScreen(this.b, {super.key});
  final ObjasniBoard b;

  bool get _urgent => b.secondsLeft <= 5;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: tvBg,
        child: Stack(
          children: [
            if (b.stage == ObjasniStageTv.play) _ticker(),
            Padding(
              padding: const EdgeInsets.fromLTRB(80, 56, 80, 70),
              child: Column(
                children: [
                  _scoreRow(),
                  const SizedBox(height: 28),
                  Expanded(child: _body()),
                ],
              ),
            ),
            if (b.pausedSeconds != null) _pause(),
          ],
        ),
      ),
    );
  }

  Widget _ticker() {
    final lit = (b.secondsLeft / b.turnSeconds * 20 - 1e-6).ceil().clamp(0, 20);
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            for (var i = 0; i < 20; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  key: ValueKey('tick-$i'),
                  decoration: BoxDecoration(
                    color: i < lit ? (_urgent ? _red : _amber) : const Color(0x14FFFFFF),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scoreRow() {
    Widget side(int t) {
      final on = b.stage != ObjasniStageTv.setup && b.stage != ObjasniStageTv.over && b.turnTeam == t;
      return Expanded(
        child: Container(
          key: ValueKey('team-$t'),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
          decoration: BoxDecoration(
            color: objasniTeamColors[t].withValues(alpha: on ? 0.28 : 0.12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: objasniTeamColors[t], width: on ? 5 : 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(Strings.objasniTeam(t),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: tvText)),
              ),
              Text('${b.scores[t]}', key: ValueKey('score-$t'), style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: tvText)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [side(0), const SizedBox(width: 40), side(1)]),
        const SizedBox(height: 10),
        Text(Strings.objasniTarget(b.target), style: const TextStyle(fontSize: 30, color: tvMuted)),
      ],
    );
  }

  Widget _body() => switch (b.stage) {
        ObjasniStageTv.setup => _setup(),
        ObjasniStageTv.ready => _ready(),
        ObjasniStageTv.play => _play(),
        ObjasniStageTv.summary => _summary(),
        ObjasniStageTv.over => _over(),
      };

  Widget _face(PlayerInfo p, double size) => PlayerDot(playerColors[p.colorIndex % playerColors.length], size: size, character: p.character);

  Widget _setup() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var t = 0; t < 2; t++) ...[
                if (t > 0) const SizedBox(width: 40),
                Expanded(
                  child: Wrap(
                    key: ValueKey('members-$t'),
                    alignment: WrapAlignment.center,
                    spacing: 36,
                    runSpacing: 20,
                    children: [
                      for (final p in b.teams[t])
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          _face(p, 110),
                          const SizedBox(height: 6),
                          Text(p.name, maxLines: 1, style: const TextStyle(fontSize: 34, color: tvText)),
                        ]),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 40),
          const Text(Strings.objasniSetupHint, style: TextStyle(fontSize: 36, color: tvMuted)),
        ],
      );

  Widget _explainerBlock({required String caption}) {
    final p = b.explainer;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(caption, style: const TextStyle(fontSize: 36, color: tvMuted)),
        const SizedBox(height: 18),
        if (p != null) _face(p, 220),
        const SizedBox(height: 12),
        Text(p?.name ?? '',
            key: const ValueKey('explainer'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 88, fontWeight: FontWeight.w900, color: tvText)),
      ],
    );
  }

  Widget _ready() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _explainerBlock(caption: Strings.objasniNextExplains),
          const SizedBox(height: 26),
          const Text(Strings.objasniReadyHint, style: TextStyle(fontSize: 38, color: tvMuted)),
        ],
      );

  Widget _wordChips({required bool big}) => Wrap(
        key: const ValueKey('turn-words'),
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 14,
        children: [
          for (var i = 0; i < b.words.length; i++) _chip(i, b.words[i], big),
        ],
      );

  Widget _chip(int i, ObjasniMarked w, bool big) {
    final (Color c, String tag) = switch (w.mark) {
      ObjasniMark.correct => (_green, ''),
      ObjasniMark.skip => (const Color(0xFF6B6B80), ''),
      ObjasniMark.foul => (_red, Strings.objasniFoul),
    };
    return Container(
      key: ValueKey('word-$i-${w.mark.name}'),
      padding: EdgeInsets.symmetric(horizontal: 26, vertical: big ? 14 : 10),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(999), border: Border.all(color: c, width: 3)),
      child: Text(tag.isEmpty ? w.word : '${w.word} · $tag',
          style: TextStyle(fontSize: big ? 40 : 34, fontWeight: FontWeight.w700, color: w.mark == ObjasniMark.skip ? tvMuted : tvText)),
    );
  }

  Widget _play() => Row(
        children: [
          Expanded(flex: 5, child: _explainerBlock(caption: Strings.objasniExplains)),
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${b.secondsLeft}',
                    key: const ValueKey('seconds'), style: TextStyle(fontSize: 150, fontWeight: FontWeight.w900, color: _urgent ? _red : tvText)),
                const SizedBox(height: 20),
                if (b.words.isEmpty)
                  const Text(Strings.objasniGuessAloud, style: TextStyle(fontSize: 38, color: tvMuted))
                else
                  _wordChips(big: false),
              ],
            ),
          ),
        ],
      );

  Widget _summary() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(Strings.objasniTurnOver, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: tvText)),
          const SizedBox(height: 30),
          if (b.words.isEmpty) const Text(Strings.objasniNoWords, style: TextStyle(fontSize: 36, color: tvMuted)) else _wordChips(big: true),
          const SizedBox(height: 40),
          Text(Strings.objasniNextIn(b.summarySeconds), key: const ValueKey('summary-next'), style: const TextStyle(fontSize: 34, color: tvMuted)),
        ],
      );

  Widget _over() {
    final w = b.winnerTeam;
    return Center(
      child: Text(w == null ? '' : Strings.objasniWins(w),
          key: const ValueKey('winner'), style: TextStyle(fontSize: 110, fontWeight: FontWeight.w900, color: w == null ? tvText : objasniTeamColors[w])),
    );
  }

  Widget _pause() => Positioned.fill(
        child: Container(
          color: const Color(0xE614141E),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(Strings.waitingForPlayers, key: ValueKey('paused'), style: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: tvText)),
              const SizedBox(height: 20),
              Text('${b.pausedSeconds} s', style: const TextStyle(fontSize: 56, color: tvMuted)),
            ],
          ),
        ),
      );
}
