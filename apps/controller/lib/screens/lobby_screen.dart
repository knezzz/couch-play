import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../character_grid.dart';
import '../connection.dart';
import '../theme.dart';
import '../strings.dart';
import 'game_cards.dart';
import 'blef_screens.dart';
import 'kaosvi_screens.dart';
import 'koliko_screens.dart';
import 'objasni_screens.dart';
import 'pack_grid.dart';
import 'tkobi_screens.dart';
import 'power_up_legend.dart';
import 'uljez_screens.dart';
import 'wolf_screens.dart';

const _seats = 8;

/// The settings with some fields changed, every other field kept. All the
/// game settings live in one object the TV owns, so every change must send
/// the whole of it; a hand-written constructor call drops new fields.
GameSettings copySettings(
  GameSettings s, {
  int? quizSeconds,
  int? quizQuestions,
  int? revealSeconds,
  int? curveCountdown,
  CurveMode? curveMode,
  String? quizPackId,
  bool setQuizPack = false, // quizPackId may be set to null on purpose
  Set<WolfRole>? wolfRoles,
  bool? wolfHideRoles,
  String? uljezPackId,
  int? uljezImpostors,
  int? objasniSeconds,
  int? objasniTarget,
  String? objasniPackId,
  int? kolikoSeconds,
  int? kolikoQuestions,
  String? kolikoPackId,
  int? blefQuestions,
  String? blefPackId,
  int? tkobiPrompts,
  String? tkobiPackId,
  int? kaosviQuestions,
  int? kaosviTarget,
  String? kaosviPackId,
  // Replace one game's switched-off packs (and drop its old single pack id,
  // which the TV would turn into 'only that pack').
  GameKind? offFor,
  Set<String>? off,
}) => GameSettings(
  quizSeconds: quizSeconds ?? s.quizSeconds,
  quizQuestions: quizQuestions ?? s.quizQuestions,
  revealSeconds: revealSeconds ?? s.revealSeconds,
  curveCountdown: curveCountdown ?? s.curveCountdown,
  curveMode: curveMode ?? s.curveMode,
  quizPackId: offFor == GameKind.quiz
      ? null
      : (setQuizPack ? quizPackId : s.quizPackId),
  wolfRoles: wolfRoles ?? s.wolfRoles,
  wolfHideRoles: wolfHideRoles ?? s.wolfHideRoles,
  uljezPackId: offFor == GameKind.uljez ? null : (uljezPackId ?? s.uljezPackId),
  uljezImpostors: uljezImpostors ?? s.uljezImpostors,
  objasniSeconds: objasniSeconds ?? s.objasniSeconds,
  objasniTarget: objasniTarget ?? s.objasniTarget,
  objasniPackId: offFor == GameKind.objasni
      ? null
      : (objasniPackId ?? s.objasniPackId),
  kolikoSeconds: kolikoSeconds ?? s.kolikoSeconds,
  kolikoQuestions: kolikoQuestions ?? s.kolikoQuestions,
  kolikoPackId: offFor == GameKind.koliko
      ? null
      : (kolikoPackId ?? s.kolikoPackId),
  blefQuestions: blefQuestions ?? s.blefQuestions,
  blefPackId: offFor == GameKind.blef ? null : (blefPackId ?? s.blefPackId),
  tkobiPrompts: tkobiPrompts ?? s.tkobiPrompts,
  tkobiPackId: offFor == GameKind.tkobi ? null : (tkobiPackId ?? s.tkobiPackId),
  kaosviQuestions: kaosviQuestions ?? s.kaosviQuestions,
  kaosviTarget: kaosviTarget ?? s.kaosviTarget,
  kaosviPackId: offFor == GameKind.kaosvi
      ? null
      : (kaosviPackId ?? s.kaosviPackId),
  quizOffPacks: offFor == GameKind.quiz ? off! : s.quizOffPacks,
  uljezOffPacks: offFor == GameKind.uljez ? off! : s.uljezOffPacks,
  objasniOffPacks: offFor == GameKind.objasni ? off! : s.objasniOffPacks,
  kolikoOffPacks: offFor == GameKind.koliko ? off! : s.kolikoOffPacks,
  blefOffPacks: offFor == GameKind.blef ? off! : s.blefOffPacks,
  tkobiOffPacks: offFor == GameKind.tkobi ? off! : s.tkobiOffPacks,
  kaosviOffPacks: offFor == GameKind.kaosvi ? off! : s.kaosviOffPacks,
);

class LobbyScreen extends StatefulWidget {
  const LobbyScreen(
    this.conn,
    this.lobby,
    this.myId, {
    this.addPack,
    super.key,
  });
  final Connection conn;
  final LobbyState lobby;
  final int myId;

  /// Picks a pack file and uploads it with the host's token. Returns what the
  /// TV said, or null if nothing was picked. Null here hides the button (tests).
  final Future<String?> Function(String token)? addPack;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  /// The TV decides what is open: a tap only asks, LobbyState.selected answers.
  void _select(GameKind? k) => widget.conn.send(SelectGame(k));

  /// A tap only asks. The TV answers with a LobbyState (changed) or an
  /// ErrorMsg (refused: the banner shows its reason, the old one stays).
  Future<void> _pickCharacter(PlayerInfo me, List<PlayerInfo> players) async {
    final taken = {
      for (final p in players)
        if (p.id != me.id && p.character.isNotEmpty) p.character,
    };
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      barrierColor: const Color(0xCC0A0A10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                Strings.pickCharacter,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              CharacterGrid(
                selected: me.character,
                taken: taken,
                color: playerColors[me.colorIndex % playerColors.length],
                onPick: (id) {
                  Navigator.pop(c);
                  if (id != me.character) widget.conn.send(SetCharacter(id));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmKick(PlayerInfo p) async {
    final color = playerColors[p.colorIndex % playerColors.length];
    final ok = await showModalBottomSheet<bool>(
      isScrollControlled:
          true, // the Croatian text can need more than the default 9/16 height
      context: context,
      backgroundColor: surface,
      barrierColor: const Color(0xCC0A0A10),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      Strings.removeTitle(p.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                Strings.removeBody(p.name),
                style: const TextStyle(fontSize: 18, color: muted, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D6D),
                  foregroundColor: ink,
                ),
                onPressed: () => Navigator.pop(c, true),
                child: const Text(
                  Strings.remove,
                  style: TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: raised,
                  foregroundColor: textColor,
                ),
                onPressed: () => Navigator.pop(c, false),
                child: const Text(Strings.keep, style: TextStyle(fontSize: 22)),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) widget.conn.send(Kick(p.id));
  }

  /// The ids of [packs] that are ticked: every pack not switched off, so a
  /// pack the TV has just got starts ticked.
  Set<String> _ticked(GameKind k, List<PackInfo> packs, GameSettings s) => {
    for (final p in packs)
      if (!s.offPacks(k).contains(p.id)) p.id,
  };

  /// Flips one pack. The TV refuses to switch the last one off; the checklist
  /// does not even send that.
  GameSettings _toggle(GameSettings s, GameKind k, String id) {
    final off = {...s.offPacks(k)};
    if (!off.remove(id)) off.add(id);
    return copySettings(s, offFor: k, off: off);
  }

  GameSettings _wolf(GameSettings s, {Set<WolfRole>? roles, bool? hide}) =>
      copySettings(s, wolfRoles: roles, wolfHideRoles: hide);

  /// Pushes a screen that follows the TV's latest LobbyState.
  void _pushLive(Widget Function(LobbyState l) build) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StreamBuilder<LobbyState>(
          initialData: widget.lobby,
          stream: widget.conn.messages.where((m) => m is LobbyState).cast(),
          builder: (c, snap) => build(snap.data!),
        ),
      ),
    );
  }

  void _showRoles() => _pushLive(
    (l) => WolfRolesInfoScreen(
      players: l.players.length,
      enabled: {for (final r in l.settings.wolfRoles) r.name},
      onBack: () => Navigator.of(context).pop(),
    ),
  );

  void _pickRoles() => _pushLive(
    (l) => WolfRolesPickScreen(
      players: l.players.length,
      enabled: {for (final r in l.settings.wolfRoles) r.name},
      onToggle: (id) {
        final r = WolfRole.values.byName(id);
        final on = {...l.settings.wolfRoles};
        if (!on.remove(r)) on.add(r);
        widget.conn.send(SetSettings(_wolf(l.settings, roles: on)));
      },
      onBack: () => Navigator.of(context).pop(),
    ),
  );

  Widget _kaosviSettings(LobbyState l, void Function(GameSettings) change) {
    final s = l.settings;
    return KaosviSettingsView(
      questions: s.kaosviQuestions,
      target: s.kaosviTarget,
      packs: l.kaosviPacks,
      ticked: _ticked(GameKind.kaosvi, l.kaosviPacks, s),
      onQuestions: (v) => change(copySettings(s, kaosviQuestions: v)),
      onTarget: (v) => change(copySettings(s, kaosviTarget: v)),
      onTogglePack: (id) => change(_toggle(s, GameKind.kaosvi, id)),
    );
  }

  Widget _tkobiSettings(LobbyState l, void Function(GameSettings) change) {
    final s = l.settings;
    return TkobiSettingsView(
      prompts: s.tkobiPrompts,
      packs: l.tkobiPacks,
      ticked: _ticked(GameKind.tkobi, l.tkobiPacks, s),
      onPrompts: (v) => change(copySettings(s, tkobiPrompts: v)),
      onTogglePack: (id) => change(_toggle(s, GameKind.tkobi, id)),
    );
  }

  Widget _blefSettings(LobbyState l, void Function(GameSettings) change) {
    final s = l.settings;
    return BlefSettingsView(
      questions: s.blefQuestions,
      packs: l.blefPacks,
      ticked: _ticked(GameKind.blef, l.blefPacks, s),
      onQuestions: (v) => change(copySettings(s, blefQuestions: v)),
      onTogglePack: (id) => change(_toggle(s, GameKind.blef, id)),
    );
  }

  Widget _kolikoSettings(LobbyState l, void Function(GameSettings) change) {
    final s = l.settings;
    return KolikoSettingsView(
      seconds: s.kolikoSeconds,
      questions: s.kolikoQuestions,
      packs: l.kolikoPacks,
      ticked: _ticked(GameKind.koliko, l.kolikoPacks, s),
      onSeconds: (v) => change(copySettings(s, kolikoSeconds: v)),
      onQuestions: (v) => change(copySettings(s, kolikoQuestions: v)),
      onTogglePack: (id) => change(_toggle(s, GameKind.koliko, id)),
    );
  }

  Widget _objasniSettings(LobbyState l, void Function(GameSettings) change) {
    final s = l.settings;
    return ObjasniSettingsView(
      seconds: s.objasniSeconds,
      target: s.objasniTarget,
      packs: l.objasniPacks,
      ticked: _ticked(GameKind.objasni, l.objasniPacks, s),
      onSeconds: (v) => change(copySettings(s, objasniSeconds: v)),
      onTarget: (v) => change(copySettings(s, objasniTarget: v)),
      onTogglePack: (id) => change(_toggle(s, GameKind.objasni, id)),
    );
  }

  Widget _uljezSettings(LobbyState l, void Function(GameSettings) change) {
    final s = l.settings;
    return UljezSettingsView(
      players: l.players.length,
      packs: l.uljezPacks,
      ticked: _ticked(GameKind.uljez, l.uljezPacks, s),
      impostors: s.uljezImpostors,
      onTogglePack: (id) => change(_toggle(s, GameKind.uljez, id)),
      onImpostors: (n) => change(copySettings(s, uljezImpostors: n)),
    );
  }

  Widget _wolfSettings(LobbyState l, void Function(GameSettings) change) {
    final s = l.settings;
    return WolfSettingsView(
      players: l.players.length,
      enabled: {for (final r in s.wolfRoles) r.name},
      hidden: s.wolfHideRoles,
      onHidden: (v) => change(_wolf(s, hide: v)),
      onPickRoles: _pickRoles,
      onShowRoles: _showRoles,
    );
  }

  /// The ticked packs in a line ("Svi paketi" or "3 paketa"); opens the grid.
  Widget _packRow(LobbyState l) {
    final ticked = _ticked(GameKind.quiz, l.packs, l.settings);
    final questions = l.packs
        .where((p) => ticked.contains(p.id))
        .fold(0, (n, p) => n + p.questionCount);
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const ValueKey('open-packs'),
        borderRadius: BorderRadius.circular(16),
        onTap: _openPacks,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.packs.isEmpty
                      ? Strings.pickPack
                      : Strings.packCount(ticked.length, l.packs.length),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (l.packs.isNotEmpty)
                Text(
                  Strings.questions(questions),
                  style: const TextStyle(fontSize: 18, color: muted),
                ),
              const SizedBox(width: 12),
              const Text('›', style: TextStyle(fontSize: 22, color: accent)),
            ],
          ),
        ),
      ),
    );
  }

  void _openPacks() => _pushLive(
    (l) => PackGridScreen(
      packs: l.packs,
      ticked: _ticked(GameKind.quiz, l.packs, l.settings),
      addPack: widget.addPack == null
          ? null
          : () => widget.addPack!(widget.conn.token),
      onToggle: (id) =>
          widget.conn.send(SetSettings(_toggle(l.settings, GameKind.quiz, id))),
      onBack: () => Navigator.of(context).pop(),
    ),
  );

  Widget _details(GameKind kind, LobbyState l) {
    final s = l.settings;
    void change(GameSettings n) => widget.conn.send(SetSettings(n));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        foregroundColor: accent,
                        textStyle: const TextStyle(fontSize: 20),
                      ),
                      onPressed: () => _select(null),
                      icon: const Icon(Icons.arrow_back, size: 28),
                      label: const Text(Strings.back),
                    ),
                  ),
                  if (kind == GameKind.quiz || kind == GameKind.curve)
                    GameHeaderCard(kind)
                  else
                    Text(
                      Strings.gameName(kind),
                      key: const ValueKey('game-title'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  if (kind == GameKind.vukodlak)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        Strings.playerCount(l.players.length),
                        key: const ValueKey('wolf-players'),
                        style: const TextStyle(fontSize: 18, color: muted),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (kind == GameKind.quiz &&
                      (l.packs.isNotEmpty || widget.addPack != null)) ...[
                    const Text(
                      Strings.quizPack,
                      style: TextStyle(fontSize: 18, color: muted),
                    ),
                    const SizedBox(height: 8),
                    _packRow(l),
                    const SizedBox(height: 12),
                  ],
                  if (kind == GameKind.vukodlak)
                    _wolfSettings(l, change)
                  else if (kind == GameKind.uljez)
                    _uljezSettings(l, change)
                  else if (kind == GameKind.objasni)
                    _objasniSettings(l, change)
                  else if (kind == GameKind.koliko)
                    _kolikoSettings(l, change)
                  else if (kind == GameKind.blef)
                    _blefSettings(l, change)
                  else if (kind == GameKind.tkobi)
                    _tkobiSettings(l, change)
                  else if (kind == GameKind.kaosvi)
                    _kaosviSettings(l, change)
                  else if (kind == GameKind.quiz || kind == GameKind.curve)
                    _GameSettings(kind, s, onChange: change),
                  if (kind == GameKind.curve) ...[
                    const SizedBox(height: 4),
                    const PowerUpLegend(),
                  ],
                  if (kind == GameKind.quiz || kind == GameKind.curve) ...[
                    const SizedBox(height: 14),
                    const Text(
                      Strings.settingsNote,
                      style: TextStyle(fontSize: 18, color: muted, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                height: 72,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () => widget.conn.send(StartGame(kind, null)),
                  child: const Text(Strings.play),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A player in the list: face, name, a tag (host, robot) and, for the
  /// host, Ukloni.
  Widget _playerRow(PlayerInfo p, {required bool isHost, required int hostId}) {
    final color = playerColors[p.colorIndex % playerColors.length];
    final me = p.id == widget.myId;
    final tag = p.bot
        ? Strings.botTag
        : (p.id == hostId && !isHost ? Strings.hostTag : '');
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Opacity(
            opacity: p.connected ? 1 : 0.6,
            child: p.character.isEmpty
                ? Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : CharacterFace(p.character, 40, color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${p.name}${me ? Strings.youSuffix : ''}${p.connected ? '' : Strings.away}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                color: p.connected ? textColor : muted,
              ),
            ),
          ),
          if (tag.isNotEmpty)
            Text(tag, style: const TextStyle(fontSize: 18, color: muted))
          else if (isHost && !p.bot)
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: surface,
                foregroundColor: muted,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () => _confirmKick(p),
              child: const Text(Strings.remove),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lobby;
    final players = l.players;
    final me = players.where((p) => p.id == widget.myId).firstOrNull;
    final isHost = l.hostId == widget.myId;
    final bots = players.where((p) => p.bot).length;
    final host = players.where((p) => p.id == l.hostId).firstOrNull;

    final others = [
      for (final p in players)
        if (p.id != widget.myId) p,
    ];

    final kind = l.selected;
    if (isHost && kind != null) {
      return _details(kind, l);
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            if (me != null) ...[
              _MyChip(
                me,
                host: isHost,
                onChange: isHost ? null : () => _pickCharacter(me, players),
              ),
              if (isHost)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      foregroundColor: accent,
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed: () => _pickCharacter(me, players),
                    child: const Text(Strings.changeCharacter),
                  ),
                ),
            ],
            if (!isHost) ...[
              const SizedBox(height: 16),
              if (l.selected == null)
                Text(
                  Strings.waitingForHost(host?.name),
                  style: const TextStyle(fontSize: 20, color: muted),
                )
              else
                _WatchingCard(
                  host: host?.name,
                  kind: l.selected!,
                  line: Strings.settingsLine(
                    l.selected!,
                    l.settings,
                    l.packs,
                    l.uljezPacks,
                    l.objasniPacks,
                    l.kolikoPacks,
                    l.blefPacks,
                    l.tkobiPacks,
                    l.kaosviPacks,
                  ),
                ),
              if (l.selected == GameKind.vukodlak)
                TextButton(
                  key: const ValueKey('guest-roles'),
                  onPressed: _showRoles,
                  style: TextButton.styleFrom(minimumSize: const Size(56, 56)),
                  child: const Text(
                    Strings.rolesInThisGame,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
            ],
            if (isHost) ...[
              const SizedBox(height: 24),
              const Text(
                Strings.pickGame,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
              const SizedBox(height: 16),
              GameCarousel(lobby: l, onPick: _select),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        Strings.bots,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _Stepper(
                      tooltip: Strings.fewerBots,
                      icon: Icons.remove,
                      onPressed: bots > 0
                          ? () => widget.conn.send(SetBots(bots - 1))
                          : null,
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '$bots',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _Stepper(
                      tooltip: Strings.moreBots,
                      icon: Icons.add,
                      onPressed: players.length < _seats
                          ? () => widget.conn.send(SetBots(bots + 1))
                          : null,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              isHost
                  ? Strings.others(others.length)
                  : Strings.players(players.length),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
            const SizedBox(height: 8),
            for (final p in isHost ? others : players)
              _playerRow(p, isHost: isHost, hostId: l.hostId),
            if (!isHost) ...[
              const SizedBox(height: 24),
              Text(
                Strings.startsWhen(host?.name),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One game's settings, always shown. The host's tap only sends; the next
/// LobbyState changes the number.
class _GameSettings extends StatelessWidget {
  const _GameSettings(this.kind, this.s, {required this.onChange});
  final GameKind kind;
  final GameSettings s;
  final void Function(GameSettings) onChange;

  GameSettings _with({int? sec, int? qs, int? rev, int? cd, CurveMode? mode}) =>
      copySettings(
        s,
        quizSeconds: sec,
        quizQuestions: qs,
        revealSeconds: rev,
        curveCountdown: cd,
        curveMode: mode,
      );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (kind == GameKind.quiz) ...[
        _row(
          Strings.quizSeconds,
          s.quizSeconds,
          10,
          60,
          5,
          (v) => _with(sec: v),
        ),
        _row(
          Strings.quizQuestions,
          s.quizQuestions,
          5,
          30,
          5,
          (v) => _with(qs: v),
          unit: false,
        ),
        _row(
          Strings.revealSeconds,
          s.revealSeconds,
          2,
          15,
          1,
          (v) => _with(rev: v),
        ),
      ] else ...[
        _modes(),
        _row(
          Strings.curveCountdown,
          s.curveCountdown,
          1,
          10,
          1,
          (v) => _with(cd: v),
        ),
      ],
    ],
  );

  /// The four modes as 2 x 2 cards with a line about each.
  Widget _modes() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          Strings.curveModeLabel,
          style: TextStyle(fontSize: 18, color: muted),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (_, c) {
            final w = (c.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final m in CurveMode.values)
                  SizedBox(
                    width: w,
                    child: Material(
                      color: m == s.curveMode ? accent : surface,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: ValueKey('mode-${m.name}'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onChange(_with(mode: m)),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 96),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: m == s.curveMode
                                ? null
                                : Border.all(color: raised, width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Strings.curveMode(m),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: m == s.curveMode ? ink : textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Strings.curveModeBlurb[m]!,
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1.25,
                                  color: m == s.curveMode ? ink : muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );

  /// One setting in its own card: the name, then - value +.
  Widget _row(
    String label,
    int value,
    int min,
    int max,
    int step,
    GameSettings Function(int) make, {
    bool unit = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 18))),
          _Stepper(
            tooltip: Strings.lessOf(label),
            icon: Icons.remove,
            onPressed: value - step >= min
                ? () => onChange(make(value - step))
                : null,
          ),
          SizedBox(
            width: 64,
            child: Text(
              unit ? Strings.seconds(value) : '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          _Stepper(
            tooltip: Strings.moreOf(label),
            icon: Icons.add,
            onPressed: value + step <= max
                ? () => onChange(make(value + step))
                : null,
          ),
        ],
      ),
    ),
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 56,
    child: IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: raised,
        foregroundColor: textColor,
        disabledForegroundColor: muted.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 28),
      onPressed: onPressed,
    ),
  );
}

class _MyChip extends StatelessWidget {
  const _MyChip(this.p, {required this.host, this.onChange});
  final PlayerInfo p;
  final bool host;

  /// "Promijeni lik" inside the chip (guests; the host has it below).
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: playerColors[p.colorIndex % playerColors.length],
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        if (p.character.isNotEmpty) ...[
          KeyedSubtree(
            key: ValueKey('my-character-${p.character}'),
            // A dark disc behind the face: the face is drawn in the player's own
            // color, which would vanish on a chip of that same color.
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: ink,
                shape: BoxShape.circle,
              ),
              child: CharacterFace(
                p.character,
                40,
                playerColors[p.colorIndex % playerColors.length],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
        ),
        // The star alone marks the host: no word, so long names keep their room
        // (the board's "★ Domaćin" pill left room for ~5 letters at 360 px).
        if (host) ...[
          const SizedBox(width: 8),
          const Icon(Icons.star, size: 28, color: ink),
        ],
        if (onChange != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: TextButton(
              key: const ValueKey('change-character'),
              onPressed: onChange,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 56),
                foregroundColor: ink,
                backgroundColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(Strings.changeCharacter),
              ),
            ),
          ),
      ],
    ),
  );
}

/// What the host has open, for the others: "Luka gleda:", the game, its
/// settings.
class _WatchingCard extends StatelessWidget {
  const _WatchingCard({
    required this.host,
    required this.kind,
    required this.line,
  });
  final String? host, line;
  final GameKind kind;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('watching-card'),
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Strings.watchingLabel(host),
          style: const TextStyle(fontSize: 18, color: muted),
        ),
        Text(
          Strings.gameName(kind),
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          line ?? '',
          style: const TextStyle(fontSize: 18, color: muted, height: 1.35),
        ),
      ],
    ),
  );
}
