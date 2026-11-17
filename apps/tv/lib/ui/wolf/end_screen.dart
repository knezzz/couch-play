import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../session/wolf_text.dart';
import '../../strings.dart';
import '../tv_theme.dart';
import 'village_screen.dart';

/// The end of Vukodlak: who won, and every player's role (hidden roles are
/// revealed only now). Pass roles only once the game is over.
class WolfEndScreen extends StatelessWidget {
  const WolfEndScreen({required this.players, required this.roles, required this.headline, super.key});
  final List<VillagePlayer> players;
  final Map<int, WolfRole> roles;
  final String headline;

  static const _red = Color(0xFFFF4D6D), _green = Color(0xFF2ECC71), _amber = Color(0xFFFFB020);

  static Color teamColor(WolfRole r) => switch (r.team) {
        WolfTeam.wolves => _red,
        WolfTeam.village => _green,
        WolfTeam.solo => _amber,
      };

  @override
  Widget build(BuildContext context) {
    final n = players.length;
    final cols = n <= 4 ? n : 4;
    final face = n <= 4 ? 140.0 : 100.0;
    return Scaffold(
      backgroundColor: const Color(0xFF14141E),
      body: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          width: 1920,
          height: 1080,
          padding: const EdgeInsets.fromLTRB(96, 72, 96, 48),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A1E2E), Color(0xFF14141E)]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(Strings.wolfEndHeader,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: 4, color: Color(0xFFE7B36A))),
              const SizedBox(height: 8),
              Text(headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: tvText)),
              const SizedBox(height: 48),
              Wrap(
                spacing: 28,
                runSpacing: 28,
                children: [
                  for (final p in players) _card(p, face, (1728 - 28 * (cols - 1)) / cols),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(VillagePlayer p, double face, double width) {
    final role = roles[p.id];
    return Container(
      key: ValueKey('end-card-${p.id}'),
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(32)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerDot(playerColors[p.colorIndex % playerColors.length], size: face, character: p.character),
          const SizedBox(height: 12),
          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: tvText)),
          if (role != null)
            Text(WolfText.roleNames[role]!,
                key: const ValueKey('role'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: teamColor(role))),
        ],
      ),
    );
  }
}
