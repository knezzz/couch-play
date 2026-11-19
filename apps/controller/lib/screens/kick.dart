import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import '../strings.dart';
import '../theme.dart';

/// "Ukloniti igrača X?" with Ukloni / Zadrži; Ukloni sends Kick(id). Used by
/// the lobby and by the host's bar during a game.
Future<void> confirmKick(
  BuildContext context,
  Connection conn,
  PlayerInfo p,
) async {
  final color = playerColors[p.colorIndex % playerColors.length];
  final ok = await showModalBottomSheet<bool>(
    isScrollControlled:
        true, // the Croatian text can need more than the default 9/16 height
    context: context,
    backgroundColor: surface,
    barrierColor: const Color(0xCC0A0A10),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    Strings.removeTitle(p.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              Strings.removeBody(p.name),
              style: const TextStyle(fontSize: 18, color: muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D6D),
                foregroundColor: ink,
              ),
              onPressed: () => Navigator.pop(c, true),
              child: const Text(Strings.remove, style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: raised,
                foregroundColor: textColor,
              ),
              onPressed: () => Navigator.pop(c, false),
              child: const Text(Strings.keep, style: TextStyle(fontSize: 22)),
            ),
          ],
        ),
      ),
    ),
  );
  if (ok == true) conn.send(Kick(p.id));
}

/// The host's strip at the bottom of a game screen: opens the list of the
/// other players. Shown on the host's phone only, and not at night.
class HostKickBar extends StatefulWidget {
  const HostKickBar({
    super.key,
    required this.conn,
    required this.players,
    required this.myId,
  });
  final Connection conn;
  final List<PlayerInfo> players;
  final int myId;

  @override
  State<HostKickBar> createState() => _HostKickBarState();
}

class _HostKickBarState extends State<HostKickBar> {
  // The open list follows the players as the TV reports them.
  late final _live = ValueNotifier(widget.players);
  Connection get conn => widget.conn;
  int get myId => widget.myId;

  @override
  void didUpdateWidget(HostKickBar old) {
    super.didUpdateWidget(old);
    // Not during this build: the open list listens to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _live.value = widget.players;
    });
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.players;
    final away = players.where((p) => p.id != myId && !p.bot && !p.connected);
    return Material(
      color: bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: TextButton(
              key: const ValueKey('kick-open'),
              onPressed: () => _list(context),
              style: TextButton.styleFrom(
                foregroundColor: away.isEmpty ? muted : const Color(0xFFFF4D6D),
              ),
              child: Text(
                away.isEmpty
                    ? Strings.removePlayer
                    : Strings.removeAway(away.length),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _list(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      barrierColor: const Color(0xCC0A0A10),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                Strings.removePlayer,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ValueListenableBuilder(
                  valueListenable: _live,
                  builder: (_, players, _) => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in players)
                        if (p.id != myId && !p.bot) _row(c, context, p),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext sheet, BuildContext outer, PlayerInfo p) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: raised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CharacterFace(
            p.character,
            40,
            playerColors[p.colorIndex % playerColors.length],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!p.connected)
                  const Text(
                    Strings.noConnection,
                    style: TextStyle(fontSize: 18, color: muted),
                  ),
              ],
            ),
          ),
          TextButton(
            key: ValueKey('kick-${p.id}'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: const Color(0xFFFF4D6D),
              textStyle: const TextStyle(fontSize: 18),
            ),
            onPressed: () {
              Navigator.pop(sheet);
              confirmKick(outer, conn, p);
            },
            child: const Text(Strings.remove),
          ),
        ],
      ),
    ),
  );
}
