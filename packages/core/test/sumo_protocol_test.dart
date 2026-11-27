import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the Sumo joystick and Dash messages round-trip', () {
    expect(Message.decode(const SumoMove(5, 3).encode()), const SumoMove(5, 3));
    expect(Message.decode(const SumoMove(0, 0).encode()), const SumoMove(0, 0));
    expect(Message.decode(const SumoDash().encode()), const SumoDash());
  });

  test('the Sumo settings round-trip, and an older message keeps the defaults', () {
    const s = GameSettings(sumoMap: SumoMap.ice, sumoPowerUps: false);
    final back = Message.decode(const SetSettings(s).encode()) as SetSettings;
    expect(back.settings.sumoMap, SumoMap.ice);
    expect(back.settings.sumoPowerUps, isFalse);
    expect(s.clamped().sumoMap, SumoMap.ice);
    expect(s.withOffPacks({}).sumoPowerUps, isFalse);
    final old = GameSettings.fromJson({
      'quizSeconds': 20, 'quizQuestions': 10, 'revealSeconds': 4, 'curveCountdown': 2, //
    });
    expect(old.sumoMap, SumoMap.classic);
    expect(old.sumoPowerUps, isTrue);
  });

  test('the Curve status says whether it is Sumo; an older one reads as Curve', () {
    const st = CurveStatus(alive: true, score: 3, target: 10, round: 1, sumo: true);
    expect((Message.decode(st.encode()) as CurveStatus).sumo, isTrue);
    expect((Message.decode(const CurveStatus(alive: true, score: 0, target: 10).encode()) as CurveStatus).sumo, isFalse);
    final json = {'type': 'curve', 'alive': true, 'score': 1, 'target': 10};
    expect(Message.decode('{"type":"curve","alive":true,"score":1,"target":10}'), isA<CurveStatus>());
    expect(json['type'], 'curve');
  });

  test('Sumo is a game kind and starts like the others', () {
    expect(Message.decode(const StartGame(GameKind.sumo, null).encode()), const StartGame(GameKind.sumo, null));
  });
}
