import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../strings.dart';
import 'tv_theme.dart';

class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

/// Back during a game asks "End this game and return to the lobby?"; Yes calls
/// [onEnd]. The remote's Back reaches Android apps as a pop-route, not a key,
/// so this listens for that; Escape does the same for macOS. With the dialog
/// open, Back or Escape closes it (No). Outside a game ([active] false) Back is
/// left to [onIdleBack] if it handles it (it returns true), else to the system.
/// Put it in `MaterialApp.builder`.
class BackGuard extends StatefulWidget {
  const BackGuard({
    required this.navigatorKey,
    required this.active,
    required this.changes,
    required this.onEnd,
    required this.child,
    this.onIdleBack,
    this.players,
    this.onKick,
    super.key,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final bool Function() active;

  /// Fires when [active] may have changed: a dialog left open over a finished
  /// game is closed.
  final Listenable changes;
  final VoidCallback onEnd;

  /// Back (or Escape) while no game is active: true if it did something (e.g.
  /// closed the results screen), false to leave Back to the system.
  final bool Function()? onIdleBack;
  final Widget child;

  /// With both set, the Back menu also offers "Ukloni igrača": the players to pick
  /// from (in join order, the same for everyone) and what a confirmed pick calls.
  final List<PlayerInfo> Function()? players;
  final void Function(int playerId)? onKick;

  @override
  State<BackGuard> createState() => _BackGuardState();
}

class _BackGuardState extends State<BackGuard> with WidgetsBindingObserver {
  var _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.changes.addListener(_changed);
  }

  @override
  void dispose() {
    widget.changes.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _changed() {
    if (_open && !widget.active()) widget.navigatorKey.currentState?.pop();
  }

  Future<void> _ask() async {
    final ctx = widget.navigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;
    _open = true;
    final canKick = widget.players != null && widget.onKick != null;
    final r = await showDialog<_Choice>(context: ctx, builder: (_) => _EndGameDialog(canKick: canKick));
    if (r == _Choice.kick && mounted) await _kick(ctx);
    _open = false;
    if (r == _Choice.end && mounted) widget.onEnd();
  }

  Future<void> _kick(BuildContext ctx) async {
    final people = widget.players!();
    final id = await showDialog<int>(context: ctx, builder: (_) => _KickDialog(people));
    if (id == null || !mounted) return;
    final name = people.where((p) => p.id == id).firstOrNull?.name ?? '';
    if (!ctx.mounted) return;
    final yes = await showDialog<bool>(context: ctx, builder: (_) => _KickConfirm(name));
    if (yes == true && mounted) widget.onKick!(id);
  }

  /// The navigator's own observer runs first and closes an open dialog; this
  /// only sees Back when nothing was open.
  @override
  Future<bool> didPopRoute() async {
    if (_open) return false;
    if (!widget.active()) return widget.onIdleBack?.call() ?? false;
    _ask();
    return true;
  }

  void _escape() {
    if (_open) {
      widget.navigatorKey.currentState?.pop();
    } else if (widget.active()) {
      _ask();
    } else {
      widget.onIdleBack?.call();
    }
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
        shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): _EscapeIntent()},
        child: Actions(
          actions: {
            _EscapeIntent: CallbackAction<_EscapeIntent>(onInvoke: (_) {
              _escape();
              return null;
            }),
          },
          child: widget.child,
        ),
      );
}

enum _Choice { end, kick }

class _EndGameDialog extends StatelessWidget {
  const _EndGameDialog({required this.canKick});
  final bool canKick;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text(Strings.endGameTitle, style: TextStyle(fontSize: 44)),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context),
            child: const Text(Strings.no),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _Choice.end),
            child: const Text(Strings.yes),
          ),
          if (canKick)
            FilledButton(
              onPressed: () => Navigator.pop(context, _Choice.kick),
              child: const Text(Strings.kickPlayer),
            ),
        ],
      );
}

/// The players, as buttons. Only names and whether a phone has no connection (a connection
/// is not a role): never who has finished a night task, never a role.
class _KickDialog extends StatelessWidget {
  const _KickDialog(this.people);
  final List<PlayerInfo> people;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text(Strings.kickPlayer, style: TextStyle(fontSize: 44)),
        content: SizedBox(
          width: 1100,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 20,
              runSpacing: 16,
              children: [
                for (var i = 0; i < people.length; i++)
                  FilledButton(
                    autofocus: i == 0,
                    onPressed: () => Navigator.pop(context, people[i].id),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      PlayerDot(playerColors[people[i].colorIndex % playerColors.length], size: 44, character: people[i].character),
                      const SizedBox(width: 14),
                      Text(people[i].connected ? people[i].name : '${people[i].name} · ${Strings.kickOffline}', style: const TextStyle(fontSize: 36)),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _KickConfirm extends StatelessWidget {
  const _KickConfirm(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(Strings.kickConfirm(name), style: const TextStyle(fontSize: 44)),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          FilledButton(autofocus: true, onPressed: () => Navigator.pop(context, false), child: const Text(Strings.no)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(Strings.yes)),
        ],
      );
}
