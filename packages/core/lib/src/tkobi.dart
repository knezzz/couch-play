import 'dart:math';

/// Tko bi? (who in the room), pure Dart.
///
/// Rule readings (simplest):
///  * 3-8 players, N prompts drawn without repeats.
///  * One vote each, final, for anyone including yourself.
///  * The most voted is crowned; a tie crowns everyone tied; no votes crown nobody.
///  * You score 1 if your vote went to a crowned player; being crowned scores
///    nothing by itself.
///  * The reveal holds counts only. Who voted for whom is never exposed (the
///    game keeps the votes private to compute the points).
///  * A player who drops out misses that prompt (0) and votes again from the next.
class TkobiPack {
  const TkobiPack(this.id, this.title, this.prompts);
  final String id;
  final String title;
  final List<String> prompts;

  /// {"id","title","prompts":[...]}: at least 30, none empty, no duplicates
  /// ignoring case. Throws [FormatException].
  factory TkobiPack.fromJson(Map<String, dynamic> j) {
    final id = j['id'], title = j['title'], raw = j['prompts'];
    if (id is! String || title is! String || raw is! List) throw const FormatException('bad pack');
    final prompts = <String>[];
    final seen = <String>{};
    for (final e in raw) {
      if (e is! String) throw const FormatException('a prompt is not text');
      final t = e.trim();
      if (t.isEmpty) throw const FormatException('an empty prompt');
      if (!seen.add(t.toLowerCase())) throw FormatException('a repeated prompt: $t');
      prompts.add(t);
    }
    if (prompts.length < 30) throw const FormatException('fewer than 30 prompts');
    return TkobiPack(id, title, prompts);
  }
}

class TkobiReveal {
  const TkobiReveal(this.counts, this.crowned, this.points);

  /// Votes each player got (every player is a key).
  final Map<int, int> counts;
  final List<int> crowned;

  /// Points per player for this prompt.
  final Map<int, int> points;
}

class TkobiGame {
  TkobiGame(List<int> ids, TkobiPack pack, {int prompts = 10, Random? random}) : ids = List.unmodifiable(ids) {
    if (ids.length < 3 || ids.length > 8) throw ArgumentError('Tko bi? is for 3 to 8 players');
    final rnd = random ?? Random();
    _drawn = ([...pack.prompts]..shuffle(rnd)).take(min(prompts, pack.prompts.length)).toList();
    for (final id in ids) {
      totals[id] = 0;
    }
  }

  final List<int> ids;
  late final List<String> _drawn;
  final Map<int, int> totals = {};
  final Map<int, int> _votes = {}; // private: voter -> target
  final Set<int> _away = {};
  final Set<int> _missed = {};
  var _i = 0;
  var _revealed = false;
  TkobiReveal? lastReveal;

  int get total => _drawn.length;
  int get number => _i + 1;
  bool get over => _i >= _drawn.length;
  bool get revealed => _revealed;
  String get current => _drawn[_i];
  Set<int> get voted => {..._votes.keys};

  /// This player's own vote (for a reload); never anyone else's.
  int? pickOf(int id) => _votes[id];
  int get votedCount => _votes.length;
  Set<int> get away => Set.unmodifiable(_away);

  bool _present(int id) => ids.contains(id) && !_away.contains(id) && !_missed.contains(id);

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

  bool vote(int voter, int target) {
    if (over || _revealed || !_present(voter) || !ids.contains(target) || _votes.containsKey(voter)) return false;
    _votes[voter] = target;
    return true;
  }

  bool get allVoted => ids.where(_present).every(_votes.containsKey);

  TkobiReveal reveal() {
    if (_revealed) return lastReveal!;
    _revealed = true;
    final counts = {for (final id in ids) id: 0};
    for (final t in _votes.values) {
      counts[t] = counts[t]! + 1;
    }
    final top = counts.values.fold(0, max);
    final crowned = top == 0 ? <int>[] : [for (final e in counts.entries) if (e.value == top) e.key];
    final points = {for (final id in ids) id: crowned.contains(_votes[id]) ? 1 : 0};
    points.forEach((id, p) => totals[id] = totals[id]! + p);
    return lastReveal = TkobiReveal(counts, crowned, points);
  }

  void next() {
    if (over) return;
    if (!_revealed) reveal();
    _i++;
    _votes.clear();
    _missed.clear();
    _revealed = false;
    lastReveal = null;
  }

  Map<int, int> get sessionScores => over ? Map.of(totals) : const {};
}
