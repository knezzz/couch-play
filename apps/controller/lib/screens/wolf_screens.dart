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
    this.bottom,
  });
  final String name;
  final int night;

  /// Day buttons (Idemo glasati, Dao sam trag) under the card.
  final Widget? bottom;

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
              if (widget.bottom != null) widget.bottom!,
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
    this.picked,
    this.picked2,
    this.done = false,
    this.showSpecial = true,
    this.more = false,
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

  /// Restored picks after a reload.
  final int? picked, picked2;

  /// The TV already has this phone's confirm (a reload): shown as sent.
  final bool done;
  final bool showSpecial;
  final void Function(int target, bool special) onConfirm;

  /// The first of two picks (the Provodadžija's first lover): Potvrdi sends it
  /// but does not turn the screen into the sent card; the TV's next list does.
  final bool more;
  @override
  State<NightScreen> createState() => _NightState();
}

class _NightState extends State<NightScreen> {
  late int? _p1 = widget.picked;
  late bool _special = widget.special;
  late int _left = widget.seconds ?? 0;
  Timer? _tick;
  final _scroll = ScrollController();
  late bool _sent = widget.done; // the same "done" look for every role

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
    _scroll.dispose();
    super.dispose();
  }

  Widget _list(
    List<NightItem> items,
    int? picked,
    String prefix,
    void Function(int) pick, {
    double rowH = 64,
  }) => Column(
    children: [
      for (final t in items)
        Opacity(
          opacity: t.enabled ? 1 : 0.5,
          child: _row(
            key: ValueKey('$prefix-${t.id}'),
            name: t.label,
            on: picked == t.id,
            height: rowH,
            face: SizedBox(
              key: const ValueKey('face'),
              width: rowH - 20,
              height: rowH - 20,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF9A9AA6),
                ),
              ),
            ),
            border: const Color(0xFFB8B8C2),
            fill: _nightCard,
            note: picked == t.id ? '●' : t.note,
            onTap: _sent || !t.enabled
                ? null
                : () => setState(() => pick(t.id)),
          ),
        ),
    ],
  );

  String _label(List<NightItem> items, int? id) =>
      items.where((t) => t.id == id).firstOrNull?.label ?? '';

  @override
  Widget build(BuildContext context) {
    // Sent: the pick is on screen only while a finger is down, the same card
    // for a sum, a player and a role (night phones stay alike).
    if (_sent && _p1 != null) {
      return RoleHoldScreen(
        key: const ValueKey('night-sent'),
        name: widget.title,
        night: widget.night,
        header: widget.header,
        heading: Strings.yourPickCaps,
        hiddenHint: Strings.sentHint,
        role: [
          _label(widget.targets, _p1),
          if (widget.picked2 != null) _label(widget.targets, widget.picked2),
        ].join('\n'),
        description: Strings.waitTv,
      );
    }
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
              if (widget.hint.isNotEmpty)
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
              // Rows shrink (down to 40) so that up to 8 fit above the strip
              // at 360x640; a sum has one answer per player and the same rows.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final n = widget.targets.length;
                    final rowH = n == 0
                        ? 64.0
                        : (box.maxHeight / n - 8).clamp(40.0, 64.0);
                    return Scrollbar(
                      controller: _scroll,
                      thumbVisibility: true,
                      child: ListView(
                        controller: _scroll,
                        children: [
                          _list(
                            widget.targets,
                            _p1,
                            'night',
                            (id) => _p1 = id,
                            rowH: rowH,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (widget.showSpecial)
                SwitchListTile(
                  key: const ValueKey('night-special'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _special,
                  onChanged: _sent ? null : (v) => setState(() => _special = v),
                  title: const Text(
                    Strings.nightSpecial,
                    style: TextStyle(fontSize: 16, color: _nightMuted),
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
                    if (_p1 == null || _sent) return;
                    if (!widget.more) setState(() => _sent = true);
                    widget.onConfirm(_p1!, _special);
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
  final int day, selfId;
  final List<WolfTarget> targets;
  final void Function(int target) onVote;
  final VoidCallback onSkip;
  @override
  State<VoteScreen> createState() => _VoteState();
}

class _VoteState extends State<VoteScreen> {
  late int? _pick = widget.picked;
  late bool _sent = widget.picked != null; // a reload restores a sent vote
  String? _skipped;

  @override
  Widget build(BuildContext context) {
    final who = widget.targets.where((t) => t.id == _pick).firstOrNull;
    if (_skipped != null || (_sent && who != null)) {
      return RoleHoldScreen(
        key: const ValueKey('vote-sent'),
        name: Strings.voteHeader(widget.day),
        night: 0,
        header: '',
        heading: Strings.yourVoteCaps,
        hiddenHint: Strings.sentHint,
        role: _skipped ?? who!.name,
        description: Strings.waitTv,
      );
    }
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
                    onPressed: widget.canVote
                        ? () {
                            setState(() => _skipped = Strings.skipVote);
                            widget.onSkip();
                          }
                        : null,
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
                        : () {
                            setState(() => _sent = true);
                            widget.onVote(_pick!);
                          },
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

/// "Spreman" under the role card before night 1: final once pressed, with the
/// TV's count. The same for every phone.
class ReadyBar extends StatelessWidget {
  const ReadyBar({
    super.key,
    required this.ready,
    required this.count,
    required this.total,
    required this.onReady,
  });
  final bool ready;
  final int count, total;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      children: [
        SizedBox(
          height: 64,
          width: double.infinity,
          child: ready
              ? const FilledButton(
                  key: ValueKey('play-ready'),
                  onPressed: null,
                  child: Text(
                    Strings.readyDone,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                )
              : FilledButton(
                  key: const ValueKey('play-ready'),
                  onPressed: onReady,
                  child: const Text(
                    Strings.readyButton,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          Strings.readyCount(count, total),
          key: const ValueKey('ready-count'),
          style: const TextStyle(fontSize: 18, color: _nightMuted),
        ),
      ],
    ),
  );
}

/// "Idemo glasati" under the day card: a wish that can be taken back, with the
/// TV's count. The same for every phone; [onWish] sends the wish itself.
class VoteWishBar extends StatelessWidget {
  const VoteWishBar({
    super.key,
    required this.ready,
    required this.want,
    required this.needed,
    required this.onWish,
    this.showWish = true,
    this.onClue,
  });
  final bool ready, showWish;
  final int want, needed;
  final void Function(bool on) onWish;

  /// The speaker's "Dao sam trag" (Uljez only); null on other phones.
  final VoidCallback? onClue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      children: [
        if (onClue != null) ...[
          SizedBox(
            height: 64,
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('clue-done'),
              onPressed: onClue,
              child: const Text(
                Strings.clueDone,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (showWish) const SizedBox(height: 8),
        ],
        if (showWish) ...[
          SizedBox(
            height: 64,
            width: double.infinity,
            child: ready
                ? FilledButton(
                    key: const ValueKey('vote-wish'),
                    onPressed: () => onWish(false),
                    child: const Text(
                      Strings.letsVoteOn,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : OutlinedButton(
                    key: const ValueKey('vote-wish'),
                    onPressed: () => onWish(true),
                    child: const Text(
                      Strings.letsVote,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            Strings.wishCount(want, needed),
            key: const ValueKey('wish-count'),
            style: const TextStyle(fontSize: 18, color: _nightMuted),
          ),
        ],
      ],
    ),
  );
}
