import 'dart:math';

import 'quiz_pack.dart';
import 'scoring.dart';

enum QuizStep { asking, revealing, done }

/// A question as shown: choices already shuffled, [correctIndex] into them.
class ShownQuestion {
  const ShownQuestion(this.q, this.image, this.choices, this.correctIndex);
  final String q;
  final String? image;
  final List<String> choices;
  final int correctIndex;
}

/// Pure quiz state. The caller owns the clock and passes `now`, the time since
/// the round started; it must never go backwards. The round records each
/// phase's start itself (the first question starts at 0), so a caller can't
/// feed it a stale per-phase time.
///
/// [lastPoints] is partial while asking (only players who have answered):
/// broadcast it at the reveal, not before.
class QuizRound {
  QuizRound(
    QuizPack pack,
    List<int> playerIds, {
    Random? random,
    int length = 10,
    this.limit = const Duration(seconds: 20),
    this.reveal = const Duration(seconds: 4),
  }) : _active = playerIds.toSet() {
    final rnd = random ?? Random();
    final picked = ([...pack.questions]..shuffle(rnd)).take(min(length, pack.questions.length));
    for (final q in picked) {
      final order = [0, 1, 2, 3]..shuffle(rnd);
      _questions.add(ShownQuestion(
          q.q, q.image, [for (final i in order) q.choices[i]], order.indexOf(q.answer)));
    }
    for (final id in playerIds) {
      _totals[id] = 0;
    }
  }

  final Duration limit, reveal;
  final _questions = <ShownQuestion>[];
  final Set<int> _active;
  final _answered = <int>{};
  final _totals = <int, int>{};
  final _last = <int, int>{};
  var _phaseStart = Duration.zero;
  var _index = 0;
  var _step = QuizStep.asking;

  QuizStep get step => _step;
  int get number => _index + 1;
  int get total => _questions.length;
  ShownQuestion get current => _questions[min(_index, total - 1)];
  Map<int, int> get totals => Map.unmodifiable(_totals);
  Map<int, int> get lastPoints => Map.unmodifiable(_last);

  /// The first answer counts. Unknown players, a gone player, an index outside
  /// 0-3 and answers outside the asking step are ignored.
  void answer(int playerId, int index, Duration now) {
    if (_step != QuizStep.asking ||
        index < 0 ||
        index > 3 ||
        !_active.contains(playerId) ||
        !_answered.add(playerId)) {
      return;
    }
    final elapsed = now - _phaseStart;
    final pts = quizPoints(
        correct: index == current.correctIndex,
        elapsed: elapsed.isNegative ? Duration.zero : elapsed,
        limit: limit);
    _last[playerId] = pts;
    _totals[playerId] = _totals[playerId]! + pts;
  }

  /// A player who left keeps their points and scores nothing from now on.
  void removePlayer(int id) => _active.remove(id);

  /// A player who came back answers again from the current question on, with
  /// their total intact; questions they missed scored 0.
  void addPlayer(int id) {
    _active.add(id);
    _totals.putIfAbsent(id, () => 0);
  }

  void advance(Duration now) {
    final elapsed = now - _phaseStart;
    switch (_step) {
      case QuizStep.asking:
        if (elapsed >= limit || _active.every(_answered.contains)) {
          for (final id in _totals.keys) {
            _last.putIfAbsent(id, () => 0);
          }
          _step = QuizStep.revealing;
          _phaseStart = now;
        }
      case QuizStep.revealing:
        if (elapsed < reveal) return;
        if (_index + 1 >= total) {
          _step = QuizStep.done;
        } else {
          _index++;
          _answered.clear();
          _last.clear();
          _step = QuizStep.asking;
          _phaseStart = now;
        }
      case QuizStep.done:
        break;
    }
  }
}
