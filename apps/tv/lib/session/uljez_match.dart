import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';

import '../sound/sfx.dart';
import 'uljez_text.dart';

/// One game of Uljez on the TV: drives [UljezGame] through the clue turns, the
/// discussion, the vote(s) and the caught impostor's guess, and talks to the
/// phones.
///
/// PRIVACY. The impostor's phone gets the same message types at the same
/// moments as every other phone; only the [UljezWord] differs. Nothing says
/// "you are the impostor" until someone is voted out, and that is public.
/// Turns, votes and the end go to everyone alike.
class UljezMatch {
  UljezMatch({
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
  final UljezPack pack;
  final GameSettings settings;
  final void Function(int id, Message m) send;
  final Duration Function() clock;
  final Random random;
  Sfx sfx;
  final void Function()? notify;

  /// Called once with the scores (1 for the winning side, 0 for the rest).
  final void Function(Map<int, int> scores)? onOver;

  static const clueTime = Duration(seconds: 20);
  static const voteTime = Duration(seconds: 30);
  static const guessTime = Duration(seconds: 15);

  /// The end screen (both words, who the impostors were) stays up this long
  /// before the results take over, like Vukodlak's end.
  static const endHold = Duration(seconds: 10);

  late UljezGame game;
  Timer? _timer;
  Duration _stageEnd = Duration.zero;
  int voteNo = 0;

  /// The last counted vote, and who it put out (null: nobody).
  Map<int, int?> lastVotes = {};
  int? lastOut;

  UljezPhase get phase => game.phase;
  int? get speaker => game.speaker;
  int get round => game.round;
  List<int> get order => game.order;
  List<int> get alive => game.alive;
  UljezWinner? get winner => game.winner;
  int get votedCount => game.votes.length;

  /// Both words and the impostors, only once the game is over.
  String? get villageWord => phase == UljezPhase.over ? game.villageWord : null;
  String? get impostorWord => phase == UljezPhase.over ? game.impostorWord : null;
  List<int> get impostors => phase == UljezPhase.over ? [for (final i in ids) if (game.isImpostor(i)) i] : const [];

  Duration get remaining {
    final r = _stageEnd - clock();
    return r.isNegative ? Duration.zero : r;
  }

  void _stage(Duration length, void Function() then) {
    _timer?.cancel();
    _stageEnd = clock() + length;
    _timer = Timer(length, then);
  }

  void start() {
    game = UljezGame(ids, pack, impostors: settings.uljezImpostors, random: random);
    for (final id in ids) {
      send(id, UljezWord(game.wordOf(id)));
    }
    _turnStart();
  }

  void dispose() => _timer?.cancel();

  // ---- clues ----

  void _broadcastTurn() {
    final m = _turnMsg();
    for (final id in ids) {
      send(id, m);
    }
  }

  UljezTurn _turnMsg() => UljezTurn(
      round: game.round,
      speaker: game.speaker,
      seconds: remaining.inSeconds,
      stage: game.phase == UljezPhase.clues ? 'clues' : 'discussion');

  void _turnStart() {
    // A kicked player has no turn: skip them.
    while (game.phase == UljezPhase.clues && !game.alive.contains(game.speaker)) {
      game.nextTurn();
    }
    if (game.phase != UljezPhase.clues) return _discussion();
    _stage(clueTime, _turnEnd);
    _broadcastTurn();
    notify?.call();
  }

  void _turnEnd() {
    game.nextTurn();
    if (game.phase == UljezPhase.clues) {
      _turnStart();
    } else {
      _discussion();
    }
  }

  void _discussion() {
    _stage(Duration(seconds: settings.uljezDiscussion), _beginVote);
    _broadcastTurn();
    notify?.call();
  }

  // ---- vote ----

  void _beginVote() {
    if (voteNo == 0) game.startVote();
    voteNo++;
    sfx.play(Sound.voteBell);
    _stage(voteTime, _endVote);
    for (final id in game.alive) {
      send(id, VotePrompt(day: voteNo, seconds: voteTime.inSeconds, ids: game.alive));
    }
    notify?.call();
  }

  void onVote(int id, Vote m) {
    if (game.phase != UljezPhase.vote) return;
    if (!game.vote(id, m.target)) return;
    notify?.call();
    if (game.voteComplete) _endVote();
  }

  void _endVote() {
    if (game.phase != UljezPhase.vote) return;
    final before = game.alive;
    final r = game.resolveVote();
    lastVotes = r.votes;
    lastOut = r.out;
    if (r.out != null) sfx.play(Sound.drum);
    // Someone voted out of a game that goes on leaves the vote screen. (The
    // caught impostor gets the guess instead; the end goes to everyone.)
    if (r.out != null && !r.caught && game.phase != UljezPhase.over) send(r.out!, const Waiting(UljezText.out));
    if (r.caught) {
      _beginGuess();
    } else {
      _afterRound(before);
    }
  }

  void _afterRound(List<int> before) {
    if (game.phase == UljezPhase.over) return _finish();
    // another vote follows (two impostors): same prompt, everyone alive
    _beginVote();
  }

  // ---- the caught impostor's guess ----

  void _beginGuess() {
    final g = game.guesser!;
    _stage(guessTime, _endGuess);
    for (final id in ids) {
      send(id, id == g ? UljezGuess(seconds: guessTime.inSeconds, options: game.guessOptions) : const Waiting(_guessing));
    }
    notify?.call();
  }

  static const _guessing = 'Uljez pogađa riječ sela.';

  void onGuess(int id, Guess m) {
    if (game.phase != UljezPhase.guess) return;
    if (game.guess(id, m.index)) _endGuess();
  }

  void _endGuess() {
    if (game.phase != UljezPhase.guess) return;
    final guesser = game.guesser;
    game.resolveGuess();
    if (game.phase == UljezPhase.over) return _finish();
    if (guesser != null) send(guesser, const Waiting(UljezText.out)); // caught and wrong: out, the game goes on
    _beginVote();
  }

  // ---- a kicked player is out at once ----

  /// The host kicked [id]. A kicked impostor counts as caught with no guess:
  /// the village wins if that was the last one. Nobody waits for them.
  void expel(int id) {
    if (!ids.contains(id)) return;
    // The guesser is already out (voted out): their kick just ends the guess.
    if (game.phase == UljezPhase.guess && game.guesser == id) return _endGuess();
    if (!game.expel(id)) return;
    switch (game.phase) {
      case UljezPhase.over:
        return _finish();
      case UljezPhase.clues:
        if (game.speaker == id) _turnEnd();
      case UljezPhase.vote:
        if (game.voteComplete) _endVote();
      case UljezPhase.guess:
        if (game.guesser == id) _endGuess();
      case UljezPhase.discussion:
        break;
    }
    notify?.call();
  }

  // ---- end ----

  void _finish() {
    _timer?.cancel();
    final end = UljezEnd(game.winner!, game.villageWord, game.impostorWord,
        [for (final i in ids) if (game.isImpostor(i)) i]);
    sfx.play(game.winner == UljezWinner.village ? Sound.fanfare : Sound.wrong);
    for (final id in ids) {
      send(id, end);
    }
    notify?.call();
    _timer?.cancel();
    _stageEnd = clock() + endHold;
    _timer = Timer(endHold, () => onOver?.call(game.scores));
  }

  // ---- reconnect: own state only ----

  void rejoin(int id) {
    if (!ids.contains(id)) return;
    send(id, UljezWord(game.wordOf(id)));
    switch (game.phase) {
      case UljezPhase.clues:
      case UljezPhase.discussion:
        send(id, _turnMsg());
      case UljezPhase.vote:
        send(
            id,
            game.alive.contains(id)
                ? VotePrompt(day: voteNo, seconds: remaining.inSeconds, ids: game.alive, picked: game.votes[id])
                : const Waiting(UljezText.out));
      case UljezPhase.guess:
        send(
            id,
            id == game.guesser
                ? UljezGuess(seconds: remaining.inSeconds, options: game.guessOptions)
                : const Waiting(_guessing));
      case UljezPhase.over:
        send(id, UljezEnd(game.winner!, game.villageWord, game.impostorWord, [for (final i in ids) if (game.isImpostor(i)) i]));
    }
  }
}
