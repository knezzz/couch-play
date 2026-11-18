import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../session/wolf_match.dart';
import '../../session/wolf_text.dart';
import '../../strings.dart';
import '../../vukodlak/wolf_story.dart';
import 'end_screen.dart';
import 'village_screen.dart';
import 'vote_screen.dart';

/// Vukodlak on the TV: turns the running [WolfMatch] into the village, the vote
/// or the end screen.
///
/// PRIVACY: this reads only what the match makes public: `stage`, `alive` /
/// `isAlive`, `lit`, `story`, `publicRole`, `votedCount`, `lastOut`, `wishCount`, `present`,
/// `night`, `day`. It never touches `WolfMatch.game` (which holds every role) and
/// never asks for a role except through `publicRole`, which is null for someone
/// out while roles are hidden and everything once the game is over.
class WolfView extends StatefulWidget {
  const WolfView({required this.match, required this.players, super.key});
  final WolfMatch match;
  final List<PlayerInfo> players;

  @override
  State<WolfView> createState() => _WolfViewState();
}

class _WolfViewState extends State<WolfView> {
  static const _resultKeys = {
    'voteOut',
    'voteOutRole',
    'voteTie',
    'voteNobody',
    'foolSpared',
    'trampWins',
  };
  static const _holdFor = Duration(seconds: 7);

  final _random = Random();
  final _lines = <int, String>{};
  Timer? _hold;
  var _seen = 0;
  int? _resultAt; // the story index of the vote's result, while it is held on the vote screen
  var _voted = 0,
      _expected =
          0; // the last count seen while the vote ran, for the held result

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  String _name(int id) =>
      widget.players.where((p) => p.id == id).firstOrNull?.name ?? '';

  String _line(int i) =>
      _lines[i] ??= wolfStoryLine(widget.match.story[i], _name, _random);

  /// The vote's result stays on the vote screen for a few seconds, even though
  /// the match has already moved on (a night starts at once after a tie).
  void _watchStory() {
    final story = widget.match.story;
    for (var i = _seen; i < story.length; i++) {
      if (_resultKeys.contains(story[i].key)) {
        _resultAt = i;
        _hold?.cancel();
        _hold = Timer(_holdFor, () {
          if (mounted) setState(() => _resultAt = null);
        });
      }
    }
    _seen = story.length;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    _watchStory();
    final people = <VillagePlayer>[
      for (final id in m.ids)
        VillagePlayer(
          id: id,
          name: _name(id),
          colorIndex:
              widget.players.where((p) => p.id == id).firstOrNull?.colorIndex ??
              0,
          character:
              widget.players.where((p) => p.id == id).firstOrNull?.character ??
              '',
          out: !m.isAlive(id),
          lit: m.lit.contains(id),
        ),
    ];

    if (m.stage == WolfStage.over) {
      final i = m.story.lastIndexWhere((e) => e.key == 'gameOver');
      return WolfEndScreen(
        players: people,
        roles: {
          for (final id in m.ids)
            if (m.publicRole(id) != null) id: m.publicRole(id)!,
        },
        headline: i >= 0 ? _line(i) : '',
      );
    }

    if (m.stage == WolfStage.vote) {
      _voted = m.votedCount;
      _expected = m.alive.length;
    }
    final held = _resultAt;
    if (m.stage == WolfStage.vote || held != null) {
      final story = m.story;
      final wolves = held == null
          ? -1
          : story.indexWhere((e) => e.key == 'wolvesLeft', held);
      final out = held == null ? null : m.lastOut;
      final role = out == null ? null : m.publicRole(out);
      return WolfVoteScreen(
        // Only the players still in the game; the one just voted out stays for the result.
        players: [
          for (final p in people)
            if (!p.out || p.id == out) p,
        ],
        day: m.day,
        voted: _voted,
        expected: held == null ? m.alive.length : _expected,
        outId: out,
        // The first part never names the role: that is the banner's second part, and only when it may be shown.
        result: held == null
            ? null
            : wolfStoryLine(m.story[held], _name, _random, showRole: false),
        role: role == null ? null : WolfText.roleNames[role],
        extra: wolves >= 0 ? _line(wolves) : null,
      );
    }

    final night = m.stage == WolfStage.night || m.stage == WolfStage.dawn;
    final beat = currentBeat(m.story);
    final first = m.story.length - beat.length;
    var story = [for (var i = 0; i < beat.length; i++) _line(first + i)]
        .where((s) => s.isNotEmpty)
        .join(' ');
    // At night the lit windows are the players still deciding: say how many.
    if (m.stage == WolfStage.night && m.lit.isNotEmpty) {
      story = '$story ${Strings.wolfLightsLeft(m.lit.length)}';
    }
    final morning = beat.any((e) => e.key.startsWith('morning'));
    return VillageScreen(
      players: people,
      night: night,
      kicker: night
          ? Strings.wolfNight(m.night)
          : (morning ? Strings.wolfMorning(m.day) : Strings.wolfDay(m.day)),
      story: story,
      // By day: how many want to vote (a count, never who). Night and dawn have no clock.
      clock: m.wishOpen ? '${Strings.wishLabel} ${Strings.wishCount(m.wishCount, m.present.length)}' : '',
    );
  }
}
