import 'dart:convert';

import 'kaosvi.dart' show KaosviMergeItem;
import 'uljez.dart';
import 'wolf.dart';

enum GameKind { quiz, curve, vukodlak, uljez, objasni, koliko, blef, tkobi, kaosvi }

/// Value equality from the JSON form, so every wire type compares by content.
mixin _JsonEq {
  Map<String, Object?> toJson();
  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      jsonEncode(toJson()) == jsonEncode((other as _JsonEq).toJson());
  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

class PlayerInfo with _JsonEq {
  final int id, colorIndex, sessionScore;
  final String name;
  final bool connected, bot;

  /// An id from `characterIds`; '' while none is chosen.
  final String character;
  const PlayerInfo(
      this.id, this.name, this.colorIndex, this.connected, this.sessionScore,
      {this.bot = false, this.character = ''});
  factory PlayerInfo.fromJson(Map<String, dynamic> j) => PlayerInfo(
      j['id'] as int,
      j['name'] as String,
      j['colorIndex'] as int,
      j['connected'] as bool,
      j['sessionScore'] as int,
      bot: (j['bot'] as bool?) ?? false,
      character: (j['character'] as String?) ?? '');
  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'colorIndex': colorIndex,
        'connected': connected,
        'sessionScore': sessionScore,
        'bot': bot,
        'character': character,
      };
}

/// How power-ups behave in a Curve match (the TV turns it into CurveConfig
/// values): chaos = many, balanced = today's, peaceful = none, onlyYou = only
/// the green (helpful) kinds.
enum CurveMode { chaos, balanced, peaceful, onlyYou }

/// What the host can set in the lobby. Seconds, or a count of questions.
class GameSettings with _JsonEq {
  /// Time to answer a question: 10-60 in steps of 5.
  final int quizSeconds;

  /// Questions per game: 5-30 in steps of 5 (never more than the pack has).
  final int quizQuestions;

  /// How long the answer shows between questions: 2-15.
  final int revealSeconds;

  /// Curve pause before each round: 1-10.
  final int curveCountdown;

  /// Curve power-up mode.
  final CurveMode curveMode;

  /// The quiz pack the host picked; null means the TV's default pack.
  final String? quizPackId;

  /// Vukodlak: the roles that may be drawn (Vukodlak and Seljanin are always
  /// in) and whether a player who is out stays unrevealed until the end. (The
  /// day has no clock; old settings messages with a discussion time still decode.)
  final Set<WolfRole> wolfRoles;
  final bool wolfHideRoles;

  /// Uljez: the word pack (null = the TV's first pack) and 1 or 2 impostors (2
  /// only counts with 7-8 players).
  final String? uljezPackId;
  final int uljezImpostors;

  /// Objasni: seconds per turn (45 / 60 / 90), target score (20 / 30 / 50), word pack.
  final int objasniSeconds, objasniTarget;
  final String? objasniPackId;

  /// Koliko?: seconds per question (20 / 30 / 45), questions (5 / 10 / 15), pack.
  final int kolikoSeconds, kolikoQuestions;
  final String? kolikoPackId;

  /// Blef: questions (5 / 7 / 10), pack.
  final int blefQuestions;
  final String? blefPackId;

  /// Tko bi?: prompts (5 / 10 / 15), pack.
  final int tkobiPrompts;
  final String? tkobiPackId;

  /// Kao svi: questions (8 / 12 / 16), target score (5 / 8 / 10), pack.
  final int kaosviQuestions, kaosviTarget;
  final String? kaosviPackId;
  /// Packs are multi-select in every game: the ids of the packs that are
  /// switched OFF, per game. Empty (the default) = every pack is ticked, so a
  /// pack that appears later starts ticked. The session keeps at least one
  /// pack ticked. The single `<game>PackId` above is the old way: an old
  /// message with one is turned into "only that pack" by the session.
  final Set<String> quizOffPacks, uljezOffPacks, objasniOffPacks, kolikoOffPacks, blefOffPacks, tkobiOffPacks, kaosviOffPacks;

  /// The off-set of [game] (empty for a game without packs).
  Set<String> offPacks(GameKind game) => switch (game) {
        GameKind.quiz => quizOffPacks,
        GameKind.uljez => uljezOffPacks,
        GameKind.objasni => objasniOffPacks,
        GameKind.koliko => kolikoOffPacks,
        GameKind.blef => blefOffPacks,
        GameKind.tkobi => tkobiOffPacks,
        GameKind.kaosvi => kaosviOffPacks,
        _ => const {},
      };

  static const defaultWolfRoles = {
    WolfRole.wolf,
    WolfRole.villager,
    WolfRole.seer,
    WolfRole.doc,
    WolfRole.hunter,
    WolfRole.herb,
  };
  const GameSettings({
    this.quizSeconds = 20,
    this.quizQuestions = 10,
    this.revealSeconds = 4,
    this.curveCountdown = 2,
    this.curveMode = CurveMode.balanced,
    this.quizPackId,
    this.wolfRoles = defaultWolfRoles,
    this.wolfHideRoles = true,
    this.uljezPackId,
    this.uljezImpostors = 1,
    this.objasniSeconds = 60,
    this.objasniTarget = 30,
    this.objasniPackId,
    this.kolikoSeconds = 30,
    this.kolikoQuestions = 10,
    this.kolikoPackId,
    this.blefQuestions = 7,
    this.blefPackId,
    this.tkobiPrompts = 10,
    this.tkobiPackId,
    this.kaosviQuestions = 12,
    this.kaosviTarget = 8,
    this.kaosviPackId,
    this.quizOffPacks = const {},
    this.uljezOffPacks = const {},
    this.objasniOffPacks = const {},
    this.kolikoOffPacks = const {},
    this.blefOffPacks = const {},
    this.tkobiOffPacks = const {},
    this.kaosviOffPacks = const {},
  });
  factory GameSettings.fromJson(Map<String, dynamic> j) => GameSettings(
      quizSeconds: j['quizSeconds'] as int,
      quizQuestions: j['quizQuestions'] as int,
      revealSeconds: j['revealSeconds'] as int,
      curveCountdown: j['curveCountdown'] as int,
      curveMode: j['curveMode'] == null
          ? CurveMode.balanced
          : CurveMode.values.byName(j['curveMode'] as String),
      quizPackId: j['quizPackId'] as String?,
      wolfRoles: j['wolfRoles'] == null
          ? defaultWolfRoles
          : {for (final n in j['wolfRoles'] as List) WolfRole.values.byName(n as String)},
      wolfHideRoles: (j['wolfHideRoles'] as bool?) ?? true,
      uljezPackId: j['uljezPackId'] as String?,
      uljezImpostors: (j['uljezImpostors'] as int?) ?? 1,
      objasniSeconds: (j['objasniSeconds'] as int?) ?? 60,
      objasniTarget: (j['objasniTarget'] as int?) ?? 30,
      objasniPackId: j['objasniPackId'] as String?,
      kolikoSeconds: (j['kolikoSeconds'] as int?) ?? 30,
      kolikoQuestions: (j['kolikoQuestions'] as int?) ?? 10,
      kolikoPackId: j['kolikoPackId'] as String?,
      blefQuestions: (j['blefQuestions'] as int?) ?? 7,
      blefPackId: j['blefPackId'] as String?,
      tkobiPrompts: (j['tkobiPrompts'] as int?) ?? 10,
      tkobiPackId: j['tkobiPackId'] as String?,
      kaosviQuestions: (j['kaosviQuestions'] as int?) ?? 12,
      kaosviTarget: (j['kaosviTarget'] as int?) ?? 8,
      kaosviPackId: j['kaosviPackId'] as String?,
      quizOffPacks: _ids(j['quizOffPacks']),
      uljezOffPacks: _ids(j['uljezOffPacks']),
      objasniOffPacks: _ids(j['objasniOffPacks']),
      kolikoOffPacks: _ids(j['kolikoOffPacks']),
      blefOffPacks: _ids(j['blefOffPacks']),
      tkobiOffPacks: _ids(j['tkobiOffPacks']),
      kaosviOffPacks: _ids(j['kaosviOffPacks']));

  static Set<String> _ids(Object? v) => v == null ? const {} : {for (final e in v as List) e as String};

  /// The same settings with the off-sets of the games in [off] replaced (and
  /// their old single pack id cleared: the selection is now the off-set).
  GameSettings withOffPacks(Map<GameKind, Set<String>> off) => GameSettings(
      quizSeconds: quizSeconds,
      quizQuestions: quizQuestions,
      revealSeconds: revealSeconds,
      curveCountdown: curveCountdown,
      curveMode: curveMode,
      quizPackId: off.containsKey(GameKind.quiz) ? null : quizPackId,
      wolfRoles: wolfRoles,
      wolfHideRoles: wolfHideRoles,
      uljezPackId: off.containsKey(GameKind.uljez) ? null : uljezPackId,
      uljezImpostors: uljezImpostors,
      objasniSeconds: objasniSeconds,
      objasniTarget: objasniTarget,
      objasniPackId: off.containsKey(GameKind.objasni) ? null : objasniPackId,
      kolikoSeconds: kolikoSeconds,
      kolikoQuestions: kolikoQuestions,
      kolikoPackId: off.containsKey(GameKind.koliko) ? null : kolikoPackId,
      blefQuestions: blefQuestions,
      blefPackId: off.containsKey(GameKind.blef) ? null : blefPackId,
      tkobiPrompts: tkobiPrompts,
      tkobiPackId: off.containsKey(GameKind.tkobi) ? null : tkobiPackId,
      kaosviQuestions: kaosviQuestions,
      kaosviTarget: kaosviTarget,
      kaosviPackId: off.containsKey(GameKind.kaosvi) ? null : kaosviPackId,
      quizOffPacks: off[GameKind.quiz] ?? quizOffPacks,
      uljezOffPacks: off[GameKind.uljez] ?? uljezOffPacks,
      objasniOffPacks: off[GameKind.objasni] ?? objasniOffPacks,
      kolikoOffPacks: off[GameKind.koliko] ?? kolikoOffPacks,
      blefOffPacks: off[GameKind.blef] ?? blefOffPacks,
      tkobiOffPacks: off[GameKind.tkobi] ?? tkobiOffPacks,
      kaosviOffPacks: off[GameKind.kaosvi] ?? kaosviOffPacks);

  /// The same values pulled into range and onto their steps.
  GameSettings clamped() {
    // The allowed value nearest to v (the lower one on a tie).
    int oneOf(int v, List<int> allowed) =>
        allowed.reduce((a, b) => (a - v).abs() <= (b - v).abs() ? a : b);
    int snap(int v, int lo, int hi, int step) =>
        ((v / step).round() * step).clamp(lo, hi);
    return GameSettings(
      quizSeconds: snap(quizSeconds, 10, 60, 5),
      quizQuestions: snap(quizQuestions, 5, 30, 5),
      revealSeconds: snap(revealSeconds, 2, 15, 1),
      curveCountdown: snap(curveCountdown, 1, 10, 1),
      curveMode: curveMode,
      quizPackId: quizPackId,
      wolfRoles: {...wolfRoles, ...wolfAlwaysOn},
      wolfHideRoles: wolfHideRoles,
      uljezPackId: uljezPackId,
      uljezImpostors: uljezImpostors.clamp(1, 2),
      objasniSeconds: oneOf(objasniSeconds, const [45, 60, 90]),
      objasniTarget: oneOf(objasniTarget, const [20, 30, 50]),
      objasniPackId: objasniPackId,
      kolikoSeconds: oneOf(kolikoSeconds, const [20, 30, 45]),
      kolikoQuestions: oneOf(kolikoQuestions, const [5, 10, 15]),
      kolikoPackId: kolikoPackId,
      blefQuestions: oneOf(blefQuestions, const [5, 7, 10]),
      blefPackId: blefPackId,
      tkobiPrompts: oneOf(tkobiPrompts, const [5, 10, 15]),
      tkobiPackId: tkobiPackId,
      kaosviQuestions: oneOf(kaosviQuestions, const [8, 12, 16]),
      kaosviTarget: oneOf(kaosviTarget, const [5, 8, 10]),
      kaosviPackId: kaosviPackId,
      quizOffPacks: quizOffPacks,
      uljezOffPacks: uljezOffPacks,
      objasniOffPacks: objasniOffPacks,
      kolikoOffPacks: kolikoOffPacks,
      blefOffPacks: blefOffPacks,
      tkobiOffPacks: tkobiOffPacks,
      kaosviOffPacks: kaosviOffPacks,
    );
  }

  @override
  Map<String, Object?> toJson() => {
        'quizSeconds': quizSeconds,
        'quizQuestions': quizQuestions,
        'revealSeconds': revealSeconds,
        'curveCountdown': curveCountdown,
        'curveMode': curveMode.name,
        'quizPackId': quizPackId,
        'wolfRoles': [for (final r in WolfRole.values) if (wolfRoles.contains(r)) r.name],
        'wolfHideRoles': wolfHideRoles,
        'uljezPackId': uljezPackId,
        'uljezImpostors': uljezImpostors,
        'objasniSeconds': objasniSeconds,
        'objasniTarget': objasniTarget,
        'objasniPackId': objasniPackId,
        'kolikoSeconds': kolikoSeconds,
        'kolikoQuestions': kolikoQuestions,
        'kolikoPackId': kolikoPackId,
        'blefQuestions': blefQuestions,
        'blefPackId': blefPackId,
        'tkobiPrompts': tkobiPrompts,
        'tkobiPackId': tkobiPackId,
        'kaosviQuestions': kaosviQuestions,
        'kaosviTarget': kaosviTarget,
        'kaosviPackId': kaosviPackId,
        'quizOffPacks': (quizOffPacks.toList()..sort()),
        'uljezOffPacks': (uljezOffPacks.toList()..sort()),
        'objasniOffPacks': (objasniOffPacks.toList()..sort()),
        'kolikoOffPacks': (kolikoOffPacks.toList()..sort()),
        'blefOffPacks': (blefOffPacks.toList()..sort()),
        'tkobiOffPacks': (tkobiOffPacks.toList()..sort()),
        'kaosviOffPacks': (kaosviOffPacks.toList()..sort()),
      };
}

class PackInfo with _JsonEq {
  final String id, title;
  final int questionCount;

  /// The pack has questions with a picture (a tag on the pack grid).
  final bool pictures;

  /// A pack added recently: the six packs of Task 28, or one the host
  /// uploaded since the TV app started (a tag on the pack grid).
  final bool isNew;
  const PackInfo(this.id, this.title, this.questionCount, {this.pictures = false, this.isNew = false});
  factory PackInfo.fromJson(Map<String, dynamic> j) => PackInfo(
      j['id'] as String, j['title'] as String, j['questionCount'] as int,
      pictures: (j['pictures'] as bool?) ?? false, isNew: (j['isNew'] as bool?) ?? false);
  @override
  Map<String, Object?> toJson() =>
      {'id': id, 'title': title, 'questionCount': questionCount, 'pictures': pictures, 'isNew': isNew};
}

class Placement with _JsonEq {
  final int playerId, place, gameScore, sessionPoints;
  const Placement(this.playerId, this.place, this.gameScore, this.sessionPoints);
  factory Placement.fromJson(Map<String, dynamic> j) => Placement(
      j['playerId'] as int,
      j['place'] as int,
      j['gameScore'] as int,
      j['sessionPoints'] as int);
  @override
  Map<String, Object?> toJson() => {
        'playerId': playerId,
        'place': place,
        'gameScore': gameScore,
        'sessionPoints': sessionPoints,
      };
}

sealed class Message with _JsonEq {
  const Message();
  String get type;
  Map<String, Object?> get fields => const {};

  @override
  Map<String, Object?> toJson() => {'type': type, ...fields};

  String encode() => jsonEncode(toJson());

  /// Returns null for malformed JSON, an unknown type or wrong field types.
  static Message? decode(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
          [for (final e in m[k] as List) f(e as Map<String, dynamic>)];
      return switch (m['type']) {
        'join' => Join(m['name'] as String, m['token'] as String,
            character: m['character'] as String?),
        'character' => SetCharacter(m['id'] as String),
        'steer' =>
          Steer(left: m['left'] as bool, right: m['right'] as bool),
        'answer' => Answer(m['index'] as int),
        'start' => StartGame(
            GameKind.values.byName(m['game'] as String), m['packId'] as String?),
        'kick' => Kick(m['playerId'] as int),
        'bots' => SetBots(m['count'] as int),
        'settings' => SetSettings(GameSettings.fromJson(m)),
        'select' => SelectGame(m['game'] == null ? null : GameKind.values.byName(m['game'] as String)),
        'nightPick' => NightPick(m['target'] as int?,
            special: m['special'] as bool, second: m['second'] as int?),
        'vote' => Vote(m['target'] as int?),
        'uljezDone' => const UljezDone(),
        'readyToVote' => ReadyToVote(m['on'] as bool),
        'guess' => Guess(m['index'] as int),
        'number' => NumberAnswer((m['value'] as num).toDouble()),
        'kaosviAnswer' => KaosviAnswer(m['text'] as String),
        'kaosviMerge' => KaosviMerge(m['a'] as int, m['b'] as int),
        'kaosviDone' => const KaosviDone(),
        'blefFake' => BlefFake(m['text'] as String),
        'blefPick' => BlefPick(m['index'] as int),
        'reshuffle' => const Reshuffle(),
        'go' => const Go(),
        'objasniAction' => ObjasniAction(ObjasniAct.values.byName(m['act'] as String), wordNo: m['wordNo'] as int?),
        'shoot' => Shoot(m['target'] as int?),
        'ping' => Ping(m['t'] as int),
        'welcome' =>
          Welcome(m['playerId'] as int, m['colorIndex'] as int, m['token'] as String,
              character: (m['character'] as String?) ?? ''),
        'lobby' => LobbyState(
            players: list('players', PlayerInfo.fromJson),
            packs: list('packs', PackInfo.fromJson),
            hostId: m['hostId'] as int,
            uljezPacks: m['uljezPacks'] == null ? const [] : list('uljezPacks', PackInfo.fromJson),
            objasniPacks: m['objasniPacks'] == null ? const [] : list('objasniPacks', PackInfo.fromJson),
            kolikoPacks: m['kolikoPacks'] == null ? const [] : list('kolikoPacks', PackInfo.fromJson),
            blefPacks: m['blefPacks'] == null ? const [] : list('blefPacks', PackInfo.fromJson),
            tkobiPacks: m['tkobiPacks'] == null ? const [] : list('tkobiPacks', PackInfo.fromJson),
            kaosviPacks: m['kaosviPacks'] == null ? const [] : list('kaosviPacks', PackInfo.fromJson),
            selected: m['selected'] == null
                ? null
                : GameKind.values.byName(m['selected'] as String),
            settings: m['settings'] == null
                ? const GameSettings()
                : GameSettings.fromJson(m['settings'] as Map<String, dynamic>)),
        'quizQ' => QuizQuestion(m['number'] as int, m['total'] as int,
            [for (final c in m['choices'] as List) c as String], m['seconds'] as int),
        'quizReveal' => QuizReveal(
            m['correctIndex'] as int, m['yourPoints'] as int, m['yourTotal'] as int),
        'curve' => CurveStatus(
            alive: m['alive'] as bool,
            score: m['score'] as int,
            target: m['target'] as int,
            round: m['round'] as int?),
        'results' => Results(list('placements', Placement.fromJson)),
        'effect' => Effect(m['name'] as String),
        'role' => RoleMsg(WolfRole.values.byName(m['role'] as String),
            [for (final e in m['mates'] as List) e as int],
            [for (final e in m['possible'] as List) WolfRole.values.byName(e as String)],
            hide: m['hide'] as bool),
        'night' => NightPrompt(
            night: m['night'] as int,
            text: m['text'] as String,
            choices: [for (final e in m['choices'] as List) e as String],
            ids: [for (final e in m['ids'] as List) e as int],
            choices2: [for (final e in m['choices2'] as List) e as String],
            ids2: [for (final e in m['ids2'] as List) e as int],
            picks: m['picks'] as int,
            picked: m['picked'] as int?,
            picked2: m['picked2'] as int?,
            special: m['special'] as bool,
            done: (m['done'] as bool?) ?? false),
        'morning' => Morning(m['day'] as int, m['text'] as String),
        'votePrompt' => VotePrompt(
            day: m['day'] as int,
            seconds: m['seconds'] as int,
            ids: [for (final e in m['ids'] as List) e as int],
            canVote: m['canVote'] as bool,
            picked: m['picked'] as int?),
        'farewell' => Farewell(
            seconds: m['seconds'] as int, ids: [for (final e in m['ids'] as List) e as int]),
        'wolfEnd' => WolfEnd(WolfWinner.values.byName(m['winner'] as String), {
            for (final e in (m['roles'] as Map<String, dynamic>).entries)
              int.parse(e.key): WolfRole.values.byName(e.value as String)
          }),
        'uljezWord' => UljezWord(m['word'] as String),
        'voteWish' => VoteWish(
            open: m['open'] as bool, ready: m['ready'] as bool, want: m['want'] as int, needed: m['needed'] as int),
        'uljezTurn' => UljezTurn(
            round: m['round'] as int,
            speaker: m['speaker'] as int?,
            seconds: m['seconds'] as int,
            stage: m['stage'] as String),
        'uljezGuess' => UljezGuess(
            seconds: m['seconds'] as int, options: [for (final e in m['options'] as List) e as String]),
        'uljezEnd' => UljezEnd(UljezWinner.values.byName(m['winner'] as String), m['village'] as String,
            m['impostor'] as String, [for (final e in m['impostors'] as List) e as int]),
        'kaosviAsk' => KaosviAsk(
            number: m['number'] as int,
            total: m['total'] as int,
            seconds: m['seconds'] as int,
            q: m['q'] as String,
            sent: m['sent'] as String?),
        'kaosviMerging' => KaosviMerging(
            seconds: m['seconds'] as int,
            groups: [
              for (final e in m['groups'] as List)
                KaosviMergeItem((e as Map<String, dynamic>)['id'] as int, e['text'] as String)
            ],
            host: m['host'] as bool),
        'kaosviResult' => KaosviResult(
            answer: m['answer'] as String?,
            size: m['size'] as int,
            points: m['points'] as int,
            total: m['total'] as int,
            largest: m['largest'] as bool,
            lone: m['lone'] as bool),
        'tkobiAsk' => TkobiAsk(
            number: m['number'] as int,
            total: m['total'] as int,
            seconds: m['seconds'] as int,
            text: m['text'] as String,
            ids: [for (final e in m['ids'] as List) e as int],
            picked: m['picked'] as int?),
        'tkobiResult' => TkobiResult(
            counts: {
              for (final e in (m['counts'] as Map<String, dynamic>).entries) int.parse(e.key): e.value as int
            },
            crowned: [for (final e in m['crowned'] as List) e as int],
            votedRight: m['votedRight'] as bool,
            points: m['points'] as int,
            total: m['total'] as int),
        'blefWrite' => BlefWrite(
            number: m['number'] as int,
            total: m['total'] as int,
            seconds: m['seconds'] as int,
            q: m['q'] as String,
            sent: m['sent'] as String?),
        'blefList' => BlefList(
            seconds: m['seconds'] as int,
            options: [for (final e in m['options'] as List) e as String],
            ids: [for (final e in m['ids'] as List) e as int],
            picked: m['picked'] as int?),
        'blefResult' => BlefResult(
            points: m['points'] as int,
            total: m['total'] as int,
            foundTruth: m['foundTruth'] as bool,
            fooled: m['fooled'] as int),
        'kolikoAsk' => KolikoAsk(
            number: m['number'] as int,
            total: m['total'] as int,
            seconds: m['seconds'] as int,
            q: m['q'] as String,
            unit: m['unit'] as String,
            sent: (m['sent'] as num?)?.toDouble()),
        'kolikoResult' => KolikoResult(
            answer: (m['answer'] as num).toDouble(),
            value: (m['value'] as num?)?.toDouble(),
            rank: m['rank'] as int?,
            points: m['points'] as int,
            total: m['total'] as int,
            unit: (m['unit'] as String?) ?? ''),
        'objasniTeams' => ObjasniTeams(
            team: m['team'] as int,
            teams: [
              for (final t in m['teams'] as List) [for (final e in t as List) e as int]
            ]),
        'objasniTurn' => ObjasniTurn(
            stage: ObjasniStage.values.byName(m['stage'] as String),
            role: ObjasniRole.values.byName(m['role'] as String),
            team: m['team'] as int,
            explainer: m['explainer'] as int,
            word: m['word'] as String?,
            wordNo: (m['wordNo'] as int?) ?? 0,
            seconds: m['seconds'] as int,
            scores: [for (final e in m['scores'] as List) e as int]),
        'pong' => Pong(m['t'] as int),
        'waiting' => Waiting(m['reason'] as String),
        'error' => ErrorMsg(m['message'] as String),
        'kicked' => const Kicked(),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

// Phone -> TV

class Join extends Message {
  final String name, token;

  /// A character the phone proposes; the TV may give another if it is taken.
  final String? character;
  const Join(this.name, this.token, {this.character});
  @override
  String get type => 'join';
  @override
  Map<String, Object?> get fields =>
      {'name': name, 'token': token, 'character': character};
}

/// Lobby only: change my character. A taken one is refused with an ErrorMsg.
class SetCharacter extends Message {
  final String id;
  const SetCharacter(this.id);
  @override
  String get type => 'character';
  @override
  Map<String, Object?> get fields => {'id': id};
}

class Steer extends Message {
  final bool left, right;
  const Steer({required this.left, required this.right});
  @override
  String get type => 'steer';
  @override
  Map<String, Object?> get fields => {'left': left, 'right': right};
}

class Answer extends Message {
  final int index;
  const Answer(this.index);
  @override
  String get type => 'answer';
  @override
  Map<String, Object?> get fields => {'index': index};
}

class StartGame extends Message {
  final GameKind game;
  final String? packId;
  const StartGame(this.game, this.packId);
  @override
  String get type => 'start';
  @override
  Map<String, Object?> get fields => {'game': game.name, 'packId': packId};
}

class Kick extends Message {
  final int playerId;
  const Kick(this.playerId);
  @override
  String get type => 'kick';
  @override
  Map<String, Object?> get fields => {'playerId': playerId};
}

/// Host only: how many bots to have in the lobby. The TV clamps it so that
/// players + bots never exceed 8.
class SetBots extends Message {
  final int count;
  const SetBots(this.count);
  @override
  String get type => 'bots';
  @override
  Map<String, Object?> get fields => {'count': count};
}

/// Host only, lobby only: the game settings. The TV clamps them and answers
/// with a fresh [LobbyState].
class SetSettings extends Message {
  final GameSettings settings;
  const SetSettings(this.settings);
  @override
  String get type => 'settings';
  @override
  Map<String, Object?> get fields => settings.toJson();
}

/// Host only, lobby only: the game whose details the host is looking at
/// (null: the carousel). The TV shows it to everyone via [LobbyState.selected].
class SelectGame extends Message {
  final GameKind? game;
  const SelectGame(this.game);
  @override
  String get type => 'select';
  @override
  Map<String, Object?> get fields => {'game': game?.name};
}

class Ping extends Message {
  final int t;
  const Ping(this.t);
  @override
  String get type => 'ping';
  @override
  Map<String, Object?> get fields => {'t': t};
}

// TV -> phone

class Welcome extends Message {
  final int playerId, colorIndex;
  final String token;

  /// This player's character id; '' if none.
  final String character;
  const Welcome(this.playerId, this.colorIndex, this.token, {this.character = ''});
  @override
  String get type => 'welcome';
  @override
  Map<String, Object?> get fields =>
      {'playerId': playerId, 'colorIndex': colorIndex, 'token': token, 'character': character};
}

class LobbyState extends Message {
  final List<PlayerInfo> players;
  final List<PackInfo> packs;
  final int hostId;
  final GameSettings settings;

  /// Uljez word packs (questionCount = number of word pairs).
  final List<PackInfo> uljezPacks;

  /// The packs of the party games (questionCount = words / questions / prompts).
  final List<PackInfo> objasniPacks, kolikoPacks, blefPacks, tkobiPacks, kaosviPacks;

  /// The game the host has open, or null.
  final GameKind? selected;
  const LobbyState(
      {required this.players,
      required this.packs,
      required this.hostId,
      this.selected,
      this.uljezPacks = const [],
      this.objasniPacks = const [],
      this.kolikoPacks = const [],
      this.blefPacks = const [],
      this.tkobiPacks = const [],
      this.kaosviPacks = const [],
      this.settings = const GameSettings()});
  @override
  String get type => 'lobby';
  @override
  Map<String, Object?> get fields => {
        'players': [for (final p in players) p.toJson()],
        'packs': [for (final p in packs) p.toJson()],
        'hostId': hostId,
        'selected': selected?.name,
        'uljezPacks': [for (final p in uljezPacks) p.toJson()],
        'objasniPacks': [for (final p in objasniPacks) p.toJson()],
        'kolikoPacks': [for (final p in kolikoPacks) p.toJson()],
        'blefPacks': [for (final p in blefPacks) p.toJson()],
        'tkobiPacks': [for (final p in tkobiPacks) p.toJson()],
        'kaosviPacks': [for (final p in kaosviPacks) p.toJson()],
        'settings': settings.toJson(),
      };
}

class QuizQuestion extends Message {
  final int number, total, seconds;
  final List<String> choices;
  const QuizQuestion(this.number, this.total, this.choices, this.seconds);
  @override
  String get type => 'quizQ';
  @override
  Map<String, Object?> get fields => {
        'number': number,
        'total': total,
        'choices': choices,
        'seconds': seconds,
      };
}

class QuizReveal extends Message {
  final int correctIndex, yourPoints, yourTotal;
  const QuizReveal(this.correctIndex, this.yourPoints, this.yourTotal);
  @override
  String get type => 'quizReveal';
  @override
  Map<String, Object?> get fields => {
        'correctIndex': correctIndex,
        'yourPoints': yourPoints,
        'yourTotal': yourTotal,
      };
}

class CurveStatus extends Message {
  final bool alive;
  final int score, target;

  /// The current round of the match, 1-based; null from an older TV.
  final int? round;
  const CurveStatus(
      {required this.alive, required this.score, required this.target, this.round});
  @override
  String get type => 'curve';
  @override
  Map<String, Object?> get fields =>
      {'alive': alive, 'score': score, 'target': target, 'round': round};
}

class Results extends Message {
  final List<Placement> placements;
  const Results(this.placements);
  @override
  String get type => 'results';
  @override
  Map<String, Object?> get fields =>
      {'placements': [for (final p in placements) p.toJson()]};
}

class Effect extends Message {
  final String name;
  const Effect(this.name);
  @override
  String get type => 'effect';
  @override
  Map<String, Object?> get fields => {'name': name};
}

class Pong extends Message {
  final int t;
  const Pong(this.t);
  @override
  String get type => 'pong';
  @override
  Map<String, Object?> get fields => {'t': t};
}

class Waiting extends Message {
  final String reason;
  const Waiting(this.reason);
  @override
  String get type => 'waiting';
  @override
  Map<String, Object?> get fields => {'reason': reason};
}

class ErrorMsg extends Message {
  final String message;
  const ErrorMsg(this.message);
  @override
  String get type => 'error';
  @override
  Map<String, Object?> get fields => {'message': message};
}

class Kicked extends Message {
  const Kicked();
  @override
  String get type => 'kicked';
}

// Vukodlak. Privacy rule: every alive phone gets the SAME message types at the
// same moments; only short text and the choice list differ. Private messages
// go to one phone only and never inside a broadcast.

/// Fixed width of the free-text field in [NightPrompt] and [Morning]: the
/// session pads to it so a message's length does not tell the role. 200 holds
/// the longest hint (an alpha with two packmates, 16-letter names).
const wolfTextWidth = 200;

/// Phone -> TV, night: [target] is the id picked (null: skipped, or a sum
/// answer: the TV does not look). [special] is the extra switch every phone
/// carries; only some roles read it.
class NightPick extends Message {
  final int? target;

  /// Night 1 has two picks on every phone; only the cupid's count.
  final int? second;
  final bool special;
  const NightPick(this.target, {this.special = false, this.second});
  @override
  String get type => 'nightPick';
  @override
  Map<String, Object?> get fields => {'target': target, 'second': second, 'special': special};
}

/// Phone -> TV, day vote: [target] null = skip.
class Vote extends Message {
  final int? target;
  const Vote(this.target);
  @override
  String get type => 'vote';
  @override
  Map<String, Object?> get fields => {'target': target};
}

/// Phone -> TV, Uljez: the speaker's "Dao sam trag". Passes the turn; from
/// anyone else, or out of turn, it is ignored.
class UljezDone extends Message {
  const UljezDone();
  @override
  String get type => 'uljezDone';
  @override
  Map<String, Object?> get fields => const {};
}

/// Phone -> TV, "Idemo glasati" (Uljez from the end of round 1, Vukodlak by
/// day): [on] is the phone's wish, not a toggle, so a double send changes
/// nothing. Ignored when the wish is not open for that player.
class ReadyToVote extends Message {
  final bool on;
  const ReadyToVote(this.on);
  @override
  String get type => 'readyToVote';
  @override
  Map<String, Object?> get fields => {'on': on};
}

/// TV -> one phone (Uljez; Vukodlak day, living players only): the state of
/// "Idemo glasati". [open] false = hide the button (Uljez round 1); [ready] is
/// this phone's own wish; [want] of the players still in (connected or not) want to
/// vote and the vote starts at [needed] (more than half). The same shape for
/// every phone; it carries nothing private. Sent again on every change and on
/// reconnect. Never sent at night.
class VoteWish extends Message {
  final bool open, ready;
  final int want, needed;
  const VoteWish({required this.open, required this.ready, required this.want, required this.needed});
  @override
  String get type => 'voteWish';
  @override
  Map<String, Object?> get fields => {'open': open, 'ready': ready, 'want': want, 'needed': needed};
}

/// Phone -> TV: the farewell pick of a player who just went out (only a
/// hunter's counts; everyone gets the same window).
class Shoot extends Message {
  final int? target;
  const Shoot(this.target);
  @override
  String get type => 'shoot';
  @override
  Map<String, Object?> get fields => {'target': target};
}

/// TV -> one phone: your role, your packmates' ids (wolves only), the roles
/// that are in this game's mix, and whether roles stay hidden. Resent to
/// every alive phone each morning and on reconnect.
class RoleMsg extends Message {
  final WolfRole role;
  final List<int> mates;
  final List<WolfRole> possible;
  final bool hide;
  const RoleMsg(this.role, this.mates, this.possible, {required this.hide});
  @override
  String get type => 'role';
  @override
  Map<String, Object?> get fields => {
        'role': role.name,
        'mates': mates,
        'possible': [for (final r in possible) r.name],
        'hide': hide,
      };
}

/// TV -> one phone, night: the hint [text] (padded), and the list to choose
/// from: [choices] are the labels, [ids] what a pick sends back. For a role
/// with a night action the labels are the alive players; otherwise they are
/// the five answers of a sum. [picks] is 2 on night 1 for EVERY phone (the
/// cupid's two lovers), else 1; then [choices2]/[ids2] are the list for the
/// second pick (the alive players again, or a second sum) and empty on every
/// other night. [picked], [picked2] and [special] restore the screen.
class NightPrompt extends Message {
  final int night;
  final String text;
  final List<String> choices;
  final List<int> ids;
  final List<String> choices2;
  final List<int> ids2;
  final int picks;
  final int? picked;
  final int? picked2;
  final bool special;

  /// This phone already confirmed its night answer (the same for every role,
  /// a sum included): show 'Poslano'. False from an older TV.
  final bool done;
  const NightPrompt(
      {required this.night,
      required this.text,
      required this.choices,
      required this.ids,
      this.choices2 = const [],
      this.ids2 = const [],
      this.picks = 1,
      this.picked,
      this.picked2,
      this.special = false,
      this.done = false});
  @override
  String get type => 'night';
  @override
  Map<String, Object?> get fields => {
        'night': night,
        'text': text,
        'choices': choices,
        'ids': ids,
        'choices2': choices2,
        'ids2': ids2,
        'picks': picks,
        'picked': picked,
        'picked2': picked2,
        'special': special,
        'done': done,
      };
}

/// TV -> one phone, morning: a short private result (padded); the same text
/// for a player with nothing to learn.
class Morning extends Message {
  final int day;
  final String text;
  const Morning(this.day, this.text);
  @override
  String get type => 'morning';
  @override
  Map<String, Object?> get fields => {'day': day, 'text': text};
}

/// TV -> every alive phone: the day vote opens. [canVote] is false for a
/// spared fool; [ids] are the players that can be voted for.
class VotePrompt extends Message {
  final int day;
  final int seconds;
  final List<int> ids;
  final bool canVote;
  final int? picked;
  const VotePrompt(
      {required this.day,
      required this.seconds,
      required this.ids,
      this.canVote = true,
      this.picked});
  @override
  String get type => 'votePrompt';
  @override
  Map<String, Object?> get fields =>
      {'day': day, 'seconds': seconds, 'ids': ids, 'canVote': canVote, 'picked': picked};
}

/// TV -> a phone whose player just went out: the same window for every one.
class Farewell extends Message {
  final int seconds;
  final List<int> ids;
  const Farewell({required this.seconds, required this.ids});
  @override
  String get type => 'farewell';
  @override
  Map<String, Object?> get fields => {'seconds': seconds, 'ids': ids};
}

/// TV -> everyone, at the end: who won and everybody's role.
class WolfEnd extends Message {
  final WolfWinner winner;
  final Map<int, WolfRole> roles;
  const WolfEnd(this.winner, this.roles);
  @override
  String get type => 'wolfEnd';
  @override
  Map<String, Object?> get fields => {
        'winner': winner.name,
        'roles': {for (final e in roles.entries) '${e.key}': e.value.name},
      };
}

// Uljez. The impostor's phone gets the same message types at the same moments
// as every other phone; only the word differs.

/// Phone -> TV: the caught impostor's pick among the guess options.
class Guess extends Message {
  final int index;
  const Guess(this.index);
  @override
  String get type => 'guess';
  @override
  Map<String, Object?> get fields => {'index': index};
}

/// TV -> one phone: your word (everyone gets one; sent at the start and on
/// reconnect). The phone shows it only while a finger is down.
class UljezWord extends Message {
  final String word;
  const UljezWord(this.word);
  @override
  String get type => 'uljezWord';
  @override
  Map<String, Object?> get fields => {'word': word};
}

/// TV -> everyone: whose turn it is to give a clue ([stage] 'clues', [speaker]
/// the player id). [stage] is always 'clues' now (no discussion stage).
/// Public: it carries no private information.
class UljezTurn extends Message {
  final int round, seconds;
  final int? speaker;
  final String stage;
  const UljezTurn({required this.round, required this.speaker, required this.seconds, required this.stage});
  @override
  String get type => 'uljezTurn';
  @override
  Map<String, Object?> get fields =>
      {'round': round, 'speaker': speaker, 'seconds': seconds, 'stage': stage};
}

/// TV -> the caught impostor only (everybody already knows who was voted
/// out): the 4 options, pick one with [Guess].
class UljezGuess extends Message {
  final int seconds;
  final List<String> options;
  const UljezGuess({required this.seconds, required this.options});
  @override
  String get type => 'uljezGuess';
  @override
  Map<String, Object?> get fields => {'seconds': seconds, 'options': options};
}

/// TV -> everyone, at the end: both words and who the impostors were.
class UljezEnd extends Message {
  final UljezWinner winner;
  final String villageWord, impostorWord;
  final List<int> impostors;
  const UljezEnd(this.winner, this.villageWord, this.impostorWord, this.impostors);
  @override
  String get type => 'uljezEnd';
  @override
  Map<String, Object?> get fields =>
      {'winner': winner.name, 'village': villageWord, 'impostor': impostorWord, 'impostors': impostors};
}

// Objasni (explain the word in teams).

enum ObjasniAct { correct, skip, foul }

/// 'ready' (waiting for the explainer's Kreni), 'play', 'summary' (the 5 s after a turn).
enum ObjasniStage { ready, play, summary }

/// explain: the explainer's phone (word, Točno / Preskoči). watch: the other
/// team (word, Prekršaj). guess: the explainer's team (no word: Pogađaj naglas!).
enum ObjasniRole { explain, watch, guess }

/// Phone -> TV, host only, in the Objasni setup: draw the teams again.
class Reshuffle extends Message {
  const Reshuffle();
  @override
  String get type => 'reshuffle';
}

/// Phone -> TV: "Kreni". The host's in the setup (start the game), the explainer's
/// when it is their turn (start the clock).
class Go extends Message {
  const Go();
  @override
  String get type => 'go';
}

/// Phone -> TV: Točno / Preskoči (the explainer), Prekršaj (the other team).
class ObjasniAction extends Message {
  final ObjasniAct act;

  /// The [ObjasniTurn.wordNo] of the word the press is about. The TV ignores a
  /// press for a word that is no longer on screen (two phones racing for the
  /// same word, a double tap). Null from an older phone: no check.
  final int? wordNo;
  const ObjasniAction(this.act, {this.wordNo});
  @override
  String get type => 'objasniAction';
  @override
  Map<String, Object?> get fields => {'act': act.name, 'wordNo': wordNo};
}

/// TV -> everyone: the teams (player ids) and which one this phone is on ([team]).
/// Teams are public. Sent in the setup and after every Promiješaj.
class ObjasniTeams extends Message {
  final int team;
  final List<List<int>> teams;
  const ObjasniTeams({required this.team, required this.teams});
  @override
  String get type => 'objasniTeams';
  @override
  Map<String, Object?> get fields => {'team': team, 'teams': teams};
}

/// TV -> one phone: the state of the turn for ITS role. [word] is set only for
/// the explainer and the other team, never for the explainer's own team.
/// [team] is the team on turn; [scores] are both teams' scores.
class ObjasniTurn extends Message {
  final ObjasniStage stage;
  final ObjasniRole role;
  final int team, explainer, seconds;
  final String? word;

  /// Counts the words of the game; echo it in [ObjasniAction.wordNo].
  final int wordNo;
  final List<int> scores;
  const ObjasniTurn(
      {required this.stage,
      required this.role,
      required this.team,
      required this.explainer,
      required this.word,
      this.wordNo = 0,
      required this.seconds,
      required this.scores});
  @override
  String get type => 'objasniTurn';
  @override
  Map<String, Object?> get fields => {
        'stage': stage.name,
        'role': role.name,
        'team': team,
        'explainer': explainer,
        'word': word,
        'wordNo': wordNo,
        'seconds': seconds,
        'scores': scores,
      };
}

// Koliko? (guess the number).

/// Phone -> TV: the player's number (>= 0). The phone groups the digits as they
/// are typed; what travels is the plain number. The first one counts.
class NumberAnswer extends Message {
  final double value;
  const NumberAnswer(this.value);
  @override
  String get type => 'number';
  @override
  Map<String, Object?> get fields => {'value': value};
}

/// TV -> every phone: a question is open. [seconds] is the time left when sent;
/// [sent] is this phone's own number if it already answered (a reload).
class KolikoAsk extends Message {
  final int number, total, seconds;
  final String q, unit;
  final double? sent;
  const KolikoAsk(
      {required this.number,
      required this.total,
      required this.seconds,
      required this.q,
      required this.unit,
      this.sent});
  @override
  String get type => 'kolikoAsk';
  @override
  Map<String, Object?> get fields =>
      {'number': number, 'total': total, 'seconds': seconds, 'q': q, 'unit': unit, 'sent': sent};
}

/// TV -> one phone after the reveal: the true answer, this phone's own number
/// (null: no answer), its rank, the points it got and its total. Nobody else's
/// numbers are sent to a phone.
class KolikoResult extends Message {
  final double answer;
  final double? value;
  final int? rank;
  final int points, total;

  /// The question's unit ('m', 'km'...), so a phone that reloads during the
  /// reveal can still show it; '' when there is none or from an older TV.
  final String unit;
  const KolikoResult(
      {required this.answer,
      required this.value,
      required this.rank,
      required this.points,
      required this.total,
      this.unit = ''});
  @override
  String get type => 'kolikoResult';
  @override
  Map<String, Object?> get fields =>
      {'answer': answer, 'value': value, 'rank': rank, 'points': points, 'total': total, 'unit': unit};
}

// Blef (bluff trivia). Nobody sees another player's fake before the list.

/// Phone -> TV: a fake answer (at most 40 characters; the TV checks it).
class BlefFake extends Message {
  final String text;
  const BlefFake(this.text);
  @override
  String get type => 'blefFake';
  @override
  Map<String, Object?> get fields => {'text': text};
}

/// Phone -> TV: the entry (an id from [BlefList.ids]) the player believes.
class BlefPick extends Message {
  final int index;
  const BlefPick(this.index);
  @override
  String get type => 'blefPick';
  @override
  Map<String, Object?> get fields => {'index': index};
}

/// TV -> every phone: a question to write a fake for. [sent] is this phone's
/// own accepted fake (also the ack, and the restore after a reload).
class BlefWrite extends Message {
  final int number, total, seconds;
  final String q;
  final String? sent;
  const BlefWrite({required this.number, required this.total, required this.seconds, required this.q, required this.sent});
  @override
  String get type => 'blefWrite';
  @override
  Map<String, Object?> get fields =>
      {'number': number, 'total': total, 'seconds': seconds, 'q': q, 'sent': sent};
}

/// TV -> one phone: the entries to pick from WITHOUT this player's own fake.
/// [ids] are what [BlefPick] sends back. No writers, no marks: nothing says
/// which entry is the true one. [picked] restores a reload.
class BlefList extends Message {
  final int seconds;
  final List<String> options;
  final List<int> ids;
  final int? picked;
  const BlefList({required this.seconds, required this.options, required this.ids, this.picked});
  @override
  String get type => 'blefList';
  @override
  Map<String, Object?> get fields => {'seconds': seconds, 'options': options, 'ids': ids, 'picked': picked};
}

/// TV -> one phone after the reveal: its own points for the question.
class BlefResult extends Message {
  final int points, total, fooled;
  final bool foundTruth;
  const BlefResult({required this.points, required this.total, required this.foundTruth, required this.fooled});
  @override
  String get type => 'blefResult';
  @override
  Map<String, Object?> get fields =>
      {'points': points, 'total': total, 'foundTruth': foundTruth, 'fooled': fooled};
}

// Tko bi? (who in the room). The phone votes with the existing [Vote] (any
// player, yourself included, one tap); nobody ever receives who voted for whom.

/// TV -> every phone: a prompt. [ids] are the players that can be voted for
/// (all of them); [picked] restores a reload.
class TkobiAsk extends Message {
  final int number, total, seconds;
  final String text;
  final List<int> ids;
  final int? picked;
  const TkobiAsk(
      {required this.number,
      required this.total,
      required this.seconds,
      required this.text,
      required this.ids,
      this.picked});
  @override
  String get type => 'tkobiAsk';
  @override
  Map<String, Object?> get fields =>
      {'number': number, 'total': total, 'seconds': seconds, 'text': text, 'ids': ids, 'picked': picked};
}

/// TV -> every phone after the reveal: how many votes each player got (public),
/// who is crowned, and whether THIS phone's vote went to a crowned player.
class TkobiResult extends Message {
  final Map<int, int> counts;
  final List<int> crowned;
  final bool votedRight;
  final int points, total;
  const TkobiResult(
      {required this.counts, required this.crowned, required this.votedRight, required this.points, required this.total});
  @override
  String get type => 'tkobiResult';
  @override
  Map<String, Object?> get fields => {
        'counts': {for (final e in counts.entries) '${e.key}': e.value},
        'crowned': crowned,
        'votedRight': votedRight,
        'points': points,
        'total': total,
      };
}

// Kao svi (match the herd). No answer reaches the TV or another phone before the
// reveal; only the HOST's phone sees the grouped answers (texts, not writers)
// during the merge.

/// Phone -> TV: the player's answer (<= 30 characters; the first accepted one is final).
class KaosviAnswer extends Message {
  final String text;
  const KaosviAnswer(this.text);
  @override
  String get type => 'kaosviAnswer';
  @override
  Map<String, Object?> get fields => {'text': text};
}

/// Host phone -> TV, during the merge: merge group [a] and group [b].
class KaosviMerge extends Message {
  final int a, b;
  const KaosviMerge(this.a, this.b);
  @override
  String get type => 'kaosviMerge';
  @override
  Map<String, Object?> get fields => {'a': a, 'b': b};
}

/// Host phone -> TV: "Gotovo", end the merge now.
class KaosviDone extends Message {
  const KaosviDone();
  @override
  String get type => 'kaosviDone';
}

/// TV -> every phone: an open question. [sent] is this phone's own accepted
/// answer (the ack, and the restore after a reload).
class KaosviAsk extends Message {
  final int number, total, seconds;
  final String q;
  final String? sent;
  const KaosviAsk({required this.number, required this.total, required this.seconds, required this.q, required this.sent});
  @override
  String get type => 'kaosviAsk';
  @override
  Map<String, Object?> get fields =>
      {'number': number, 'total': total, 'seconds': seconds, 'q': q, 'sent': sent};
}

/// TV -> every phone while the host merges. [groups] holds the answers (id +
/// text, never who wrote them) ONLY for the host's phone ([host] true); every
/// other phone gets an empty list and just waits.
class KaosviMerging extends Message {
  final int seconds;
  final List<KaosviMergeItem> groups;
  final bool host;
  const KaosviMerging({required this.seconds, required this.groups, required this.host});
  @override
  String get type => 'kaosviMerging';
  @override
  Map<String, Object?> get fields =>
      {'seconds': seconds, 'groups': [for (final g in groups) g.toJson()], 'host': host};
  @override
  bool operator ==(Object other) => other is KaosviMerging && jsonEncode(toJson()) == jsonEncode(other.toJson());
  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// TV -> one phone after the reveal: this phone's own answer (null: none), the
/// size of its group, the points it got, its total, and whether its group was
/// the single largest or it was the lone one.
class KaosviResult extends Message {
  final String? answer;
  final int size, points, total;
  final bool largest, lone;
  const KaosviResult(
      {required this.answer,
      required this.size,
      required this.points,
      required this.total,
      required this.largest,
      required this.lone});
  @override
  String get type => 'kaosviResult';
  @override
  Map<String, Object?> get fields =>
      {'answer': answer, 'size': size, 'points': points, 'total': total, 'largest': largest, 'lone': lone};
}
