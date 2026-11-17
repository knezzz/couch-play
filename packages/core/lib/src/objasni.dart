import 'dart:math';

/// Objasni: explain the word to your team, two teams, pure Dart.
///
/// Rule readings (simplest):
///  * 4-8 players, two random teams as near equal as possible; which team gets
///    the extra player is random. Team 0 always goes first.
///  * Turns alternate between the teams; inside a team the explainer rotates
///    through the members, skipping anyone who is away.
///  * Točno +1, Preskoči -1, Prekršaj (a player of the OTHER team) -1; each ends
///    the word and the next one comes up. A team's score may go below 0.
///  * Time up: the word on screen is lost for no points and is not listed.
///  * An explainer who drops during a turn does not end it: the clock runs on,
///    and if they come back they resume with the current word.
///  * A word does not come up twice in a game; if a very long game uses the
///    whole pack, the words start over (reshuffled).
///  * The game ends after a FULL round (both teams had the same number of
///    turns) when a team has the target and the scores differ; level scores
///    play another round. [abandon] ends it at once: the higher score wins,
///    a tie wins nothing.
///  * Session points: 1 for each player of the winning team, 0 for the others.
class ObjasniPack {
  const ObjasniPack(this.id, this.title, this.words);
  final String id;
  final String title;
  final List<String> words;

  /// The content format {"id","title","words":[...]}: at least 100 words, none
  /// empty, no duplicates (ignoring case and surrounding spaces). Throws
  /// [FormatException] otherwise.
  factory ObjasniPack.fromJson(Map<String, dynamic> j) {
    final id = j['id'], title = j['title'], raw = j['words'];
    if (id is! String || title is! String || raw is! List) throw const FormatException('bad pack');
    final words = <String>[];
    final seen = <String>{};
    for (final w in raw) {
      if (w is! String) throw const FormatException('a word is not text');
      final t = w.trim();
      if (t.isEmpty) throw const FormatException('an empty word');
      if (!seen.add(t.toLowerCase())) throw FormatException('a repeated word: $t');
      words.add(t);
    }
    if (words.length < 100) throw const FormatException('fewer than 100 words');
    return ObjasniPack(id, title, words);
  }
}

enum ObjasniPhase { setup, ready, turn, summary, over }

enum ObjasniMark { correct, skip, foul }

class ObjasniMarked {
  const ObjasniMarked(this.word, this.mark);
  final String word;
  final ObjasniMark mark;
}

class ObjasniGame {
  ObjasniGame(List<int> ids, ObjasniPack pack,
      {this.turnSeconds = 60, this.target = 30, Random? random})
      : ids = List.unmodifiable(ids),
        _pack = pack,
        _random = random ?? Random() {
    if (ids.length < 4 || ids.length > 8) throw ArgumentError('Objasni is for 4 to 8 players');
    reshuffle();
  }

  final List<int> ids;
  final ObjasniPack _pack;
  final Random _random;
  final int turnSeconds, target;

  final List<List<int>> _teams = [[], []];
  final Set<int> _away = {};
  final List<int> _rot = [0, 0];
  final List<int> _score = [0, 0];
  var _deck = <String>[];
  var _deckAt = 0;
  var _turnNo = 0;

  ObjasniPhase phase = ObjasniPhase.setup;
  int? explainer;
  String? word;

  /// Counts the words shown in the game; a press names the word it is about.
  int wordNo = 0;
  int? winnerTeam;
  final List<ObjasniMarked> turnWords = [];

  List<int> teamMembers(int t) => List.unmodifiable(_teams[t]);
  int teamOf(int id) => _teams[0].contains(id) ? 0 : 1;
  int score(int team) => _score[team];
  int get turnTeam => _turnNo % 2;
  Set<int> get away => Set.unmodifiable(_away);

  /// "Promiješaj": draw the teams again. Only before the game begins.
  void reshuffle() {
    if (phase != ObjasniPhase.setup) return;
    final shuffled = [...ids]..shuffle(_random);
    final n = ids.length;
    final k = n.isOdd && _random.nextBool() ? n ~/ 2 : (n + 1) ~/ 2;
    _teams[0]
      ..clear()
      ..addAll(shuffled.take(k));
    _teams[1]
      ..clear()
      ..addAll(shuffled.skip(k));
  }

  void begin() {
    if (phase != ObjasniPhase.setup) return;
    _deck = [..._pack.words]..shuffle(_random);
    _deckAt = 0;
    phase = ObjasniPhase.ready;
    _pickExplainer();
  }

  /// The next connected member of the team on turn, from its rotation point.
  void _pickExplainer() {
    final t = turnTeam, m = _teams[t];
    explainer = null;
    for (var i = 0; i < m.length; i++) {
      final idx = (_rot[t] + i) % m.length;
      if (!_away.contains(m[idx])) {
        explainer = m[idx];
        _rot[t] = idx; // advanced past it when the turn ends
        return;
      }
    }
  }

  /// A team has nobody connected: the session pauses (and may end the game).
  bool get teamNeedsPause => phase != ObjasniPhase.over && [0, 1].any((t) => _teams[t].every(_away.contains));

  /// A player drops out or comes back. An explainer who leaves in the middle of
  /// a turn does NOT end it (a locked iPhone drops its socket): the clock runs
  /// on, and they resume with the current word if they come back; one who
  /// leaves before "Kreni" is replaced.
  void setAway(int id, bool away) {
    if (!ids.contains(id)) return;
    if (away) {
      _away.add(id);
      if (phase == ObjasniPhase.ready && id == explainer) {
        _pickExplainer();
      }
    } else {
      _away.remove(id);
      if (phase == ObjasniPhase.ready && explainer == null) _pickExplainer();
    }
  }

  String _nextWord() {
    wordNo++;
    if (_deckAt >= _deck.length) {
      _deck = [..._pack.words]..shuffle(_random);
      _deckAt = 0;
    }
    return _deck[_deckAt++];
  }

  /// The explainer's "Kreni".
  bool startTurn() {
    if (phase != ObjasniPhase.ready || explainer == null) return false;
    phase = ObjasniPhase.turn;
    turnWords.clear();
    word = _nextWord();
    return true;
  }

  bool _mark(ObjasniMark m, int delta) {
    turnWords.add(ObjasniMarked(word!, m));
    _score[turnTeam] += delta;
    word = _nextWord();
    return true;
  }

  bool _current(int? n) => n == null || n == wordNo;

  /// Točno: only the explainer. [word] is the word number the press is about;
  /// a stale one (the word is gone) does nothing, so a double tap scores once.
  bool correct(int id, {int? word}) =>
      phase == ObjasniPhase.turn && id == explainer && _current(word) && _mark(ObjasniMark.correct, 1);

  /// Preskoči: only the explainer.
  bool skip(int id, {int? word}) =>
      phase == ObjasniPhase.turn && id == explainer && _current(word) && _mark(ObjasniMark.skip, -1);

  /// Prekršaj: only a (connected) player of the other team; two watchers
  /// calling the same word cost one point, not two.
  bool foul(int id, {int? word}) =>
      phase == ObjasniPhase.turn &&
      ids.contains(id) &&
      teamOf(id) != turnTeam &&
      !_away.contains(id) &&
      _current(word) &&
      _mark(ObjasniMark.foul, -1);

  /// Time is up (or the explainer left): the word on screen is lost.
  void endTurn() {
    if (phase != ObjasniPhase.turn) return;
    word = null;
    phase = ObjasniPhase.summary;
    final t = turnTeam, m = _teams[t];
    final at = m.indexOf(explainer!);
    _rot[t] = (at + 1) % m.length;
  }

  /// After the summary: the next explainer is up, or the game is over.
  void nextTurn() {
    if (phase != ObjasniPhase.summary) return;
    _turnNo++;
    if (_turnNo.isEven && _score.reduce(max) >= target && _score[0] != _score[1]) {
      _finish();
      return;
    }
    phase = ObjasniPhase.ready;
    _pickExplainer();
  }

  /// Ends the game now (a team did not come back): the higher score wins.
  void abandon() {
    if (phase == ObjasniPhase.over) return;
    word = null;
    explainer = null;
    _finish();
  }

  void _finish() {
    phase = ObjasniPhase.over;
    explainer = null;
    winnerTeam = _score[0] == _score[1] ? null : (_score[0] > _score[1] ? 0 : 1);
  }

  /// 1 for each player of the winning team, 0 for the rest; empty until over.
  Map<int, int> get sessionScores => phase != ObjasniPhase.over
      ? const {}
      : {for (final i in ids) i: winnerTeam != null && teamOf(i) == winnerTeam ? 1 : 0};
}
