import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

import '../sound/sfx.dart';

enum KaosviStageTv { answer, merge, reveal, over }

/// One game of Kao svi on the TV: the question, the answers (hidden), the
/// host's merge, the reveal as group stacks.
///
/// PRIVACY. No answer reaches the TV or another phone before the reveal: while
/// answering the TV knows only WHO has sent ([sent]). During the merge ONLY the
/// host's phone gets the grouped answers (texts and ids, never who wrote them);
/// every other phone gets the same message type with an empty list. The writers
/// become visible only in [reveal].
class KaosviMatch {
  KaosviMatch({
    required this.ids,
    required this.pack,
    required this.settings,
    required this.hostId,
    required this.send,
    required this.clock,
    required this.random,
    this.sfx = const SilentSfx(),
    this.notify,
    this.onOver,
  });

  final List<int> ids;
  final KaosviPack pack;
  final GameSettings settings;

  /// The host right now: the only phone that sees the groups and may merge.
  final int? Function() hostId;
  final void Function(int id, Message m) send;
  final Duration Function() clock;
  final Random random;
  Sfx sfx;
  final void Function()? notify;
  final void Function(Map<int, int> scores)? onOver;

  static const answerTime = Duration(seconds: 30);
  static const mergeTime = Duration(seconds: 15);
  static const revealTime = Duration(seconds: 8);

  /// The rules. Holds every answer: not for the TV to show from.
  @visibleForTesting
  late KaosviGame game;
  KaosviStageTv stage = KaosviStageTv.answer;
  Timer? _tick, _timer;
  var _left = 0;
  Duration _stageEnd = Duration.zero;

  int get number => game.number;
  int get total => game.total;
  String get q => game.current;
  int get secondsLeft => _left;
  int get target => settings.kaosviTarget;
  Set<int> get sent => game.sent;
  Map<int, int> get totals => Map.of(game.totals);

  /// Only after the reveal: the groups (largest first, with writers), the
  /// points really applied, the tie flag and the lone player.
  KaosviReveal? get reveal => stage == KaosviStageTv.reveal ? game.lastReveal : null;

  Duration get remaining {
    final r = _stageEnd - clock();
    return r.isNegative ? Duration.zero : r;
  }

  void start() {
    game = KaosviGame(ids, pack, questions: settings.kaosviQuestions, target: settings.kaosviTarget, random: random);
    _ask();
  }

  void dispose() {
    _tick?.cancel();
    _timer?.cancel();
  }

  // ---- answering ----

  KaosviAsk _askMsg(int id) => KaosviAsk(
      number: game.number, total: game.total, seconds: _left, q: game.current, sent: game.answerOf(id));

  void _ask() {
    stage = KaosviStageTv.answer;
    _left = answerTime.inSeconds;
    sfx.play(Sound.quizStart);
    for (final id in ids) {
      send(id, _askMsg(id));
    }
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      _left--;
      if (_left > 0) sfx.play(_left <= 5 ? Sound.tick : Sound.quizTick);
      if (_left <= 0) {
        _endAnswering();
      } else {
        notify?.call();
      }
    });
    notify?.call();
  }

  void onAnswer(int id, KaosviAnswer m) {
    if (stage != KaosviStageTv.answer) return;
    switch (game.answer(id, m.text)) {
      case KaosviAnswerResult.ok:
        send(id, _askMsg(id)); // the ack: sent is now set
        notify?.call();
        if (game.allSent) _endAnswering();
      case KaosviAnswerResult.empty:
        send(id, const ErrorMsg(KaosviText.empty));
      case KaosviAnswerResult.tooLong:
        send(id, const ErrorMsg(KaosviText.tooLong));
      case KaosviAnswerResult.alreadySent:
      case KaosviAnswerResult.closed:
        break;
    }
  }

  void _endAnswering() {
    if (stage != KaosviStageTv.answer) return;
    _tick?.cancel();
    game.closeAnswering();
    if (game.phase == KaosviPhase.reveal) return _toReveal(); // nobody answered
    stage = KaosviStageTv.merge;
    _mergeHost = hostId();
    _stageEnd = clock() + mergeTime;
    _timer?.cancel();
    _timer = Timer(mergeTime, _endMerge);
    for (final id in ids) {
      send(id, _mergingMsg(id));
    }
    notify?.call();
  }

  // ---- the host's merge ----

  int? _mergeHost;

  /// The host may change in the middle of the merge (a phone dropped): the new
  /// host gets the list, the old one an empty one. Call it whenever the host may
  /// have changed.
  void refreshHost() {
    if (stage != KaosviStageTv.merge) return;
    final h = hostId();
    if (h == _mergeHost) return;
    final old = _mergeHost;
    _mergeHost = h;
    if (old != null && ids.contains(old)) send(old, _mergingMsg(old));
    if (h != null && ids.contains(h)) send(h, _mergingMsg(h));
  }

  KaosviMerging _mergingMsg(int id) {
    final host = id == hostId();
    return KaosviMerging(seconds: remaining.inSeconds, groups: host ? game.mergeView : const [], host: host);
  }

  void onMerge(int id, KaosviMerge m) {
    if (stage != KaosviStageTv.merge || id != hostId()) return;
    if (!game.merge(m.a, m.b)) return;
    sfx.play(Sound.menuMove);
    send(id, _mergingMsg(id));
    notify?.call();
  }

  void onDone(int id) {
    if (stage != KaosviStageTv.merge || id != hostId()) return;
    _endMerge();
  }

  void _endMerge() {
    if (stage != KaosviStageTv.merge) return;
    game.finishMerge();
    _toReveal();
  }

  // ---- the reveal ----

  void _toReveal() {
    stage = KaosviStageTv.reveal;
    sfx.play(Sound.right);
    final r = game.lastReveal!;
    for (final id in ids) {
      send(id, _resultMsg(id, r));
    }
    _stageEnd = clock() + revealTime;
    _timer?.cancel();
    _timer = Timer(revealTime, _next);
    notify?.call();
  }

  KaosviResult _resultMsg(int id, KaosviReveal r) {
    final g = r.groupOf(id);
    final largest = g != null && !r.largestTie && r.groups.isNotEmpty && identical(g, r.groups.first) && g.members.length >= 2;
    return KaosviResult(
      answer: game.answerOf(id), // the player's OWN spelling
      size: g?.members.length ?? 0,
      points: r.points[id] ?? 0,
      total: game.totals[id]!,
      largest: largest,
      lone: r.lone == id,
    );
  }

  void _next() {
    game.next();
    if (game.phase == KaosviPhase.over) return _finish();
    _ask();
  }

  void _finish() {
    _tick?.cancel();
    _timer?.cancel();
    stage = KaosviStageTv.over;
    sfx.play(Sound.fanfare);
    notify?.call();
    onOver?.call(game.sessionScores);
  }

  // ---- dropping out, reload ----

  void setAway(int id, bool away) {
    if (!ids.contains(id) || stage == KaosviStageTv.over) return;
    game.setAway(id, away);
    if (stage == KaosviStageTv.answer && game.allSent && game.sent.isNotEmpty) _endAnswering();
    notify?.call();
  }

  void rejoin(int id) {
    if (!ids.contains(id) || stage == KaosviStageTv.over) return;
    switch (stage) {
      case KaosviStageTv.answer:
        send(id, _askMsg(id));
      case KaosviStageTv.merge:
        send(id, _mergingMsg(id));
      case KaosviStageTv.reveal:
        send(id, _resultMsg(id, game.lastReveal!));
      case KaosviStageTv.over:
        break;
    }
  }
}

/// Croatian lines Kao svi sends to a phone.
class KaosviText {
  static const empty = 'Upiši svoj odgovor.';
  static const tooLong = 'Najviše 30 znakova.';
}
