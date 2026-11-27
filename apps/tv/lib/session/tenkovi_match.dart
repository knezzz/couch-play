import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';

import '../sound/sfx.dart';

enum TenkoviStageTv { aim, fly, end, over }

/// One match of Tenkovi on the TV: the rules live in core ([TenkoviRound]);
/// this runs the stages, talks to the phones and pays out the points.
///
/// PRIVACY. An aim (angle, power, shell) goes from a phone to [onFire] and
/// stays inside [round] until the volley fires. Nothing is sent about it to
/// any phone (each phone only ever gets back its OWN aim in [TenkoviTurn]),
/// and the TV reads only [ready] (a set of ids) before the volley.
class TenkoviTvMatch {
  TenkoviTvMatch({
    required this.ids,
    required this.settings,
    required this.send,
    required this.random,
    this.sfx = const SilentSfx(),
    this.notify,
    this.onOver,
    this.breakTime = const Duration(seconds: 6),
    Duration Function()? clock,
  }) : clock = clock ?? _wall;

  static final _stopwatch = Stopwatch()..start();
  static Duration _wall() => _stopwatch.elapsed;

  final List<int> ids;
  final GameSettings settings;
  final void Function(int id, Message m) send;
  final Random random;
  Sfx sfx;
  final void Function()? notify;
  final void Function(Map<int, int> scores)? onOver;
  final Duration breakTime;

  /// The match runs its own volley (see [_loop]): the TV view only draws.
  final Duration Function() clock;

  late TenkoviMatch match;
  TenkoviStageTv stage = TenkoviStageTv.aim;
  final _away = <int>{};
  Timer? _timer;

  /// The last volley's aim of each tank (its own phone gets it back as "Prošli put").
  final _last = <int, List<int>>{};

  /// The aims of the volley in the air. Public from the moment it fires: the TV
  /// turns each barrel to its angle, as the board shows.
  final volleyAims = <int, TenkoviAim>{};

  /// Round points and winner of the round that just ended (stage end).
  Map<int, int> lastPoints = const {};
  int? lastWinner;

  /// Who was still alive when the round ended: one tank, or several when only
  /// absent players were left and the round was ended for them.
  List<int> lastSurvivors = const [];

  /// What happened in the ticks since the TV last looked (blasts to draw, sounds are
  /// played here). The TV drains it.
  final events = <TenkoviEvent>[];

  TenkoviRound get round => match.round!;
  int get roundNo => stage == TenkoviStageTv.end || stage == TenkoviStageTv.over
      ? match.played
      : match.played + 1;
  int get rounds => match.rounds;
  Map<int, int> get scores => Map.of(match.scores);
  Set<int> get connected => {for (final i in ids) if (!_away.contains(i)) i};

  /// Ticks for the TV (who pressed Pucaj), never what they set.
  Set<int> get ready => round.ready;

  void start() {
    final pick = settings.tenkoviMap;
    match = TenkoviMatch(
      ids,
      rounds: settings.tenkoviRounds,
      map: pick == TenkoviMapPick.random ? null : TenkoviMap.values.byName(pick.name),
      seed: random.nextInt(1 << 30),
    );
    _newRound();
  }

  void dispose() {
    _timer?.cancel();
    _loop?.cancel();
  }

  // --- the volley loop and the pause ---

  Timer? _loop;
  Duration _loopLast = Duration.zero;
  double _acc = 0;

  /// True while the session has the whole game frozen (nobody to play, or one
  /// player left): nothing advances and no Pucaj is taken.
  bool paused = false;

  /// The volley flies here at 1/60 s steps from [clock], whether or not any
  /// screen is drawing; a frame that comes late catches up (at most 6 steps).
  void _startLoop() {
    _loop?.cancel();
    _loopLast = clock();
    _acc = 0;
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _pump());
  }

  void _pump() {
    if (paused || stage != TenkoviStageTv.fly) return;
    final now = clock();
    _acc += (now - _loopLast).inMicroseconds / 1e6;
    _loopLast = now;
    if (_acc > 0.1) _acc = 0.1;
    const step = 1 / Tenkovi.tickHz;
    var n = 0;
    while (_acc >= step && n < 6 && stage == TenkoviStageTv.fly) {
      _acc -= step;
      n++;
      tick();
    }
    if (stage != TenkoviStageTv.fly) _loop?.cancel();
  }

  /// Freezes the match: a volley in the air stops where it is and goes on from
  /// there on [resume]; nothing fires twice and nothing is lost.
  void pause() {
    if (paused) return;
    paused = true;
    _loop?.cancel();
    _timer?.cancel();
    notify?.call();
  }

  /// Carries on: the volley flies again, a round break starts its card again,
  /// and everybody is told the turn once more.
  void resume() {
    if (!paused) return;
    paused = false;
    switch (stage) {
      case TenkoviStageTv.fly:
        _startLoop();
      case TenkoviStageTv.end:
        _startBreak();
      default:
    }
    _tellAll();
    _maybeFire();
    notify?.call();
  }

  void _newRound() {
    match.start();
    stage = TenkoviStageTv.aim;
    _tellAll();
    notify?.call();
  }

  /// Pucaj from a phone.
  void onFire(int id, TenkoviFire m) {
    if (paused || stage != TenkoviStageTv.aim || !ids.contains(id)) return;
    if (!round.submit(id, TenkoviAim(m.angle, m.power, m.shell))) return;
    sfx.play(Sound.menuConfirm);
    _tellAll(); // the count; each phone's own aim only to itself
    _maybeFire();
    notify?.call();
  }

  void _maybeFire() {
    if (paused || stage != TenkoviStageTv.aim || !round.shouldFire(connected)) return;
    for (final e in round.aims.entries) {
      if (connected.contains(e.key)) {
        _last[e.key] = [e.value.angle, e.value.power];
      }
    }
    volleyAims
      ..clear()
      ..addAll({
        for (final e in round.aims.entries)
          if (connected.contains(e.key)) e.key: e.value,
      });
    events.addAll(round.fire(connected));
    stage = TenkoviStageTv.fly;
    _startLoop();
    sfx.play(Sound.cannon);
    _tellAll();
  }

  /// One 1/60 s step while the volley flies (the loop calls it; tests may too).
  void tick() {
    if (paused || stage != TenkoviStageTv.fly) return;
    final ev = round.tick();
    for (final e in ev) {
      switch (e) {
        case TkBlast(:final shell):
          sfx.play(shell == TenkoviShell.heavy ? Sound.bigBlast : Sound.blast);
        case TkKnockout():
          sfx.play(Sound.crash);
        case TkVolleyDone(:final over):
          events.addAll(ev);
          return over ? _endRound() : _nextTurn();
        default:
      }
    }
    events.addAll(ev);
  }

  void _nextTurn() {
    stage = TenkoviStageTv.aim;
    _tellAll();
    _maybeFire(); // everyone left may be away
    _checkStall();
    notify?.call();
  }

  void _endRound() {
    lastWinner = round.winner;
    lastSurvivors = [for (final t in round.living) t.id]..sort();
    lastPoints = match.finish();
    stage = TenkoviStageTv.end;
    sfx.play(Sound.roundWin);
    _tellAll();
    notify?.call();
    _startBreak();
  }

  void _startBreak() {
    _timer?.cancel();
    _timer = Timer(breakTime, () {
      if (match.over) {
        stage = TenkoviStageTv.over;
        sfx.play(Sound.fanfare);
        notify?.call();
        onOver?.call(match.scores);
      } else {
        _newRound();
      }
    });
  }

  void setAway(int id, bool away) {
    if (!ids.contains(id) || stage == TenkoviStageTv.over) return;
    away ? _away.add(id) : _away.remove(id);
    _tellAll();
    _maybeFire();
    _checkStall();
    notify?.call();
  }

  /// Every connected tank is out and 2 or more absent ones are alive (a drop or a
  /// kick): nobody can fire, so the round ends now. The absent tanks tie at the
  /// top, everyone else gets the players they outlived.
  void _checkStall() {
    if (paused || stage != TenkoviStageTv.aim || round.living.length < 2) return;
    if (round.living.any((t) => connected.contains(t.id))) return;
    _endRound();
  }

  void rejoin(int id) {
    if (ids.contains(id) && stage != TenkoviStageTv.over) send(id, _turnFor(id));
  }

  void _tellAll() {
    for (final id in ids) {
      send(id, _turnFor(id));
    }
  }

  TenkoviTurn _turnFor(int id) {
    final t = round.tank(id);
    final a = round.aims[id];
    final waiting = round.living.where((x) => connected.contains(x.id)).length;
    return TenkoviTurn(
      stage: switch (stage) {
        TenkoviStageTv.aim => 'aim',
        TenkoviStageTv.fly => 'fly',
        _ => 'end',
      },
      round: roundNo.clamp(1, rounds),
      turn: round.volleys + (stage == TenkoviStageTv.aim ? 1 : 0),
      rounds: rounds,
      map: round.map,
      wind: round.wind,
      alive: t.alive,
      hp: t.hp,
      heavy: t.heavyLeft,
      cluster: t.clusterLeft,
      ready: round.aims.keys.where(connected.contains).length,
      total: waiting,
      sent: a == null ? null : [a.angle, a.power, a.shell.index],
      last: _last[id],
      points: stage == TenkoviStageTv.end || stage == TenkoviStageTv.over ? (lastPoints[id] ?? 0) : 0,
      score: match.scores[id] ?? 0,
      winner: stage == TenkoviStageTv.end || stage == TenkoviStageTv.over ? lastWinner : null,
      waiting: stage == TenkoviStageTv.aim
          ? [for (final t in round.living) if (connected.contains(t.id) && !round.aims.containsKey(t.id)) t.id]
          : const [],
    );
  }
}
