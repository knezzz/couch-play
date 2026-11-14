import 'protocol.dart';

/// Best score first. Ties share the better place and its points; the next
/// place skips (9, 9, 5 -> places 1, 1, 3, points 3, 3, 1). Equal scores keep
/// player-id order so the result is stable.
List<Placement> placementPoints(Map<int, int> gameScores) {
  final ids = gameScores.keys.toList()
    ..sort((a, b) {
      final c = gameScores[b]!.compareTo(gameScores[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  final n = ids.length;
  var place = 1;
  return [
    for (var i = 0; i < n; i++)
      () {
        if (i > 0 && gameScores[ids[i]] != gameScores[ids[i - 1]]) place = i + 1;
        return Placement(ids[i], place, gameScores[ids[i]]!, n - place + 1);
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
