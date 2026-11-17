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
  const NightItem(this.id, this.label, {this.enabled = true, this.note = ''});
  final int id;
  final String label;

  /// False greys the row out and ignores taps (your own name in a vote).
  final bool enabled;
  final String note;
}

/// The role card: hidden until a finger is down.
class RoleHoldScreen extends StatefulWidget {
  const RoleHoldScreen({
    super.key,
    required this.name,
    required this.night,
    this.header,
    this.heading = Strings.yourRole,
    this.hiddenHint = Strings.holdHint,
    required this.role,
    required this.description,
    this.extra = '',
    this.onRoles,
  });
  final String name;
  final int night;

  /// Replaces "NOĆ n" (Uljez shows its round); [heading] and [hiddenHint] are
  /// the small label over the shown text and the hint on the hidden card.
  final String? header;
  final String heading, hiddenHint;
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
                    widget.header ?? Strings.night(widget.night),
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

  Widget _hidden() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.touch_app_outlined, size: 96, color: Color(0xFF5A5A66)),
      const SizedBox(height: 16),
      const Text(
        Strings.holdHere,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      Text(
        widget.hiddenHint,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, color: _nightMuted, height: 1.4),
      ),
    ],
  );

  Widget _shown() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        widget.heading,
        style: const TextStyle(
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
    this.header,
    this.seconds,
    this.title = Strings.nightTitle,
    this.confirmLabel = Strings.confirm,
    required this.hint,
    required this.targets,
    required this.onConfirm,
    this.special = false,
    this.targets2 = const [],
    this.picked,
    this.picked2,
    this.showSpecial = true,
  });
  final int night;

  /// Replaces "NOĆ n", the title and the button text (Uljez's vote and guess
  /// use this same screen).
  final String? header;

  /// A clock after the header (Uljez's vote and guess), counting down.
  final int? seconds;
  final String title, confirmLabel;
  final String hint;
  final List<NightItem> targets;

  /// The switch every phone carries; the TV gives the restored value.
  final bool special;

  /// Night 1: a second list, a second pick on every phone; both go out
  /// together.
  final List<NightItem> targets2;

  /// Restored picks after a reload.
  final int? picked, picked2;
  final bool showSpecial;
  final void Function(int target, int? second, bool special) onConfirm;
  @override
  State<NightScreen> createState() => _NightState();
}

class _NightState extends State<NightScreen> {
  late int? _p1 = widget.picked, _p2 = widget.picked2;
  late bool _special = widget.special;
  late int _left = widget.seconds ?? 0;
  Timer? _tick;
  bool _sent = false; // the same "done" look for every role

  @override
  void initState() {
    super.initState();
    if (widget.seconds != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_left > 0) setState(() => _left--);
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Widget _list(
    List<NightItem> items,
    int? picked,
    String prefix,
    void Function(int) pick,
  ) => Column(
    children: [
      for (final t in items)
        Opacity(
          opacity: t.enabled ? 1 : 0.5,
          child: _row(
            key: ValueKey('$prefix-${t.id}'),
            name: t.label,
            on: picked == t.id,
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
            note: t.note,
            onTap: _sent || !t.enabled
                ? null
                : () => setState(() => pick(t.id)),
          ),
        ),
    ],
  );

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
                (widget.header ?? Strings.night(widget.night)) +
                    (widget.seconds == null
                        ? ''
                        : ' · ${Strings.minutes(_left)}'),
                key: const ValueKey('night-header'),
                style: const TextStyle(
                  fontSize: 18,
                  color: _nightMuted,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.title,
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
                    _list(widget.targets, _p1, 'night', (id) => _p1 = id),
                    if (widget.targets2.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _list(widget.targets2, _p2, 'night2', (id) => _p2 = id),
                    ],
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
                    final two = widget.targets2.isNotEmpty;
                    if (_p1 == null || (two && _p2 == null) || _sent) return;
                    setState(() => _sent = true);
                    widget.onConfirm(_p1!, two ? _p2 : null, _special);
                  },
                  child: Text(
                    _sent ? Strings.sent : widget.confirmLabel,
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
    this.picked,
  });

  /// False for a fool the village spared: he may not vote.
  final bool canVote;

  /// The vote the TV already has from this phone (after a reload).
  final int? picked;
  final int day, secondsLeft, selfId;
  final List<WolfTarget> targets;
  final void Function(int target) onVote;
  final VoidCallback onSkip;
  @override
  State<VoteScreen> createState() => _VoteState();
}

class _VoteState extends State<VoteScreen> {
  late int? _pick = widget.picked;
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
    final slots = (players - wolves - 2) <= 0
        ? 0
        : on.length.clamp(0, players - wolves - 2);
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
            _intro(
              key: const ValueKey('mix'),
              lead: Strings.rolesPickIntroLead,
              bold: Strings.rolesPickMix(players, m.$1, m.$2, m.$3),
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
/// The grey box above a roles list: a sentence, optionally one in bold.
Widget _intro({Key? key, String? lead, required String bold}) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
  child: Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 18,
          height: 1.4,
          color: Color(0xFFC9C9D8),
        ),
        children: [
          if (lead != null) TextSpan(text: '$lead\n'),
          TextSpan(
            text: bold,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    ),
  ),
);

class WolfRolesInfoScreen extends StatelessWidget {
  const WolfRolesInfoScreen({
    super.key,
    required this.enabled,
    required this.onBack,
    this.players,
  });
  final Set<String> enabled;

  /// The number of players, for the intro; no intro without it.
  final int? players;
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
          if (players != null)
            Builder(
              builder: (_) {
                final m = WolfRolesPickScreen.mix(players!, enabled);
                return _intro(
                  key: const ValueKey('roles-intro'),
                  bold: Strings.rolesInfoIntro(m.$1, m.$2),
                );
              },
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

/// "Razgovor danju" with - and + (30 s steps, 0:30 to 5:00), shared by the
/// games that have a discussion.
class DiscussRow extends StatelessWidget {
  const DiscussRow({super.key, required this.seconds, required this.onChange});
  final int seconds;
  final void Function(int seconds) onChange;

  static const min = 30, max = 300, step = 30;

  @override
  Widget build(BuildContext context) => Container(
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
        _btn('discuss-less', Strings.shorter, '−', seconds <= min, -step),
        SizedBox(
          width: 64,
          child: Text(
            Strings.minutes(seconds),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        _btn('discuss-more', Strings.longer, '+', seconds >= max, step),
      ],
    ),
  );

  Widget _btn(String key, String tip, String sign, bool off, int d) =>
      IconButton(
        key: ValueKey(key),
        tooltip: tip,
        onPressed: off ? null : () => onChange(seconds + d),
        icon: Text(sign, style: const TextStyle(fontSize: 26)),
        style: IconButton.styleFrom(
          minimumSize: const Size(56, 56),
          backgroundColor: raised,
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
        DiscussRow(seconds: discussSeconds, onChange: onDiscuss),
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
