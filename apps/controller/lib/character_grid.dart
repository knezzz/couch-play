import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// The 16 characters, 4 across. [taken] ones are greyed and cannot be picked.
class CharacterGrid extends StatelessWidget {
  const CharacterGrid({
    required this.selected,
    required this.taken,
    required this.color,
    required this.onPick,
    super.key,
  });
  final String? selected;
  final Set<String> taken;
  final Color color;
  final void Function(String id) onPick;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cell = (c.maxWidth - 3 * _gap) / 4; // 72 px at 360 wide, never under 56
      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (final id in characterIds)
            Semantics(
              button: true,
              enabled: !taken.contains(id),
              child: Opacity(
                opacity: taken.contains(id) ? 0.25 : 1,
                child: InkWell(
                  key: ValueKey('char-$id'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: taken.contains(id) ? null : () => onPick(id),
                  child: Container(
                    width: cell,
                    height: cell,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: id == selected ? accent : raised,
                        width: id == selected ? 3 : 1,
                      ),
                    ),
                    child: CharacterFace(id, cell - 16, color),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
