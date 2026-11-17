import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

import '../sound/sfx.dart';

enum KolikoStageTv { ask, reveal, over }

/// One game of Koliko? on the TV: asks the questions, collects the numbers,
/// reveals them together and keeps the points.
///
/// PRIVACY. During a question the TV (and any phone) learns only WHO has
/// answered, never what they typed. At the reveal everybody's number becomes
/// public (it is drawn on the number line). A phone only ever receives its own
/// number back.
class KolikoMatch {
  KolikoMatch({
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
  final KolikoPack pack;
  final GameSettings settings;
  final void Function(int id, Message m) send;
  final Duration Function() clock;
  final Random random;
  Sfx sfx;
  final void Function()? notify;
  final void Function(Map<int, int> scores)? onOver;

  static const revealTime = Duration(seconds: 8);

  /// The rules. Holds the answer: the TV shows it only through [reveal].
  @visibleForTesting
  late KolikoGame game;
  KolikoStageTv stage = KolikoStageTv.ask;
  Timer? _tick, _timer;
  var _left = 0;
  Duration _stageEnd = Duration.zero;

  int get number => game.number;
  int get total => game.total;
  String get q => game.current.q;
  String get unit => game.current.unit;
  int get secondsLeft => _left;
  int get seconds => settings.kolikoSeconds;
  Set<int> get answered => game.answered;
  Map<int, int> get totals => Map.of(game.totals);

  /// Only after the reveal (null while asking): every number and the answer.
  KolikoReveal? get reveal => stage == KolikoStageTv.reveal ? game.lastReveal : null;

  Duration get remaining {
    final r = _stageEnd - clock();
    return r.isNegative ? Duration.zero : r;
  }

  void start() {
    game = KolikoGame(ids, pack, questions: settings.kolikoQuestions, random: random);
    _ask();
  }

  void dispose() {
    _tick?.cancel();
    _timer?.cancel();
  }

  KolikoAsk _askMsg(int id) => KolikoAsk(
      number: game.number, total: game.total, seconds: _left, q: game.current.q, unit: game.current.unit, sent: game.valueOf(id));

  void _ask() {
    stage = KolikoStageTv.ask;
    _left = settings.kolikoSeconds;
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

  void onNumber(int id, NumberAnswer m) {
    if (stage != KolikoStageTv.ask) return;
    if (!game.answer(id, m.value)) return;
    notify?.call();
    if (game.allAnswered) _reveal();
  }

  void _reveal() {
    if (stage != KolikoStageTv.ask) return;
    _tick?.cancel();
    final r = game.reveal();
    stage = KolikoStageTv.reveal;
    sfx.play(Sound.right);
    final byId = {for (final e in r.entries) e.id: e};
    for (final id in ids) {
      final e = byId[id]!;
      send(id, KolikoResult(answer: r.answer, value: e.value, rank: e.rank, points: e.points, total: game.totals[id]!));
    }
    _stageEnd = clock() + revealTime;
    _timer?.cancel();
    _timer = Timer(revealTime, _next);
    notify?.call();
  }

  void _next() {
    game.next();
    if (game.over) return _finish();
    _ask();
  }

  void _finish() {
    _tick?.cancel();
    _timer?.cancel();
    stage = KolikoStageTv.over;
    sfx.play(Sound.fanfare);
    notify?.call();
    onOver?.call(game.sessionScores);
  }

  void setAway(int id, bool away) {
    if (!ids.contains(id) || stage == KolikoStageTv.over) return;
    game.setAway(id, away);
    if (stage == KolikoStageTv.ask && game.allAnswered && game.answered.isNotEmpty) _reveal();
    notify?.call();
  }

  /// A reload: the open question with the phone's own number, or its own result.
  void rejoin(int id) {
    if (!ids.contains(id) || stage == KolikoStageTv.over) return;
    if (stage == KolikoStageTv.ask) {
      send(id, _askMsg(id));
    } else {
      final e = game.lastReveal!.entries.firstWhere((e) => e.id == id);
      send(id, KolikoResult(answer: game.lastReveal!.answer, value: e.value, rank: e.rank, points: e.points, total: game.totals[id]!));
    }
  }
}
