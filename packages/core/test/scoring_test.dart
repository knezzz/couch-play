import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ties share the better place and its points; the next place skips', () {
    final p = placementPoints({1: 9, 2: 9, 3: 5});
    expect(p.map((e) => e.place), [1, 1, 3]);
    expect(p.map((e) => e.sessionPoints), [2, 2, 0]);
    expect(p.map((e) => e.gameScore), [9, 9, 5]);
    expect(p.map((e) => e.playerId).toSet(), {1, 2, 3});
  });

  test('a single player gets 0 points (1st = N-1)', () {
    expect(placementPoints({7: 4}), [const Placement(7, 1, 4, 0)]);
    expect(placementPoints({7: 0}), [const Placement(7, 1, 0, 0)]);
  });

  test('sorted by score, descending: 1st gets N-1, last gets 0', () {
    final p = placementPoints({1: 2, 2: 8, 3: 5, 4: 1});
    expect(p.map((e) => e.playerId), [2, 3, 1, 4]);
    expect(p.map((e) => e.sessionPoints), [3, 2, 1, 0]);
  });

  test('a game where everyone scored 0 gives everyone 0', () {
    final p = placementPoints({1: 0, 2: 0, 3: 0, 4: 0});
    expect(p.map((e) => e.sessionPoints), [0, 0, 0, 0]);
    expect(p.map((e) => e.place), [1, 1, 1, 1], reason: 'they still tie for first');
  });

  test('everyone tied on something other than 0 shares first place and its points', () {
    expect(placementPoints({1: 5, 2: 5, 3: 5}).map((e) => e.sessionPoints), [2, 2, 2]);
  });

  test('someone with 0 among scorers is last and gets 0; several zeros tie for the better of their places', () {
    expect(placementPoints({1: 3, 2: 0, 3: 7}).map((e) => e.sessionPoints), [2, 1, 0]);
    // 3, 0, 0: the zeros share place 2 and its point (they did not all score 0)
    expect(placementPoints({1: 3, 2: 0, 3: 0}).map((e) => e.sessionPoints), [2, 1, 1]);
  });

  test('no players, no placements', () {
    expect(placementPoints({}), isEmpty);
  });

  test('quizPoints scale with speed and clamp', () {
    int pts(int s) => quizPoints(correct: true, elapsed: Duration(seconds: s));
    expect(pts(0), 1000);
    expect(pts(10), 750);
    expect(pts(20), 500);
    expect(pts(25), 500);
    expect(quizPoints(correct: false, elapsed: Duration.zero), 0);
  });
}
