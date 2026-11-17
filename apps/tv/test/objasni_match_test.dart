import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/objasni_match.dart';
import 'package:tv/sound/sfx.dart';

ObjasniPack pack() => ObjasniPack('p', 'Paket', [for (var i = 0; i < 120; i++) 'riječ$i']);

class _Sfx implements Sfx {
  _Sfx(this.log);
  final List<Sound> log;
  @override
  void play(Sound s) => log.add(s);
}

class Rig {
  Rig({int n = 6, int seconds = 60, int target = 2, int host = 1, int seed = 1}) {
    match = ObjasniMatch(
      ids: [for (var i = 1; i <= n; i++) i],
      pack: pack(),
      settings: GameSettings(objasniSeconds: seconds, objasniTarget: target),
      hostId: () => host,
      send: (id, m) => (sent[id] ??= []).add(m),
      clock: () => at,
      random: Random(seed),
      sfx: _Sfx(played),
      onOver: (s) => result = s,
    )..start();
  }
  late final ObjasniMatch match;
  final sent = <int, List<Message>>{};
  final played = <Sound>[];
  Map<int, int>? result;
  Duration at = Duration.zero;

  Future<void> wait(WidgetTester t, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await t.pump(const Duration(seconds: 1));
      at += const Duration(seconds: 1);
    }
  }

  List<ObjasniTurn> turns(int id) => (sent[id] ?? []).whereType<ObjasniTurn>().toList();
  int get ex => match.explainer!;
  List<int> get guessers => match.teamMembers(match.turnTeam).where((i) => i != ex).toList();
  List<int> get others => match.teamMembers(1 - match.turnTeam);

  void begin() {
    match.onGo(1);
    match.onGo(ex);
  }
}

void main() {
  testWidgets('setup: everyone is told their team; only the host can Promiješaj and start', (t) async {
    final r = Rig();
    for (final id in r.match.ids) {
      final m = r.sent[id]!.whereType<ObjasniTeams>().single;
      expect(m.team, r.match.teamOf(id));
      expect(m.teams, [r.match.teamMembers(0), r.match.teamMembers(1)]);
    }
    final before = r.match.teamMembers(0);
    r.match.onReshuffle(2); // not the host
    expect(r.match.teamMembers(0), before);
    var changed = false;
    for (var i = 0; i < 20 && !changed; i++) {
      r.match.onReshuffle(1);
      changed = r.match.teamMembers(0).join() != before.join();
    }
    expect(changed, isTrue);
    expect(r.sent[3]!.whereType<ObjasniTeams>().last.teams[0], r.match.teamMembers(0));
    r.match.onGo(2);
    expect(r.match.stage, ObjasniStageTv.setup, reason: 'only the host starts');
    r.match.onGo(1);
    expect(r.match.stage, ObjasniStageTv.ready);
    r.match.onReshuffle(1);
    expect(r.match.stage, ObjasniStageTv.ready, reason: 'teams are fixed now');
    r.match.dispose();
  });

  testWidgets('only the explainer\'s Kreni starts the turn', (t) async {
    final r = Rig();
    r.match.onGo(1);
    final other = r.others.first;
    r.match.onGo(other);
    r.match.onGo(r.guessers.first);
    expect(r.match.stage, ObjasniStageTv.ready);
    r.match.onGo(r.ex);
    expect(r.match.stage, ObjasniStageTv.play);
    r.match.dispose();
  });

  testWidgets('racing presses: a double Točno is +1, two watchers on the same word are -1, a stale press does nothing', (t) async {
    final r = Rig();
    r.begin();
    final n = r.turns(r.ex).last.wordNo;
    r.match.onAction(r.ex, ObjasniAction(ObjasniAct.correct, wordNo: n));
    r.match.onAction(r.ex, ObjasniAction(ObjasniAct.correct, wordNo: n));
    expect(r.match.scores[r.match.turnTeam], 1);
    final n2 = r.turns(r.ex).last.wordNo;
    expect(n2, isNot(n), reason: 'the explainer was sent the new number');
    final w = r.others;
    r.match.onAction(w[0], ObjasniAction(ObjasniAct.foul, wordNo: n2));
    r.match.onAction(w[1], ObjasniAction(ObjasniAct.foul, wordNo: n2));
    expect(r.match.scores[r.match.turnTeam], 0, reason: '+1 -1, not -2');
    r.match.onAction(r.ex, ObjasniAction(ObjasniAct.skip, wordNo: n2));
    expect(r.match.scores[r.match.turnTeam], 0, reason: 'a skip for a word that is gone');
    expect(r.match.turnWords.length, 2);
    r.match.dispose();
  });

  testWidgets('every phone is sent the same word number as the word it sees', (t) async {
    final r = Rig();
    r.begin();
    r.match.onAction(r.ex, ObjasniAction(ObjasniAct.correct, wordNo: r.turns(r.ex).last.wordNo));
    final a = r.turns(r.ex).last, b = r.turns(r.others.first).last;
    expect([a.wordNo, a.word], [b.wordNo, b.word]);
    r.match.dispose();
  });

  testWidgets('the host cannot start while a team has nobody connected, and no pause runs in the setup', (t) async {
    final r = Rig();
    for (final id in r.match.teamMembers(1)) {
      r.match.setAway(id, true);
    }
    expect(r.match.paused, isFalse);
    r.match.onGo(1);
    expect(r.match.stage, ObjasniStageTv.setup);
    expect(r.sent[1]!.whereType<ErrorMsg>().single.message, ObjasniText.teamEmpty);
    r.match.setAway(r.match.teamMembers(1).first, false);
    r.match.onGo(1);
    expect(r.match.stage, ObjasniStageTv.ready);
    r.match.dispose();
  });

  testWidgets('the host\'s phone can press Kreni for the explainer', (t) async {
    final r = Rig();
    r.match.onGo(1);
    final stranger = r.match.ids.firstWhere((i) => i != r.ex && i != 1);
    r.match.onGo(stranger);
    expect(r.match.stage, ObjasniStageTv.ready);
    r.match.onGo(1); // the host
    expect(r.match.stage, ObjasniStageTv.play);
    r.match.dispose();
  });

  testWidgets('the word goes to the explainer and the OTHER team, never to the explainer\'s own team', (t) async {
    final r = Rig();
    r.begin();
    r.match.onAction(r.ex, const ObjasniAction(ObjasniAct.correct));
    r.match.onAction(r.ex, const ObjasniAction(ObjasniAct.skip));
    await r.wait(t, 3);
    for (final id in r.guessers) {
      for (final m in r.turns(id)) {
        expect(m.word, isNull, reason: 'guesser $id got a word');
        expect(m.role, ObjasniRole.guess);
      }
    }
    final words = r.turns(r.ex).where((m) => m.stage == ObjasniStage.play).map((m) => m.word).toList();
    expect(words.every((w) => w != null), isTrue);
    expect(words.toSet().length, greaterThanOrEqualTo(3), reason: 'a new word after every press');
    for (final id in r.others) {
      expect(r.turns(id).where((m) => m.stage == ObjasniStage.play).map((m) => m.word).toList(), words, reason: 'the other team sees the same words');
      expect(r.turns(id).last.role, ObjasniRole.watch);
    }
    expect(r.turns(r.ex).last.role, ObjasniRole.explain);
    r.match.dispose();
  });

  testWidgets('Točno +1, Preskoči -1, Prekršaj (other team) -1; wrong senders are ignored; the TV lists the done words', (t) async {
    final r = Rig();
    r.begin();
    r.match.onAction(r.guessers.first, const ObjasniAction(ObjasniAct.correct));
    r.match.onAction(r.others.first, const ObjasniAction(ObjasniAct.correct));
    r.match.onAction(r.guessers.first, const ObjasniAction(ObjasniAct.foul));
    expect(r.match.scores, [0, 0]);
    r.match.onAction(r.ex, const ObjasniAction(ObjasniAct.correct));
    r.match.onAction(r.ex, const ObjasniAction(ObjasniAct.correct));
    r.match.onAction(r.ex, const ObjasniAction(ObjasniAct.skip));
    r.match.onAction(r.others.first, const ObjasniAction(ObjasniAct.foul));
    expect(r.match.scores[r.match.turnTeam], 2 - 1 - 1);
    expect([for (final w in r.match.turnWords) w.mark], [ObjasniMark.correct, ObjasniMark.correct, ObjasniMark.skip, ObjasniMark.foul]);
    r.match.dispose();
  });

  testWidgets('the clock: a tick every second, sharper in the last 5, the turn ends at 60, a 5 s summary, then the other team', (t) async {
    final r = Rig(target: 100);
    r.begin();
    final firstTeam = r.match.turnTeam;
    await r.wait(t, 59);
    expect(r.match.stage, ObjasniStageTv.play);
    expect(r.match.secondsLeft, 1);
    await r.wait(t, 1);
    expect(r.match.stage, ObjasniStageTv.summary);
    expect(r.played.where((s) => s == Sound.quizTick).length, 54, reason: '59 down to 6');
    expect(r.played.where((s) => s == Sound.tick).length, 5);
    await r.wait(t, 4);
    expect(r.match.stage, ObjasniStageTv.summary);
    await r.wait(t, 1);
    expect(r.match.stage, ObjasniStageTv.ready);
    expect(r.match.turnTeam, 1 - firstTeam);
    r.match.dispose();
  });

  testWidgets('time up: the word on screen is lost, the summary phones get no word', (t) async {
    final r = Rig(target: 100);
    r.begin();
    r.match.onAction(r.ex, const ObjasniAction(ObjasniAct.correct));
    await r.wait(t, 60);
    expect(r.match.scores[r.match.turnTeam], 1);
    for (final id in r.match.ids) {
      expect(r.turns(id).last.stage, ObjasniStage.summary);
      expect(r.turns(id).last.word, isNull);
    }
    r.match.dispose();
  });

  testWidgets('the game ends at the end of a full round at the target; session points to the winners', (t) async {
    final r = Rig(target: 2);
    r.begin();
    final winners = r.match.teamMembers(r.match.turnTeam);
    r.match.onAction(r.ex, const ObjasniAction(ObjasniAct.correct));
    r.match.onAction(r.ex, const ObjasniAction(ObjasniAct.correct));
    await r.wait(t, 60 + 5);
    expect(r.match.stage, ObjasniStageTv.ready, reason: 'the other team has not had its turn');
    r.match.onGo(r.ex);
    await r.wait(t, 60 + 5);
    expect(r.match.stage, ObjasniStageTv.over);
    expect(r.result, {for (final id in r.match.ids) id: winners.contains(id) ? 1 : 0});
    expect(r.played, contains(Sound.fanfare));
    r.match.dispose();
  });

  testWidgets('the explainer dropping out ends the turn at once with the score it had', (t) async {
    final r = Rig(target: 100);
    r.begin();
    r.match.onAction(r.ex, const ObjasniAction(ObjasniAct.correct));
    final team = r.match.turnTeam;
    r.match.setAway(r.ex, true);
    expect(r.match.stage, ObjasniStageTv.summary);
    expect(r.match.scores[team], 1);
    await r.wait(t, 5);
    expect(r.match.stage, ObjasniStageTv.ready);
    r.match.dispose();
  });

  testWidgets('a team with nobody left pauses the game: the clock stands still, and it resumes when someone returns', (t) async {
    final r = Rig(target: 100);
    r.begin();
    await r.wait(t, 10);
    final left = r.match.secondsLeft;
    final empty = r.others;
    for (final id in empty) {
      r.match.setAway(id, true);
    }
    expect(r.match.paused, isTrue);
    await r.wait(t, 20);
    expect(r.match.secondsLeft, left, reason: 'the clock stood still');
    r.match.setAway(empty.first, false);
    expect(r.match.paused, isFalse);
    await r.wait(t, 1);
    expect(r.match.secondsLeft, left - 1);
    r.match.dispose();
  });

  testWidgets('nobody comes back in 30 s: the game ends with the scores as they are', (t) async {
    final r = Rig(target: 100);
    r.begin();
    r.match.onAction(r.ex, const ObjasniAction(ObjasniAct.correct));
    final team = r.match.turnTeam;
    for (final id in r.others) {
      r.match.setAway(id, true);
    }
    await r.wait(t, 29);
    expect(r.match.stage, ObjasniStageTv.play);
    await r.wait(t, 1);
    expect(r.match.stage, ObjasniStageTv.over);
    expect(r.match.winnerTeam, team);
    expect(r.result!.values.where((v) => v == 1).length, r.match.teamMembers(team).length);
    r.match.dispose();
  });

  testWidgets('a rejoin gets the teams and the phone\'s own turn state, never a word it may not see', (t) async {
    final r = Rig();
    r.begin();
    final g = r.guessers.first;
    final before = r.sent[g]!.length;
    r.match.rejoin(g);
    final again = r.sent[g]!.skip(before).toList();
    expect(again.whereType<ObjasniTeams>().single.team, r.match.teamOf(g));
    expect(again.whereType<ObjasniTurn>().single.word, isNull);
    final w = r.others.first;
    final b2 = r.sent[w]!.length;
    r.match.rejoin(w);
    expect(r.sent[w]!.skip(b2).whereType<ObjasniTurn>().single.word, isNotNull);
    r.match.dispose();
  });
}
