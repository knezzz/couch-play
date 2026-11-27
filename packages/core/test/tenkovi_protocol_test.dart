import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Message? round(Message m) => Message.decode(m.encode());

  test('TenkoviFire round-trips', () {
    const m = TenkoviFire(135, 62, TenkoviShell.cluster);
    expect(round(m), m);
    expect(Message.decode('{"type":"tkFire","angle":1,"power":2,"shell":"nope"}'), isNull);
  });

  test('TenkoviTurn round-trips, with and without the phone\'s own aim', () {
    const aim = TenkoviTurn(
      stage: 'aim',
      round: 2,
      rounds: 3,
      map: TenkoviMap.mars,
      wind: -7,
      alive: true,
      hp: 64,
      heavy: true,
      cluster: false,
      ready: 2,
      total: 5,
      sent: [45, 70, 1],
      last: [50, 60],
    );
    expect(round(aim), aim);
    const bare = TenkoviTurn(
      stage: 'end',
      round: 1,
      rounds: 3,
      map: TenkoviMap.moon,
      wind: 0,
      alive: false,
      hp: 0,
      heavy: true,
      cluster: true,
      ready: 0,
      total: 4,
      points: 3,
      score: 3,
      winner: 2,
    );
    expect(round(bare), bare);
  });

  test('the turn has the same keys for every phone: no other aim in it', () {
    const a = TenkoviTurn(
        stage: 'aim', round: 1, rounds: 3, map: TenkoviMap.earth, wind: 3, alive: true,
        hp: 100, heavy: true, cluster: true, ready: 1, total: 3);
    const b = TenkoviTurn(
        stage: 'aim', round: 1, rounds: 3, map: TenkoviMap.earth, wind: 3, alive: true,
        hp: 100, heavy: true, cluster: true, ready: 1, total: 3, sent: [10, 20, 0], last: [30, 40]);
    expect(a.toJson().keys.toSet(), b.toJson().keys.toSet());
    expect(a.toJson().keys, isNot(contains('aims')));
  });

  test('Tenkovi settings: defaults, round trip, clamp, old messages', () {
    expect(const GameSettings().tenkoviMap, TenkoviMapPick.random);
    expect(const GameSettings().tenkoviRounds, 3);
    const s = GameSettings(tenkoviMap: TenkoviMapPick.mars, tenkoviRounds: 5);
    expect(GameSettings.fromJson(s.toJson()), s);
    expect(const GameSettings(tenkoviRounds: 4).clamped().tenkoviRounds, anyOf(3, 5));
    expect(const GameSettings(tenkoviRounds: 9).clamped().tenkoviRounds, 5);
    final old = const GameSettings().toJson()
      ..remove('tenkoviMap')
      ..remove('tenkoviRounds');
    expect(GameSettings.fromJson(old).tenkoviRounds, 3);
    expect(GameSettings.fromJson({...old, 'tenkoviMap': 'pluto'}).tenkoviMap, TenkoviMapPick.random);
  });

  test('the game kind travels', () {
    expect(round(const StartGame(GameKind.tenkovi, null)), const StartGame(GameKind.tenkovi, null));
    expect(round(const SelectGame(GameKind.tenkovi)), const SelectGame(GameKind.tenkovi));
  });
}
