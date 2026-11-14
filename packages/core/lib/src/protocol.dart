import 'dart:convert';

enum GameKind { quiz, curve }

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
  const PlayerInfo(
      this.id, this.name, this.colorIndex, this.connected, this.sessionScore,
      {this.bot = false});
  factory PlayerInfo.fromJson(Map<String, dynamic> j) => PlayerInfo(
      j['id'] as int,
      j['name'] as String,
      j['colorIndex'] as int,
      j['connected'] as bool,
      j['sessionScore'] as int,
      bot: (j['bot'] as bool?) ?? false);
  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'colorIndex': colorIndex,
        'connected': connected,
        'sessionScore': sessionScore,
        'bot': bot,
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
        'join' => Join(m['name'] as String, m['token'] as String),
        'steer' =>
          Steer(left: m['left'] as bool, right: m['right'] as bool),
        'answer' => Answer(m['index'] as int),
        'start' => StartGame(
            GameKind.values.byName(m['game'] as String), m['packId'] as String?),
        'kick' => Kick(m['playerId'] as int),
        'bots' => SetBots(m['count'] as int),
        'ping' => Ping(m['t'] as int),
        'welcome' =>
          Welcome(m['playerId'] as int, m['colorIndex'] as int, m['token'] as String),
        'lobby' => LobbyState(
            players: list('players', PlayerInfo.fromJson),
            packs: list('packs', PackInfo.fromJson),
            hostId: m['hostId'] as int),
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
  const Join(this.name, this.token);
  @override
  String get type => 'join';
  @override
  Map<String, Object?> get fields => {'name': name, 'token': token};
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
  const Welcome(this.playerId, this.colorIndex, this.token);
  @override
  String get type => 'welcome';
  @override
  Map<String, Object?> get fields =>
      {'playerId': playerId, 'colorIndex': colorIndex, 'token': token};
}

class LobbyState extends Message {
  final List<PlayerInfo> players;
  final List<PackInfo> packs;
  final int hostId;
  const LobbyState(
      {required this.players, required this.packs, required this.hostId});
  @override
  String get type => 'lobby';
  @override
  Map<String, Object?> get fields => {
        'players': [for (final p in players) p.toJson()],
        'packs': [for (final p in packs) p.toJson()],
        'hostId': hostId,
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
