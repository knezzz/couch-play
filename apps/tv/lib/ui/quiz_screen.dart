import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'tv_theme.dart';
import '../strings.dart';

// Fixed by the spec: tile colours are player colours 0, 3, 1, 2.
const _tileColors = [
  Color(0xFFFF4D6D),
  Color(0xFF22B8F0),
  Color(0xFFFFB020),
  Color(0xFF2ECC71),
];
const _green = Color(0xFF2ECC71);

/// One quiz question (TvQuiz) or its reveal (TvReveal) on a 1920x1080 canvas,
/// scaled to fit. Pure: [Session] rebuilds it on each tick. [correctIndex] is
/// null while asking.
class QuizScreen extends StatelessWidget {
  const QuizScreen({
    required this.question,
    required this.choices,
    required this.number,
    required this.total,
    required this.remaining,
    required this.answered,
    required this.expected,
    required this.players,
    this.packTitle = '',
    this.svg,
    this.correctIndex,
    this.picks = const {},
    this.totals = const {},
    this.points = const {},
    super.key,
  });

  final String question, packTitle;
  final Uint8List? svg;
  final List<String> choices;
  final int number, total, answered, expected;

  /// Countdown, 1 down to 0.
  final double remaining;
  final int? correctIndex;

  /// Player id -> shown choice index. Only used at the reveal.
  final Map<int, int> picks;
  final List<PlayerInfo> players;

  /// Player id -> quiz total, and -> points won on this question.
  final Map<int, int> totals, points;

  Color _color(PlayerInfo p) =>
      playerColors[p.colorIndex % playerColors.length];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: tvBg,
    body: FittedBox(
      child: SizedBox(
        width: 1920,
        height: 1080,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(96, 56, 96, 72),
          child: correctIndex == null ? _asking() : _reveal(),
        ),
      ),
    ),
  );

  // --- the question ---

  Widget _asking() => Column(
    children: [
      Row(
        children: [
          Text(
            Strings.questionOf(number, total),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: tvText,
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Text(
              packTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 40, color: tvMuted),
            ),
          ),
          const SizedBox(width: 32),
          Text(
            Strings.answered(answered, expected),
            style: const TextStyle(fontSize: 40, color: tvMuted),
          ),
        ],
      ),
      const SizedBox(height: 36),
      Container(
        width: double.infinity,
        height: 16,
        decoration: BoxDecoration(
          color: tvRaised,
          borderRadius: BorderRadius.circular(999),
        ),
        child: FractionallySizedBox(
          key: const ValueKey('timer-bar'),
          alignment: Alignment.centerLeft,
          widthFactor: remaining.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tvAccent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
      const SizedBox(height: 36),
      Expanded(
        child: Row(
          children: [
            Expanded(
              child: Text(
                question,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1,
                  color: tvText,
                ),
              ),
            ),
            if (svg != null) ...[
              const SizedBox(width: 64),
              Container(
                key: const ValueKey('picture-card'),
                width: 520,
                height: 347,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SvgPicture.memory(svg!, fit: BoxFit.contain),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 36),
      for (var r = 0; r < 2; r++) ...[
        if (r == 1) const SizedBox(height: 24),
        Row(
          children: [
            for (var c = 0; c < 2; c++) ...[
              if (c == 1) const SizedBox(width: 24),
              Expanded(child: _tile(r * 2 + c)),
            ],
          ],
        ),
      ],
    ],
  );

  Widget _tile(int i) {
    final long = choices[i].length > 24;
    return Container(
      key: ValueKey('tile-$i'),
      height: 168,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: _tileColors[i],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          ShapeMark(i, 48, tvInk),
          const SizedBox(width: 32),
          Expanded(
            child: Text(
              choices[i],
              // Long answers wrap to 3 lines at 40 px.
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: long ? 40 : 52,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: tvInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- the reveal ---

  List<PlayerInfo> _voters(int i) => [
    for (final p in players)
      if (picks[p.id] == i) p,
  ];

  Widget _dots(int i, double size) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final p in _voters(i))
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: PlayerDot(_color(p), size: size, ring: true),
        ),
    ],
  );

  Widget _reveal() {
    final right = correctIndex!;
    final wrong = [
      for (var i = 0; i < 4; i++)
        if (i != right) i,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: Strings.questionOf(number, total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: tvText,
                      ),
                    ),
                    const TextSpan(text: Strings.answerIs),
                  ],
                ),
                style: const TextStyle(fontSize: 40, color: tvMuted),
              ),
              const SizedBox(height: 32),
              Text(
                question,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -1,
                  color: tvText,
                ),
              ),
              const Spacer(),
              Container(
                key: ValueKey('tile-$right'),
                height: 168,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: _tileColors[right],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: tvText, width: 6),
                ),
                child: Row(
                  children: [
                    ShapeMark(right, 48, tvInk),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Text(
                        choices[right],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          color: tvInk,
                        ),
                      ),
                    ),
                    _dots(right, 48),
                    const SizedBox(width: 32),
                    const Icon(Icons.check, size: 56, color: tvInk),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  for (final i in wrong) ...[
                    if (i != wrong.first) const SizedBox(width: 20),
                    Expanded(child: _wrongTile(i)),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 64),
        SizedBox(width: 520, child: _scores()),
      ],
    );
  }

  Widget _wrongTile(int i) => Container(
    key: ValueKey('tile-$i'),
    height: 120,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: _tileColors[i].withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        ShapeMark(i, 30, _tileColors[i]),
        const SizedBox(width: 16),
        Expanded(child: _wrongAnswer(choices[i])),
        _Voters([for (final p in _voters(i)) _color(p)]),
      ],
    ),
  );

  /// A one-word answer shrinks before it would break mid-word beside the voters.
  Widget _wrongAnswer(String text) {
    const style = TextStyle(fontSize: 40, fontWeight: FontWeight.w500, height: 1.1, color: tvText);
    if (text.contains(' ')) {
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: style);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, style: style),
    );
  }

  Text _points(PlayerInfo p) {
    final won = (points[p.id] ?? 0) > 0;
    return Text(
      '+${points[p.id] ?? 0}',
      style: TextStyle(
        fontSize: 32,
        fontWeight: won ? FontWeight.w700 : FontWeight.w400,
        color: won ? _green : tvMuted,
      ),
    );
  }

  Widget _scores() {
    final byTotal = [
      for (final p in players)
        if (totals.containsKey(p.id)) p,
    ]..sort((a, b) => (totals[b.id] ?? 0).compareTo(totals[a.id] ?? 0));
    final gap = byTotal.length > 5 ? 12.0 : 24.0;
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: tvSurface,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            Strings.quizScores,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: tvText,
            ),
          ),
          SizedBox(height: gap),
          for (final p in byTotal) ...[
            Row(
              children: [
                PlayerDot(_color(p)),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 40, color: tvText),
                  ),
                ),
                // With many players the points share the row; else they sit below.
                if (byTotal.length > 5) ...[
                  _points(p),
                  const SizedBox(width: 16),
                ],
                Text(
                  grouped(totals[p.id] ?? 0),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: tvText,
                  ),
                ),
              ],
            ),
            if (byTotal.length <= 5)
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: _points(p),
              ),
            SizedBox(height: gap),
          ],
        ],
      ),
    );
  }
}

/// Voter dots on a wrong tile (about 280 px of room): overlapped, and past 3
/// the last one becomes "+N", so the answer keeps its room.
class _Voters extends StatelessWidget {
  const _Voters(this.colors);
  final List<Color> colors;

  static const _dot = 44.0, _step = 24.0, _max = 3;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) return const SizedBox.shrink();
    final more = colors.length > _max;
    final shown = more ? _max - 1 : colors.length;
    final count = shown + (more ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: SizedBox(
        width: _dot + _step * (count - 1),
        height: _dot,
        child: Stack(
          children: [
            for (var i = 0; i < shown; i++)
              Positioned(
                left: i * _step,
                child: PlayerDot(colors[i], size: _dot, ring: true),
              ),
            if (more)
              Positioned(
                left: shown * _step,
                child: Container(
                  width: _dot,
                  height: _dot,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tvRaised,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                  ),
                  child: Text(
                    '+${colors.length - shown}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: tvText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
