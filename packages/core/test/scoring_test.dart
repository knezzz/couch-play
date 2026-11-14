import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ties share the better place and the next place skips', () {
    final p = placementPoints({1: 9, 2: 9, 3: 5});
    expect(p.map((e) => e.place), [1, 1, 3]);
    expect(p.map((e) => e.sessionPoints), [3, 3, 1]);
    expect(p.map((e) => e.gameScore), [9, 9, 5]);
    expect(p.map((e) => e.playerId).toSet(), {1, 2, 3});
  });

  test('a single player gets 1 point', () {
    expect(placementPoints({7: 0}), [const Placement(7, 1, 0, 1)]);
  });

  test('sorted by score, descending, 1st gets N', () {
    final p = placementPoints({1: 2, 2: 8, 3: 5, 4: 1});
    expect(p.map((e) => e.playerId), [2, 3, 1, 4]);
    expect(p.map((e) => e.sessionPoints), [4, 3, 2, 1]);
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
