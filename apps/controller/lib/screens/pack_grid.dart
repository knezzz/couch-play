import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';

/// "Paket pitanja": every quiz pack in two columns, opened from the Kviz
/// details; any number can be ticked. The TV owns the choice: [ticked] comes
/// from its LobbyState and a tap only sends [onToggle]. The last ticked pack
/// says it stays and a tap on it shows why.
class PackGridScreen extends StatefulWidget {
  const PackGridScreen({
    super.key,
    required this.packs,
    required this.ticked,
    required this.onToggle,
    required this.onBack,
    this.addPack,
  });
  final List<PackInfo> packs;
  final Set<String> ticked;
  final void Function(String id) onToggle;
  final VoidCallback onBack;

  /// Browser-only upload; null in tests and where it is unavailable.
  final Future<String?> Function()? addPack;

  @override
  State<PackGridScreen> createState() => _PackGridState();
}

class _PackGridState extends State<PackGridScreen> {
  String? _message;
  bool _refused = false;

  Future<void> _add() async {
    final msg = await widget.addPack!();
    if (mounted) setState(() => _message = msg);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton(
              key: const ValueKey('packs-back'),
              onPressed: widget.onBack,
              style: TextButton.styleFrom(minimumSize: const Size(56, 56)),
              child: const Text(
                '‹ ${Strings.back}',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const Text(
              Strings.quizPack,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: LayoutBuilder(
                  builder: (_, c) {
                    final w = (c.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in widget.packs)
                          SizedBox(
                            width: w,
                            child: _PackTile(
                              p,
                              on: widget.ticked.contains(p.id),
                              last:
                                  widget.ticked.length == 1 &&
                                  widget.ticked.contains(p.id),
                              onTap: () {
                                final last =
                                    widget.ticked.length == 1 &&
                                    widget.ticked.contains(p.id);
                                setState(() => _refused = last);
                                if (!last) widget.onToggle(p.id);
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (_refused)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  Strings.lastPackStays,
                  key: ValueKey('pack-refused'),
                  style: TextStyle(fontSize: 18),
                ),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_message!, style: const TextStyle(fontSize: 18)),
              ),
            if (widget.addPack != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                key: const ValueKey('add-pack'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  foregroundColor: accent,
                  side: const BorderSide(color: raised, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: _add,
                child: const Text(Strings.addPack),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PackTile extends StatelessWidget {
  const _PackTile(
    this.p, {
    required this.on,
    required this.last,
    required this.onTap,
  });
  final PackInfo p;
  final bool on, last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: on,
    child: Material(
      color: on ? accent : surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('pack-${p.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      on ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 24,
                      color: on ? ink : muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: on ? ink : textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  last
                      ? '${Strings.packMeta(p)} · ${Strings.packMustStay}'
                      : Strings.packMeta(p),
                  style: TextStyle(fontSize: 18, color: on ? ink : muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
