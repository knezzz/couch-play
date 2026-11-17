import 'dart:math';

/// Blef: bluff trivia, pure Dart.
///
/// Rule readings (simplest):
///  * 3-8 players, N questions drawn without repeats.
///  * A fake is trimmed, 1-40 characters, accepted ONCE (the first accepted
///    one stays). A fake equal to the true answer ignoring case, spaces and
///    Croatian diacritics is refused ([FakeResult.truth]) and must be replaced.
///  * Identical fakes (same folding) merge into one entry with all their
///    writers. The list is every fake plus the true answer, shuffled.
///  * A player's own list leaves out their own entry (also a merged one).
///    A player who sent no fake sees every entry.
///  * One pick per player, final. Points: finding the true answer +1000; for
///    every player a fake fooled, EACH writer of that fake gets +500.
///  * If nobody wrote a fake, there is nothing to pick from: straight to the reveal.
///  * Reveal order: the fakes, then the true answer last.
///  * A player who drops out misses the rest of that question (no fake, no
///    pick, 0 points, not waited for) and plays again from the next question.
String blefFold(String s) {
  const map = {'č': 'c', 'ć': 'c', 'š': 's', 'ž': 'z', 'đ': 'd'};
  final sb = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    if (ch.trim().isEmpty) continue; // spaces of any kind
    sb.write(map[ch] ?? ch);
  }
  return sb.toString();
}

class BlefQuestion {
  const BlefQuestion(this.q, this.answer, this.source);
  final String q;
  final String answer;
  final String source;
}

class BlefPack {
  const BlefPack(this.id, this.title, this.questions);
  final String id;
  final String title;
  final List<BlefQuestion> questions;

  /// {"id","title","questions":[{"q","answer","source"}]}: at least 10
  /// questions; each text, answer (1-40 characters) and source non-empty.
  /// Throws [FormatException].
  factory BlefPack.fromJson(Map<String, dynamic> j) {
    final id = j['id'], title = j['title'], raw = j['questions'];
    if (id is! String || title is! String || raw is! List) throw const FormatException('bad pack');
    final qs = <BlefQuestion>[];
    for (final e in raw) {
      if (e is! Map) throw const FormatException('bad question');
      final q = e['q'], a = e['answer'], source = e['source'];
      if (q is! String || q.trim().isEmpty) throw const FormatException('a question has no text');
      if (a is! String || a.trim().isEmpty || a.trim().length > 40) throw FormatException('bad answer for: $q');
      if (source is! String || source.trim().isEmpty) throw FormatException('no source for: $q');
      qs.add(BlefQuestion(q.trim(), a.trim(), source));
    }
    if (qs.length < 10) throw const FormatException('fewer than 10 questions');
    return BlefPack(id, title, qs);
  }
}

enum BlefPhase { writing, picking, reveal, over }

enum FakeResult { ok, empty, tooLong, truth, alreadySent, closed }

class BlefEntry {
  BlefEntry(this.text, this.isTruth);
  final String text;
  final bool isTruth;
  final List<int> writers = [];
  final List<int> pickers = [];
}

class BlefReveal {
  const BlefReveal(this.order, this.points);

  /// Indexes into [BlefGame.entries]: the fakes first, the true answer last.
  final List<int> order;

  /// Points per player for this question.
  final Map<int, int> points;
}

class BlefGame {
  BlefGame(List<int> ids, BlefPack pack, {int questions = 7, Random? random})
      : ids = List.unmodifiable(ids),
        _random = random ?? Random() {
    if (ids.length < 3 || ids.length > 8) throw ArgumentError('Blef is for 3 to 8 players');
    _drawn = ([...pack.questions]..shuffle(_random)).take(min(questions, pack.questions.length)).toList();
    for (final id in ids) {
      totals[id] = 0;
    }
  }

  final List<int> ids;
  final Random _random;
  late final List<BlefQuestion> _drawn;
  final Map<int, int> totals = {};
  final Map<int, String> _fakes = {};
  final Set<int> _away = {};
  final Set<int> _missed = {};
  final Map<int, int> _picks = {};
  var _i = 0;
  List<BlefEntry> entries = [];
  BlefReveal? lastReveal;

  BlefPhase phase = BlefPhase.writing;

  int get total => _drawn.length;
  int get number => _i + 1;
  BlefQuestion get current => _drawn[_i];
  Set<int> get sent => {..._fakes.keys};
  Set<int> get away => Set.unmodifiable(_away);

  bool _present(int id) => ids.contains(id) && !_away.contains(id) && !_missed.contains(id);

  void setAway(int id, bool away) {
    if (!ids.contains(id)) return;
    if (away) {
      _away.add(id);
      _missed.add(id);
    } else {
      _away.remove(id);
    }
  }

  // ---- writing ----

  FakeResult submitFake(int id, String text) {
    if (phase != BlefPhase.writing || !_present(id)) return FakeResult.closed;
    if (_fakes.containsKey(id)) return FakeResult.alreadySent;
    final t = text.trim();
    if (t.isEmpty) return FakeResult.empty;
    if (t.length > 40) return FakeResult.tooLong;
    if (blefFold(t) == blefFold(current.answer)) return FakeResult.truth;
    _fakes[id] = t;
    return FakeResult.ok;
  }

  bool get allSent => ids.where(_present).every(_fakes.containsKey);

  /// Writing is over (time, or everyone sent): build the list.
  void closeWriting() {
    if (phase != BlefPhase.writing) return;
    final byKey = <String, BlefEntry>{};
    for (final e in _fakes.entries) {
      final entry = byKey.putIfAbsent(blefFold(e.value), () => BlefEntry(e.value, false));
      entry.writers.add(e.key);
    }
    entries = [...byKey.values, BlefEntry(current.answer, true)]..shuffle(_random);
    phase = byKey.isEmpty ? BlefPhase.reveal : BlefPhase.picking;
    if (phase == BlefPhase.reveal) _score();
  }

  // ---- picking ----

  /// The entry indexes this player may pick: everything but their own fake.
  List<int> optionsFor(int id) =>
      [for (var i = 0; i < entries.length; i++) if (!entries[i].writers.contains(id)) i];

  bool pick(int id, int index) {
    if (phase != BlefPhase.picking || !_present(id) || _picks.containsKey(id)) return false;
    if (index < 0 || index >= entries.length || entries[index].writers.contains(id)) return false;
    _picks[id] = index;
    entries[index].pickers.add(id);
    return true;
  }

  Set<int> get picked => {..._picks.keys};

  /// This player's own entry index pick, or null.
  int? pickOf(int id) => _picks[id];

  /// This player's own accepted fake (null if none).
  String? sentTextOf(int id) => _fakes[id];
  bool get allPicked => ids.where(_present).every(_picks.containsKey);

  // ---- reveal ----

  BlefReveal reveal() {
    if (phase == BlefPhase.picking) {
      phase = BlefPhase.reveal;
      _score();
    }
    return lastReveal!;
  }

  void _score() {
    final pts = {for (final id in ids) id: 0};
    for (final e in entries) {
      if (e.isTruth) {
        for (final p in e.pickers) {
          pts[p] = pts[p]! + 1000;
        }
      } else {
        for (final w in e.writers) {
          pts[w] = pts[w]! + 500 * e.pickers.length;
        }
      }
    }
    pts.forEach((id, v) => totals[id] = totals[id]! + v);
    final order = [
      for (var i = 0; i < entries.length; i++)
        if (!entries[i].isTruth) i,
      entries.indexWhere((e) => e.isTruth),
    ];
    lastReveal = BlefReveal(order, pts);
  }

  void next() {
    if (phase == BlefPhase.over) return;
    if (phase == BlefPhase.writing) closeWriting();
    if (phase == BlefPhase.picking) reveal();
    _i++;
    _fakes.clear();
    _picks.clear();
    _missed.clear();
    entries = [];
    lastReveal = null;
    phase = _i >= _drawn.length ? BlefPhase.over : BlefPhase.writing;
  }

  Map<int, int> get sessionScores => phase == BlefPhase.over ? Map.of(totals) : const {};
}
