import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';
import 'game_cards.dart';
import 'home_rows.dart';

/// The two colours of a game's background and the two tints of its circles.
({Color a, Color b, Color t1, Color t2}) scene(GameKind k) => switch (k) {
  GameKind.curve => (
    a: const Color(0xFF0B0B18),
    b: const Color(0xFF1A1236),
    t1: const Color(0xFFFF4D6D),
    t2: const Color(0xFF2ECC71),
  ),
  GameKind.quiz => (
    a: const Color(0xFF0E1A2E),
    b: const Color(0xFF132744),
    t1: const Color(0xFF22B8F0),
    t2: const Color(0xFFFFB020),
  ),
  GameKind.vukodlak => (
    a: const Color(0xFF05060F),
    b: const Color(0xFF101A3A),
    t1: const Color(0xFFF2E9C9),
    t2: const Color(0xFF3A2D5C),
  ),
  GameKind.uljez => (
    a: const Color(0xFF1A0E2E),
    b: const Color(0xFF2A1646),
    t1: const Color(0xFFE7B36A),
    t2: const Color(0xFF9B5CFF),
  ),
  GameKind.objasni => (
    a: const Color(0xFF2A1410),
    b: const Color(0xFF14283A),
    t1: const Color(0xFFFF8A4D),
    t2: const Color(0xFF22B8F0),
  ),
  GameKind.koliko => (
    a: const Color(0xFF0B1F1A),
    b: const Color(0xFF12304A),
    t1: const Color(0xFF3DDCC4),
    t2: const Color(0xFF22B8F0),
  ),
  GameKind.blef => (
    a: const Color(0xFF3A2008),
    b: const Color(0xFF2A0E0E),
    t1: const Color(0xFFFF4D6D),
    t2: const Color(0xFFFFB020),
  ),
  GameKind.tkobi => (
    a: const Color(0xFF2A1030),
    b: const Color(0xFF3A1430),
    t1: const Color(0xFF9B5CFF),
    t2: const Color(0xFFFF4D6D),
  ),
  GameKind.sumo => (
    a: const Color(0xFF2A1020),
    b: const Color(0xFF15101E),
    t1: const Color(0xFFFF4D6D),
    t2: const Color(0xFF22B8F0),
  ),
  GameKind.tenkovi => (
    a: const Color(0xFF0E1A2E),
    b: const Color(0xFF2A1A12),
    t1: const Color(0xFF7FD8A8),
    t2: const Color(0xFFFFB020),
  ),
};

/// "2–8 igrača".
String playersRange(GameKind k) {
  final r = switch (k) {
    GameKind.quiz => '1–8',
    GameKind.curve || GameKind.koliko || GameKind.sumo || GameKind.tenkovi => '2–8',
    GameKind.vukodlak => '5–8',
    GameKind.objasni => '4–8',
    _ => '3–8',
  };
  return '$r igrača';
}

/// The settings line under the title: the range of players, then each plain
/// setting; "bez robota" when the game has no bots row.
String homeMeta(GameKind k, LobbyState l) {
  final rows = homeRows(k, l);
  final parts = [
    playersRange(k),
    for (final r in rows)
      if (r.opens != HomeOpens.roles)
        r.key == 'bots' ? '${r.display} rob.' : r.display,
  ];
  if (!rows.any((r) => r.key == 'bots')) parts.add('bez robota');
  return parts.join(' · ');
}

/// The game card of the home: background, title, blurb, settings line and the
/// edges that name the neighbours. With [onPrev]/[onNext] the edges are
/// buttons (the host); without, they only show the names (guests). [pill] is
/// the "Ana gleda" label (guests).
class GameBanner extends StatelessWidget {
  const GameBanner({
    super.key,
    required this.kind,
    required this.prev,
    required this.next,
    required this.meta,
    this.onPrev,
    this.onNext,
    this.pill,
    this.compact = false,
  });
  final GameKind kind, prev, next;
  final String meta;
  final VoidCallback? onPrev, onNext;
  final String? pill;
  final bool compact;

  Widget _edge(
    String name, {
    required bool left,
    required String label,
    VoidCallback? onTap,
  }) {
    final text = Text(
      '${left ? '‹' : '›'}\n$name',
      textAlign: left ? TextAlign.right : TextAlign.left,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 12 : 14,
        fontWeight: FontWeight.w900,
        color: Color(0xFFF4F4F8).withValues(alpha: compact ? 0.45 : 0.6),
      ),
    );
    final box = Container(
      width: compact ? 70 : 92,
      height: compact ? 56 : 72,
      alignment: left ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.only(left: left ? 0 : 10, right: left ? 10 : 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: text,
    );
    return Positioned(
      left: left ? -24 : null,
      right: left ? null : -24,
      top: compact ? 100 : 104,
      child: onTap == null
          ? ExcludeSemantics(child: box)
          : Semantics(
              button: true,
              label: label,
              child: GestureDetector(
                key: ValueKey(left ? 'game-prev' : 'game-next'),
                onTap: onTap,
                child: box,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = scene(kind);
    final h = compact ? 250.0 : 290.0;
    return GestureDetector(
      key: const ValueKey('game-banner'),
      onHorizontalDragEnd: onPrev == null
          ? null
          : (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -200) onNext?.call();
              if (v > 200) onPrev?.call();
            },
      child: ClipRect(
        child: Container(
          height: h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(-0.6, -1),
              end: const Alignment(0.6, 1),
              colors: [c.a, c.b],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -60,
                top: -50,
                child: _circle(compact ? 200 : 220, c.t1, 0.28),
              ),
              Positioned(
                left: -70,
                bottom: -80,
                child: _circle(compact ? 180 : 200, c.t2, 0.22),
              ),
              if (pill != null)
                Positioned(
                  left: 16,
                  top: 14,
                  child: Container(
                    key: const ValueKey('watch-pill'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      pill!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              _edge(
                Strings.gameName(prev),
                left: true,
                label: Strings.prevGame(Strings.gameName(prev)),
                onTap: onPrev,
              ),
              _edge(
                Strings.gameName(next),
                left: false,
                label: Strings.nextGame(Strings.gameName(next)),
                onTap: onNext,
              ),
              Positioned(
                left: compact ? 56 : 76,
                right: compact ? 56 : 76,
                top: 64,
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Strings.gameName(kind),
                        key: const ValueKey('banner-title'),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: compact ? 46 : 54,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -1,
                          shadows: const [
                            Shadow(blurRadius: 20, color: Color(0x99000000)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      Strings.gameBlurb(kind),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: Color(0xFFE6E6F0),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Text(
                  meta,
                  key: const ValueKey('banner-meta'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFC9C9D8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle(double size, Color color, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: alpha),
    ),
  );
}

/// One dot per game; the selected one is long.
class HomeDots extends StatelessWidget {
  const HomeDots({super.key, required this.selected});
  final GameKind selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Row(
      key: const ValueKey('dots'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final k in supportedGames)
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: k == selected ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: k == selected
                  ? textColor
                  : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    ),
  );
}

const _rowRadius = 16.0;

/// The host's settings: − value + for steps and choices, a button for packs
/// and roles. The row `changed` points at is outlined in the accent. A tap only
/// sends; the next LobbyState changes the value.
class HostSettingsList extends StatelessWidget {
  const HostSettingsList({
    super.key,
    required this.rows,
    required this.changed,
    required this.onSend,
    required this.onOpen,
  });
  final List<HomeRow> rows;
  final String? changed;
  final void Function(Message m) onSend;
  final void Function(HomeOpens what) onOpen;

  Widget _step(String label, IconData glyph, VoidCallback? onTap, Key key) =>
      SizedBox(
        width: 56,
        height: 56,
        child: IconButton(
          key: key,
          tooltip: label,
          style: IconButton.styleFrom(
            backgroundColor: raised,
            foregroundColor: textColor,
            disabledForegroundColor: muted.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(glyph, size: 28),
          onPressed: onTap,
        ),
      );

  Widget _row(HomeRow r) {
    final prev = r.prev, next = r.next;
    final number = r.isNumber;
    return Container(
      key: ValueKey('row-${r.key}'),
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_rowRadius),
        border: Border.all(
          color: changed == r.key ? accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              r.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, height: 1.2),
            ),
          ),
          if (r.adjustable) ...[
            _step(
              Strings.lessOf(r.label),
              number ? Icons.remove : Icons.chevron_left,
              prev == null ? null : () => onSend(r.messageFor!(prev)),
              ValueKey('dec-${r.key}'),
            ),
            SizedBox(
              width: 88,
              child: Text(
                r.display,
                key: ValueKey('val-${r.key}'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            _step(
              Strings.moreOf(r.label),
              number ? Icons.add : Icons.chevron_right,
              next == null ? null : () => onSend(r.messageFor!(next)),
              ValueKey('inc-${r.key}'),
            ),
          ] else
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: SizedBox(
                height: 56,
                child: TextButton(
                  key: ValueKey('open-${r.key}'),
                  onPressed: () => onOpen(r.opens!),
                  style: TextButton.styleFrom(
                    backgroundColor: raised,
                    foregroundColor: textColor,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(
                    '${r.display} ›',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final r in rows)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: _row(r)),
    ],
  );
}

/// The guest's settings: read-only. On the changed row the old value is struck
/// through next to the new one, under an accent outline.
class GuestSettingsList extends StatelessWidget {
  const GuestSettingsList({
    super.key,
    required this.rows,
    required this.changed,
    required this.old,
  });
  final List<HomeRow> rows;
  final String? changed;

  /// The old value, worded, for the changed row.
  final String? old;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            key: ValueKey('row-${r.key}'),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: changed == r.key ? accent : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    r.label,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFFC9C9D8),
                    ),
                  ),
                ),
                if (changed == r.key && old != null) ...[
                  Text(
                    old!,
                    key: const ValueKey('old-value'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: muted,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  r.display,
                  key: ValueKey('val-${r.key}'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: changed == r.key ? accent : textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

/// "Zadnje promjene": the TV's last five changes, newest first.
class ChangeFeed extends StatelessWidget {
  const ChangeFeed({super.key, required this.lobby, required this.host});
  final LobbyState lobby;
  final String host;

  String _text(LobbyChange c) {
    final game = c.game == null ? '' : Strings.gameName(c.game!);
    switch (c.kind) {
      case ChangeKind.game:
        return Strings.changedGame(game);
      case ChangeKind.settings:
        return Strings.changedSettings(game);
      case ChangeKind.packs:
        return Strings.changedPacks(game);
      case ChangeKind.setting:
        final row = c.game == null
            ? null
            : homeRows(c.game!, lobby).where((r) => r.key == c.key).firstOrNull;
        // A key that is not one of the game's rows: never print it raw.
        if (row == null) return Strings.changedSettings(game);
        return Strings.changedSetting(
          game,
          row.label,
          changeValue(c, c.old, lobby),
          changeValue(c, c.new_, lobby),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        Strings.changesTitle,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      ),
      const SizedBox(height: 8),
      if (lobby.changes.isEmpty)
        Text(
          Strings.changesEmpty(host),
          key: const ValueKey('feed-empty'),
          style: const TextStyle(fontSize: 14, color: muted),
        ),
      for (final c in lobby.changes.take(5))
        if (c.game != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              key: const ValueKey('feed-line'),
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    _text(c),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: c.kind == ChangeKind.setting ? textColor : muted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  c.by == ChangeBy.remote ? Strings.byRemote : Strings.byPhone,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
    ],
  );
}
