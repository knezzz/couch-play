import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../session/blef_match.dart' show BlefStageTv;
import '../../strings.dart';
import '../tv_theme.dart';

const _amber = Color(0xFFFFB020), _red = Color(0xFFFF4D6D), _green = Color(0xFF2ECC71);

/// An entry shown at the reveal.
class BlefCard {
  const BlefCard(this.text, this.isTruth, this.writers, this.pickers);
  final String text;
  final bool isTruth;
  final List<PlayerInfo> writers, pickers;
}

/// What the TV needs of one Blef question, as plain data. While writing, [sent] says who has sent
/// (never the texts); the list exists only while picking and, entry by entry, at the reveal.
class BlefBoard {
  const BlefBoard({
    required this.stage,
    required this.number,
    required this.total,
    required this.question,
    required this.players,
    required this.sent,
    required this.picked,
    required this.secondsLeft,
    required this.seconds,
    this.list = const [],
    this.shown = const [],
    this.points,
  });
  final BlefStageTv stage;
  final int number, total;
  final String question;
  final List<PlayerInfo> players;
  final Set<int> sent, picked;
  final int secondsLeft, seconds;
  final List<String> list; // picking: the shuffled texts, nothing marked
  final List<BlefCard> shown; // the reveal so far
  final Map<int, int>? points; // after the last entry
}

/// Blef on the TV: the question, who has written, the shuffled list, then the reveal one entry at a time.
class BlefScreen extends StatelessWidget {
  const BlefScreen(this.b, {super.key});
  final BlefBoard b;

  bool get _timed => b.stage == BlefStageTv.write || b.stage == BlefStageTv.pick;
  bool get _urgent => b.secondsLeft <= 5;

  Widget _face(PlayerInfo p, double size) => PlayerDot(playerColors[p.colorIndex % playerColors.length], size: size, character: p.character);

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Container(
          color: tvBg,
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
        Text(Strings.blefQuestionOf(b.number, b.total), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: tvMuted)),
        const Spacer(),
        if (_timed) Text('${b.secondsLeft}', key: const ValueKey('seconds'), style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: _urgent ? _red : tvText)),
      ]);

  Widget _who(Set<int> lit, String label) => Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(alignment: WrapAlignment.center, spacing: 30, runSpacing: 12, children: [
          for (final p in b.players)
            Opacity(
              key: ValueKey('who-${p.id}-${lit.contains(p.id) ? 'yes' : 'no'}'),
              opacity: lit.contains(p.id) ? 1 : 0.3,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _face(p, 80),
                Text(p.name, maxLines: 1, style: const TextStyle(fontSize: 28, color: tvText)),
              ]),
            ),
        ]),
        const SizedBox(height: 10),
        Text(label, key: const ValueKey('count'), style: const TextStyle(fontSize: 34, color: tvMuted)),
      ]);

  Widget _body() => switch (b.stage) {
        BlefStageTv.write => Column(children: [
            _header(),
            Expanded(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(b.question, key: const ValueKey('question'), textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: tvText, height: 1.15)),
                  const SizedBox(height: 22),
                  const Text(Strings.blefWriteHint, style: TextStyle(fontSize: 40, color: tvAccent)),
                ]),
              ),
            ),
            _who(b.sent, Strings.blefSent(b.sent.length, b.players.length)),
          ]),
        BlefStageTv.pick => Column(children: [
            _header(),
            Text(b.question, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 46, color: tvMuted)),
            const SizedBox(height: 18),
            Expanded(
              child: Center(
                child: Wrap(alignment: WrapAlignment.center, spacing: 28, runSpacing: 20, children: [
                  for (var i = 0; i < b.list.length; i++)
                    Container(
                      key: ValueKey('option-$i'),
                      width: 820,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      decoration: BoxDecoration(color: tvSurface, borderRadius: BorderRadius.circular(24)),
                      child: Text(b.list[i], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: tvText)),
                    ),
                ]),
              ),
            ),
            _who(b.picked, Strings.blefPicked(b.picked.length, b.players.length)),
          ]),
        BlefStageTv.reveal || BlefStageTv.over => _reveal(),
      };

  Widget _names(List<PlayerInfo> ps) => Text(ps.isEmpty ? Strings.blefNobody : ps.map((p) => p.name).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, color: tvMuted));

  Widget _reveal() {
    final last = b.shown.length - 1;
    return Column(children: [
      _header(),
      Text(b.question, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 42, color: tvMuted)),
      const SizedBox(height: 14),
      Expanded(
        child: Wrap(alignment: WrapAlignment.center, spacing: 28, runSpacing: 14, children: [
          for (var i = 0; i < b.shown.length; i++) _card(i, b.shown[i], i == last),
        ]),
      ),
      if (b.points != null)
        Wrap(key: const ValueKey('points'), alignment: WrapAlignment.center, spacing: 34, children: [
          for (final p in b.players)
            if ((b.points![p.id] ?? 0) > 0)
              Row(mainAxisSize: MainAxisSize.min, children: [
                _face(p, 52),
                const SizedBox(width: 8),
                Text('${p.name} +${b.points![p.id]}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _green)),
              ]),
        ]),
    ]);
  }

  /// With more than four players there can be nine entries: three smaller cards to a row.
  bool get _compact => b.players.length > 4;

  Widget _card(int i, BlefCard c, bool newest) {
    final big = _compact ? 32.0 : 40.0, small = _compact ? 26.0 : 28.0;
    final color = c.isTruth ? _green : _red;
    return Container(
      key: ValueKey('card-$i-${c.isTruth ? 'truth' : 'fake'}'),
      width: _compact ? 540 : 820,
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: _compact ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: newest ? 0.3 : 0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: newest ? 5 : 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(c.text, maxLines: _compact ? 1 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: big, fontWeight: FontWeight.w800, color: tvText)),
        const SizedBox(height: 2),
        Text(c.isTruth ? Strings.blefTruth : Strings.blefAuthor(c.writers.map((p) => p.name).join(', ')), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: small, fontWeight: FontWeight.w700, color: color)),
        Row(children: [
          Text('${Strings.blefChoice}: ', style: TextStyle(fontSize: small, color: tvMuted)),
          for (final p in c.pickers.take(_compact ? 3 : 8)) Padding(padding: const EdgeInsets.only(right: 4), child: _face(p, _compact ? 28 : 34)),
          Expanded(child: _names(c.pickers)),
        ]),
      ]),
    );
  }
}
