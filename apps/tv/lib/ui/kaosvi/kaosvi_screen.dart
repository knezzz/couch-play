import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../strings.dart';
import '../tv_theme.dart';

const _amber = Color(0xFFFFB020), _red = Color(0xFFFF4D6D), _gold = Color(0xFFFFD54A), _green = Color(0xFF2ECC71);

enum KaosviShow { ask, merge, reveal, over }

/// One group of equal answers at the reveal.
class KaosviStack {
  const KaosviStack(this.text, this.members, {this.points = 0});
  final String text;
  final List<PlayerInfo> members;

  /// What each member of the group scored: +1 for the single largest group, -1 for a lone unique answer
  /// (the player's total never goes below 0, the phone says so), else 0.
  final int points;
}

/// What the TV needs of one Kao svi question, as plain data. While asking only [answered] is known, never
/// an answer; [groups] (largest first) exist only at the reveal.
class KaosviBoard {
  const KaosviBoard({
    required this.stage,
    required this.number,
    required this.total,
    required this.question,
    required this.players,
    required this.answered,
    required this.secondsLeft,
    required this.seconds,
    this.groups = const [],
    this.tie = false,
  });
  final KaosviShow stage;
  final int number, total;
  final String question;
  final List<PlayerInfo> players;
  final Set<int> answered;
  final int secondsLeft, seconds;
  final List<KaosviStack> groups;

  /// Two or more groups tie for largest: nobody scores.
  final bool tie;
}

/// Kao svi on the TV: the question and who has answered, "the host is merging", then the groups as stacks of
/// player faces, largest first, with the answer and the points. Everything on the 1920x1080 canvas.
class KaosviScreen extends StatelessWidget {
  const KaosviScreen(this.b, {super.key});
  final KaosviBoard b;

  bool get _timed => b.stage == KaosviShow.ask || b.stage == KaosviShow.merge;
  bool get _urgent => b.secondsLeft <= 5;

  Widget _face(PlayerInfo p, double size) => PlayerDot(playerColors[p.colorIndex % playerColors.length], size: size, character: p.character);

  @override
  Widget build(BuildContext context) => TvCanvas(
        child: Material(
          type: MaterialType.transparency,
          child: Stack(children: [
            if (_timed) _ticker(),
            Padding(padding: const EdgeInsets.fromLTRB(100, 50, 100, 70), child: _body()),
          ]),
        ),
      );

  Widget _ticker() {
    final lit = (b.secondsLeft / b.seconds * 20 - 1e-6).ceil().clamp(0, 20);
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(children: [
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
        ]),
      ),
    );
  }

  Widget _header() => Row(children: [
        Text(Strings.kaosviQuestionOf(b.number, b.total), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: tvMuted)),
        const Spacer(),
        if (_timed) Text('${b.secondsLeft}', key: const ValueKey('seconds'), style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: _urgent ? _red : tvText)),
      ]);

  Widget _question(double size) => Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1720),
            child: Text(b.question, key: const ValueKey('question'), textAlign: TextAlign.center, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: tvText, height: 1.15)),
          ),
        ),
      );

  Widget _who(String label) => Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(alignment: WrapAlignment.center, spacing: 30, runSpacing: 10, children: [
          for (final p in b.players)
            Opacity(
              key: ValueKey('who-${p.id}-${b.answered.contains(p.id) ? 'yes' : 'no'}'),
              opacity: b.answered.contains(p.id) ? 1 : 0.3,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _face(p, 72),
                Text(p.name, maxLines: 1, style: const TextStyle(fontSize: 40, color: tvText)),
              ]),
            ),
        ]),
        const SizedBox(height: 8),
        Text(label, key: const ValueKey('count'), style: const TextStyle(fontSize: 40, color: tvMuted)),
      ]);

  Widget _body() => switch (b.stage) {
        KaosviShow.ask => Column(children: [
            _header(),
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              _question(76),
              const SizedBox(height: 18),
              const Text(Strings.kaosviHint, style: TextStyle(fontSize: 40, color: tvAccent)),
            ]))),
            _who(Strings.kaosviAnswered(b.answered.length, b.players.length)),
          ]),
        KaosviShow.merge => Column(children: [
            _header(),
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              _question(56),
              const SizedBox(height: 30),
              const Text(Strings.kaosviMerging, key: ValueKey('merging'), textAlign: TextAlign.center, style: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: tvAccent)),
              const SizedBox(height: 12),
              const Text(Strings.kaosviMergingHint, style: TextStyle(fontSize: 40, color: tvMuted)),
            ]))),
          ]),
        KaosviShow.reveal || KaosviShow.over => _reveal(),
      };

  Widget _reveal() {
    final many = b.groups.length > 6;
    final rowH = many ? 96.0 : 112.0;
    return Column(children: [
      _header(),
      Text(b.question, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 42, color: tvMuted)),
      const SizedBox(height: 8),
      if (b.tie)
        const Text(Strings.kaosviTie, key: ValueKey('tie'), style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: _amber)),
      Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < b.groups.length; i++) _row(i, b.groups[i], rowH, crowned: b.groups[i].points > 0),
        ]),
      ),
    ]);
  }

  Widget _row(int i, KaosviStack g, double h, {required bool crowned}) {
    final color = g.points < 0 ? _red : (crowned ? _gold : const Color(0x66FFFFFF));
    return Container(
      key: ValueKey('group-$i${crowned ? '-top' : ''}'),
      height: h,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: crowned ? 0.22 : 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: crowned ? 5 : 2),
      ),
      child: Row(children: [
        // A merged group shows every spelling ('jabuka · Banana'); a long one takes two lines at 40 px.
        Expanded(
          flex: 7,
          child: Text(g.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: g.text.length > 22 ? 40 : 48, height: 1.05, fontWeight: FontWeight.w800, color: tvText)),
        ),
        // The group as a stack of faces: overlapping, so eight still fit.
        Expanded(
          flex: 8,
          child: SizedBox(
            height: h - 16,
            child: Stack(children: [
              for (var k = 0; k < g.members.length; k++)
                Positioned(left: k * (g.members.length > 5 ? 62.0 : 78.0), top: 0, child: _face(g.members[k], h - 16)),
            ]),
          ),
        ),
        SizedBox(
          width: 140,
          child: Text(g.points == 0 ? '' : (g.points > 0 ? '+${g.points}' : '−${g.points.abs()}'),
              key: ValueKey('points-$i'), textAlign: TextAlign.right, style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: g.points < 0 ? _red : _green)),
        ),
      ]),
    );
  }
}
