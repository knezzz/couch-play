import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';

const _quizBlue = Color(0xFF22B8F0);
const _pink = Color(0xFFFF4D6D);
const _amberTile = Color(0xFFFFB020);
const _green = Color(0xFF2ECC71);
const _nightPurple = Color(0xFF3A2D5C);
const _uljezAmber = Color(0xFFE7B36A);

/// The two Curve ribbons of the card art, in the board's 240 x 120 box. They
/// never cross or touch (a crossing is a crash in the game itself); a test
/// samples them.
({Path red, Path green}) curveRibbons() => (
  red: Path()
    ..moveTo(10, 100)
    ..cubicTo(60, 70, 100, 110, 150, 85)
    ..cubicTo(180, 70, 210, 70, 230, 95),
  green: Path()
    ..moveTo(20, 30)
    ..cubicTo(80, 50, 120, 10, 190, 35),
);

class _CurvePainter extends CustomPainter {
  const _CurvePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 240;
    canvas.scale(k);
    final r = curveRibbons();
    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(r.red, stroke(_pink));
    canvas.drawPath(r.green, stroke(_green));
  }

  @override
  bool shouldRepaint(_CurvePainter old) => false;
}

/// Colours and art of one game: used by the carousel card and the details
/// header, so the two look like one thing.
class GameLook {
  const GameLook(this.fill, this.fg, this.sub, this.border);
  final Color fill, fg, sub;
  final Color? border;

  static GameLook of(GameKind k) => switch (k) {
    GameKind.quiz => const GameLook(_quizBlue, ink, ink, null),
    GameKind.curve => const GameLook(surface, textColor, muted, raised),
    GameKind.vukodlak => const GameLook(
      _nightPurple,
      textColor,
      Color(0xFFD5CBE8),
      null,
    ),
    GameKind.uljez => const GameLook(_uljezAmber, ink, ink, null),
  };
}

Widget _art(GameKind k) => switch (k) {
  GameKind.quiz => SizedBox(
    width: 150,
    child: GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 70 / 64,
      children: [
        _tile(_pink, ink, Icons.change_history),
        _tile(ink, _quizBlue, Icons.diamond),
        _tile(_amberTile, ink, Icons.circle),
        _tile(_green, ink, Icons.square),
      ],
    ),
  ),
  GameKind.curve => const SizedBox(
    width: 240,
    height: 120,
    child: CustomPaint(painter: _CurvePainter()),
  ),
  GameKind.vukodlak => const Icon(
    Icons.nights_stay,
    size: 96,
    color: Color(0xFFFFE08A),
  ),
  GameKind.uljez => const Text(
    '?',
    style: TextStyle(
      fontSize: 96,
      fontWeight: FontWeight.w900,
      height: 1,
      color: ink,
    ),
  ),
};

Widget _tile(Color bg, Color fg, IconData icon) => Container(
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
  alignment: Alignment.center,
  child: Icon(icon, size: 28, color: fg),
);

/// The host's game picker: one card per game and page dots.
class GameCarousel extends StatefulWidget {
  const GameCarousel({super.key, required this.lobby, required this.onPick});
  final LobbyState lobby;
  final void Function(GameKind) onPick;

  @override
  State<GameCarousel> createState() => _GameCarouselState();
}

class _GameCarouselState extends State<GameCarousel> {
  final _controller = PageController(viewportFraction: 0.82);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lobby;
    return Column(
      children: [
        SizedBox(
          height: 400,
          child: PageView(
            padEnds: false,
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final k in GameKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _card(k, l),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          key: const ValueKey('dots'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < GameKind.values.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _page ? accent : raised,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _card(GameKind k, LobbyState l) {
    final look = GameLook.of(k);
    return Material(
      color: look.fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: look.border == null
            ? BorderSide.none
            : BorderSide(color: look.border!, width: 3),
      ),
      child: InkWell(
        key: ValueKey('card-${k.name}'),
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        onTap: () => widget.onPick(k),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The art gives way first, so long texts never overflow the card.
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: _art(k),
                  ),
                ),
              ),
              Text(
                Strings.gameName(k),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: look.fg,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                Strings.gameBlurb(k),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, height: 1.35, color: look.sub),
              ),
              const SizedBox(height: 8),
              Text(
                Strings.settingsLine(k, l.settings, l.packs, l.uljezPacks),
                key: ValueKey('line-${k.name}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: look.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The coloured card at the top of a game's details: name and blurb.
class GameHeaderCard extends StatelessWidget {
  const GameHeaderCard(this.kind, {super.key});
  final GameKind kind;

  @override
  Widget build(BuildContext context) {
    final look = GameLook.of(kind);
    return Container(
      key: const ValueKey('game-header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: look.fill,
        borderRadius: BorderRadius.circular(24),
        border: look.border == null
            ? null
            : Border.all(color: look.border!, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Strings.gameName(kind),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: look.fg,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Strings.gameBlurb(kind),
            style: TextStyle(fontSize: 18, height: 1.35, color: look.sub),
          ),
        ],
      ),
    );
  }
}
