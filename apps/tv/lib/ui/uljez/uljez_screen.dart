import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../strings.dart';
import '../tv_theme.dart';

/// One player at the table. There is deliberately no word here.
class UljezSeat {
  const UljezSeat({
    required this.id,
    required this.name,
    required this.colorIndex,
    this.character = '',
    this.turn = false,
    this.done = false,
    this.impostor = false,
    this.out = false,
    this.voters = const [],
  });
  final int id;
  final String name;
  final int colorIndex;
  final String character;

  /// Their clue turn now / already gave their clue.
  final bool turn, done;

  /// Shown as the impostor (caught, or the game is over).
  final bool impostor;
  final bool out;

  /// Ids of the players who voted for this one (shown when the vote result is up).
  final List<int> voters;
}

/// Where each seat stands: round the table, the first at the top, then clockwise.
List<Offset> uljezSpots(int n) => [
      for (var i = 0; i < n; i++)
        Offset(
          (960 + 560 * cos(-pi / 2 + i * 2 * pi / n)).roundToDouble(),
          (565 + 270 * sin(-pi / 2 + i * 2 * pi / n)).roundToDouble(),
        ),
    ];

/// Uljez on the TV (docs/design/couchplay-screens/UljezTv.dc.html), console look,
/// on a 1920x1080 canvas scaled to fit: the players round a table, whose turn
/// it is and the clock, the vote result and, only at the end, both words.
///
/// [villageWord] / [impostorWord] are null until the game is over: the screen
/// draws them only when given, so a word can never show earlier.
class UljezScreen extends StatefulWidget {
  const UljezScreen({
    required this.seats,
    required this.kicker,
    required this.headline,
    this.clockLabel = '',
    this.clock = '',
    this.hint,
    this.villageWord,
    this.impostorWord,
    this.showVotes = false,
    super.key,
  });
  final List<UljezSeat> seats;
  final String kicker, headline, clockLabel, clock;

  /// A line in the middle of the table (the clue instruction).
  final String? hint;
  final String? villageWord, impostorWord;

  /// The vote result is up: the voters' faces and the tally under each seat.
  final bool showVotes;

  @override
  State<UljezScreen> createState() => _UljezScreenState();
}

class _UljezScreenState extends State<UljezScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    if (reduced) {
      _pulse.stop();
      _pulse.value = 0;
    } else {
      _pulseTurn();
    }
  }

  // The speaker's ring pulses a few times when the turn moves, then holds still: an endless
  // ticker kept the TV drawing 60 frames a second all game (heat, power).
  void _pulseTurn() => _pulse.repeat(reverse: true, count: 6);

  @override
  void didUpdateWidget(UljezScreen old) {
    super.didUpdateWidget(old);
    if (_reduced == false && _turnId(widget) != _turnId(old)) _pulseTurn();
  }

  static int? _turnId(UljezScreen w) => w.seats.where((s) => s.turn).firstOrNull?.id;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spots = uljezSpots(widget.seats.length);
    return Scaffold(
      backgroundColor: const Color(0xFF120E1E),
      body: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          width: 1920,
          height: 1080,
          decoration: const BoxDecoration(
            gradient: RadialGradient(center: Alignment(0, 0.1), radius: 0.9, colors: [Color(0xFF2A1F3D), Color(0xFF120E1E)], stops: [0, 0.7]),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 72,
                top: 56,
                width: 1200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.kicker, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 4, color: Color(0xFFC9A8FF))),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(widget.headline, maxLines: 1, style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: tvText)),
                    ),
                  ],
                ),
              ),
              if (widget.clock.isNotEmpty || widget.clockLabel.isNotEmpty)
                Positioned(
                  right: 72,
                  top: 64,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.clockLabel.isNotEmpty) Text(widget.clockLabel, style: const TextStyle(fontSize: 40, color: tvMuted)),
                      if (widget.clock.isNotEmpty) Text(widget.clock, style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w900, height: 1, color: tvText)),
                    ],
                  ),
                ),
              const Positioned.fill(child: CustomPaint(painter: _TablePainter())),
              for (var i = 0; i < widget.seats.length; i++) _seat(widget.seats[i], spots[i]),
              Positioned(
                left: 610,
                top: 515,
                width: 700,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.villageWord != null && widget.impostorWord != null)
                      Row(
                        key: const ValueKey('words'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _word(Strings.uljezVillageWord, widget.villageWord!, tvText),
                          const SizedBox(width: 28),
                          _word(Strings.uljezImpostorWord, widget.impostorWord!, const Color(0xFFFF4D6D)),
                        ],
                      ),
                    if (widget.hint != null)
                      Text(widget.hint!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, color: Color(0xFFE6DDF7))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _word(String label, String word, Color bg) => Container(
        constraints: const BoxConstraints(maxWidth: 336),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: tvInk)),
            FittedBox(fit: BoxFit.scaleDown, child: Text(word, maxLines: 1, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: tvInk))),
          ],
        ),
      );

  Widget _seat(UljezSeat s, Offset at) {
    final color = s.out ? const Color(0xFF6E6E7A) : playerColors[s.colorIndex % playerColors.length];
    // From four players up, the votes under a seat need the room (and TVs crop the edges): smaller rings.
    final big = widget.seats.length <= 3;
    final ringColor = s.impostor ? const Color(0xFFFF4D6D) : (s.turn ? const Color(0xFFFFE27A) : Colors.transparent);
    Widget ring = Container(
      key: s.impostor ? const ValueKey('impostor-ring') : (s.turn ? const ValueKey('turn-ring') : null),
      width: big ? 152 : 128,
      height: big ? 152 : 128,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ringColor, width: 6)),
      child: Container(
        width: big ? 140 : 116,
        height: big ? 140 : 116,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1E1830)),
        child: PlayerDot(color, size: big ? 110 : 92, character: s.character),
      ),
    );
    if (s.turn) ring = ScaleTransition(scale: Tween(begin: 1.0, end: 1.06).animate(_pulse), child: ring);

    String? note;
    var noteColor = tvMuted;
    Widget? noteIcon;
    if (s.impostor) {
      note = Strings.uljezTag;
      noteColor = const Color(0xFFFF4D6D);
    } else if (s.turn) {
      note = Strings.uljezNow;
      noteColor = const Color(0xFFFFE27A);
    } else if (s.done) {
      note = Strings.uljezSaidClue;
      noteIcon = const Icon(Icons.check, size: 28, color: tvMuted);
    }
    final votes = widget.showVotes ? s.voters.length : 0;
    Widget col = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ring,
        const SizedBox(height: 6),
        Text(s.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: tvText, decoration: s.out ? TextDecoration.lineThrough : TextDecoration.none)),
        if (note != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?noteIcon,
              Flexible(
                child: Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: noteColor)),
              ),
            ],
          ),
        if (votes > 0) ...[
          Text(Strings.uljezVotes(votes), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFFFFE27A))),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              for (final v in s.voters) _voter(v),
            ],
          ),
        ],
      ],
    );
    if (s.out && !s.impostor) col = Opacity(opacity: 0.55, child: col);
    return Positioned(
      key: ValueKey('seat-${s.id}'),
      left: at.dx - 120,
      top: at.dy - 100,
      width: 240,
      child: col,
    );
  }

  Widget _voter(int id) {
    final v = widget.seats.where((p) => p.id == id).firstOrNull;
    if (v == null) return const SizedBox.shrink();
    return PlayerDot(playerColors[v.colorIndex % playerColors.length], size: 28, character: v.character);
  }
}

class _TablePainter extends CustomPainter {
  const _TablePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1920, size.height / 1080);
    final p = Paint()..color = const Color(0xFF3A2A55);
    canvas.drawOval(Rect.fromCenter(center: const Offset(960, 585), width: 840, height: 440), p);
    canvas.drawOval(Rect.fromCenter(center: const Offset(960, 575), width: 800, height: 410), p..color = const Color(0xFF4A3670));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TablePainter old) => false;
}
