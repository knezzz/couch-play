import 'dart:math';

/// Uljez: a hidden-word game, pure Dart. Everyone gets the same word, except
/// the impostor(s), who get the pair's other word and do not know it.
///
/// Rule readings (simplest):
///  * 3-8 players. 1 impostor for 3-6; at 7-8 the host may ask for 2.
///  * Two clue rounds in one fixed shuffled order (the session times each turn).
///  * One vote per impostor: with 1 impostor a single vote, with 2 the village
///    votes twice in a row (out players cannot vote or be voted for). Plurality;
///    a tie, or nobody voting, puts nobody out and still uses the vote up.
///  * An impostor voted out is caught and guesses the village word from 4
///    options (the right word + 3 words of other pairs). A right guess wins
///    for the impostors at once; a wrong or missing one does not.
///  * Village wins if every impostor was caught and no guess was right;
///    otherwise (an impostor survived all the votes, or a right guess)
///    the impostors win. Winners score 1, the rest 0, fed to placementPoints.
class WordPair {
  const WordPair(this.a, this.b);
  final String a, b;
}

class UljezPack {
  const UljezPack(this.id, this.title, this.pairs);
  final String id;
  final String title;
  final List<WordPair> pairs;

  /// The content format: {"id","title","pairs":[[a,b],...]}. At least 4 pairs
  /// (the guess needs 3 decoys from other pairs); each pair two different words.
  /// Throws [FormatException] otherwise.
  factory UljezPack.fromJson(Map<String, dynamic> j) {
    final id = j['id'], title = j['title'], raw = j['pairs'];
    if (id is! String || title is! String || raw is! List) throw const FormatException('bad pack');
    final pairs = <WordPair>[];
    for (final e in raw) {
      if (e is! List || e.length != 2 || e[0] is! String || e[1] is! String) {
        throw const FormatException('bad pair');
      }
      final a = (e[0] as String).trim(), b = (e[1] as String).trim();
      if (a.isEmpty || b.isEmpty || a == b) throw const FormatException('bad pair');
      pairs.add(WordPair(a, b));
    }
    if (pairs.length < 4) throw const FormatException('too few pairs');
    return UljezPack(id, title, pairs);
  }
}

enum UljezPhase { clues, vote, guess, over }

enum UljezWinner { village, impostors }

class UljezVoteResult {
  const UljezVoteResult(this.votes, this.out, {this.caught = false, this.tie = false});
  final Map<int, int?> votes;
  final int? out;
  final bool caught;
  final bool tie;
}

class UljezGame {
  UljezGame(List<int> ids, UljezPack pack, {int impostors = 1, Random? random})
      : ids = List.unmodifiable(ids),
        _pack = pack,
        _random = random ?? Random() {
    if (ids.length < 3 || ids.length > 8) throw ArgumentError('Uljez is for 3 to 8 players');
    impostorCount = ids.length >= 7 && impostors >= 2 ? 2 : 1;
    pairIndex = _random.nextInt(pack.pairs.length);
    pair = pack.pairs[pairIndex];
    final flip = _random.nextBool();
    villageWord = flip ? pair.b : pair.a;
    impostorWord = flip ? pair.a : pair.b;
    final shuffled = [...ids]..shuffle(_random);
    _impostors.addAll(shuffled.take(impostorCount));
    order = [...ids]..shuffle(_random);
    votesLeft = impostorCount;
  }

  final List<int> ids;
  final UljezPack _pack;
  final Random _random;
  late final int impostorCount;
  late final int pairIndex;
  late final WordPair pair;
  late final String villageWord, impostorWord;
  late final List<int> order;
  final Set<int> _impostors = {};
  final Set<int> _out = {};
  final List<int> _caught = [];
  final Map<int, int?> _votes = {};

  UljezPhase phase = UljezPhase.clues;
  UljezWinner? winner;
  int turn = 0;
  late int votesLeft;

  /// Private: for the session, which sends each phone only its own word.
  bool isImpostor(int id) => _impostors.contains(id);
  String wordOf(int id) => isImpostor(id) ? impostorWord : villageWord;

  List<int> get alive => [for (final i in ids) if (!_out.contains(i)) i];
  Map<int, int?> get votes => Map.unmodifiable(_votes);

  // ---- clues ----

  int? get speaker => phase == UljezPhase.clues ? order[turn % order.length] : null;
  int get round => turn ~/ order.length + 1;

  /// The next speaker. Rounds repeat until the vote starts (no clock).
  void nextTurn() {
    if (phase != UljezPhase.clues) return;
    turn++;
  }

  /// "Idemo glasati" opens at the end of round 1.
  bool get voteMayStart => phase == UljezPhase.clues && turn >= order.length;

  // ---- vote ----

  void startVote() {
    if (!voteMayStart) throw StateError('not after round 1');
    _beginVote();
  }

  void _beginVote() {
    _votes.clear();
    phase = UljezPhase.vote;
  }

  /// [target] null = skip. False if it does not count.
  bool vote(int who, int? target) {
    if (phase != UljezPhase.vote || !alive.contains(who)) return false;
    if (target != null && (target == who || !ids.contains(target))) return false;
    _votes[who] = target != null && !alive.contains(target) ? null : target;
    return true;
  }

  bool get voteComplete => alive.every(_votes.containsKey);

  UljezVoteResult resolveVote() {
    if (phase != UljezPhase.vote) throw StateError('not the vote');
    final votes = Map<int, int?>.of(_votes);
    final tally = <int, int>{};
    for (final e in votes.entries) {
      final t = e.value;
      if (t != null && alive.contains(e.key) && alive.contains(t)) tally[t] = (tally[t] ?? 0) + 1;
    }
    votesLeft--;
    int? out;
    var tie = false;
    if (tally.isNotEmpty) {
      final top = tally.values.reduce(max);
      final tied = [for (final e in tally.entries) if (e.value == top) e.key];
      if (tied.length == 1) {
        out = tied.first;
      } else {
        tie = true;
      }
    }
    if (out == null) {
      _nextVoteOrEnd();
      return UljezVoteResult(votes, null, tie: tie);
    }
    _out.add(out);
    if (isImpostor(out)) {
      _caught.add(out);
      _beginGuess(out);
      return UljezVoteResult(votes, out, caught: true);
    }
    _nextVoteOrEnd();
    return UljezVoteResult(votes, out);
  }

  void _nextVoteOrEnd() {
    if (votesLeft > 0 && _caught.length < impostorCount) {
      _beginVote();
    } else {
      _end(_caught.length == impostorCount ? UljezWinner.village : UljezWinner.impostors);
    }
  }

  // ---- the caught impostor's guess ----

  int? guesser;
  List<String> guessOptions = const [];
  int rightGuess = -1;
  int? _guess;
  bool guessedRight = false;

  void _beginGuess(int id) {
    guesser = id;
    phase = UljezPhase.guess;
    _guess = null;
    final others = [for (var i = 0; i < _pack.pairs.length; i++) if (i != pairIndex) _pack.pairs[i]]..shuffle(_random);
    final decoys = <String>[];
    for (final p in others) {
      final w = _random.nextBool() ? p.a : p.b;
      if (w != pair.a && w != pair.b && !decoys.contains(w)) decoys.add(w);
      if (decoys.length == 3) break;
    }
    final options = [...decoys, villageWord]..shuffle(_random);
    guessOptions = options;
    rightGuess = options.indexOf(villageWord);
  }

  bool guess(int who, int index) {
    if (phase != UljezPhase.guess || who != guesser || index < 0 || index >= guessOptions.length) return false;
    _guess = index;
    return true;
  }

  /// Ends the guess (the guess came in, or the guesser is gone).
  void resolveGuess() {
    if (phase != UljezPhase.guess) return;
    guessedRight = _guess == rightGuess;
    if (guessedRight) {
      _end(UljezWinner.impostors);
    } else {
      guesser = null;
      _nextVoteOrEnd();
    }
  }

  // ---- a kicked player ----

  /// [id] was kicked: out at once, votes for and by them are void. A kicked
  /// impostor counts as caught with no guess (the village wins if that was the
  /// last one). A kicked guesser's guess is simply missing. Returns false if
  /// there was nothing to do.
  bool expel(int id) {
    if (phase == UljezPhase.over || !alive.contains(id)) return false;
    _out.add(id);
    _votes.remove(id);
    _votes.updateAll((_, t) => t == id ? null : t); // voted for them: now a skip
    if (isImpostor(id) && !_caught.contains(id)) {
      _caught.add(id);
      // While a caught impostor is still guessing, resolveGuess ends the game.
      if (_caught.length == impostorCount && phase != UljezPhase.guess) _end(UljezWinner.village);
    }
    return true;
  }

  // ---- the end ----

  void _end(UljezWinner w) {
    winner = w;
    phase = UljezPhase.over;
  }

  /// 1 for the winning side, 0 for the rest; empty until the game is over.
  Map<int, int> get scores => winner == null
      ? const {}
      : {
          for (final i in ids)
            i: (winner == UljezWinner.impostors) == isImpostor(i) ? 1 : 0,
        };
}
