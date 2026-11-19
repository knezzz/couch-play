import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

import '../sound/sfx.dart';

enum ObjasniStageTv { setup, ready, play, summary, over }

/// One game of Objasni on the TV: drives [ObjasniGame] (teams, turns, the clock,
/// the pause) and talks to the phones.
///
/// PRIVACY. The word on screen goes only to the explainer's phone and to the
/// OTHER team's phones (they call the fouls); the explainer's own team and the
/// TV never get it. The TV reads [turnWords] (the words already done), never
/// the current word.
class ObjasniMatch {
  ObjasniMatch({
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
  final ObjasniPack pack;
  final GameSettings settings;

  /// The host right now (the one who may Promiješaj and start the game).
  final int? Function() hostId;
  final void Function(int id, Message m) send;
  final Duration Function() clock;
  final Random random;
  Sfx sfx;
  final void Function()? notify;

  /// Called once with the session points (1 for the winning team's players).
  final void Function(Map<int, int> scores)? onOver;

  static const summaryTime = Duration(seconds: 5);
  static const pauseTime = Duration(seconds: 30);

  /// The winner screen stays up this long before the results take over.
  static const endHold = Duration(seconds: 8);

  /// The rules. Not for the TV to display from: it holds the current word.
  @visibleForTesting
  late ObjasniGame game;
  ObjasniStageTv stage = ObjasniStageTv.setup;
  Timer? _tick, _timer;
  var _left = 0; // seconds left in the turn
  Duration? _pauseEnd;
  Duration _stageEnd = Duration.zero;

  List<int> teamMembers(int t) => game.teamMembers(t);
  int teamOf(int id) => game.teamOf(id);
  int get turnTeam => game.turnTeam;
  int? get explainer => game.explainer;
  List<ObjasniMarked> get turnWords => List.unmodifiable(game.turnWords);
  List<int> get scores => [game.score(0), game.score(1)];
  int? get winnerTeam => game.winnerTeam;
  int get turnSeconds => settings.objasniSeconds;
  int get target => settings.objasniTarget;
  int get secondsLeft => _left;

  bool get paused => _pauseEnd != null;
  Duration get pauseRemaining {
    final e = _pauseEnd;
    if (e == null) return Duration.zero;
    final r = e - clock();
    return r.isNegative ? Duration.zero : r;
  }

  Duration get remaining {
    final r = _stageEnd - clock();
    return r.isNegative ? Duration.zero : r;
  }

  void start() {
    game = ObjasniGame(ids, pack, turnSeconds: settings.objasniSeconds, target: settings.objasniTarget, random: random);
    _sendTeams();
    notify?.call();
  }

  void dispose() {
    _tick?.cancel();
    _timer?.cancel();
  }

  // ---- messages out ----

  /// Kicked players: the phones' team lists leave them out (the TV does too).
  final _kicked = <int>{};

  List<List<int>> _teamLists() => [
        for (var t = 0; t < 2; t++) [for (final id in game.teamMembers(t)) if (!_kicked.contains(id)) id]
      ];

  void _sendTeams() {
    final teams = _teamLists();
    for (final id in ids) {
      if (!_kicked.contains(id)) send(id, ObjasniTeams(team: game.teamOf(id), teams: teams));
    }
  }

  /// A kick: the others get the teams again without that player.
  void kicked(int id) {
    if (!ids.contains(id) || !_kicked.add(id)) return;
    game.drop(id); // the setup deals again among the rest
    _sendTeams();
    // An explainer who is kicked mid-turn has nobody to press: the turn ends.
    if (stage == ObjasniStageTv.play && id == game.explainer) _endTurn();
    _checkPause();
    notify?.call();
  }

  ObjasniRole _role(int id) => id == game.explainer
      ? ObjasniRole.explain
      : game.teamOf(id) == game.turnTeam
          ? ObjasniRole.guess
          : ObjasniRole.watch;

  ObjasniTurn _turnMsg(int id, ObjasniStageTv st) {
    final role = _role(id);
    final stg = st == ObjasniStageTv.play
        ? ObjasniStage.play
        : st == ObjasniStageTv.summary
            ? ObjasniStage.summary
            : ObjasniStage.ready;
    return ObjasniTurn(
      stage: stg,
      role: role,
      team: game.turnTeam,
      explainer: game.explainer ?? -1,
      // never to the explainer's own team
      word: st == ObjasniStageTv.play && role != ObjasniRole.guess ? game.word : null,
      wordNo: game.wordNo,
      seconds: st == ObjasniStageTv.play ? _left : (st == ObjasniStageTv.summary ? remaining.inSeconds : 0),
      scores: scores,
    );
  }

  void _sendTurn(ObjasniStageTv st) {
    for (final id in ids) {
      send(id, _turnMsg(id, st));
    }
  }

  /// A new word: only the phones that may see it.
  void _sendWord() {
    for (final id in ids) {
      if (_role(id) != ObjasniRole.guess) send(id, _turnMsg(id, ObjasniStageTv.play));
    }
  }

  // ---- messages in ----

  void onReshuffle(int id) {
    if (stage != ObjasniStageTv.setup || id != hostId()) return;
    game.reshuffle();
    sfx.play(Sound.menuMove);
    _sendTeams();
    notify?.call();
  }

  void onGo(int id) {
    if (paused) return;
    if (stage == ObjasniStageTv.setup && id == hostId()) {
      // A team with nobody connected cannot play: do not start.
      if (game.teamNeedsPause) {
        send(id, const ErrorMsg(ObjasniText.teamEmpty));
        return;
      }
      game.begin();
      _toReady();
    } else if (stage == ObjasniStageTv.ready && (id == game.explainer || id == hostId())) {
      // the host's phone may press Kreni for an explainer who wandered off
      _startTurn();
    }
  }

  void onAction(int id, ObjasniAction m) {
    if (stage != ObjasniStageTv.play || paused) return;
    final ok = switch (m.act) {
      ObjasniAct.correct => game.correct(id, word: m.wordNo),
      ObjasniAct.skip => game.skip(id, word: m.wordNo),
      ObjasniAct.foul => game.foul(id, word: m.wordNo),
    };
    if (!ok) return;
    sfx.play(m.act == ObjasniAct.correct ? Sound.right : Sound.wrong);
    _sendWord();
    notify?.call();
  }

  // ---- the turn ----

  void _toReady() {
    stage = ObjasniStageTv.ready;
    _timer?.cancel();
    _tick?.cancel();
    if (game.teamNeedsPause) _startPause();
    _sendTurn(ObjasniStageTv.ready);
    notify?.call();
  }

  void _startTurn() {
    if (!game.startTurn()) return;
    stage = ObjasniStageTv.play;
    _left = settings.objasniSeconds;
    sfx.play(Sound.quizStart);
    _runClock();
    _sendTurn(ObjasniStageTv.play);
    notify?.call();
  }

  void _runClock() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      _left--;
      if (_left > 0) sfx.play(_left <= 5 ? Sound.tick : Sound.quizTick);
      if (_left <= 0) {
        _tick?.cancel();
        _endTurn();
      } else {
        notify?.call();
      }
    });
  }

  void _endTurn() {
    if (stage != ObjasniStageTv.play) return;
    _tick?.cancel();
    game.endTurn();
    _toSummary();
  }

  void _toSummary() {
    stage = ObjasniStageTv.summary;
    // Paused (a team has nobody): the abandon timer keeps running; _endPause
    // starts the summary timer when someone returns.
    if (!paused) {
      _stageEnd = clock() + summaryTime;
      _timer?.cancel();
      _timer = Timer(summaryTime, _afterSummary);
    }
    _sendTurn(ObjasniStageTv.summary);
    notify?.call();
  }

  void _afterSummary() {
    game.nextTurn();
    if (game.phase == ObjasniPhase.over) return _finish();
    _toReady();
  }

  void _finish() {
    _tick?.cancel();
    _timer?.cancel();
    stage = ObjasniStageTv.over;
    sfx.play(Sound.fanfare);
    notify?.call();
    _stageEnd = clock() + endHold;
    _timer = Timer(endHold, () => onOver?.call(game.sessionScores));
  }

  // ---- dropping out: Quiz-style, and a pause when a team is empty ----

  void setAway(int id, bool away) {
    if (!ids.contains(id) || stage == ObjasniStageTv.over) return;
    game.setAway(id, away);
    // An explainer who drops mid-turn (a locked iPhone) does not end the turn:
    // the clock runs on and they resume with the current word on return.
    if (stage == ObjasniStageTv.ready) _sendTurn(ObjasniStageTv.ready);
    _checkPause();
    notify?.call();
  }

  void _checkPause() {
    if (stage == ObjasniStageTv.setup) return; // setup waits for the host; no pause
    if (game.teamNeedsPause) {
      if (!paused) _startPause();
    } else if (paused) {
      _endPause();
    }
  }

  void _startPause() {
    if (paused) return;
    _pauseEnd = clock() + pauseTime;
    _tick?.cancel(); // the clock stands still; _left keeps its value
    _timer?.cancel();
    _timer = Timer(pauseTime, () {
      // nobody came back: the game ends with the scores as they are
      _pauseEnd = null;
      game.abandon();
      _finish();
    });
  }

  void _endPause() {
    _pauseEnd = null;
    _timer?.cancel();
    if (stage == ObjasniStageTv.play) {
      _runClock();
    } else if (stage == ObjasniStageTv.summary) {
      _stageEnd = clock() + summaryTime;
      _timer = Timer(summaryTime, _afterSummary);
    }
    notify?.call();
  }

  // ---- reconnect ----

  void rejoin(int id) {
    if (!ids.contains(id)) return;
    send(id, ObjasniTeams(team: game.teamOf(id), teams: _teamLists()));
    if (stage == ObjasniStageTv.setup || stage == ObjasniStageTv.over) return;
    send(id, _turnMsg(id, stage));
  }
}

class ObjasniText {
  static const teamEmpty = 'Jedan tim nema nikoga spojenog. Pričekaj ili promiješaj.';
}
