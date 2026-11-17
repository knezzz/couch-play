import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../strings.dart';
import '../tv_theme.dart';

const _amber = Color(0xFFFFB020), _red = Color(0xFFFF4D6D), _gold = Color(0xFFFFD54A), _green = Color(0xFF2ECC71);

/// One player's result at the reveal: the votes they got and whether they are crowned. No points and no
/// running totals on the TV: a point means "voted for the crowned", so beside each name it would say who
/// voted for whom. The phones show their own result.
class TkobiRow {
  const TkobiRow(this.player, this.votes, this.crowned);
  final PlayerInfo player;
  final int votes;
  final bool crowned;
}

/// What the TV needs of one Tko bi? prompt, as plain data. While asking only [votedCount] is known (never who
/// voted for whom); [rows] exist only at the reveal.
class TkobiBoard {
  const TkobiBoard({
    required this.number,
    required this.total,
    required this.prompt,
    required this.players,
    required this.votedCount,
    required this.secondsLeft,
    required this.seconds,
    this.rows,
  });
  final int number, total;
  final String prompt;
  final List<PlayerInfo> players;
  final int votedCount, secondsLeft, seconds;
  final List<TkobiRow>? rows; // null while asking; most votes first
}

/// Tko bi? on the TV: the prompt and how many have voted, then who got how many votes and who is crowned.
class TkobiScreen extends StatelessWidget {
  const TkobiScreen(this.b, {super.key});
  final TkobiBoard b;

  bool get _reveal => b.rows != null;
  bool get _urgent => b.secondsLeft <= 5;

  Widget _face(PlayerInfo p, double size) => PlayerDot(playerColors[p.colorIndex % playerColors.length], size: size, character: p.character);

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Container(
          color: tvBg,
          child: Stack(children: [
            if (!_reveal) _ticker(),
            Padding(padding: const EdgeInsets.fromLTRB(100, 50, 100, 70), child: _reveal ? _revealBody() : _askBody()),
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
        Text(Strings.tkobiQuestionOf(b.number, b.total), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: tvMuted)),
        const Spacer(),
        if (!_reveal) Text('${b.secondsLeft}', key: const ValueKey('seconds'), style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: _urgent ? _red : tvText)),
      ]);

  Widget _askBody() => Column(children: [
        _header(),
        Expanded(
          child: Center(
            child: Text(b.prompt, key: const ValueKey('prompt'), textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w800, color: tvText, height: 1.15)),
          ),
        ),
        Wrap(alignment: WrapAlignment.center, spacing: 32, runSpacing: 12, children: [
          for (final p in b.players)
            Column(mainAxisSize: MainAxisSize.min, children: [_face(p, 84), Text(p.name, maxLines: 1, style: const TextStyle(fontSize: 30, color: tvText))]),
        ]),
        const SizedBox(height: 14),
        Text(Strings.tkobiVoted(b.votedCount, b.players.length), key: const ValueKey('count'), style: const TextStyle(fontSize: 38, color: tvMuted)),
      ]);

  Widget _revealBody() {
    final rows = b.rows!;
    final most = rows.fold<int>(1, (m, r) => r.votes > m ? r.votes : m);
    final h = rows.length > 6 ? 76.0 : 94.0;
    return Column(children: [
      _header(),
      Text(b.prompt, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 46, color: tvMuted)),
      const SizedBox(height: 16),
      Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final r in rows)
            SizedBox(
              key: ValueKey('row-${r.player.id}${r.crowned ? '-crowned' : ''}'),
              height: h,
              child: Row(children: [
                _face(r.player, h - 14),
                const SizedBox(width: 18),
                SizedBox(width: 280, child: Text(r.player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 40, fontWeight: r.crowned ? FontWeight.w900 : FontWeight.w500, color: r.crowned ? _gold : tvText))),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: r.votes == 0 ? 0.012 : r.votes / most,
                      child: Container(
                        key: ValueKey('bar-${r.player.id}'),
                        height: h * 0.5,
                        decoration: BoxDecoration(color: r.crowned ? _gold : const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(width: 70, child: Text('${r.votes}', textAlign: TextAlign.right, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: r.crowned ? _gold : tvText))),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
