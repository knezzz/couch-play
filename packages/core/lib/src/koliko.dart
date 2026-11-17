import 'dart:math';

/// Koliko?: guess the number, pure Dart.
///
/// Rule readings (simplest):
///  * 2-8 players. The first number a player sends counts; no changing it.
///  * Numbers are finite and not negative. A question has an answer >= 0.
///  * Ranked by distance from the answer: closest 1000, then 750, 500, 250,
///    everyone else 0. Equal distances share the better rank and its points;
///    the next rank skips (1, 1, 3). An exact hit adds 500. No answer: 0 and
///    no rank.
///  * A player who drops out is not waited for while away and keeps their points;
///    coming back while the question is still open puts them in again for it.
///  * The game's points are the totals; they go through placementPoints.
class KolikoQuestion {
  const KolikoQuestion(this.q, this.answer, this.unit, this.image, this.source);
  final String q;
  final double answer;
  final String unit;

  /// A file name inside the pack, like quiz pictures (the TV does not load
  /// them yet); null for most questions.
  final String? image;
  final String source;
}

class KolikoPack {
  const KolikoPack(this.id, this.title, this.questions);
  final String id;
  final String title;
  final List<KolikoQuestion> questions;

  /// {"id","title","questions":[{"q","answer","unit","image"?,"source"}]}: at
  /// least 15 questions, each with a text, a finite answer >= 0, a unit (may be
  /// empty), an optional image name and a source. Throws [FormatException].
  factory KolikoPack.fromJson(Map<String, dynamic> j) {
    final id = j['id'], title = j['title'], raw = j['questions'];
    if (id is! String || title is! String || raw is! List) throw const FormatException('bad pack');
    final qs = <KolikoQuestion>[];
    for (final e in raw) {
      if (e is! Map) throw const FormatException('bad question');
      final q = e['q'], a = e['answer'], unit = e['unit'], image = e['image'], source = e['source'];
      if (q is! String || q.trim().isEmpty) throw const FormatException('a question has no text');
      if (a is! num || !a.isFinite || a < 0) throw FormatException('bad answer for: $q');
      if (unit is! String) throw FormatException('bad unit for: $q');
      if (image != null && image is! String) throw FormatException('bad image for: $q');
      if (source is! String || source.trim().isEmpty) throw FormatException('no source for: $q');
      qs.add(KolikoQuestion(q.trim(), a.toDouble(), unit, image as String?, source));
    }
    if (qs.length < 15) throw const FormatException('fewer than 15 questions');
    return KolikoPack(id, title, qs);
  }
}

/// One player's result for a question. [value] null = no answer.
class KolikoEntry {
  const KolikoEntry(this.id, this.value, this.distance, this.rank, this.points, this.exact);
  final int id;
  final double? value;
  final double? distance;
  final int? rank;
  final int points;
  final bool exact;
}

class KolikoReveal {
  const KolikoReveal(this.answer, this.entries);
  final double answer;

  /// Closest first, then those with no answer.
  final List<KolikoEntry> entries;
}

class KolikoGame {
  KolikoGame(List<int> ids, KolikoPack pack, {int questions = 10, Random? random})
      : ids = List.unmodifiable(ids) {
    if (ids.length < 2 || ids.length > 8) throw ArgumentError('Koliko? is for 2 to 8 players');
    final rnd = random ?? Random();
    _drawn = ([...pack.questions]..shuffle(rnd)).take(min(questions, pack.questions.length)).toList();
    for (final id in ids) {
      totals[id] = 0;
    }
  }

  final List<int> ids;
  late final List<KolikoQuestion> _drawn;
  final Map<int, int> totals = {};
  final Map<int, double> _answers = {};
  final Set<int> _away = {};
  final Set<int> _missed = {}; // away at some point during this question
  var _i = 0;
  var _revealed = false;
  KolikoReveal? lastReveal;

  int get total => _drawn.length;
  int get number => _i + 1;
  bool get over => _i >= _drawn.length;
  bool get revealed => _revealed;
  KolikoQuestion get current => _drawn[_i];
  Set<int> get answered => {..._answers.keys};
  double? valueOf(int id) => _answers[id];
  Set<int> get away => Set.unmodifiable(_away);

  bool _present(int id) => !_away.contains(id) && !_missed.contains(id);

  /// A player drops out or comes back: they miss the rest of this question.
  void setAway(int id, bool away) {
    if (!ids.contains(id)) return;
    if (away) {
      _away.add(id);
      _missed.add(id);
    } else {
      // Back while the step is still open: in again for it (not just from the next).
      _away.remove(id);
      _missed.remove(id);
    }
  }

  /// A number from [id]; false if it does not count (not asking, unknown or
  /// absent player, already answered, negative or not finite).
  bool answer(int id, double value) {
    if (over || _revealed || !ids.contains(id) || !_present(id) || _answers.containsKey(id)) return false;
    if (!value.isFinite || value < 0) return false;
    _answers[id] = value;
    return true;
  }

  /// Everyone who is present has answered.
  bool get allAnswered => ids.where(_present).every(_answers.containsKey);

  static const _rankPoints = [1000, 750, 500, 250];

  KolikoReveal reveal() {
    if (_revealed) return lastReveal!;
    _revealed = true;
    final t = current.answer;
    final ranked = _answers.entries.toList()
      ..sort((a, b) {
        final c = (a.value - t).abs().compareTo((b.value - t).abs());
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    final entries = <KolikoEntry>[];
    var rank = 1;
    for (var i = 0; i < ranked.length; i++) {
      final d = (ranked[i].value - t).abs();
      if (i > 0 && d != (ranked[i - 1].value - t).abs()) rank = i + 1;
      final exact = d == 0;
      final pts = (rank <= _rankPoints.length ? _rankPoints[rank - 1] : 0) + (exact ? 500 : 0);
      totals[ranked[i].key] = totals[ranked[i].key]! + pts;
      entries.add(KolikoEntry(ranked[i].key, ranked[i].value, d, rank, pts, exact));
    }
    for (final id in ids) {
      if (!_answers.containsKey(id)) entries.add(KolikoEntry(id, null, null, null, 0, false));
    }
    return lastReveal = KolikoReveal(t, entries);
  }

  /// To the next question (reveals first if that was skipped).
  void next() {
    if (over) return;
    if (!_revealed) reveal();
    _i++;
    _answers.clear();
    _missed.clear();
    _revealed = false;
    lastReveal = null;
  }

  /// The game's points per player; empty until the game is over.
  Map<int, int> get sessionScores => over ? Map.of(totals) : const {};
}
