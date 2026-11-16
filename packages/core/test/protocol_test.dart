import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('roundtrip_all_messages', () {
    final messages = <Message>[
      const Join('Ana', 'tok'),
      const Steer(left: true, right: false),
      const Answer(2),
      const StartGame(GameKind.quiz, 'pack1'),
      const StartGame(GameKind.curve, null),
      const Kick(3),
      const SetBots(4),
      const SetSettings(GameSettings(quizSeconds: 30, quizQuestions: 15, revealSeconds: 6, curveCountdown: 3)),
      const Ping(123),
      const Welcome(1, 2, 'tok'),
      const LobbyState(
        players: [
          PlayerInfo(1, 'Ana', 0, true, 5),
          PlayerInfo(2, 'Bot 1', 1, true, 0, bot: true),
        ],
        packs: [PackInfo('p', 'Pack', 10)],
        hostId: 1,
      ),
      const LobbyState(
        players: [],
        packs: [],
        hostId: 1,
        settings: GameSettings(quizSeconds: 45, quizQuestions: 5, revealSeconds: 2, curveCountdown: 10),
      ),
      const QuizQuestion(1, 10, ['a', 'b', 'c', 'd'], 20),
      const QuizReveal(2, 750, 1500),
      const CurveStatus(alive: true, score: 3, target: 10),
      const Results([Placement(1, 1, 7, 3)]),
      const Effect('confetti'),
      const Pong(123),
      const Waiting('Waiting for the host.'),
      const ErrorMsg('The game is full (8 players).'),
      const Kicked(),
    ];
    for (final m in messages) {
      expect(Message.decode(m.encode()), m, reason: m.encode());
    }
  });

  test('decode_rejects_garbage', () {
    expect(Message.decode('not json'), isNull);
    expect(Message.decode('{"type":"nope"}'), isNull);
    expect(Message.decode('{"type":"answer","index":"2"}'), isNull);
    expect(Message.decode('[1]'), isNull);
    expect(Message.decode('{"type":"bots","count":"3"}'), isNull);
    expect(Message.decode('{"type":"bots"}'), isNull);
    expect(Message.decode('{"type":"start","game":"chess"}'), isNull);
    expect(Message.decode('{"type":"lobby","players":[1],"packs":[],"hostId":1}'),
        isNull);
  });

  test('player_info_without_bot_field_is_a_human', () {
    final m = Message.decode(
        '{"type":"lobby","players":[{"id":1,"name":"Ana","colorIndex":0,'
        '"connected":true,"sessionScore":0}],"packs":[],"hostId":1}');
    expect((m as LobbyState).players.single.bot, isFalse);
  });

  group('game settings', () {
    test('defaults', () {
      const d = GameSettings();
      expect([d.quizSeconds, d.quizQuestions, d.revealSeconds, d.curveCountdown], [20, 10, 4, 2]);
    });

    test('clamped_snaps_to_the_steps_and_the_range', () {
      GameSettings g(int a, int b, int c, int d) =>
          GameSettings(quizSeconds: a, quizQuestions: b, revealSeconds: c, curveCountdown: d).clamped();
      expect(g(-5, 0, -1, 0), const GameSettings(quizSeconds: 10, quizQuestions: 5, revealSeconds: 2, curveCountdown: 1));
      expect(g(999, 999, 999, 999), const GameSettings(quizSeconds: 60, quizQuestions: 30, revealSeconds: 15, curveCountdown: 10));
      expect(g(22, 12, 4, 2), const GameSettings(quizSeconds: 20, quizQuestions: 10, revealSeconds: 4, curveCountdown: 2));
      expect(g(23, 13, 4, 2), const GameSettings(quizSeconds: 25, quizQuestions: 15, revealSeconds: 4, curveCountdown: 2));
    });

    test('a_lobby_without_settings_decodes_to_the_defaults', () {
      final m = Message.decode('{"type":"lobby","players":[],"packs":[],"hostId":1}');
      expect((m as LobbyState).settings, const GameSettings());
    });

    test('a_settings_message_with_a_wrong_type_is_null', () {
      expect(Message.decode('{"type":"settings","quizSeconds":"20","quizQuestions":10,"revealSeconds":4,"curveCountdown":2}'), isNull);
      expect(Message.decode('{"type":"settings"}'), isNull);
    });
  });
}
