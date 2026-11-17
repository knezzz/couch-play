import 'dart:math';

/// Vukodlak: the rules of the werewolf-style game, pure Dart, no I/O.
///
/// The engine takes player ids (ints) and answers with ids; the session turns
/// those into names, Croatian text and private messages. Every player alive at
/// night makes ONE pick (villagers too, so every phone looks busy), plus a
/// `special` flag every phone carries and only some roles read.
///
/// Rule readings where WolfRoles.dc.html leaves room (simplest reading wins):
///  * Wolves choose the victim by plurality of the pack's picks; a tie is
///    drawn by the seeded random; no pick, no attack. A wolf picking a
///    packmate counts for nothing.
///  * Night order: doctor protection, herbalist cure, bodyguard, elder,
///    alpha conversion, death; the herbalist's poison kills on its own.
///  * Doctor: may protect himself; the same player two nights running is
///    ignored. Bodyguard: guarding the victim means the bodyguard dies
///    instead (the victim lives); guarding himself is ignored.
///  * Herbalist: special off = cure the picked player (works only if they
///    are the victim; the cure is spent only when it saves someone). Special
///    on = poison the picked player (once; not himself).
///  * Alpha: special on, his own pick is the pack's victim, conversion unused,
///    and the attack would have killed: the victim becomes an ordinary
///    Vukodlak instead of dying.
///  * Elder: the first wolf attack that reaches him fails, once.
///  * Cupid (night 1 only): picks two OTHER players, who become lovers. Night 1
///    has two picks on every phone (the second is ignored for everyone else).
///    If one lover leaves, so does the other.
///  * Seer: learns the exact role of the picked player (as of the start of
///    that night).
///  * Hunter: whenever he leaves (night, vote, lover, poison), he must shoot
///    one alive player, or skip. The session gives EVERY player who leaves
///    the same farewell window so the wait does not tell who was a hunter.
///    Win checks wait until no shot is pending.
///  * Vote: plurality of votes (skips count for nobody); mayor's vote is 2;
///    a tie goes to the mayor's pick if it is one of the tied, otherwise
///    nobody is out. A fool is spared the first time (stays, cannot vote any
///    more); after that an ordinary vote. A tramp voted out wins alone.
///  * Win: no wolf-side player alive: village. Wolf side (Vukodlak, Vođa,
///    Vuk samotnjak) not smaller than the rest while a pack wolf (not the
///    lone wolf) is alive: wolves. The lone wolf wins only as the last one
///    alive. Nobody alive: nobody. Lovers have no win of their own.
enum WolfTeam { wolves, village, solo }

/// Declaration order is the order on the roles screen.
enum WolfRole {
  wolf(WolfTeam.wolves),
  alpha(WolfTeam.wolves),
  lone(WolfTeam.wolves),
  villager(WolfTeam.village),
  seer(WolfTeam.village),
  doc(WolfTeam.village),
  guard(WolfTeam.village),
  herb(WolfTeam.village),
  hunter(WolfTeam.village),
  elder(WolfTeam.village),
  mayor(WolfTeam.village),
  cupid(WolfTeam.village),
  fool(WolfTeam.village),
  tramp(WolfTeam.solo);

  const WolfRole(this.team);
  final WolfTeam team;
  bool get isWolf => team == WolfTeam.wolves;

  static WolfRole? byName(String? n) {
    for (final r in values) {
      if (r.name == n) return r;
    }
    return null;
  }
}

/// Roles that are always in the mix.
const wolfAlwaysOn = {WolfRole.wolf, WolfRole.villager};

/// Roles the draw hands out as "special" ones.
final wolfSpecials = [
  for (final r in WolfRole.values)
    if (!r.isWolf && r != WolfRole.villager) r
];

int wolfCount(int players) => players <= 6 ? 1 : 2;

/// The mix for [players] people from the roles switched [on]: Vukodlak and
/// Seljanin are always on. Length is [players]; the result is shuffled.
List<WolfRole> drawRoles(int players, Set<WolfRole> on, Random random) {
  final w = wolfCount(players);
  final pool = [for (final r in wolfSpecials) if (on.contains(r)) r]..shuffle(random);
  final k = min(max(players - w - 2, 0), pool.length);
  final roles = <WolfRole>[...pool.take(k)];
  // Each wolf slot may be an ordinary wolf, or the alpha / lone wolf once.
  final wolfKinds = <WolfRole>[
    WolfRole.wolf,
    if (on.contains(WolfRole.alpha)) WolfRole.alpha,
    if (on.contains(WolfRole.lone)) WolfRole.lone,
  ];
  final usedUnique = <WolfRole>{};
  for (var i = 0; i < w; i++) {
    final choices = [
      for (final r in wolfKinds)
        if (r == WolfRole.wolf || !usedUnique.contains(r)) r
    ];
    final r = choices[random.nextInt(choices.length)];
    usedUnique.add(r);
    roles.add(r);
  }
  while (roles.length < players) {
    roles.add(WolfRole.villager);
  }
  return roles..shuffle(random);
}

/// The night task of a player with no night action: a times-table sum with
/// five answers. A wrong answer counts as done like a right one.
class NightSum {
  const NightSum(this.a, this.b, this.answers, this.correct);
  final int a, b;
  final List<int> answers;
  final int correct;

  factory NightSum.draw(Random random) {
    final a = 3 + random.nextInt(7), b = 3 + random.nextInt(7);
    final right = a * b;
    final wrong = <int>{};
    while (wrong.length < 4) {
      final x = right + (random.nextInt(21) - 10);
      if (x > 0 && x != right) wrong.add(x);
    }
    final answers = [...wrong, right]..shuffle(random);
    return NightSum(a, b, answers, answers.indexOf(right));
  }
}

enum WolfPhase { night, day, vote, over }

enum WolfWinner { village, wolves, lone, tramp, nobody }

enum DeathCause { wolves, poison, guard, lover, vote, shot }

class WolfDeath {
  const WolfDeath(this.id, this.cause);
  final int id;
  final DeathCause cause;
  @override
  String toString() => 'WolfDeath($id, $cause)';
}

/// A story event for the TV. [key] and [args] are the contract with the story
/// writers: args hold player ids under 'player' / 'partner' / 'hunter',
/// numbers under 'votes' / 'count' / 'night', and 'role' (a [WolfRole] name)
/// only when the role may be shown (hidden roles off, or the game is over).
class WolfEvent {
  const WolfEvent(this.key, [this.args = const {}]);
  final String key;
  final Map<String, Object> args;
  @override
  String toString() => 'WolfEvent($key, $args)';
}

/// A private fact for one player after the night: 'saw' (seer: [target] and
/// [role]), 'lover' (the partner is [target]; the cupid gets none), 'converted' (you are a wolf now).
class WolfNote {
  const WolfNote(this.kind, {this.target, this.role});
  final String kind;
  final int? target;
  final WolfRole? role;
  @override
  String toString() => 'WolfNote($kind, $target, $role)';
}

class NightResult {
  NightResult(this.deaths, this.converted, this.notes, this.events, {this.attacked, this.saved = false});
  final List<WolfDeath> deaths;
  final int? converted;
  final Map<int, List<WolfNote>> notes;
  final List<WolfEvent> events;

  /// The pack's victim, and whether they lived. Not for phones: for tests.
  final int? attacked;
  final bool saved;
}

class VoteResult {
  VoteResult(this.votes, this.out, this.events, {this.spared = false, this.tie = false});
  final Map<int, int?> votes;

  /// Who the village voted out (also a spared fool or a winning tramp), or null.
  final int? out;
  final bool spared;
  final bool tie;
  final List<WolfEvent> events;
}

class WolfGame {
  WolfGame(Map<int, WolfRole> roles, {this.hideRoles = true, Random? random})
      : _roles = Map.of(roles),
        _random = random ?? Random() {
    startNight();
  }

  final bool hideRoles;
  final Map<int, WolfRole> _roles;
  final Random _random;
  final Set<int> _out = {};
  final Set<int> _silenced = {};
  final List<int> _pendingHunters = [];
  final Map<int, ({int? target, int? second, bool special})> _picks = {};
  final Map<int, int?> _votes = {};
  final Set<int> _lovers = {};

  WolfPhase _phase = WolfPhase.night;
  WolfWinner? _winner;
  int? _tramp;
  int night = 0;
  int? _lastDocPick;
  bool _cureUsed = false, _poisonUsed = false, _alphaUsed = false, _elderUsed = false;

  WolfPhase get phase => _phase;
  WolfWinner? get winner => _winner;
  List<int> get ids => _roles.keys.toList();
  List<int> get alive => [for (final id in _roles.keys) if (!_out.contains(id)) id];
  bool isAlive(int id) => _roles.containsKey(id) && !_out.contains(id);
  WolfRole roleOf(int id) => _roles[id]!;
  List<int> get pendingHunters => List.unmodifiable(_pendingHunters);
  Set<int> get lovers => Set.unmodifiable(_lovers);
  bool canVote(int id) => isAlive(id) && !_silenced.contains(id);

  /// The role an onlooker (the TV, other phones) may see: null for someone
  /// still in, and for someone out while roles are hidden; everything once
  /// the game is over.
  WolfRole? publicRole(int id) => _winner != null || (!hideRoles && _out.contains(id)) ? _roles[id] : null;

  /// The wolf-side players other than [id], if [id] is wolf-side (the pack
  /// knows itself); else empty.
  List<int> mates(int id) =>
      _roles[id]?.isWolf == true ? [for (final o in _roles.keys) if (o != id && _roles[o]!.isWolf) o] : [];

  /// What [id] picked tonight so far (null: nothing or skipped).
  int? pickOf(int id) => _picks[id]?.target;
  bool hasPicked(int id) => _picks.containsKey(id);

  /// Who has finished tonight: the ONLY per-player state phones and the TV may
  /// learn during the night (never what was picked, never why).
  Set<int> get done => {..._picks.keys};

  /// True if [id]'s night task is a real action; false: a sum with no effect.
  /// Seer, doctor, bodyguard and wolves always act; the cupid only on night 1;
  /// the herbalist while a potion is left.
  bool hasNightAction(int id) {
    final r = _roles[id];
    if (r == null) return false;
    return switch (r) {
      WolfRole.wolf || WolfRole.alpha || WolfRole.lone || WolfRole.seer || WolfRole.doc || WolfRole.guard => true,
      WolfRole.cupid => night == 1,
      WolfRole.herb => !_cureUsed || !_poisonUsed,
      _ => false,
    };
  }

  bool get nightComplete => alive.every(_picks.containsKey);

  void startNight() {
    if (_winner != null) throw StateError('game is over');
    if (_pendingHunters.isNotEmpty) throw StateError('a hunter has not shot yet');
    night++;
    _picks.clear();
    _phase = WolfPhase.night;
  }

  /// A night pick by [who]; [target] null = skip. False (and nothing stored)
  /// if it is not night, [who] is out, or [target] is not an alive player.
  /// A pick with no effect (a wolf on a wolf, a repeat protection) is
  /// accepted and ignored, so a phone cannot learn anything from it.
  bool pick(int who, int? target, {bool special = false, int? second}) {
    if (_phase != WolfPhase.night || !isAlive(who)) return false;
    if (target != null && !isAlive(target)) return false;
    if (second != null && !isAlive(second)) return false;
    _picks[who] = (target: target, second: second, special: special);
    return true;
  }

  List<int> _alive(bool Function(WolfRole) test) =>
      [for (final id in alive) if (test(_roles[id]!)) id];

  int? _pickOfRole(WolfRole r) {
    for (final id in _alive((x) => x == r)) {
      return _picks[id]?.target;
    }
    return null;
  }

  NightResult resolveNight() {
    if (_phase != WolfPhase.night) throw StateError('not night');
    final events = <WolfEvent>[];
    final notes = <int, List<WolfNote>>{};
    final rolesAtStart = Map.of(_roles);
    final deaths = <WolfDeath>[];
    int? converted;

    // Lovers, night 1 only.
    if (night == 1) {
      for (final c in _alive((r) => r == WolfRole.cupid)) {
        final a = _picks[c]?.target, b = _picks[c]?.second;
        if (a != null && b != null && a != b && a != c && b != c && _lovers.isEmpty) {
          _lovers
            ..add(a)
            ..add(b);
          notes.putIfAbsent(a, () => []).add(WolfNote('lover', target: b));
          notes.putIfAbsent(b, () => []).add(WolfNote('lover', target: a));
        }
      }
    }

    // The pack's victim: plurality, a tie drawn.
    final tally = <int, int>{};
    for (final id in _alive((r) => r.isWolf)) {
      final t = _picks[id]?.target;
      if (t != null && !_roles[t]!.isWolf) tally[t] = (tally[t] ?? 0) + 1;
    }
    int? victim;
    if (tally.isNotEmpty) {
      final top = tally.values.reduce(max);
      final tied = [for (final e in tally.entries) if (e.value == top) e.key]..sort();
      victim = tied[_random.nextInt(tied.length)];
    }

    var saved = false;
    var dies = victim != null;
    int? guardDies;
    if (victim != null) {
      final docPick = _pickOfRole(WolfRole.doc);
      final docOk = docPick != null && docPick != _lastDocPick;
      final herb = _alive((r) => r == WolfRole.herb);
      final herbPick = herb.isEmpty ? null : _picks[herb.first];
      if (docOk && docPick == victim) {
        dies = false;
        saved = true;
      } else if (herbPick != null && !herbPick.special && herbPick.target == victim && !_cureUsed) {
        _cureUsed = true;
        dies = false;
        saved = true;
      } else if (_alive((r) => r == WolfRole.guard).any((g) => g != victim && _picks[g]?.target == victim)) {
        guardDies = _alive((r) => r == WolfRole.guard).firstWhere((g) => g != victim && _picks[g]?.target == victim);
        dies = false;
        saved = true;
      } else if (_roles[victim] == WolfRole.elder && !_elderUsed) {
        _elderUsed = true;
        dies = false;
        saved = true;
      } else {
        final alphas = _alive((r) => r == WolfRole.alpha);
        final a = alphas.isEmpty ? null : alphas.first;
        if (a != null && !_alphaUsed && _picks[a]!.special && _picks[a]!.target == victim) {
          _alphaUsed = true;
          _roles[victim] = WolfRole.wolf;
          converted = victim;
          dies = false;
          notes.putIfAbsent(victim, () => []).add(const WolfNote('converted'));
        }
      }
    }
    _lastDocPick = _pickOfRole(WolfRole.doc);

    // Herbalist's poison: independent of the attack.
    int? poisoned;
    for (final h in _alive((r) => r == WolfRole.herb)) {
      final p = _picks[h];
      if (p != null && p.special && !_poisonUsed && p.target != null && p.target != h) {
        _poisonUsed = true;
        poisoned = p.target;
      }
    }

    // Seer, from the roles as the night began.
    for (final s in _alive((r) => r == WolfRole.seer)) {
      final t = _picks[s]?.target;
      if (t != null && t != s) notes.putIfAbsent(s, () => []).add(WolfNote('saw', target: t, role: rolesAtStart[t]));
    }

    if (dies) _kill(victim!, DeathCause.wolves, deaths);
    if (guardDies != null) _kill(guardDies, DeathCause.guard, deaths);
    if (poisoned != null) _kill(poisoned, DeathCause.poison, deaths);
    notes.removeWhere((id, _) => _out.contains(id));

    _phase = WolfPhase.day;
    if (deaths.isEmpty) {
      events.add(const WolfEvent('morningNobody'));
    } else {
      for (final d in deaths) {
        events.add(_deathEvent(d));
      }
    }
    if (_pendingHunters.isEmpty) _checkWin(events);
    return NightResult(deaths, converted, notes, events, attacked: victim, saved: saved);
  }

  WolfEvent _deathEvent(WolfDeath d) {
    final args = <String, Object>{'player': d.id};
    if (publicRole(d.id) != null || !hideRoles) args['role'] = _roles[d.id]!.name;
    return WolfEvent(d.cause == DeathCause.lover ? 'loverDied' : 'morningDied', args);
  }

  /// Marks [id] out, and their lover; a hunter is queued to shoot.
  void _kill(int id, DeathCause cause, List<WolfDeath> into) {
    if (_out.contains(id)) return;
    _out.add(id);
    into.add(WolfDeath(id, cause));
    if (_roles[id] == WolfRole.hunter) _pendingHunters.add(id);
    if (_lovers.contains(id)) {
      for (final o in _lovers) {
        if (o != id && !_out.contains(o)) _kill(o, DeathCause.lover, into);
      }
    }
  }

  /// A dead hunter's shot at [target] (an alive player), or null to skip.
  /// Returns the deaths; throws if [hunter] has no shot pending.
  List<WolfDeath> shoot(int hunter, int? target) {
    if (!_pendingHunters.contains(hunter)) throw StateError('no shot pending for $hunter');
    final deaths = <WolfDeath>[];
    final events = <WolfEvent>[];
    _pendingHunters.remove(hunter);
    if (target != null && isAlive(target)) {
      _kill(target, DeathCause.shot, deaths);
      for (final d in deaths) {
        final args = <String, Object>{'hunter': hunter, 'player': d.id};
        if (!hideRoles) args['role'] = _roles[d.id]!.name;
        events.add(WolfEvent(d.cause == DeathCause.shot ? 'hunterShot' : 'loverDied', args));
      }
    }
    if (_pendingHunters.isEmpty) _checkWin(events);
    lastShotEvents = events;
    return deaths;
  }

  /// Story events of the latest [shoot].
  List<WolfEvent> lastShotEvents = const [];

  void startVote() {
    if (_phase != WolfPhase.day) throw StateError('not day');
    _votes.clear();
    _phase = WolfPhase.vote;
  }

  /// A day vote; [target] null = skip. False when it does not count: not the
  /// vote phase, [who] cannot vote, [target] is [who] or not alive.
  bool vote(int who, int? target) {
    if (_phase != WolfPhase.vote || !canVote(who)) return false;
    if (target != null && (target == who || !isAlive(target))) return false;
    _votes[who] = target;
    return true;
  }

  bool get voteComplete => alive.where(canVote).every(_votes.containsKey);

  VoteResult resolveVote() {
    if (_phase != WolfPhase.vote) throw StateError('not the vote phase');
    final events = <WolfEvent>[];
    final votes = Map<int, int?>.of(_votes);
    final tally = <int, int>{};
    for (final e in votes.entries) {
      final t = e.value;
      if (t == null) continue;
      tally[t] = (tally[t] ?? 0) + (_roles[e.key] == WolfRole.mayor ? 2 : 1);
    }
    _phase = WolfPhase.day;
    if (tally.isEmpty) {
      events.add(const WolfEvent('voteNobody'));
      return VoteResult(votes, null, events);
    }
    final top = tally.values.reduce(max);
    final tied = [for (final e in tally.entries) if (e.value == top) e.key];
    int? out;
    var viaMayor = false;
    if (tied.length == 1) {
      out = tied.first;
    } else {
      final mayors = _alive((r) => r == WolfRole.mayor);
      final mv = mayors.isEmpty ? null : votes[mayors.first];
      if (mv != null && tied.contains(mv)) {
        out = mv;
        viaMayor = true;
      }
    }
    if (out == null) {
      events.add(const WolfEvent('voteTie'));
      return VoteResult(votes, null, events, tie: true);
    }
    final args = <String, Object>{'player': out, 'votes': top};
    if (viaMayor) events.add(WolfEvent('mayorBreaksTie', {'player': mayorOf()!}));
    if (_roles[out] == WolfRole.fool && !_silenced.contains(out)) {
      _silenced.add(out);
      events.add(WolfEvent('foolSpared', {'player': out}));
      return VoteResult(votes, out, events, spared: true);
    }
    if (_roles[out] == WolfRole.tramp) {
      _out.add(out);
      _tramp = out;
      events.add(WolfEvent('trampWins', {'player': out}));
      _winner = WolfWinner.tramp;
      _phase = WolfPhase.over;
      events.add(const WolfEvent('gameOver', {'winner': 'tramp'}));
      return VoteResult(votes, out, events);
    }
    final deaths = <WolfDeath>[];
    _kill(out, DeathCause.vote, deaths);
    if (!hideRoles) args['role'] = _roles[out]!.name;
    events.add(WolfEvent('voteOut', args));
    for (final d in deaths.skip(1)) {
      events.add(_deathEvent(d));
    }
    if (_pendingHunters.isEmpty) _checkWin(events);
    return VoteResult(votes, out, events);
  }

  int? mayorOf() {
    final m = _alive((r) => r == WolfRole.mayor);
    return m.isEmpty ? null : m.first;
  }

  int? get tramp => _tramp;

  void _checkWin(List<WolfEvent> events) {
    if (_winner != null) return;
    final a = alive;
    final wolfSide = a.where((id) => _roles[id]!.isWolf).length;
    final pack = a.where((id) => _roles[id] == WolfRole.wolf || _roles[id] == WolfRole.alpha).length;
    WolfWinner? w;
    if (a.isEmpty) {
      w = WolfWinner.nobody;
    } else if (wolfSide == 0) {
      w = WolfWinner.village;
    } else if (a.length == 1 && _roles[a.first] == WolfRole.lone) {
      w = WolfWinner.lone;
    } else if (pack > 0 && wolfSide >= a.length - wolfSide) {
      w = WolfWinner.wolves;
    }
    if (w == null) return;
    _winner = w;
    _phase = WolfPhase.over;
    events.add(WolfEvent('gameOver', {'winner': w.name}));
  }
}
