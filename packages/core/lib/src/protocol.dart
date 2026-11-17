import 'dart:convert';

import 'wolf.dart';

enum GameKind { quiz, curve, vukodlak }

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
  /// in), whether a player who is out stays unrevealed until the end, and the
  /// day discussion in seconds (30-300 in steps of 30).
  final Set<WolfRole> wolfRoles;
  final bool wolfHideRoles;
  final int wolfDiscussion;
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
    this.wolfDiscussion = 120,
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
      wolfDiscussion: (j['wolfDiscussion'] as int?) ?? 120);

  /// The same values pulled into range and onto their steps.
  GameSettings clamped() {
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
      wolfDiscussion: snap(wolfDiscussion, 30, 300, 30),
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
        'wolfDiscussion': wolfDiscussion,
      };
}

class PackInfo with _JsonEq {
  final String id, title;
  final int questionCount;
  const PackInfo(this.id, this.title, this.questionCount);
  factory PackInfo.fromJson(Map<String, dynamic> j) => PackInfo(
      j['id'] as String, j['title'] as String, j['questionCount'] as int);
  @override
  Map<String, Object?> toJson() =>
      {'id': id, 'title': title, 'questionCount': questionCount};
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
        'nightPick' => NightPick(m['target'] as int?, special: m['special'] as bool),
        'vote' => Vote(m['target'] as int?),
        'shoot' => Shoot(m['target'] as int?),
        'ping' => Ping(m['t'] as int),
        'welcome' =>
          Welcome(m['playerId'] as int, m['colorIndex'] as int, m['token'] as String,
              character: (m['character'] as String?) ?? ''),
        'lobby' => LobbyState(
            players: list('players', PlayerInfo.fromJson),
            packs: list('packs', PackInfo.fromJson),
            hostId: m['hostId'] as int,
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
            target: m['target'] as int),
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
            picked: m['picked'] as int?,
            special: m['special'] as bool),
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

  /// The game the host has open, or null.
  final GameKind? selected;
  const LobbyState(
      {required this.players,
      required this.packs,
      required this.hostId,
      this.selected,
      this.settings = const GameSettings()});
  @override
  String get type => 'lobby';
  @override
  Map<String, Object?> get fields => {
        'players': [for (final p in players) p.toJson()],
        'packs': [for (final p in packs) p.toJson()],
        'hostId': hostId,
        'selected': selected?.name,
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
  const CurveStatus(
      {required this.alive, required this.score, required this.target});
  @override
  String get type => 'curve';
  @override
  Map<String, Object?> get fields =>
      {'alive': alive, 'score': score, 'target': target};
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
/// session pads to it so a message's length does not tell the role.
const wolfTextWidth = 120;

/// Phone -> TV, night: [target] is the id picked (null: skipped, or a sum
/// answer: the TV does not look). [special] is the extra switch every phone
/// carries; only some roles read it.
class NightPick extends Message {
  final int? target;
  final bool special;
  const NightPick(this.target, {this.special = false});
  @override
  String get type => 'nightPick';
  @override
  Map<String, Object?> get fields => {'target': target, 'special': special};
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
/// the five answers of a sum. [picked] and [special] restore the screen.
class NightPrompt extends Message {
  final int night;
  final String text;
  final List<String> choices;
  final List<int> ids;
  final int? picked;
  final bool special;
  const NightPrompt(
      {required this.night,
      required this.text,
      required this.choices,
      required this.ids,
      this.picked,
      this.special = false});
  @override
  String get type => 'night';
  @override
  Map<String, Object?> get fields => {
        'night': night,
        'text': text,
        'choices': choices,
        'ids': ids,
        'picked': picked,
        'special': special,
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
