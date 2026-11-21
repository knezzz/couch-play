import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';

import '../sound/sfx.dart';
import 'uljez_text.dart';
import 'vote_wish.dart';

/// One game of Uljez on the TV: drives [UljezGame] through the clue turns, the
/// "Idemo glasati" wishes, the vote(s) and the caught impostor's guess, and talks to the
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
    this.avoid = const {},
    this.sfx = const SilentSfx(),
    this.notify,
    this.onOver,
  });

  /// Last game's impostors: not picked again if others are left.
  final Set<int> avoid;
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

  /// The end screen (both words, who the impostors were) stays up this long
  /// before the results take over, like Vukodlak's end.
  static const endHold = Duration(seconds: 10);

  /// Nobody still in is connected this long: the match is given up (the TV
  /// would wait forever otherwise, as no phase has a clock). Phones that are
  /// locked count as away, so this is long.
  static const emptyHold = Duration(minutes: 10);

  late UljezGame game;
  Timer? _timer; // only the end hold
  Timer? _emptyTimer;
  Duration _stageEnd = Duration.zero;
  int voteNo = 0;
  final _away = <int>{};
  final _wish = WishBox();

  /// Called once when nobody still in has been connected for [emptyHold].
  void Function()? onAbandon;

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

  /// Only the end hold has a clock.
  Duration get remaining {
    final r = _stageEnd - clock();
    return r.isNegative ? Duration.zero : r;
  }

  /// Everyone still in the game, connected or not (a locked phone drops its
  /// socket): the players waited for and counted. Only a kick removes one.
  List<int> get present => game.alive;

  /// "Idemo glasati": open from the end of round 1 until the vote starts.
  bool get wishOpen => phase == UljezPhase.clues && game.voteMayStart;
  int get wishCount => wishOpen ? _wish.want(present) : 0;
  int get wishNeeded => WishBox.needed(present.length);

  void start() {
    game = UljezGame(ids, pack, impostors: settings.uljezImpostors, random: random, avoid: avoid);
    for (final id in ids) {
      send(id, UljezWord(game.wordOf(id)));
    }
    _turnStart();
  }

  void dispose() {
    _timer?.cancel();
    _emptyTimer?.cancel();
  }

  // ---- clues: no clock, the speaker passes the turn ----

  void _broadcastTurn() {
    final m = _turnMsg();
    for (final id in ids) {
      send(id, m);
    }
  }

  UljezTurn _turnMsg() => UljezTurn(round: game.round, speaker: game.speaker, seconds: 0, stage: 'clues');

  VoteWish _wishMsg(int id) =>
      VoteWish(open: wishOpen, ready: _wish.has(id), want: wishCount, needed: wishNeeded);

  void _sendWishes() {
    if (phase != UljezPhase.clues) return;
    for (final id in present) {
      send(id, _wishMsg(id));
    }
  }

  bool _canSpeak(int id) => game.alive.contains(id);

  /// Skips a speaker who is out or away (a full circle of skips stops: nobody
  /// is here), then tells everyone.
  void _turnStart() {
    for (var i = 0; i < game.order.length && !_canSpeak(game.speaker!); i++) {
      game.nextTurn();
    }
    _broadcastTurn();
    _sendWishes();
    _checkEmpty();
    notify?.call();
  }

  /// The speaker's "Dao sam trag". Anyone else, or out of turn, is ignored.
  void onDone(int id) {
    if (phase != UljezPhase.clues || game.speaker != id) return;
    game.nextTurn();
    _turnStart();
  }

  /// A phone's "Idemo glasati" wish. Ignored until it is open, and from
  /// players who are out.
  void onReady(int id, ReadyToVote m) {
    if (!wishOpen || !game.alive.contains(id)) return;
    _wish.set(id, m.on);
    _afterWishChange();
  }

  void _afterWishChange() {
    if (wishOpen && _wish.majority(present)) return _beginVote();
    _sendWishes();
    notify?.call();
  }

  // ---- vote: ends when everyone connected has voted ----

  void _beginVote() {
    if (voteNo == 0) game.startVote();
    voteNo++;
    _wish.clear();
    sfx.play(Sound.voteBell);
    for (final id in game.alive) {
      send(id, VotePrompt(day: voteNo, seconds: 0, ids: game.alive));
    }
    notify?.call();
    _checkVoteDone();
  }

  bool get _voteDone => present.isNotEmpty && present.every(game.votes.containsKey);

  void _checkVoteDone() {
    if (phase == UljezPhase.vote && _voteDone) _endVote();
  }

  void onVote(int id, Vote m) {
    if (game.phase != UljezPhase.vote) return;
    if (!game.vote(id, m.target)) return;
    notify?.call();
    _checkVoteDone();
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
    for (final id in ids) {
      send(id, id == g ? UljezGuess(seconds: 0, options: game.guessOptions) : const Waiting(_guessing));
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
    _wish.set(id, false);
    switch (game.phase) {
      case UljezPhase.over:
        return _finish();
      case UljezPhase.clues:
        if (game.speaker == id) {
          game.nextTurn();
          _turnStart();
        } else {
          _afterWishChange();
        }
      case UljezPhase.vote:
        _checkVoteDone();
      case UljezPhase.guess:
        if (game.guesser == id) _endGuess();
    }
    _checkEmpty();
    notify?.call();
  }

  // ---- phones leaving and coming back ----

  /// [id] lost its connection (or came back). Nothing is waited for any
  /// differently: a sleeping phone keeps its turn, its vote, its wish and its
  /// guess. Only the host's kick moves on. This only feeds the empty-room hold.
  void setAway(int id, bool away) {
    if (!ids.contains(id) || phase == UljezPhase.over) return;
    if (away ? !_away.add(id) : !_away.remove(id)) return;
    _checkEmpty();
  }

  void _checkEmpty() {
    _emptyTimer?.cancel();
    _emptyTimer = null;
    if (phase != UljezPhase.over && game.alive.every(_away.contains)) _emptyTimer = Timer(emptyHold, () => onAbandon?.call());
  }

  // ---- end ----

  void _finish() {
    _timer?.cancel();
    _emptyTimer?.cancel();
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
        send(id, _turnMsg());
        if (game.alive.contains(id)) send(id, _wishMsg(id));
      case UljezPhase.vote:
        send(
            id,
            game.alive.contains(id)
                ? VotePrompt(day: voteNo, seconds: 0, ids: game.alive, picked: game.votes[id])
                : const Waiting(UljezText.out));
      case UljezPhase.guess:
        send(
            id,
            id == game.guesser
                ? UljezGuess(seconds: 0, options: game.guessOptions)
                : const Waiting(_guessing));
      case UljezPhase.over:
        send(id, UljezEnd(game.winner!, game.villageWord, game.impostorWord, [for (final i in ids) if (game.isImpostor(i)) i]));
    }
  }
}
