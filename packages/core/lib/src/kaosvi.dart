import 'dart:math';

/// Kao svi: match the herd, pure Dart.
///
/// Rule readings (simplest):
///  * 3-8 players, N questions drawn without repeats.
///  * One answer each, trimmed, 1-30 characters (counted as characters), the
///    first accepted one is final.
///  * Answers are grouped by [kaosviFold]: lower case, Croatian diacritics
///    removed, surrounding spaces trimmed, runs of inner spaces collapsed
///    ("Jabuka" = "jabuka " = "JABUKA"; "ne znam" is not "neznam"). A group is
///    shown with the first writer's spelling.
///  * The host may merge two groups (any number of times) before the reveal.
///  * Points: every player in the single largest group gets +1, but only if
///    that group has at least 2 players (one lone answerer is not a herd). A
///    tie for largest scores nobody. If exactly one player is alone with a
///    unique answer while every other ANSWERING player is in a group of 2+, that
///    player loses 1, never below 0 (the reveal shows the change really applied).
///    Players who sent nothing are not counted and score 0.
///  * Nobody answered: no merge phase, straight to the reveal.
///  * The game ends after the question in which a player reached the target, or
///    after the last question. Totals become the game points.
///  * A player who drops out is not waited for; coming back while the question
///    is open puts them in again for it.
String kaosviFold(String s) {
  const map = {'č': 'c', 'ć': 'c', 'š': 's', 'ž': 'z', 'đ': 'd'};
  final sb = StringBuffer();
  var space = false;
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    if (ch.trim().isEmpty) {
      space = sb.isNotEmpty;
      continue;
    }
    if (space) sb.write(' ');
    space = false;
    sb.write(map[ch] ?? ch);
  }
  return sb.toString();
}

class KaosviPack {
  const KaosviPack(this.id, this.title, this.questions);
  final String id;
  final String title;
  final List<String> questions;

  /// {"id","title","questions":["...",...]}: at least 20, none empty, no
  /// duplicates ignoring case and spaces. Throws [FormatException].
  factory KaosviPack.fromJson(Map<String, dynamic> j) {
    final id = j['id'], title = j['title'], raw = j['questions'];
    if (id is! String || title is! String || raw is! List) throw const FormatException('bad pack');
    final qs = <String>[];
    final seen = <String>{};
    for (final e in raw) {
      if (e is! String) throw const FormatException('a question is not text');
      final t = e.trim();
      if (t.isEmpty) throw const FormatException('an empty question');
      if (!seen.add(kaosviFold(t))) throw FormatException('a repeated question: $t');
      qs.add(t);
    }
    if (qs.length < 20) throw const FormatException('fewer than 20 questions');
    return KaosviPack(id, title, qs);
  }
}

enum KaosviPhase { answering, merging, reveal, over }

enum KaosviAnswerResult { ok, empty, tooLong, alreadySent, closed }

class KaosviGroup {
  KaosviGroup(this.id, this.text, this.members);
  final int id;
  String text;
  final List<int> members;
}

/// What the host sees while merging: the answer text and an id to merge by;
/// never who wrote it.
class KaosviMergeItem {
  const KaosviMergeItem(this.id, this.text);
  final int id;
  final String text;
  Map<String, Object?> toJson() => {'id': id, 'text': text};
}

class KaosviReveal {
  const KaosviReveal(this.groups, this.points, this.largestTie, this.lone);

  /// Largest first.
  final List<KaosviGroup> groups;

  /// The change each player really got for this question (the lone penalty is
  /// 0 when the total was already 0).
  final Map<int, int> points;
  final bool largestTie;

  /// The player who was alone with a unique answer, if the lone rule applied.
  final int? lone;

  KaosviGroup? groupOf(int id) {
    for (final g in groups) {
      if (g.members.contains(id)) return g;
    }
    return null;
  }
}

class KaosviGame {
  KaosviGame(List<int> ids, KaosviPack pack, {int questions = 12, this.target = 8, Random? random})
      : ids = List.unmodifiable(ids) {
    if (ids.length < 3 || ids.length > 8) throw ArgumentError('Kao svi is for 3 to 8 players');
    final rnd = random ?? Random();
    _drawn = ([...pack.questions]..shuffle(rnd)).take(min(questions, pack.questions.length)).toList();
    for (final id in ids) {
      totals[id] = 0;
    }
  }

  final List<int> ids;
  final int target;
  late final List<String> _drawn;
  final Map<int, int> totals = {};
  final Map<int, String> _answers = {};
  final Set<int> _away = {};
  final Set<int> _missed = {};
  var _i = 0;
  var _nextGroupId = 0;
  List<KaosviGroup> _groups = [];
  KaosviReveal? lastReveal;
  KaosviPhase phase = KaosviPhase.answering;

  int get total => _drawn.length;
  int get number => _i + 1;
  String get current => _drawn[_i];
  Set<int> get sent => {..._answers.keys};
  Set<int> get away => Set.unmodifiable(_away);

  /// This player's own answer (for a reload); never anyone else's.
  String? answerOf(int id) => _answers[id];

  bool _present(int id) => ids.contains(id) && !_away.contains(id) && !_missed.contains(id);

  void setAway(int id, bool away) {
    if (!ids.contains(id)) return;
    if (away) {
      _away.add(id);
      _missed.add(id);
    } else {
      _away.remove(id);
      _missed.remove(id);
    }
  }

  KaosviAnswerResult answer(int id, String text) {
    if (phase != KaosviPhase.answering || !_present(id)) return KaosviAnswerResult.closed;
    if (_answers.containsKey(id)) return KaosviAnswerResult.alreadySent;
    final t = text.trim();
    if (t.isEmpty) return KaosviAnswerResult.empty;
    if (t.runes.length > 30) return KaosviAnswerResult.tooLong;
    _answers[id] = t;
    return KaosviAnswerResult.ok;
  }

  bool get allSent => ids.where(_present).every(_answers.containsKey);

  /// Answering is over (time, or everyone sent): group the answers.
  void closeAnswering() {
    if (phase != KaosviPhase.answering) return;
    final byKey = <String, KaosviGroup>{};
    for (final e in _answers.entries) {
      byKey.putIfAbsent(kaosviFold(e.value), () => KaosviGroup(_nextGroupId++, e.value, [])).members.add(e.key);
    }
    _groups = byKey.values.toList();
    _sort();
    if (_groups.isEmpty) {
      phase = KaosviPhase.merging;
      finishMerge();
    } else {
      phase = KaosviPhase.merging;
    }
  }

  void _sort() => _groups.sort((a, b) {
        final c = b.members.length.compareTo(a.members.length);
        return c != 0 ? c : a.id.compareTo(b.id);
      });

  List<KaosviGroup> get groups => List.unmodifiable(_groups);

  /// Answers only, for the host's merge screen.
  List<KaosviMergeItem> get mergeView => [for (final g in _groups) KaosviMergeItem(g.id, g.text)];

  /// The host merges two groups; the larger group's text stays.
  bool merge(int a, int b) {
    if (phase != KaosviPhase.merging || a == b) return false;
    final ga = _groups.where((g) => g.id == a).firstOrNull, gb = _groups.where((g) => g.id == b).firstOrNull;
    if (ga == null || gb == null) return false;
    final keep = ga.members.length >= gb.members.length ? ga : gb, drop = identical(keep, ga) ? gb : ga;
    keep.members.addAll(drop.members);
    _groups.remove(drop);
    _sort();
    return true;
  }

  /// The merge phase is over (Gotovo, or the 15 s): reveal and score.
  void finishMerge() {
    if (phase != KaosviPhase.merging) return;
    phase = KaosviPhase.reveal;
    final sizes = _groups.map((g) => g.members.length).toList();
    final points = {for (final id in ids) id: 0};
    final top = sizes.isEmpty ? 0 : sizes.reduce(max);
    final tops = [for (final g in _groups) if (g.members.length == top) g];
    final tie = tops.length > 1;
    if (!tie && tops.length == 1 && top >= 2) {
      for (final m in tops.first.members) {
        points[m] = 1;
      }
    }
    int? lone;
    final singles = [for (final g in _groups) if (g.members.length == 1) g];
    if (singles.length == 1 && _groups.length > 1 && _groups.every((g) => g.members.length >= 2 || identical(g, singles.first))) {
      lone = singles.first.members.first;
    }
    for (final e in points.entries) {
      totals[e.key] = totals[e.key]! + e.value;
    }
    if (lone != null) {
      final applied = totals[lone]! > 0 ? -1 : 0;
      totals[lone] = totals[lone]! + applied;
      points[lone] = points[lone]! + applied;
    }
    lastReveal = KaosviReveal(List.of(_groups), points, tie, lone);
  }

  void next() {
    if (phase == KaosviPhase.over) return;
    if (phase == KaosviPhase.answering) closeAnswering();
    if (phase == KaosviPhase.merging) finishMerge();
    final reached = totals.values.any((v) => v >= target);
    _i++;
    _answers.clear();
    _missed.clear();
    _groups = [];
    lastReveal = null;
    phase = reached || _i >= _drawn.length ? KaosviPhase.over : KaosviPhase.answering;
  }

  Map<int, int> get sessionScores => phase == KaosviPhase.over ? Map.of(totals) : const {};
}
