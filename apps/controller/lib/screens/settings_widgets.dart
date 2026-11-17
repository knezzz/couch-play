import 'package:flutter/material.dart';

import '../theme.dart';

/// A pack dropdown for the games that list their packs this way: [title] over
/// a 56 px card. [packs] are (id, title).
class PackDropdown extends StatelessWidget {
  const PackDropdown({
    super.key,
    required this.title,
    required this.packs,
    required this.packId,
    required this.onPick,
    required this.fieldKey,
  });
  final String title;
  final List<(String, String)> packs;
  final String? packId;
  final void Function(String id) onPick;
  final Key fieldKey;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: const TextStyle(fontSize: 18, color: muted)),
      const SizedBox(height: 8),
      Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: DropdownButton<String>(
          key: fieldKey,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          value: packs.any((p) => p.$1 == packId) ? packId : null,
          dropdownColor: surface,
          style: const TextStyle(fontSize: 20, color: textColor),
          items: [
            for (final p in packs)
              DropdownMenuItem(
                value: p.$1,
                child: Text(p.$2, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) onPick(v);
          },
        ),
      ),
    ],
  );
}

/// A setting with a few fixed values, one chip each: the label over a row of
/// equal chips. Chip keys are '[keyPrefix]-[value]'.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.values,
    required this.value,
    required this.text,
    required this.onPick,
    required this.keyPrefix,
  });
  final String label, keyPrefix;
  final List<int> values;
  final int value;
  final String Function(int) text;
  final void Function(int) onPick;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 19)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                  child: ChoiceChip(
                    key: ValueKey('$keyPrefix-${values[i]}'),
                    showCheckmark: false,
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        text(values[i]),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    selected: value == values[i],
                    onSelected: (_) => onPick(values[i]),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    visualDensity: const VisualDensity(vertical: 4),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
