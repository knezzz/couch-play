import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../strings.dart';
import '../tv_theme.dart';

const _amber = Color(0xFFFFB020), _red = Color(0xFFFF4D6D), _green = Color(0xFF2ECC71);

/// 1234567.5 -> '1 234 567,5' (no-break spaces, decimal comma).
String kolikoNum(double v) {
  final whole = v == v.roundToDouble();
  final s = whole ? v.round().abs().toString() : v.abs().toString().replaceAll('.', ',');
  final parts = s.split(',');
  final grouped = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ' ');
  return '${v < 0 ? '-' : ''}$grouped${parts.length > 1 ? ',${parts[1]}' : ''}';
}

/// One player's number at the reveal.
class KolikoRow {
  const KolikoRow(this.player, this.value, this.rank, this.points, this.exact, this.total);
  final PlayerInfo player;
  final double? value; // null: no answer
  final int? rank;
  final int points, total;
  final bool exact;
}

/// What the TV needs of one Koliko? question, as plain data. During the question [answered] says who has
/// answered, never the numbers; [rows] and [answer] exist only at the reveal.
class KolikoBoard {
  const KolikoBoard({
    required this.number,
    required this.total,
    required this.question,
    required this.unit,
    required this.players,
    required this.answered,
    required this.secondsLeft,
    required this.seconds,
    this.answer,
    this.rows = const [],
  });
  final int number, total;
  final String question, unit;
  final List<PlayerInfo> players;
  final Set<int> answered;
  final int secondsLeft, seconds;
  final double? answer; // non-null = the reveal
  final List<KolikoRow> rows; // closest first, then no answer
}

/// Koliko? on the TV: the question and who has answered, then everyone's number on a number line.
class KolikoScreen extends StatelessWidget {
  const KolikoScreen(this.b, {super.key});
  final KolikoBoard b;

  bool get _reveal => b.answer != null;
  bool get _urgent => b.secondsLeft <= 5;

  Widget _face(PlayerInfo p, double size) => PlayerDot(playerColors[p.colorIndex % playerColors.length], size: size, character: p.character);

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Container(
          color: tvBg,
          child: Stack(children: [
            if (!_reveal) _ticker(),
            Padding(
              padding: const EdgeInsets.fromLTRB(100, 50, 100, 70),
              child: _reveal ? _revealBody() : _askBody(),
            ),
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
        Text(Strings.kolikoQuestionOf(b.number, b.total), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: tvMuted)),
        const Spacer(),
        if (!_reveal) Text('${b.secondsLeft}', key: const ValueKey('seconds'), style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: _urgent ? _red : tvText)),
      ]);

  Widget _askBody() => Column(children: [
        _header(),
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(b.question,
                  key: const ValueKey('question'), textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 76, fontWeight: FontWeight.w800, color: tvText, height: 1.15)),
              if (b.unit.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(Strings.kolikoUnit(b.unit), key: const ValueKey('unit'), style: const TextStyle(fontSize: 44, color: tvAccent)),
              ],
            ]),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 36,
          runSpacing: 16,
          children: [
            for (final p in b.players)
              Opacity(
                key: ValueKey('who-${p.id}-${b.answered.contains(p.id) ? 'yes' : 'no'}'),
                opacity: b.answered.contains(p.id) ? 1 : 0.3,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _face(p, 84),
                  Text(p.name, maxLines: 1, style: const TextStyle(fontSize: 30, color: tvText)),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(Strings.kolikoAnswered(b.answered.length, b.players.length), key: const ValueKey('count'), style: const TextStyle(fontSize: 36, color: tvMuted)),
      ]);

  Widget _revealBody() {
    final answer = b.answer!;
    final answered = b.rows.where((r) => r.value != null).toList();
    final values = [answer, for (final r in answered) r.value!];
    var lo = values.reduce(min), hi = values.reduce(max);
    if (hi == lo) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * 0.08;
    lo -= pad;
    hi += pad;
    const left = 80.0, width = 1560.0; // inside the 1720 px content width
    double x(double v) => left + (v - lo) / (hi - lo) * width;
    final byValue = [...answered]..sort((p, q) => p.value!.compareTo(q.value!));
    return Column(children: [
      _header(),
      Text(b.question, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 46, color: tvMuted)),
      const SizedBox(height: 10),
      Text(Strings.kolikoCorrect(kolikoNum(answer), b.unit),
          key: const ValueKey('answer'), style: const TextStyle(fontSize: 76, fontWeight: FontWeight.w900, color: _green)),
      SizedBox(
        height: 300,
        child: Stack(children: [
          Positioned(left: left, top: 160, width: width, height: 8, child: const DecoratedBox(decoration: BoxDecoration(color: Color(0x55FFFFFF), borderRadius: BorderRadius.all(Radius.circular(4))))),
          Positioned(
            key: const ValueKey('marker-answer'),
            left: x(answer) - 3,
            top: 120,
            width: 6,
            height: 90,
            child: const DecoratedBox(decoration: BoxDecoration(color: _green)),
          ),
          for (var i = 0; i < byValue.length; i++)
            Positioned(
              key: ValueKey('marker-${byValue[i].player.id}'),
              left: x(byValue[i].value!) - 36,
              // Alternate above and below, in three steps, so neighbours do not sit on each other.
              top: i.isEven ? (i % 4 == 0 ? 20 : 0) : (i % 4 == 1 ? 190 : 210),
              child: _face(byValue[i].player, 72),
            ),
        ]),
      ),
      Expanded(
        child: Wrap(
          spacing: 40,
          runSpacing: 6,
          children: [for (final r in b.rows) _row(r)],
        ),
      ),
    ]);
  }

  Widget _row(KolikoRow r) => SizedBox(
        key: ValueKey('row-${r.player.id}'),
        width: 840,
        height: 66,
        child: Row(children: [
          SizedBox(width: 50, child: Text(r.rank == null ? '' : '${r.rank}.', style: const TextStyle(fontSize: 34, color: tvMuted))),
          _face(r.player, 52),
          const SizedBox(width: 14),
          Expanded(child: Text(r.player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 34, color: tvText))),
          Text(r.value == null ? Strings.kolikoNoAnswer : kolikoNum(r.value!), style: TextStyle(fontSize: 34, color: r.value == null ? tvMuted : tvText, fontWeight: FontWeight.w700)),
          SizedBox(width: 130, child: Text(r.points > 0 ? '+${r.points}' : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: _green))),
          SizedBox(width: 120, child: Text(grouped(r.total), textAlign: TextAlign.right, style: const TextStyle(fontSize: 30, color: tvMuted))),
        ]),
      );
}
