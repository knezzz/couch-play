import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

import '../sound/sfx.dart';
import 'vote_wish.dart';
import 'wolf_text.dart';

enum WolfStage { ready, night, dawn, farewell, day, vote, over }

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

  /// Nobody still in is connected this long: the match is given up (no phase
  /// waiting on players has a clock, so the TV would wait forever). Locked
  /// phones count as away, so this is long.
  static const emptyHold = Duration(minutes: 10);

  /// No light goes out in the first 15 s of the night (the person's choice).
  static const lightsHold = Duration(seconds: 15);
  static const dawnPause = Duration(seconds: 3);
  static const farewellTime = Duration(seconds: 15);

  /// The rules. Not for the TV to display from: it holds every role and vote.
  @visibleForTesting
  late WolfGame game;
  WolfStage stage = WolfStage.night;
  Duration _stageEnd = Duration.zero;
  Timer? _timer;
  Timer? _lightTimer;
  Timer? _emptyTimer;
  final _away = <int>{};
  final _wish = WishBox();

  /// Called once when nobody still in has been connected for [emptyHold].
  void Function()? onAbandon;

  /// Everyone still in the game, connected or not (a locked phone drops its
  /// socket): the players waited for and counted. Only a kick removes one.
  List<int> get present => game.alive;

  /// Before night 1: everyone looks at the role and presses "Spreman"; night 1
  /// starts when every player still in has (connected or not; only the host's
  /// kick moves on without someone).
  final _ready = <int>{};
  bool get readyOpen => stage == WolfStage.ready;
  int get readyCount => present.where(_ready.contains).length;
  int get readyTotal => present.length;

  /// "Idemo glasati", by day only: wishes of the living players (connected or not).
  bool get wishOpen => stage == WolfStage.day;
  int get wishCount => wishOpen ? _wish.want(present) : 0;
  int get wishNeeded => WishBox.needed(present.length);

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

  /// Names as they were when the night began: a player kicked tonight keeps
  /// the row and the name, whether or not still connected.
  var _nightNames = <int, String>{};
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
    _setStage(WolfStage.ready, Duration.zero); // no clock: night 1 starts when everyone is ready
    _sendReady();
    notify?.call();
    _checkEmpty();
  }

  PlayWait _readyMsg(int id) => PlayWait(ready: _ready.contains(id), count: readyCount, total: readyTotal);

  void _sendReady() {
    for (final id in present) {
      send(id, _readyMsg(id));
    }
  }

  /// A phone's "Spreman": only before night 1, only from a player still in.
  void onReadyToPlay(int id) {
    if (!readyOpen || !game.isAlive(id)) return;
    _ready.add(id);
    _afterReady();
  }

  void _afterReady() {
    if (!readyOpen) return;
    if (present.every(_ready.contains)) return _beginNight();
    _sendReady();
    notify?.call();
  }

  void dispose() {
    _timer?.cancel();
    _lightTimer?.cancel();
    _emptyTimer?.cancel();
  }

  void _sendRole(int id) => send(
      id,
      RoleMsg(game.roleOf(id), game.mates(id), [for (final r in WolfRole.values) if (settings.wolfRoles.contains(r)) r],
          hide: settings.wolfHideRoles));

  // ---- night ----

  void _beginNight() {
    sfx.play(Sound.nightAmbience);
    story.add(game.night == 1 ? const WolfEvent('firstNight') : WolfEvent('nightFalls', {'night': game.night}));
    _setStage(WolfStage.night, Duration.zero); // no clock: it ends when every task is done
    _prompts.clear();
    _nightIds = alive;
    _nightNames = {for (final a in _nightIds) a: nameOf(a)};
    for (final id in alive) {
      _prompts[id] = game.hasNightAction(id) ? _Task.actor() : _Task.sum(random, alive.length);
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
    _checkEmpty();
    _checkNightDone();
  }

  /// The night ends when every living player has finished (a sleeping phone
  /// is waited for; only the host's kick moves on). The 15 s of [lightsHold] only hides who
  /// is done; it is not a deadline.
  void _checkNightDone() {
    if (stage == WolfStage.night && game.nightComplete) _endNight();
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
      return WolfText.sum(s.a, s.b);
    }
    switch (role) {
      case WolfRole.wolf:
      case WolfRole.alpha:
      case WolfRole.lone:
        final seen = [
          for (final m in game.mates(id))
            if (game.pickOf(m) != null) '${nameOf(m)} → ${nameOf(game.pickOf(m)!)}'
        ];
        return '${WolfText.hintWolves}${seen.isEmpty ? '' : ' ${seen.join(', ')}'}${role == WolfRole.alpha && game.hasPower(id) ? WolfText.hintAlpha : ''}';
      case WolfRole.seer:
        return WolfText.hintSeer;
      case WolfRole.doc:
        return WolfText.hintDoc;
      case WolfRole.guard:
        return WolfText.hintGuard;
      case WolfRole.herb:
        return game.hasPower(id) ? WolfText.hintHerb : WolfText.hintHerbCure;
      case WolfRole.cupid:
        return _cupidSecond(id) ? WolfText.hintCupid2 : WolfText.hintCupid;
      default:
        return '';
    }
  }

  NightPrompt _prompt(int id) {
    final t = _prompts[id]!;
    final names = [for (final a in _nightIds) _nightNames[a] ?? nameOf(a)];
    List<String> c1;
    List<int> i1;
    if (t.sum != null) {
      c1 = [for (final a in t.sum!.answers) '$a'];
      i1 = [for (var k = 0; k < c1.length; k++) k];
    } else if (_cupidSecond(id)) {
      // Only this phone ever gets this list: not self, not the first lover.
      i1 = [for (final a in _nightIds) if (a != id && a != t.first && game.isAlive(a)) a];
      c1 = [for (final a in i1) _nightNames[a] ?? nameOf(a)];
    } else {
      c1 = names;
      i1 = _nightIds;
    }
    final second = _cupidSecond(id);
    return NightPrompt(
      night: game.night,
      text: WolfText.pad(_hint(id)),
      choices: c1,
      ids: i1,
      picked: second ? null : t.first,
      picked2: t.second,
      special: t.special,
      // The same row positions grey on every phone: a sum's ids are the
      // positions in _nightIds, so a kicked player's position is its id.
      out: t.sum != null
          ? [for (var k = 0; k < _nightIds.length; k++) if (!game.isAlive(_nightIds[k])) k]
          : [for (final a in i1) if (!game.isAlive(a)) a],
      power: game.hasPower(id),
      done: game.hasPicked(id),
    );
  }

  /// The Provodadžija's first lover is in and the second is not (night 1).
  bool _cupidSecond(int id) {
    final t = _prompts[id];
    return game.night == 1 && game.roleOf(id) == WolfRole.cupid && t?.first != null && !game.hasPicked(id);
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
    if (game.night == 1 && game.roleOf(id) == WolfRole.cupid) {
      final first = t.first;
      final target = m.target;
      // A refused pick gets the current list back, so the phone never sits on a
      // card for a pick that did not count.
      if (target == null || target == id || !game.isAlive(target) || target == first) return send(id, _prompt(id));
      if (first == null) {
        // The first lover: quiet. Only this phone gets the next list; nobody
        // else hears anything, the TV does not change, the light stays on.
        t.first = target;
        send(id, _prompt(id));
        return;
      }
      if (!game.pick(id, first, special: m.special, second: target)) return send(id, _prompt(id));
      t.second = target;
      t.special = m.special;
      _refreshShown();
      _sendPrompts();
      notify?.call();
      _checkNightDone();
      return;
    }
    if (game.hasNightAction(id)) {
      final ok = game.pick(id, m.target, special: m.special);
      if (!ok) game.pick(id, null);
    } else {
      game.pick(id, null); // a sum: any answer is done, none does anything
    }
    // The phone's own choice is echoed back on reconnect for EVERY role alike.
    t.first = m.target;
    t.special = m.special;
    _refreshShown();
    _sendPrompts();
    notify?.call();
    _checkNightDone();
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
    _setStage(WolfStage.day, Duration.zero); // no clock: the players decide
    _wish.clear();
    _sendWishes();
    _checkEmpty();
    notify?.call();
  }

  VoteWish _wishMsg(int id) =>
      VoteWish(open: true, ready: _wish.has(id), want: wishCount, needed: wishNeeded);

  void _sendWishes() {
    if (!wishOpen) return;
    for (final id in present) {
      send(id, _wishMsg(id));
    }
  }

  /// A phone's "Idemo glasati" wish: only by day, only from the living.
  void onReady(int id, ReadyToVote m) {
    if (!wishOpen || !game.isAlive(id)) return;
    _wish.set(id, m.on);
    _afterWishChange();
  }

  void _afterWishChange() {
    if (!wishOpen) return;
    if (_wish.majority(present)) return _beginVote();
    _sendWishes();
    notify?.call();
  }

  void _beginVote() {
    game.startVote();
    sfx.play(Sound.voteBell);
    story.add(const WolfEvent('voteStarts'));
    _setStage(WolfStage.vote, Duration.zero); // ends when every living player who may vote has voted
    _voted.clear();
    _wish.clear();
    _voteIds = alive;
    for (final id in alive) {
      send(id, VotePrompt(day: day, seconds: 0, ids: _voteIds, canVote: game.canVote(id)));
    }
    notify?.call();
    _checkEmpty();
    _checkVoteDone();
  }

  /// Every living player who may vote has voted (a sleeping phone is waited
  /// for; only the kick moves on). If nobody left may vote (all silenced), it
  /// ends at once.
  void _checkVoteDone() {
    if (stage != WolfStage.vote) return;
    if (present.where(game.canVote).every(_voted.contains)) _endVote();
  }

  void onVote(int id, Vote m) {
    if (stage != WolfStage.vote) return;
    if (!game.vote(id, m.target)) return;
    _voted.add(id);
    notify?.call();
    _checkVoteDone();
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
    _emptyTimer?.cancel();
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
    _wish.set(id, false);
    _ready.remove(id);
    // A first lover who was just kicked: that phone starts over on the first list.
    if (stage == WolfStage.night) {
      for (final c in alive) {
        final t = _prompts[c];
        if (t != null && t.first == id && game.roleOf(c) == WolfRole.cupid && !game.hasPicked(c)) {
          t.first = null;
          send(c, _prompt(c));
        }
      }
    }
    if (stage == WolfStage.night) _sendPrompts(); // the row stays, greyed
    _afterReady();
    _checkNightDone();
    _checkVoteDone();
    _afterWishChange();
    _checkEmpty();
    notify?.call();
  }

  // ---- phones leaving and coming back ----

  /// [id] lost its connection (or came back). Nothing is waited for any
  /// differently: a sleeping phone keeps its night task, its vote and its
  /// wish. Only the host's kick moves on. This only feeds the empty-room hold.
  void setAway(int id, bool away) {
    if (!ids.contains(id) || stage == WolfStage.over) return;
    if (away ? !_away.add(id) : !_away.remove(id)) return;
    _checkEmpty();
  }

  void _checkEmpty() {
    _emptyTimer?.cancel();
    _emptyTimer = null;
    final waiting = stage == WolfStage.ready || stage == WolfStage.night || stage == WolfStage.day || stage == WolfStage.vote;
    if (waiting && game.alive.every(_away.contains)) _emptyTimer = Timer(emptyHold, () => onAbandon?.call());
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
    } else if (stage == WolfStage.ready) {
      send(id, _readyMsg(id));
    } else if (stage == WolfStage.night) {
      send(id, _prompt(id));
    } else if (stage == WolfStage.vote) {
      send(id, VotePrompt(day: day, seconds: 0, ids: _voteIds, canVote: game.canVote(id), picked: game.voteOf(id)));
    } else if (_morning.containsKey(id)) {
      send(id, Morning(day, _morning[id]!));
      if (stage == WolfStage.day) send(id, _wishMsg(id));
    }
  }
}

class _Task {
  _Task.actor() : sum = null;
  _Task.sum(Random r, int count) : sum = NightSum.draw(r, count: count);
  final NightSum? sum;
  int? first;
  int? second;
  bool special = false;
}
