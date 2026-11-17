import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../strings.dart';

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
    final yes = await showDialog<bool>(context: ctx, builder: (_) => const _EndGameDialog());
    _open = false;
    if (yes == true && mounted) widget.onEnd();
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

class _EndGameDialog extends StatelessWidget {
  const _EndGameDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text(Strings.endGameTitle, style: TextStyle(fontSize: 44)),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Strings.no),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Strings.yes),
          ),
        ],
      );
}
