import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _BackIntent extends Intent {
  const _BackIntent();
}

/// Back (remote) or Escape during a game asks "End this game and return to the
/// lobby?"; Yes calls [onEnd]. Outside a game ([active] false) the key is left
/// alone. Put it in `MaterialApp.builder`, with the app's [navigatorKey].
class BackGuard extends StatelessWidget {
  const BackGuard({
    required this.navigatorKey,
    required this.active,
    required this.onEnd,
    required this.child,
    super.key,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final bool Function() active;
  final VoidCallback onEnd;
  final Widget child;

  Future<void> _ask() async {
    final ctx = navigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;
    final yes = await showDialog<bool>(
      context: ctx,
      builder: (_) => const _EndGameDialog(),
    );
    if (yes == true) onEnd();
  }

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.goBack): _BackIntent(),
      SingleActivator(LogicalKeyboardKey.escape): _BackIntent(),
    },
    child: Actions(
      actions: {_BackIntent: _BackAction(active, _ask)},
      child: child,
    ),
  );
}

class _BackAction extends Action<_BackIntent> {
  _BackAction(this.active, this.ask);
  final bool Function() active;
  final Future<void> Function() ask;

  @override
  bool isEnabled(_BackIntent intent, [BuildContext? context]) => active();

  @override
  Object? invoke(_BackIntent intent) {
    ask();
    return null;
  }
}

class _EndGameDialog extends StatelessWidget {
  const _EndGameDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(
      'End this game and return to the lobby?',
      style: TextStyle(fontSize: 44),
    ),
    actionsAlignment: MainAxisAlignment.start,
    actions: [
      FilledButton(
        autofocus: true,
        onPressed: () => Navigator.pop(context, false),
        child: const Text('No'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Yes'),
      ),
    ],
  );
}
