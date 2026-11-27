import 'dart:io';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 57: "Bodova do pobjede" reaches the match for Curve and for Sumo, and is remembered.
void main() {
  late Session s;

  List<FakePeer> lobby(int n, GameSettings? settings) {
    s = Session(random: Random(1));
    final ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
    if (settings != null) ps.first.say(SetSettings(settings));
    return ps;
  }

  test('Automatski gives today\'s 10 x (players - 1) in both games', () {
    for (final n in [2, 4, 7]) {
      final ps = lobby(n, null);
      ps.first.say(const StartGame(GameKind.curve, null));
      expect(s.sim!.target, 10 * (n - 1));
      expect(ps.last.last<CurveStatus>()!.target, 10 * (n - 1));
      s.dispose();
      final qs = lobby(n, null);
      qs.first.say(const StartGame(GameKind.sumo, null));
      expect(s.sumo!.target, 10 * (n - 1));
      expect(qs.last.last<CurveStatus>()!.target, 10 * (n - 1));
      s.dispose();
    }
  });

  test('each game has its own number; the phones are told it', () {
    final ps = lobby(3, const GameSettings(curveTarget: 30, sumoTarget: 70));
    ps.first.say(const StartGame(GameKind.curve, null));
    expect(s.sim!.target, 30);
    expect(ps.last.last<CurveStatus>()!.target, 30);
    s.dispose();
    final qs = lobby(3, const GameSettings(curveTarget: 30, sumoTarget: 70));
    qs.first.say(const StartGame(GameKind.sumo, null));
    expect(s.sumo!.target, 70);
    expect(qs.last.last<CurveStatus>()!.target, 70);
    s.dispose();
  });

  testWidgets('it is fixed when the match starts: players dropping out do not move it', (t) async {
    final ps = lobby(4, const GameSettings(curveTarget: 50, sumoTarget: 20));
    ps.first.say(const StartGame(GameKind.sumo, null));
    ps.last.close();
    await t.pump();
    ps[1].close();
    await t.pump();
    expect(s.sumo!.target, 20, reason: 'not 10 x (2 - 1) and not changed by the leavers');
    s.dispose();
  });

  group('remembered across restarts', () {
    late File file;
    setUp(() {
      final dir = Directory.systemTemp.createTempSync('win');
      addTearDown(() => dir.deleteSync(recursive: true));
      file = File('${dir.path}/settings.json');
    });

    test('a change by the host survives a new session', () {
      s = Session(random: Random(1))..loadSettings(file);
      final host = join(s, 'A', token: 'ta');
      host.say(const SetSettings(GameSettings(curveTarget: 100, sumoTarget: 10)));
      s.dispose();
      final s2 = Session()..loadSettings(file);
      expect(s2.settings.curveTarget, 100);
      expect(s2.settings.sumoTarget, 10);
      s2.dispose();
    });

    test('an older saved file without the field reads as Automatski', () {
      file.writeAsStringSync('{"quizSeconds":30,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2,"curveMode":"chaos"}');
      final s2 = Session()..loadSettings(file);
      expect(s2.settings.curveTarget, 0);
      expect(s2.settings.sumoTarget, 0);
      expect(s2.settings.curveMode, CurveMode.chaos);
      s2.dispose();
    });

    test('a bad saved value reads as Automatski', () {
      file.writeAsStringSync('{"quizSeconds":30,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2,"curveTarget":42,"sumoTarget":"lots"}');
      final s2 = Session()..loadSettings(file);
      expect(s2.settings.curveTarget, 0);
      expect(s2.settings.sumoTarget, 0);
      s2.dispose();
    });
  });
}
