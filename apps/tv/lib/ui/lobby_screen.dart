import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'tv_theme.dart';
import '../strings.dart';

/// Designed on a 1920x1080 canvas (docs/design/couchplay-screens/Main) and
/// scaled to fit, so type stays readable from the couch on any TV.
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({
    required this.joinUrl,
    required this.players,
    required this.hostId,
    required this.onQuit,
    this.settings = const GameSettings(),
    this.selected,
    this.packTitle,
    super.key,
  });

  /// `http://<ip>:<port>/`, or null when the TV has no LAN address.
  final String? joinUrl;
  final List<PlayerInfo> players;
  final int? hostId;

  /// The host's game settings, shown read-only.
  final GameSettings settings;

  /// The game whose details the host has open (null: the carousel). While set,
  /// its card takes the scoreboard's place and the settings line is not shown.
  final GameKind? selected;

  /// Title of the pack Igraj would start (Kviz card only).
  final String? packTitle;

  /// The Quit item: exits the app.
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final byScore = [...players]..sort((a, b) => b.sessionScore.compareTo(a.sessionScore));
    final host = players.where((p) => p.id == hostId).firstOrNull;
    return Scaffold(
      backgroundColor: tvBg,
      body: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 1920,
          height: 1080,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 96, vertical: 56),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 640, child: _Left(joinUrl, onQuit)),
                const SizedBox(width: 96),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (players.isEmpty)
                        const Text(
                          Strings.scanToJoin,
                          style: TextStyle(fontSize: 56, color: tvText),
                        )
                      else ...[
                        Text(
                          Strings.players(players.length),
                          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: tvText),
                        ),
                        const SizedBox(height: 24),
                        // Two fixed-width columns; long names are cut, never scaled down.
                        Wrap(
                          spacing: 20,
                          runSpacing: players.length > 4 ? 8 : 20,
                          children: [
                            for (final p in players)
                              _Chip(p, host: p.id == hostId, tight: players.length > 4),
                          ],
                        ),
                        SizedBox(height: players.length > 4 ? 12 : 32),
                        if (selected == null)
                          _Scoreboard(byScore)
                        else
                          _GameCard(selected!, settings, packTitle, roomy: players.length <= 4),
                        const Spacer(),
                        if (host != null)
                          Text(
                            Strings.waitingForHost(host.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 40, color: tvMuted),
                          ),
                        // One line; a longer text shrinks rather than wraps.
                        if (selected == null)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Strings.settingsLine(settings),
                            maxLines: 1,
                            style: const TextStyle(fontSize: 28, color: tvMuted),
                          ),
                        ),
                      ],
                    ],
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

class _Left extends StatelessWidget {
  const _Left(this.url, this.onQuit);
  final String? url;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _OneLine(
            'CouchPlay',
            TextStyle(fontSize: 72, fontWeight: FontWeight.w900, letterSpacing: -1, color: tvText),
          ),
          const SizedBox(height: 32),
          if (url == null)
            const Text(
              Strings.noWifi,
              style: TextStyle(fontSize: 56, color: tvText),
            )
          else ...[
            // 560 card, 64 px edge: a 4-module quiet zone around a version-3 code.
            Container(
              width: 560,
              height: 560,
              padding: const EdgeInsets.all(64),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: QrImageView(data: url!, padding: EdgeInsets.zero, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 32),
            const _OneLine(Strings.scanCaption, TextStyle(fontSize: 40, color: tvMuted)),
            const SizedBox(height: 8),
            // The QR keeps the full URL; the text drops "http://" and never wraps.
            _OneLine(
              url!.replaceFirst('http://', ''),
              const TextStyle(fontSize: 52, fontWeight: FontWeight.w700, color: tvText),
            ),
          ],
          const Spacer(),
          FocusTraversalGroup(
            // One row; a wider font shrinks it rather than wrapping.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  FilledButton(
                    autofocus: true,
                    onPressed: () => _howToJoin(context),
                    child: const Text(Strings.howToJoin),
                  ),
                  const SizedBox(width: 24),
                  FilledButton(onPressed: onQuit, child: const Text(Strings.quit)),
                ],
              ),
            ),
          ),
        ],
      );

  void _howToJoin(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text(Strings.howToJoin, style: TextStyle(fontSize: 44)),
          content: const Text(
            Strings.howToJoinSteps,
            style: TextStyle(fontSize: 36, height: 1.4),
          ),
          actions: [
            Builder(
              builder: (c) => FilledButton(
                autofocus: true,
                onPressed: () => Navigator.pop(c),
                child: const Text(Strings.gotIt),
              ),
            ),
          ],
        ),
      );
}

/// Text that stays on one line: it shrinks before it would wrap.
class _OneLine extends StatelessWidget {
  const _OneLine(this.text, this.style);
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, style: style),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.p, {required this.host, required this.tight});
  final PlayerInfo p;
  final bool host, tight;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: p.connected ? 1 : 0.6,
        child: Container(
          // Half of the 992 px column, less the gap. A host with a long name
          // takes the whole row (the star marks the host, no word).
          width: host && p.name.length > 8 ? 992 : 486,
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: tight ? 6 : 20),
          decoration: BoxDecoration(
            color: playerColors[p.colorIndex % playerColors.length],
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              if (p.character.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 16, left: 0),
                  child: PlayerDot(playerColors[p.colorIndex % playerColors.length],
                      size: tight ? 48 : 64, ring: true, character: p.character),
                ),
              if (host) const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.star, size: 44, color: tvInk)),
              Expanded(child: _Ink(p.name, ellipsis: true)),
              if (p.bot) const _Badge(Strings.badgeBot),
              if (!p.connected) const _Badge(Strings.badgeAway),
            ],
          ),
        ),
      );
}

class _Ink extends StatelessWidget {
  const _Ink(this.text, {this.ellipsis = false});
  final String text;
  final bool ellipsis;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        overflow: ellipsis ? TextOverflow.ellipsis : null,
        style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: tvInk),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: tvInk, borderRadius: BorderRadius.circular(999)),
          child: Text(
            label,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: tvText),
          ),
        ),
      );
}

/// The host's open game: name, description and its current settings, in the
/// scoreboard's place and no taller than it is with 8 players.
class _GameCard extends StatelessWidget {
  const _GameCard(this.kind, this.settings, this.packTitle, {required this.roomy});
  final GameKind kind;
  final GameSettings settings;
  final String? packTitle;

  /// Few players leave room: a bigger heading and more air. (Larger body text
  /// no longer fits half the card's width.)
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    final quiz = kind == GameKind.quiz;
    final items = quiz
        ? [
            (Strings.settingPack, packTitle ?? '–'),
            (Strings.settingQuestions, '${settings.quizQuestions}'),
            (Strings.settingAnswerTime, '${settings.quizSeconds} s'),
            (Strings.settingReveal, '${settings.revealSeconds} s'),
          ]
        : [
            (Strings.settingMode, Strings.curveModeName(settings.curveMode)),
            (Strings.settingCountdown, '${settings.curveCountdown} s'),
          ];
    Widget item((String, String) it) => Text.rich(
          TextSpan(children: [
            TextSpan(text: '${it.$1}: ', style: const TextStyle(color: tvMuted)),
            TextSpan(text: it.$2, style: const TextStyle(color: tvText, fontWeight: FontWeight.w700)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 32),
        );
    return Container(
      key: const ValueKey('game-card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      decoration: BoxDecoration(
        color: tvSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: tvAccent, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(quiz ? Icons.help_outline : Icons.gesture, size: 48, color: tvAccent),
            const SizedBox(width: 20),
            Text(Strings.gameName(kind),
                style: TextStyle(fontSize: roomy ? 56 : 44, fontWeight: FontWeight.w700, color: tvText)),
          ]),
          const SizedBox(height: 8),
          Text(Strings.gameBlurb(kind),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 32, color: tvMuted)),
          SizedBox(height: roomy ? 24 : 16),
          // Two columns, row by row.
          for (var i = 0; i < items.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: roomy ? 12 : 6),
              child: Row(children: [
                Expanded(child: item(items[i])),
                const SizedBox(width: 32),
                Expanded(child: i + 1 < items.length ? item(items[i + 1]) : const SizedBox()),
              ]),
            ),
        ],
      ),
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard(this.byScore);
  final List<PlayerInfo> byScore; // highest first

  @override
  Widget build(BuildContext context) {
    final scored = byScore.first.sessionScore > 0;
    // Past 5 players a single column no longer fits under the chips.
    final split = byScore.length > 5 ? (byScore.length + 1) ~/ 2 : byScore.length;
    Widget column(int from, int to) => Expanded(
          child: Column(
            children: [
              for (var i = from; i < to; i++) _ScoreRow(i + 1, byScore[i]),
            ],
          ),
        );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 48, vertical: byScore.length > 4 ? 24 : 32),
      decoration: BoxDecoration(color: tvSurface, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            Strings.scoreboard,
            style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: tvText),
          ),
          const SizedBox(height: 16),
          if (!scored)
            const Text(
              Strings.scoreboardEmpty,
              style: TextStyle(fontSize: 32, color: tvMuted),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                column(0, split),
                if (split < byScore.length) ...[
                  const SizedBox(width: 48),
                  column(split, byScore.length),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.rank, this.p);
  final int rank;
  final PlayerInfo p;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: p.connected ? 1 : 0.6,
        child: Padding(
          key: ValueKey('score-${p.name}'),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text('$rank', style: const TextStyle(fontSize: 40, color: tvMuted)),
              ),
              PlayerDot(playerColors[p.colorIndex % playerColors.length], character: p.character),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 40, color: tvText),
                ),
              ),
              Text(
                grouped(p.sessionScore),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: tvText),
              ),
            ],
          ),
        ),
      );
}
