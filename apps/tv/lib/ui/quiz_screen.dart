import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'tv_theme.dart';

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

  Color _color(PlayerInfo p) => playerColors[p.colorIndex % playerColors.length];

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
              Text('Question $number of $total',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: tvText)),
              const SizedBox(width: 32),
              Expanded(
                child: Text(packTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 40, color: tvMuted)),
              ),
              const SizedBox(width: 32),
              Text('$answered of $expected answered', style: const TextStyle(fontSize: 40, color: tvMuted)),
            ],
          ),
          const SizedBox(height: 36),
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(color: tvRaised, borderRadius: BorderRadius.circular(999)),
            child: FractionallySizedBox(
              key: const ValueKey('timer-bar'),
              alignment: Alignment.centerLeft,
              widthFactor: remaining.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(color: tvAccent, borderRadius: BorderRadius.circular(999)),
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
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
      decoration: BoxDecoration(color: _tileColors[i], borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          _Shape(i, 48, tvInk),
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
          for (final p in _voters(i)) Padding(
            padding: const EdgeInsets.only(left: 12),
            child: PlayerDot(_color(p), size: size, ring: true),
          ),
        ],
      );

  Widget _reveal() {
    final right = correctIndex!;
    final wrong = [for (var i = 0; i < 4; i++) if (i != right) i];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: 'Question $number of $total',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: tvText),
                  ),
                  const TextSpan(text: ' · The answer is'),
                ]),
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
                    _Shape(right, 48, tvInk),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Text(
                        choices[right],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, height: 1.1, color: tvInk),
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
            _Shape(i, 30, _tileColors[i]),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                choices[i],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w500, height: 1.1, color: tvText),
              ),
            ),
            _dots(i, 44),
          ],
        ),
      );

  Widget _scores() {
    final byTotal = [
      for (final p in players)
        if (totals.containsKey(p.id)) p,
    ]..sort((a, b) => (totals[b.id] ?? 0).compareTo(totals[a.id] ?? 0));
    final gap = byTotal.length > 5 ? 12.0 : 24.0;
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: tvSurface, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Scores', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: tvText)),
          SizedBox(height: gap),
          for (final p in byTotal) ...[
            Row(
              children: [
                PlayerDot(_color(p)),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(p.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 40, color: tvText)),
                ),
                Text(grouped(totals[p.id] ?? 0),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: tvText)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 60),
              child: Text(
                '+${points[p.id] ?? 0}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: (points[p.id] ?? 0) > 0 ? FontWeight.w700 : FontWeight.w400,
                  color: (points[p.id] ?? 0) > 0 ? _green : tvMuted,
                ),
              ),
            ),
            SizedBox(height: gap),
          ],
        ],
      ),
    );
  }
}

/// ▲ ◆ ● ■ drawn, not typed: the shapes are the colour-blind channel, so they
/// must not depend on which symbol fonts the TV has.
class _Shape extends StatelessWidget {
  const _Shape(this.index, this.size, this.color);
  final int index;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ShapePainter(index, color));
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.index, this.color);
  final int index;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color;
    final w = s.width, h = s.height;
    switch (index) {
      case 0:
        canvas.drawPath(Path()..moveTo(w / 2, 0)..lineTo(w, h)..lineTo(0, h)..close(), p);
      case 1:
        canvas.drawPath(Path()..moveTo(w / 2, 0)..lineTo(w, h / 2)..lineTo(w / 2, h)..lineTo(0, h / 2)..close(), p);
      case 2:
        canvas.drawOval(Offset.zero & s, p);
      default:
        canvas.drawRect(Offset.zero & s, p);
    }
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.index != index || old.color != color;
}
