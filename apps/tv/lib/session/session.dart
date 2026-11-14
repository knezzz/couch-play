// ignore_for_file: unused_field
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';

import '../server/game_server.dart';
import 'bots.dart';

enum Phase { lobby, quiz, curve, results }

/// Shown by the TV lobby instead of the join URL when there is no network.
const noWifiText = 'Connect the TV to Wi-Fi to play.';

const maxPlayers = 8;

class Player {
  Player(this.id, this.name, this.colorIndex, {this.token = '', this.bot = false});

  /// Stable for the whole session. Bots and humans share one id space.
  final int id;
  String name;

  /// 0..7, unique among current players; always the lowest free one when handed out.
  int colorIndex;

  /// Empty for bots.
  final String token;
  final bool bot;
  bool connected = true;
  PeerSocket? socket;
  DateTime? disconnectedAt;
}

/// The lobby and the session around the games: who is here, who is host, the
/// scoreboard, and which game is on. Pure Dart apart from [changes], so tests
/// drive it with fake [PeerSocket]s.
///
/// Curve: [onStart] fires after Session has built [sim] and [bots] from the
/// connected humans and the bots. The TV builds a `CurveGame` from them, passes
/// [curveEvents] as its `onEvents`, and calls [nextRound] 2 s after a RoundOver.
class Session {
  Session({DateTime Function()? now, Random? random})
      : _now = now ?? DateTime.now,
        _random = random ?? Random();

  final DateTime Function() _now;
  final Random _random;

  /// Bumped on every change, for UI rebuilds.
  final ValueNotifier<int> _changes = ValueNotifier(0);
  ValueListenable<int> get changes => _changes;

  /// Called when the host starts a game, after the session is ready for it.
  void Function(GameKind kind, String? packId)? onStart;

  /// Task 11 turns this on. Until then StartGame(quiz) gets an ErrorMsg.
  bool quizAvailable = false;

  /// What the TV lobby shows as the join address; null means no network
  /// ([noWifiText]).
  String? joinUrl;
  String get joinHint => joinUrl ?? noWifiText;

  /// A phone's socket. The session reads its messages and tracks its close.
  void attach(PeerSocket p) {}

  /// Everyone in the session in join order: humans and bots.
  List<Player> get players => const [];

  /// The same, as sent to phones (and what the TV lobby draws).
  List<PlayerInfo> get playerInfos => const [];

  /// Oldest connected human, or null if none is connected.
  int? get hostId => null;

  Phase get phase => Phase.lobby;

  /// Session points per player id.
  Map<int, int> get sessionScores => const {};

  /// Who plays [kind] if it started now: Curve takes connected humans and bots,
  /// Quiz only connected humans.
  List<Player> participants(GameKind kind) => const [];

  /// Removes lobby players who have been disconnected for more than 10 minutes.
  /// Call it every so often (the TV does, once a minute).
  void purgeStale() {}

  // --- Curve ---

  /// The running Curve match, or null.
  CurveSim? get sim => null;
  Bots? get bots => null;

  /// Bumped for every round of a match; the TV makes a fresh `CurveGame` each time.
  int get curveRound => 0;

  /// Feed this the events of every `CurveSim.tick()` (CurveGame.onEvents).
  void curveEvents(List<CurveEvent> events) {}

  /// Starts the next round of the match. The TV calls it 2 s after RoundOver.
  void nextRound() {}

  // --- Seams for later tasks ---

  /// Ends the running game: adds placement points to [sessionScores], sends
  /// Results, and shows the results phase. [gameScores] is keyed by player id.
  void finishGame(Map<int, int> gameScores) {}

  /// Leaves the results phase. The TV calls it 8 s after [finishGame].
  void returnToLobby() {}
}
