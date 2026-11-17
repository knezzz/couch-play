import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

import '../sound/sfx.dart';

enum TkobiStageTv { ask, reveal, over }

/// One game of Tko bi? on the TV: a prompt, one tap on a player, a bar chart.
///
/// PRIVACY. Nobody ever learns who voted for whom: the TV gets only HOW MANY
/// have voted ([votedCount], not who) and, at the reveal, the vote COUNT per
/// player. A phone gets the same public counts plus whether its OWN vote
/// went to a crowned player.
class TkobiMatch {
  TkobiMatch({
    required this.ids,
    required this.pack,
    required this.settings,
    required this.send,
    required this.clock,
    required this.random,
    this.sfx = const SilentSfx(),
    this.notify,
    this.onOver,
  });

  final List<int> ids;
  final TkobiPack pack;
  final GameSettings settings;
  final void Function(int id, Message m) send;
  final Duration Function() clock;
  final Random random;
  Sfx sfx;
  final void Function()? notify;
  final void Function(Map<int, int> scores)? onOver;

  static const voteTime = Duration(seconds: 15);
  static const revealTime = Duration(seconds: 7);

  /// The rules. Holds every vote: not for the TV to show from.
  @visibleForTesting
  late TkobiGame game;
  TkobiStageTv stage = TkobiStageTv.ask;
  Timer? _tick, _timer;
  var _left = 0;
  Duration _stageEnd = Duration.zero;

  int get number => game.number;
  int get total => game.total;
  String get text => game.current;
  int get secondsLeft => _left;
  int get votedCount => game.votedCount;
  Map<int, int> get totals => Map.of(game.totals);

  /// Only at the reveal: votes per player and the crowned ones.
  TkobiReveal? get reveal => stage == TkobiStageTv.reveal ? game.lastReveal : null;

  Duration get remaining {
    final r = _stageEnd - clock();
    return r.isNegative ? Duration.zero : r;
  }

  void start() {
    game = TkobiGame(ids, pack, prompts: settings.tkobiPrompts, random: random);
    _ask();
  }

  void dispose() {
    _tick?.cancel();
    _timer?.cancel();
  }

  TkobiAsk _askMsg(int id) => TkobiAsk(
      number: game.number, total: game.total, seconds: _left, text: game.current, ids: ids, picked: game.pickOf(id));

  void _ask() {
    stage = TkobiStageTv.ask;
    _left = voteTime.inSeconds;
    sfx.play(Sound.quizStart);
    for (final id in ids) {
      send(id, _askMsg(id));
    }
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      _left--;
      if (_left > 0) sfx.play(_left <= 5 ? Sound.tick : Sound.quizTick);
      if (_left <= 0) {
        _reveal();
      } else {
        notify?.call();
      }
    });
    notify?.call();
  }

  /// A tap on a player (the existing [Vote]); a skip (null) is nothing.
  void onVote(int id, Vote m) {
    final t = m.target;
    if (stage != TkobiStageTv.ask || t == null) return;
    if (!game.vote(id, t)) return;
    notify?.call();
    if (game.allVoted) _reveal();
  }

  void _reveal() {
    if (stage != TkobiStageTv.ask) return;
    _tick?.cancel();
    final r = game.reveal();
    stage = TkobiStageTv.reveal;
    sfx.play(Sound.roundWin);
    for (final id in ids) {
      send(id, _resultMsg(id, r));
      if (r.crowned.contains(id)) send(id, const Effect('confetti'));
    }
    _stageEnd = clock() + revealTime;
    _timer?.cancel();
    _timer = Timer(revealTime, _next);
    notify?.call();
  }

  TkobiResult _resultMsg(int id, TkobiReveal r) => TkobiResult(
      counts: r.counts, crowned: r.crowned, votedRight: (r.points[id] ?? 0) > 0, points: r.points[id] ?? 0, total: game.totals[id]!);

  void _next() {
    game.next();
    if (game.over) return _finish();
    _ask();
  }

  void _finish() {
    _tick?.cancel();
    _timer?.cancel();
    stage = TkobiStageTv.over;
    sfx.play(Sound.fanfare);
    notify?.call();
    onOver?.call(game.sessionScores);
  }

  void setAway(int id, bool away) {
    if (!ids.contains(id) || stage == TkobiStageTv.over) return;
    game.setAway(id, away);
    if (stage == TkobiStageTv.ask && game.allVoted && game.votedCount > 0) _reveal();
    notify?.call();
  }

  void rejoin(int id) {
    if (!ids.contains(id) || stage == TkobiStageTv.over) return;
    if (stage == TkobiStageTv.ask) {
      send(id, _askMsg(id));
    } else {
      send(id, _resultMsg(id, game.lastReveal!));
    }
  }
}
