import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../strings.dart';
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

/// Every pack of a game as a checklist: [title] over one 64 px row per pack,
/// ticked packs filled. [ticked] is what the TV says; a tap only sends
/// [onToggle]. The last ticked pack cannot be unticked: its row says so
/// ("mora ostati") and a tap on it shows the reason instead of sending.
class PackChecklist extends StatefulWidget {
  const PackChecklist({
    super.key,
    required this.title,
    required this.packs,
    required this.ticked,
    required this.onToggle,
  });
  final String title;
  final List<PackInfo> packs;
  final Set<String> ticked;
  final void Function(String id) onToggle;

  @override
  State<PackChecklist> createState() => _PackChecklistState();
}

class _PackChecklistState extends State<PackChecklist> {
  bool _refused = false;

  @override
  Widget build(BuildContext context) {
    final on = {
      for (final p in widget.packs)
        if (widget.ticked.contains(p.id)) p.id,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: const TextStyle(fontSize: 18, color: muted)),
        const SizedBox(height: 8),
        for (final p in widget.packs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _row(
              p,
              on.contains(p.id),
              on.length == 1 && on.contains(p.id),
            ),
          ),
        if (_refused)
          const Text(
            Strings.lastPackStays,
            key: ValueKey('pack-refused'),
            style: TextStyle(fontSize: 18, color: muted),
          ),
      ],
    );
  }

  Widget _row(PackInfo p, bool on, bool last) => Semantics(
    checked: on,
    child: Material(
      color: on ? raised : surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('pack-${p.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          if (last) {
            setState(() => _refused = true);
            return;
          }
          setState(() => _refused = false);
          widget.onToggle(p.id);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(
                on ? Icons.check_box : Icons.check_box_outline_blank,
                size: 32,
                color: on ? accent : muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (last)
                      const Text(
                        Strings.packMustStay,
                        style: TextStyle(fontSize: 18, color: muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Strings.questions(p.questionCount),
                style: const TextStyle(fontSize: 18, color: muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
