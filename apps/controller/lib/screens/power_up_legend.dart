import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';

/// "Pojačanja": every Curve power-up with its icon, one line and how long it
/// lasts, grouped by whom it acts on. Opens and closes; shut by default so the
/// details stay short. The texts and icons come from core, as on the TV.
class PowerUpLegend extends StatefulWidget {
  const PowerUpLegend({super.key});

  @override
  State<PowerUpLegend> createState() => _PowerUpLegendState();
}

class _PowerUpLegendState extends State<PowerUpLegend> {
  bool _open = false;

  static const _groups = [
    (PowerUpTarget.you, Strings.puYou, Color(0xFF3DDC84)),
    (PowerUpTarget.others, Strings.puOthers, Color(0xFFFF4D4D)),
    (PowerUpTarget.all, Strings.puAll, Color(0xFF4DA6FF)),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Material(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const ValueKey('legend-toggle'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _open = !_open),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    Strings.powerUps,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 28,
                  color: accent,
                ),
              ],
            ),
          ),
        ),
      ),
      if (_open)
        for (final g in _groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: g.$3,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(g.$2, style: const TextStyle(fontSize: 18, color: muted)),
              ],
            ),
          ),
          for (final k in PowerUpKind.values)
            if (powerUpActsOn(k) == g.$1) _row(k),
        ],
    ],
  );

  Widget _row(PowerUpKind k) {
    final t = powerUpTexts[k]!;
    return Container(
      key: ValueKey('pu-${k.name}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PowerUpIcon(k, 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  t.what,
                  style: const TextStyle(
                    fontSize: 18,
                    color: muted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            t.time,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
