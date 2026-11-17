import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

import '../sound/sfx.dart';
import 'wolf_text.dart';

enum WolfStage { night, dawn, farewell, day, vote, over }

/// One game of Vukodlak on the TV: drives the [WolfGame] rules through night,
/// morning, day and vote, talks to the phones and keeps what the TV may show.
///
/// PRIVACY. Every message to a phone goes through [send] for ONE player id.
/// Every alive phone gets the same message types, in the same order, at the
/// same moments: at night start a [NightPrompt]; after any pick by anyone a
/// fresh [NightPrompt]; at dawn a [Morning] and a [RoleMsg]; at the vote a
/// [VotePrompt]. Every player who goes out gets a [Farewell] window of the
/// same length, whatever their role. Only text and the choice list differ.
/// The TV-side getters never expose a role unless [WolfGame.publicRole] does.
class WolfMatch {
  WolfMatch({
    required this.ids,
    required this.nameOf,
    required this.settings,
    required this.send,
    required this.clock,
    required this.random,
    this.sfx = const SilentSfx(),
    this.notify,
    this.onOver,
    this.fixedRoles,
  });

  /// For tests: use these roles instead of drawing.
  final Map<int, WolfRole>? fixedRoles;

  final List<int> ids;
  final String Function(int id) nameOf;
  final GameSettings settings;

  /// Sends [m] to that player's phone only (nothing if it is offline).
  final void Function(int id, Message m) send;
  final Duration Function() clock;
  final Random random;
  Sfx sfx;
  final void Function()? notify;
  final void Function(WolfWinner winner)? onOver;

  /// How long the night waits for the slowest phone.
  static const nightMax = Duration(seconds: 60);

  /// No light goes out in the first 15 s of the night (the person's choice).
  static const lightsHold = Duration(seconds: 15);
  static const dawnPause = Duration(seconds: 3);
  static const farewellTime = Duration(seconds: 15);
  static const voteTime = Duration(seconds: 30);

  /// The rules. Not for the TV to display from: it holds every role and vote.
  @visibleForTesting
  late WolfGame game;
  WolfStage stage = WolfStage.night;
  Duration _stageEnd = Duration.zero;
  Timer? _timer;
  Timer? _lightTimer;

  /// Story events for the TV, in order. Args hold player ids.
  final List<WolfEvent> story = [];

  /// Who the last vote put out (null: nobody, or a spared fool). The TV shows
  /// how many have voted ([votedCount]) and then only this: never who voted
  /// for whom (the person's choice; it would also give the mayor away).
  int? lastOut;

  final _prompts = <int, _Task>{};

  /// The night's and the vote's player lists, fixed when each begins: a kick
  /// in between must not change any phone's list (it would show who has an
  /// action and who a sum).
  List<int> _nightIds = [];
  List<int> _voteIds = [];
  final _morning = <int, String>{};
  final _shots = <int, int?>{};
  final _inFarewell = <int>{};
  final _out = <int>{}; // told they are out
  var _lightsHeld = true;
  Set<int> _shown = {};
  NightResult? _pendingNight;
  int day = 0;

  WolfWinner? get winner => game.winner;
  int get night => game.night;
  List<int> get alive => game.alive;
  bool isAlive(int id) => game.isAlive(id);
  WolfRole? publicRole(int id) => game.publicRole(id);
  bool get hideRoles => game.hideRoles;
  int get votedCount => stage == WolfStage.vote ? alive.where((id) => _voted.contains(id)).length : 0;
  final _voted = <int>{};

  /// Whose house is lit: at night, every alive player who is not shown as
  /// done. Nothing goes dark in the first [lightsHold] of the night, then it
  /// follows [WolfGame.done]. The only per-player state that leaves the match.
  Set<int> get lit => stage == WolfStage.night ? alive.where((id) => !_shown.contains(id)).toSet() : {};

  Duration get remaining {
    final r = _stageEnd - clock();
    return r.isNegative ? Duration.zero : r;
  }

  void _setStage(WolfStage s, Duration length) {
    stage = s;
    _stageEnd = clock() + length;
    _timer?.cancel();
  }

  void start() {
    final roles = drawRoles(ids.length, settings.wolfRoles, random);
    final shuffled = [...ids]..shuffle(random);
    game = WolfGame(fixedRoles ?? {for (var i = 0; i < shuffled.length; i++) shuffled[i]: roles[i]},
        hideRoles: settings.wolfHideRoles, random: random);
    for (final id in ids) {
      _sendRole(id);
    }
    _beginNight();
  }

  void dispose() {
    _timer?.cancel();
    _lightTimer?.cancel();
  }

  void _sendRole(int id) => send(
      id,
      RoleMsg(game.roleOf(id), game.mates(id), [for (final r in WolfRole.values) if (settings.wolfRoles.contains(r)) r],
          hide: settings.wolfHideRoles));

  // ---- night ----

  void _beginNight() {
    sfx.play(Sound.nightAmbience);
    story.add(game.night == 1 ? const WolfEvent('firstNight') : WolfEvent('nightFalls', {'night': game.night}));
    _setStage(WolfStage.night, nightMax);
    _timer = Timer(nightMax, _endNight);
    _prompts.clear();
    _nightIds = alive;
    for (final id in alive) {
      _prompts[id] =
          game.hasNightAction(id) ? _Task.actor() : _Task.sum(random, alive.length, two: game.night == 1);
    }
    _lightsHeld = true;
    _shown = {};
    _lightTimer?.cancel();
    _lightTimer = Timer(lightsHold, () {
      _lightsHeld = false;
      _refreshShown();
      notify?.call();
    });
    _sendPrompts();
    notify?.call();
  }

  /// The one place that decides what the TV is told is done (see [lit]). A
  /// minimum night or batched lights would change only this.
  void _refreshShown() {
    if (!_lightsHeld) _shown = game.done;
  }

  String _hint(int id) {
    final role = game.roleOf(id);
    final t = _prompts[id]!;
    if (t.sum != null) {
      final s = t.sum!;
      return t.sum2 == null ? WolfText.sum(s.a, s.b) : WolfText.sum2(s.a, s.b, t.sum2!.a, t.sum2!.b);
    }
    switch (role) {
      case WolfRole.wolf:
      case WolfRole.alpha:
      case WolfRole.lone:
        final seen = [
          for (final m in game.mates(id))
            if (game.pickOf(m) != null) '${nameOf(m)} → ${nameOf(game.pickOf(m)!)}'
        ];
        return '${WolfText.hintWolves}${seen.isEmpty ? '' : ' ${seen.join(', ')}'}${role == WolfRole.alpha ? WolfText.hintAlpha : ''}';
      case WolfRole.seer:
        return WolfText.hintSeer;
      case WolfRole.doc:
        return WolfText.hintDoc;
      case WolfRole.guard:
        return WolfText.hintGuard;
      case WolfRole.herb:
        return WolfText.hintHerb;
      case WolfRole.cupid:
        return WolfText.hintCupid;
      default:
        return '';
    }
  }

  NightPrompt _prompt(int id) {
    final t = _prompts[id]!;
    final names = [for (final a in _nightIds) nameOf(a)];
    final two = game.night == 1;
    List<String> c1, c2;
    List<int> i1, i2;
    if (t.sum != null) {
      c1 = [for (final a in t.sum!.answers) '$a'];
      i1 = [for (var k = 0; k < c1.length; k++) k];
      c2 = two ? [for (final a in t.sum2!.answers) '$a'] : [];
      i2 = two ? [for (var k = 0; k < c2.length; k++) k] : [];
    } else {
      c1 = names;
      i1 = _nightIds;
      c2 = two ? names : [];
      i2 = two ? _nightIds : [];
    }
    return NightPrompt(
      night: game.night,
      text: WolfText.pad(_hint(id)),
      choices: c1,
      ids: i1,
      choices2: c2,
      ids2: i2,
      picks: two ? 2 : 1,
      picked: t.first,
      picked2: t.second,
      special: t.special,
      done: game.hasPicked(id),
    );
  }

  void _sendPrompts() {
    for (final id in alive) {
      send(id, _prompt(id));
    }
  }

  void onNightPick(int id, NightPick m) {
    if (stage != WolfStage.night || !game.isAlive(id)) return;
    // The first confirmation is final, for every role alike (a second one, e.g.
    // from a phone that missed the 'Poslano', changes nothing).
    if (game.hasPicked(id)) return;
    final t = _prompts[id]!;
    if (game.hasNightAction(id)) {
      final ok = game.pick(id, m.target, special: m.special, second: game.night == 1 ? m.second : null);
      if (!ok) game.pick(id, null);
    } else {
      game.pick(id, null); // a sum: any answer is done, none does anything
    }
    // The phone's own choice is echoed back on reconnect for EVERY role alike.
    t.first = m.target;
    t.second = game.night == 1 ? m.second : null;
    t.special = m.special;
    _refreshShown();
    _sendPrompts();
    notify?.call();
    if (game.nightComplete) _endNight();
  }

  void _endNight() {
    if (stage != WolfStage.night) return;
    _lightTimer?.cancel();
    _pendingNight = game.resolveNight();
    sfx.play(Sound.howl); // always, so it does not say whether wolves struck
    _setStage(WolfStage.dawn, dawnPause);
    _timer = Timer(dawnPause, _morningNow);
    notify?.call();
  }

  void _morningNow() {
    final r = _pendingNight!;
    day = game.night;
    sfx.play(Sound.rooster);
    story.addAll(r.events);
    final out = [for (final d in r.deaths) d.id];
    if (out.isNotEmpty) sfx.play(Sound.drum);
    if (!game.hideRoles && out.isNotEmpty) _wolvesLeft();
    for (final id in alive) {
      final lines = <String>[];
      for (final n in r.notes[id] ?? const <WolfNote>[]) {
        switch (n.kind) {
          case 'saw':
            lines.add(WolfText.saw(nameOf(n.target!), n.role!));
          case 'lover':
            lines.add(WolfText.lover(nameOf(n.target!)));
          case 'converted':
            lines.add(WolfText.converted);
        }
      }
      final text = WolfText.pad(lines.isEmpty ? WolfText.quiet : lines.join(' '));
      _morning[id] = text;
      send(id, Morning(day, text));
      _sendRole(id);
    }
    _afterDeaths(out, _beginDay);
  }

  void _wolvesLeft() => story.add(WolfEvent('wolvesLeft', {'count': alive.where((i) => game.roleOf(i).isWolf).length}));

  // ---- going out: the same window for everyone ----

  void _afterDeaths(List<int> out, void Function() then) {
    if (out.isEmpty) return _proceed(then);
    _setStage(WolfStage.farewell, farewellTime);
    _inFarewell
      ..clear()
      ..addAll(out);
    for (final id in out) {
      _shots.remove(id);
      send(id, Farewell(seconds: farewellTime.inSeconds, ids: alive));
    }
    notify?.call();
    _timer = Timer(farewellTime, () => _closeFarewell(then));
  }

  void onShoot(int id, Shoot m) {
    if (stage == WolfStage.farewell && _inFarewell.contains(id)) _shots[id] = m.target;
  }

  void _closeFarewell(void Function() then) {
    for (final id in _inFarewell) {
      _out.add(id);
      send(id, const Waiting(WolfText.out));
    }
    _inFarewell.clear();
    final newlyOut = <int>[];
    for (final h in game.pendingHunters) {
      final before = alive.toSet();
      game.shoot(h, _shots[h]);
      story.addAll(game.lastShotEvents);
      newlyOut.addAll(before.difference(alive.toSet()));
    }
    if (newlyOut.isNotEmpty) {
      sfx.play(Sound.drum);
      if (!game.hideRoles) _wolvesLeft();
    }
    _afterDeaths(newlyOut, then);
  }

  void _proceed(void Function() then) {
    if (game.winner != null) {
      _finish();
    } else {
      then();
    }
  }

  // ---- day and vote ----

  void _beginDay() {
    story.add(WolfEvent('dayStarts', {'day': day}));
    _setStage(WolfStage.day, Duration(seconds: settings.wolfDiscussion));
    _timer = Timer(Duration(seconds: settings.wolfDiscussion), _beginVote);
    notify?.call();
  }

  void _beginVote() {
    game.startVote();
    sfx.play(Sound.voteBell);
    story.add(const WolfEvent('voteStarts'));
    _setStage(WolfStage.vote, voteTime);
    _voted.clear();
    _voteIds = alive;
    _timer = Timer(voteTime, _endVote);
    for (final id in alive) {
      send(id, VotePrompt(day: day, seconds: voteTime.inSeconds, ids: _voteIds, canVote: game.canVote(id)));
    }
    notify?.call();
  }

  void onVote(int id, Vote m) {
    if (stage != WolfStage.vote) return;
    if (!game.vote(id, m.target)) return;
    _voted.add(id);
    notify?.call();
    if (game.voteComplete) _endVote();
  }

  void _endVote() {
    if (stage != WolfStage.vote) return;
    final before = alive.toSet();
    final r = game.resolveVote();
    lastOut = r.spared ? null : r.out;
    story.addAll(r.events);
    final out = before.difference(alive.toSet()).toList();
    if (game.winner == WolfWinner.tramp) return _finish();
    if (out.isNotEmpty) {
      sfx.play(Sound.drum);
      if (!game.hideRoles) _wolvesLeft();
    }
    _afterDeaths(out, _nextNight);
    notify?.call();
  }

  void _nextNight() {
    game.startNight();
    _beginNight();
  }

  void _finish() {
    _timer?.cancel();
    _lightTimer?.cancel();
    stage = WolfStage.over;
    story.add(const WolfEvent('endReveal'));
    final end = WolfEnd(game.winner!, {for (final id in ids) id: game.roleOf(id)});
    for (final id in ids) {
      send(id, end);
    }
    notify?.call();
    onOver?.call(game.winner!);
  }

  // ---- a kicked player is out at once ----

  /// The host kicked [id]: out of the match now (no farewell window, no shot).
  /// Whoever else goes out with them (a lover) is told they are out.
  void expel(int id) {
    if (!ids.contains(id) || stage == WolfStage.over || !game.isAlive(id)) return;
    final deaths = game.expel(id);
    sfx.play(Sound.drum);
    for (final d in deaths) {
      _out.add(d.id);
      _inFarewell.remove(d.id);
      story.add(WolfEvent('playerLeft', {
        'player': d.id,
        if (!game.hideRoles) 'role': game.roleOf(d.id).name,
      }));
      if (d.id != id) send(d.id, const Waiting(WolfText.out));
    }
    if (game.winner != null) return _finish();
    if (stage == WolfStage.night && game.nightComplete) _endNight();
    if (stage == WolfStage.vote && game.voteComplete) _endVote();
    notify?.call();
  }

  // ---- reconnect: a phone gets only its own state ----

  void rejoin(int id) {
    if (!ids.contains(id)) return;
    _sendRole(id);
    if (stage == WolfStage.over) {
      send(id, WolfEnd(game.winner!, {for (final i in ids) i: game.roleOf(i)}));
    } else if (_inFarewell.contains(id)) {
      send(id, Farewell(seconds: remaining.inSeconds, ids: alive));
    } else if (!game.isAlive(id)) {
      send(id, const Waiting(WolfText.out));
    } else if (stage == WolfStage.night) {
      send(id, _prompt(id));
    } else if (stage == WolfStage.vote) {
      send(id, VotePrompt(day: day, seconds: remaining.inSeconds, ids: _voteIds, canVote: game.canVote(id), picked: game.voteOf(id)));
    } else if (_morning.containsKey(id)) {
      send(id, Morning(day, _morning[id]!));
    }
  }
}

class _Task {
  _Task.actor()
      : sum = null,
        sum2 = null;
  _Task.sum(Random r, int count, {required bool two})
      : sum = NightSum.draw(r, count: count),
        sum2 = two ? NightSum.draw(r, count: count) : null;
  final NightSum? sum;
  final NightSum? sum2;
  int? first;
  int? second;
  bool special = false;
}
