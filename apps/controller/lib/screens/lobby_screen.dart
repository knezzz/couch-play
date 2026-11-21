import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../character_grid.dart';
import '../connection.dart';
import '../theme.dart';
import '../strings.dart';
import 'game_cards.dart';
import 'home_rows.dart';
import 'home_widgets.dart';
import 'kick.dart';
import 'pack_grid.dart';
import 'power_up_legend.dart';
import 'settings_copy.dart';
import 'wolf_screens.dart';

export 'settings_copy.dart';

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

  Future<void> _confirmKick(PlayerInfo p) =>
      confirmKick(context, widget.conn, p);

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
  Future<void> _pushLive(Widget Function(LobbyState l) build) {
    return Navigator.of(context).push(
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

  /// Opens the pack screen of [k] for the host: the TV is told, and told again
  /// when it closes, however it closes.
  void _openPacks(GameKind k) {
    widget.conn.send(const PackScreen(true));
    _pushLive(
      (l) => PackGridScreen(
        packs: packsOf(k, l),
        ticked: _ticked(k, packsOf(k, l), l.settings),
        title: _packsTitle(k),
        addPack: k == GameKind.quiz && widget.addPack != null
            ? () => widget.addPack!(widget.conn.token)
            : null,
        onToggle: (id) =>
            widget.conn.send(SetSettings(_toggle(l.settings, k, id))),
        onBack: () => Navigator.of(context).pop(),
      ),
    ).then((_) => widget.conn.send(const PackScreen(false)));
  }

  String _packsTitle(GameKind k) => k == GameKind.uljez || k == GameKind.objasni
      ? Strings.wordPacks
      : Strings.quizPacks;

  GameKind _step(GameKind k, int by) =>
      supportedGames[(supportedGames.indexOf(k) + by + supportedGames.length) %
          supportedGames.length];

  /// The players below the settings: the host's list has Ukloni.
  Widget _players(LobbyState l, {required bool isHost}) {
    final others = [
      for (final p in l.players)
        if (p.id != widget.myId) p,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isHost
              ? Strings.others(others.length)
              : Strings.players(l.players.length),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
        const SizedBox(height: 8),
        for (final p in isHost ? others : l.players)
          _playerRow(p, isHost: isHost, hostId: l.hostId),
      ],
    );
  }

  Widget _hostHome(LobbyState l, GameKind kind, PlayerInfo? me) {
    final rows = homeRows(kind, l);
    final prev = _step(kind, -1), next = _step(kind, 1);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _HomeHeader(
              me,
              l.players,
              host: true,
              onChange: me == null ? null : () => _pickCharacter(me, l.players),
            ),
            Expanded(
              child: ListView(
                children: [
                  GameBanner(
                    kind: kind,
                    prev: prev,
                    next: next,
                    meta: homeMeta(kind, l),
                    onPrev: () => _select(prev),
                    onNext: () => _select(next),
                  ),
                  HomeDots(selected: kind),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            Strings.settingsForAll,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
                          ),
                        ),
                        HostSettingsList(
                          rows: rows,
                          changed: changedKey(l),
                          onSend: widget.conn.send,
                          onOpen: (what) => what == HomeOpens.packs
                              ? _openPacks(kind)
                              : _pickRoles(),
                        ),
                        if (kind == GameKind.curve) const PowerUpLegend(),
                        const SizedBox(height: 12),
                        _players(l, isHost: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: bg,
                border: Border(top: BorderSide(color: surface)),
              ),
              child: SizedBox(
                height: 64,
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('play'),
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () => widget.conn.send(StartGame(kind, null)),
                  child: Text(Strings.playGame(Strings.gameName(kind))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guestHome(LobbyState l, GameKind kind, PlayerInfo? me, String host) {
    final rows = homeRows(kind, l);
    final c = l.changed;
    final key = changedKey(l);
    final pill =
        Strings.watches(host) +
        switch (l.hostView) {
          HostView.settings => Strings.watchesSettings,
          HostView.packs => Strings.watchesPacks,
          HostView.home => '',
        };
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _HomeHeader(
                  me,
                  l.players,
                  host: false,
                  onChange: me == null
                      ? null
                      : () => _pickCharacter(me, l.players),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      GameBanner(
                        kind: kind,
                        prev: _step(kind, -1),
                        next: _step(kind, 1),
                        meta: homeMeta(kind, l),
                        pill: pill,
                        compact: true,
                      ),
                      HomeDots(selected: kind),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                Strings.settingsTitle,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: muted,
                                ),
                              ),
                            ),
                            GuestSettingsList(
                              rows: rows,
                              changed: key,
                              old: key == null || c == null
                                  ? null
                                  : changeValue(c, c.old, l),
                            ),
                            if (kind == GameKind.vukodlak)
                              TextButton(
                                key: const ValueKey('guest-roles'),
                                onPressed: _showRoles,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(56, 56),
                                ),
                                child: const Text(
                                  Strings.rolesInThisGame,
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: ChangeFeed(lobby: l, host: host),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        child: _players(l, isHost: false),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: surface)),
                  ),
                  child: Text(
                    Strings.startedBy(host),
                    key: const ValueKey('started-by'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: muted),
                  ),
                ),
              ],
            ),
            if (l.hostView == HostView.packs)
              Positioned.fill(
                top: 60,
                child: ColoredBox(
                  color: bg,
                  child: PackGridScreen(
                    packs: packsOf(kind, l),
                    ticked: _ticked(kind, packsOf(kind, l), l.settings),
                    title: _packsTitle(kind),
                    pill: Strings.picksPacks(host),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lobby;
    final me = l.players.where((p) => p.id == widget.myId).firstOrNull;
    final host = l.players.where((p) => p.id == l.hostId).firstOrNull;
    final kind = l.selected ?? GameKind.quiz;
    return l.hostId == widget.myId
        ? _hostHome(l, kind, me)
        : _guestHome(l, kind, me, host?.name ?? 'Domaćin');
  }
}

/// The top bar: my face and name (a star when I host), "Promijeni lik", and one
/// dot per player.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader(
    this.me,
    this.players, {
    required this.host,
    required this.onChange,
  });
  final PlayerInfo? me;
  final List<PlayerInfo> players;
  final bool host;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final p = me;
    final color = p == null
        ? muted
        : playerColors[p.colorIndex % playerColors.length];
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (p != null && p.character.isNotEmpty)
              KeyedSubtree(
                key: ValueKey('my-character-${p.character}'),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
                  child: CharacterFace(p.character, 34, color),
                ),
              )
            else
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      p?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (host) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.star, size: 18, color: Color(0xFFFFB020)),
                  ],
                  if (onChange != null) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: TextButton(
                        key: const ValueKey('change-character'),
                        onPressed: onChange,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: surface,
                          foregroundColor: accent,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
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
                ],
              ),
            ),
            // Overlapping dots, 12 px apart: eight players take 100 px.
            SizedBox(
              width: 6.0 + 12 * players.length,
              height: 22,
              child: Stack(
                children: [
                  for (var i = 0; i < players.length; i++)
                    Positioned(
                      left: i * 12.0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              playerColors[players[i].colorIndex %
                                  playerColors.length],
                          border: Border.all(color: bg, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
