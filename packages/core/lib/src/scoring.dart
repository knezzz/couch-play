import 'protocol.dart';

/// Best score first. 1st gets N-1 points, 2nd N-2, ... last 0. Ties share the
/// better place and its points; the next place skips (9, 9, 5 -> places 1, 1, 3,
/// points 2, 2, 0). A game where everyone scored 0 gives everyone 0 points.
/// Equal scores keep player-id order so the result is stable.
List<Placement> placementPoints(Map<int, int> gameScores) {
  final ids = gameScores.keys.toList()
    ..sort((a, b) {
      final c = gameScores[b]!.compareTo(gameScores[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  final n = ids.length;
  final nobodyScored = gameScores.values.every((v) => v == 0);
  var place = 1;
  return [
    for (var i = 0; i < n; i++)
      () {
        if (i > 0 && gameScores[ids[i]] != gameScores[ids[i - 1]]) place = i + 1;
        return Placement(ids[i], place, gameScores[ids[i]]!, nobodyScored ? 0 : n - place);
      }(),
  ];
}

/// 1000 for an instant answer, 500 at the time limit or later; wrong is 0.
int quizPoints({
  required bool correct,
  required Duration elapsed,
  Duration limit = const Duration(seconds: 20),
}) {
  if (!correct) return 0;
  final f = elapsed.inMicroseconds / limit.inMicroseconds;
  return (1000 - 500 * f).round().clamp(500, 1000);
}
