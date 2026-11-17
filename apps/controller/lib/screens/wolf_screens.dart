import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';

// Phone screens for Vukodlak. They take plain values and callbacks; the app
// wires them to the protocol. Privacy: the night screen's look never depends
// on the role, only its one hint line does.

const _nightBg = Color(0xFF101014);
const _nightCard = Color(0xFF18181E);
const _nightMuted = Color(0xFF8A8A96);
const _amber = Color(0xFFE7B36A);

/// A player to pick at night or in the day vote.
class WolfTarget {
  const WolfTarget(this.id, this.name, this.character, this.colorIndex);
  final int id;
  final String name;
  final String character;
  final int colorIndex;
}

/// One choice on the night screen: a player's name or a sum answer. Both are
/// drawn in the same row, with the same grey disc.
class NightItem {
  const NightItem(this.id, this.label);
  final int id;
  final String label;
}

/// The role card: hidden until a finger is down.
class RoleHoldScreen extends StatefulWidget {
  const RoleHoldScreen({
    super.key,
    required this.name,
    required this.night,
    required this.role,
    required this.description,
    this.extra = '',
    this.onRoles,
  });
  final String name;
  final int night;
  final String role, description, extra;
  final VoidCallback? onRoles;
  @override
  State<RoleHoldScreen> createState() => _RoleHoldState();
}

class _RoleHoldState extends State<RoleHoldScreen> {
  final _down = <int>{};

  void _up(PointerEvent e) {
    if (_down.remove(e.pointer) && _down.isEmpty) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shown = _down.isNotEmpty;
    return Scaffold(
      backgroundColor: _nightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    Strings.night(widget.night),
                    style: const TextStyle(fontSize: 18, color: _nightMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Listener(
                  onPointerDown: (e) {
                    if (_down.add(e.pointer) && _down.length == 1) {
                      setState(() {});
                    }
                  },
                  onPointerUp: _up,
                  onPointerCancel: _up,
                  child: Semantics(
                    button: true,
                    label: Strings.holdHere,
                    child: Container(
                      key: const ValueKey('role-card'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _nightCard,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF26262E),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: SingleChildScrollView(
                          child: shown ? _shown() : _hidden(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.onRoles != null)
                TextButton(
                  key: const ValueKey('open-roles'),
                  onPressed: widget.onRoles,
                  style: TextButton.styleFrom(minimumSize: const Size(56, 56)),
                  child: const Text(
                    Strings.rolesInThisGame,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hidden() => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.touch_app_outlined, size: 96, color: Color(0xFF5A5A66)),
      SizedBox(height: 16),
      Text(
        Strings.holdHere,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      SizedBox(height: 16),
      Text(
        Strings.holdHint,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: _nightMuted, height: 1.4),
      ),
    ],
  );

  Widget _shown() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        Strings.yourRole,
        style: TextStyle(
          fontSize: 18,
          color: _nightMuted,
          letterSpacing: 3,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        widget.role,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 16),
      Text(
        widget.description,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          height: 1.45,
          color: Color(0xFFB8B8C2),
        ),
      ),
      if (widget.extra.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          widget.extra,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Color(0xFFB8B8C2)),
        ),
      ],
    ],
  );
}

/// One grey screen for every role. `hint` is the only thing that may differ.
class NightScreen extends StatefulWidget {
  const NightScreen({
    super.key,
    required this.night,
    required this.hint,
    required this.targets,
    required this.onConfirm,
    this.special = false,
    this.picks = 1,
    this.picked = const [],
    this.showSpecial = true,
  });
  final int night;
  final String hint;
  final List<NightItem> targets;

  /// The switch every phone carries; the TV gives the restored value.
  final bool special;

  /// 2 on night 1 for every phone; the first and second pick go out together.
  final int picks;

  /// Restored picks after a reload.
  final List<int> picked;
  final bool showSpecial;
  final void Function(int target, int? second, bool special) onConfirm;
  @override
  State<NightScreen> createState() => _NightState();
}

class _NightState extends State<NightScreen> {
  late final List<int> _picked = [...widget.picked];
  late bool _special = widget.special;
  bool _sent = false; // the same "done" look for every role

  void _tap(int id) {
    if (_picked.remove(id)) return;
    if (_picked.length == widget.picks) _picked.removeLast();
    _picked.add(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _nightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Strings.night(widget.night),
                style: const TextStyle(
                  fontSize: 18,
                  color: _nightMuted,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                Strings.nightTitle,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              // Fixed height so a longer hint never moves anything below it.
              SizedBox(
                width: double.infinity,
                height: 72,
                child: Text(
                  widget.hint.trimRight(), // the TV pads it to a fixed length
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    color: _nightMuted,
                    height: 1.3,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final t in widget.targets)
                      _row(
                        key: ValueKey('night-${t.id}'),
                        name: t.label,
                        on: _picked.contains(t.id),
                        note: widget.picks == 2 && _picked.contains(t.id)
                            ? '${_picked.indexOf(t.id) + 1}'
                            : '',
                        face: const SizedBox(
                          key: ValueKey('face'),
                          width: 44,
                          height: 44,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF9A9AA6),
                            ),
                          ),
                        ),
                        border: const Color(0xFFB8B8C2),
                        fill: _nightCard,
                        onTap: _sent ? null : () => setState(() => _tap(t.id)),
                      ),
                  ],
                ),
              ),
              if (widget.showSpecial)
                SwitchListTile(
                  key: const ValueKey('night-special'),
                  value: _special,
                  onChanged: _sent ? null : (v) => setState(() => _special = v),
                  title: const Text(
                    Strings.nightSpecial,
                    style: TextStyle(fontSize: 18, color: _nightMuted),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('night-confirm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF26262E),
                    foregroundColor: textColor,
                    disabledBackgroundColor: const Color(0xFF26262E),
                    disabledForegroundColor: textColor,
                  ),
                  // Always looks the same; with no pick it simply does nothing.
                  onPressed: () {
                    if (_picked.length < widget.picks || _sent) return;
                    setState(() => _sent = true);
                    widget.onConfirm(
                      _picked[0],
                      widget.picks == 2 ? _picked[1] : null,
                      _special,
                    );
                  },
                  child: Text(
                    _sent ? Strings.sent : Strings.confirm,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _row({
  required Key key,
  required String name,
  required bool on,
  required Widget face,
  required Color border,
  required Color fill,
  required VoidCallback? onTap,
  String note = '',
  double height = 64,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Semantics(
    inMutuallyExclusiveGroup: true,
    checked: on,
    child: InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? border : Colors.transparent, width: 3),
        ),
        child: Row(
          children: [
            face,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (note.isNotEmpty)
              Text(note, style: const TextStyle(fontSize: 18, color: muted)),
          ],
        ),
      ),
    ),
  ),
);

/// The day vote. `selfId` cannot be picked.
class VoteScreen extends StatefulWidget {
  const VoteScreen({
    super.key,
    required this.day,
    required this.secondsLeft,
    required this.targets,
    required this.selfId,
    required this.onVote,
    required this.onSkip,
    this.canVote = true,
  });

  /// False for a fool the village spared: he may not vote.
  final bool canVote;
  final int day, secondsLeft, selfId;
  final List<WolfTarget> targets;
  final void Function(int target) onVote;
  final VoidCallback onSkip;
  @override
  State<VoteScreen> createState() => _VoteState();
}

class _VoteState extends State<VoteScreen> {
  int? _pick;
  late int _left = widget.secondsLeft;
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) {
    if (_left > 0) setState(() => _left--);
  });

  @override
  void initState() {
    super.initState();
    _tick; // start counting
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A1E2E), bg],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Strings.voteHeader(widget.day),
                        style: const TextStyle(
                          fontSize: 18,
                          color: _amber,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      Strings.minutes(_left),
                      key: const ValueKey('vote-clock'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  Strings.voteTitle,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final t in widget.targets)
                        Opacity(
                          opacity: t.id == widget.selfId ? 0.5 : 1,
                          child: _row(
                            key: ValueKey('vote-${t.id}'),
                            name: t.name,
                            on: _pick == t.id,
                            face: CharacterFace(
                              t.character,
                              48,
                              playerColors[t.colorIndex % playerColors.length],
                            ),
                            border: _amber,
                            fill: _pick == t.id
                                ? _amber.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
                            note: t.id == widget.selfId ? Strings.you : '',
                            onTap: t.id == widget.selfId || !widget.canVote
                                ? null
                                : () => setState(() => _pick = t.id),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const ValueKey('vote-skip'),
                    onPressed: widget.canVote ? widget.onSkip : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: muted,
                      side: const BorderSide(color: raised, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      Strings.skipVote,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('vote-go'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: ink,
                    ),
                    onPressed: _pick == null || !widget.canVote
                        ? null
                        : () => widget.onVote(_pick!),
                    child: const Text(Strings.vote),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The role list: switches for the host (`onToggle` set), read-only otherwise.
class WolfRolesList extends StatelessWidget {
  const WolfRolesList({super.key, required this.enabled, this.onToggle});
  final Set<String> enabled;
  final void Function(String id)? onToggle;

  @override
  Widget build(BuildContext context) {
    final edit = onToggle != null;
    const groups = [
      (Strings.groupWolves, Color(0xFFFF7A8F)),
      (Strings.groupVillage, Color(0xFF7FD8A8)),
      (Strings.groupSolo, _amber),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var g = 0; g < groups.length; g++) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              groups[g].$1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: groups[g].$2,
              ),
            ),
          ),
          for (final r in Strings.wolfRoles.where((r) => r.$4 == g))
            if (edit || r.$5 || enabled.contains(r.$1))
              _roleRow(r, edit, r.$5 || enabled.contains(r.$1)),
        ],
      ],
    );
  }

  Widget _roleRow((String, String, String, int, bool) r, bool edit, bool on) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Opacity(
          opacity: edit && !on ? 0.55 : 1,
          child: Material(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: ValueKey('role-${r.$1}'),
              borderRadius: BorderRadius.circular(14),
              onTap: edit && !r.$5 ? () => onToggle!(r.$1) : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.$2,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              edit && r.$5 ? r.$3 + Strings.rolesLocked : r.$3,
                              style: const TextStyle(
                                fontSize: 18,
                                color: muted,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (edit) ...[
                        const SizedBox(width: 12),
                        Switch(
                          key: ValueKey('switch-${r.$1}'),
                          value: on,
                          onChanged: r.$5 ? null : (_) => onToggle!(r.$1),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Host: switch on the possible roles.
class WolfRolesPickScreen extends StatelessWidget {
  const WolfRolesPickScreen({
    super.key,
    required this.players,
    required this.enabled,
    required this.onToggle,
    required this.onBack,
  });
  final int players;
  final Set<String> enabled;
  final void Function(String id) onToggle;
  final VoidCallback onBack;

  /// 1 werewolf for 5-6 players, 2 for 7-8; special roles fill up to
  /// players - werewolves - 2 from those switched on.
  static (int wolves, int specials, int villagers) mix(
    int players,
    Set<String> enabled,
  ) {
    final wolves = players <= 6 ? 1 : 2;
    final on = Strings.wolfRoles.where(
      (r) =>
          !r.$5 && enabled.contains(r.$1) && r.$1 != 'alpha' && r.$1 != 'lone',
    );
    final slots = on.length.clamp(0, players - wolves - 2);
    return (wolves, slots, players - wolves - slots);
  }

  @override
  Widget build(BuildContext context) {
    final m = mix(players, enabled);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _back(Strings.wolfName, onBack),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                Strings.possibleRoles,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                Strings.rolesPickIntro(players, m.$1, m.$2, m.$3),
                key: const ValueKey('mix'),
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  color: muted,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: WolfRolesList(enabled: enabled, onToggle: onToggle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                key: const ValueKey('roles-save'),
                onPressed: onBack,
                child: const Text(Strings.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _back(String label, VoidCallback onBack) => Align(
  alignment: Alignment.centerLeft,
  child: TextButton(
    key: const ValueKey('wolf-back'),
    onPressed: onBack,
    style: TextButton.styleFrom(minimumSize: const Size(56, 56)),
    child: Text('‹ $label', style: const TextStyle(fontSize: 18)),
  ),
);

/// Everyone: the roles that can be in this game.
class WolfRolesInfoScreen extends StatelessWidget {
  const WolfRolesInfoScreen({
    super.key,
    required this.enabled,
    required this.onBack,
  });
  final Set<String> enabled;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _back(Strings.back, onBack),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              Strings.rolesInThisGame,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: WolfRolesList(enabled: enabled),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Host: Vukodlak's details. Only the switches live here; the TV owns state.
class WolfSettingsView extends StatelessWidget {
  const WolfSettingsView({
    super.key,
    required this.players,
    required this.enabled,
    required this.hidden,
    required this.discussSeconds,
    required this.onHidden,
    required this.onDiscuss,
    required this.onPickRoles,
    required this.onShowRoles,
  });
  final int players, discussSeconds;
  final Set<String> enabled;
  final bool hidden;
  final void Function(bool) onHidden;
  final void Function(int seconds) onDiscuss;
  final VoidCallback onPickRoles, onShowRoles;

  static const minDiscuss = 30, maxDiscuss = 300, stepDiscuss = 30;

  @override
  Widget build(BuildContext context) {
    final names = [
      for (final r in Strings.wolfRoles)
        if (r.$5 || enabled.contains(r.$1)) r.$2,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _link(
          const ValueKey('open-roles-pick'),
          Strings.possibleRolesCount(names.length),
          '${names.join(', ')}. ${Strings.drawnByGame}',
          onPickRoles,
        ),
        const SizedBox(height: 8),
        _link(
          const ValueKey('open-roles-info'),
          Strings.howPlayersSeeIt,
          null,
          onShowRoles,
        ),
        const SizedBox(height: 16),
        const Text(
          Strings.rulesHeader,
          style: TextStyle(fontSize: 18, color: muted),
        ),
        const SizedBox(height: 8),
        Material(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          child: SwitchListTile(
            key: const ValueKey('hidden-roles'),
            value: hidden,
            onChanged: onHidden,
            contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            title: const Text(
              Strings.hiddenRoles,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              Strings.hiddenRolesHint,
              style: TextStyle(fontSize: 18, color: muted),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(Strings.discussion, style: TextStyle(fontSize: 19)),
              ),
              IconButton(
                key: const ValueKey('discuss-less'),
                tooltip: Strings.shorter,
                onPressed: discussSeconds <= minDiscuss
                    ? null
                    : () => onDiscuss(discussSeconds - stepDiscuss),
                icon: const Text('−', style: TextStyle(fontSize: 26)),
                style: IconButton.styleFrom(
                  minimumSize: const Size(56, 56),
                  backgroundColor: raised,
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  Strings.minutes(discussSeconds),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('discuss-more'),
                tooltip: Strings.longer,
                onPressed: discussSeconds >= maxDiscuss
                    ? null
                    : () => onDiscuss(discussSeconds + stepDiscuss),
                icon: const Text('+', style: TextStyle(fontSize: 26)),
                style: IconButton.styleFrom(
                  minimumSize: const Size(56, 56),
                  backgroundColor: raised,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _link(Key key, String title, String? sub, VoidCallback onTap) =>
      Material(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (sub != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            sub,
                            style: const TextStyle(
                              fontSize: 18,
                              color: muted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Text(
                    '›',
                    style: TextStyle(fontSize: 24, color: accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
