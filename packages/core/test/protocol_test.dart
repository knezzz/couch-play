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
      const Ping(123),
      const Welcome(1, 2, 'tok'),
      const LobbyState(
        players: [PlayerInfo(1, 'Ana', 0, true, 5)],
        packs: [PackInfo('p', 'Pack', 10)],
        hostId: 1,
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
    expect(Message.decode('{"type":"start","game":"chess"}'), isNull);
    expect(Message.decode('{"type":"lobby","players":[1],"packs":[],"hostId":1}'),
        isNull);
  });
}
