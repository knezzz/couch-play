import 'dart:convert';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/kaosvi_match.dart';
import 'package:tv/sound/sfx.dart';

KaosviPack pack() => KaosviPack('p', 'P', [for (var i = 0; i < 30; i++) 'Navedi nešto $i.']);

class _Sfx implements Sfx {
  _Sfx(this.log);
  final List<Sound> log;
  @override
  void play(Sound s) => log.add(s);
}

class Rig {
  Rig({int n = 5, int questions = 3, int target = 8, int host = 1, int seed = 1}) : _host = host {
    match = KaosviMatch(
      ids: [for (var i = 1; i <= n; i++) i],
      pack: pack(),
      settings: GameSettings(kaosviQuestions: questions, kaosviTarget: target),
      hostId: () => _host,
      send: (id, m) => (sent[id] ??= []).add(m),
      clock: () => at,
      random: Random(seed),
      sfx: _Sfx(played),
      onOver: (s) => result = s,
    )..start();
  }
  late final KaosviMatch match;
  int _host;
  void setHost(int id) => _host = id;
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

  List<Message> to(int id) => sent[id] ?? [];

  /// Everyone answers; the merge opens.
  void answers(List<String> a) {
    for (var i = 0; i < a.length; i++) {
      match.onAnswer(i + 1, KaosviAnswer(a[i]));
    }
  }
}

void main() {
  testWidgets('every phone gets the question; the TV knows who answered and never what', (t) async {
    final r = Rig();
    for (final id in r.match.ids) {
      final a = r.to(id).whereType<KaosviAsk>().single;
      expect([a.number, a.total, a.seconds, a.q, a.sent], [1, 3, 30, r.match.q, null]);
    }
    r.match.onAnswer(2, const KaosviAnswer('Tajni odgovor'));
    expect(r.match.sent, {2});
    expect(r.match.reveal, isNull);
    for (final id in r.match.ids) {
      for (final m in r.to(id)) {
        if (id == 2) continue;
        expect(jsonEncode(m.toJson()).contains('Tajni'), isFalse, reason: 'player $id: ${m.encode()}');
      }
    }
    expect(r.to(2).whereType<KaosviAsk>().last.sent, 'Tajni odgovor', reason: 'the sender\'s own ack');
    r.match.dispose();
  });

  testWidgets('empty and too long are refused with a text; the first accepted one is final', (t) async {
    final r = Rig();
    r.match.onAnswer(1, const KaosviAnswer('  '));
    expect((r.to(1).last as ErrorMsg).message, KaosviText.empty);
    r.match.onAnswer(1, KaosviAnswer('x' * 31));
    expect((r.to(1).last as ErrorMsg).message, KaosviText.tooLong);
    expect(r.match.sent, isEmpty);
    r.match.onAnswer(1, const KaosviAnswer('jabuka'));
    r.match.onAnswer(1, const KaosviAnswer('kruška'));
    expect(r.match.game.answerOf(1), 'jabuka');
    r.match.dispose();
  });

  testWidgets('everybody answered: the merge opens at once; otherwise after 30 s', (t) async {
    final r = Rig();
    r.answers(['a', 'a', 'b', 'c']);
    expect(r.match.stage, KaosviStageTv.answer);
    r.match.onAnswer(5, const KaosviAnswer('a'));
    expect(r.match.stage, KaosviStageTv.merge);
    final s = Rig(seed: 2);
    s.match.onAnswer(1, const KaosviAnswer('a'));
    await s.wait(t, 29);
    expect(s.match.stage, KaosviStageTv.answer);
    await s.wait(t, 1);
    expect(s.match.stage, KaosviStageTv.merge);
    expect(s.played.where((x) => x == Sound.tick).length, 5);
    r.match.dispose();
    s.match.dispose();
  });

  testWidgets('PRIVACY: during the merge only the host\'s phone gets the answers, texts without writers; everyone else an empty list', (t) async {
    final r = Rig();
    r.answers(['Jabuka', 'jabuka', 'Kruška', 'Šljiva', 'Višnja']);
    for (final id in r.match.ids) {
      final m = r.to(id).whereType<KaosviMerging>().single;
      expect(m.host, id == 1);
      if (id == 1) {
        expect(m.groups.map((g) => g.text).toSet(), {'Jabuka', 'Kruška', 'Šljiva', 'Višnja'});
        expect(m.groups.length, 4);
        final j = jsonEncode(m.toJson());
        expect(j.contains('members'), isFalse);
        expect(j.contains('writers'), isFalse);
      } else {
        expect(m.groups, isEmpty);
        expect(jsonEncode(m.toJson()).contains('Jabuka'), isFalse, reason: 'player $id');
      }
      expect(m.seconds, 15);
    }
    // nobody but the host got any answer text in anything
    for (final id in r.match.ids.where((i) => i != 1)) {
      final all = jsonEncode(r.to(id).map((m) => m.toJson()).toList());
      for (final w in ['Jabuka', 'Kruška', 'Šljiva', 'Višnja']) {
        expect(all.contains(w), id == 3 && w == 'Kruška' || id == 4 && w == 'Šljiva' || id == 5 && w == 'Višnja' || id == 2 && w == 'jabuka', reason: 'player $id / $w');
      }
    }
    expect(r.match.reveal, isNull, reason: 'the TV has nothing before the reveal');
    r.match.dispose();
  });

  testWidgets('only the host merges; a merge is sent back to the host; Gotovo ends it; the other phones are not sent groups', (t) async {
    final r = Rig();
    r.answers(['jabuka', 'jabuke', 'x', 'y', 'z']);
    final groups = r.to(1).whereType<KaosviMerging>().last.groups;
    final a = groups.firstWhere((g) => g.text == 'jabuka').id, b = groups.firstWhere((g) => g.text == 'jabuke').id;
    r.match.onMerge(2, KaosviMerge(a, b)); // not the host
    expect(r.match.game.groups.length, 5);
    r.match.onMerge(1, KaosviMerge(a, b));
    expect(r.match.game.groups.length, 4);
    expect(r.to(1).whereType<KaosviMerging>().last.groups.length, 4, reason: 'the host sees the merged list');
    expect(r.to(2).whereType<KaosviMerging>().length, 1, reason: 'the others are not told again');
    r.match.onDone(3); // not the host
    expect(r.match.stage, KaosviStageTv.merge);
    r.match.onDone(1);
    expect(r.match.stage, KaosviStageTv.reveal);
    r.match.dispose();
  });

  testWidgets('the merge ends by itself after 15 s', (t) async {
    final r = Rig();
    r.answers(['a', 'a', 'b', 'c', 'd']);
    await r.wait(t, 14);
    expect(r.match.stage, KaosviStageTv.merge);
    await r.wait(t, 1);
    expect(r.match.stage, KaosviStageTv.reveal);
    r.match.dispose();
  });

  testWidgets('the reveal: groups largest first with writers, each phone gets its own result; points are the change really applied', (t) async {
    final r = Rig();
    r.answers(['jabuka', 'Jabuka', 'JABUKA ', 'kruška', 'šljiva']);
    r.match.onDone(1);
    final rv = r.match.reveal!;
    expect(rv.groups.first.members.toSet(), {1, 2, 3});
    expect(rv.lone, isNull, reason: 'two singles');
    final r1 = r.to(1).whereType<KaosviResult>().single;
    expect([r1.answer, r1.size, r1.points, r1.total, r1.largest, r1.lone], ['jabuka', 3, 1, 1, true, false]);
    final r4 = r.to(4).whereType<KaosviResult>().single;
    expect([r4.answer, r4.size, r4.points, r4.largest], ['kruška', 1, 0, false]);
    r.match.dispose();
  });

  testWidgets('the lone player gets lone: true; a tie scores nobody and no group is the largest', (t) async {
    final r = Rig(n: 5);
    r.answers(['a', 'a', 'b', 'b', 'z']);
    r.match.onDone(1);
    final lone = r.to(5).whereType<KaosviResult>().single;
    expect([lone.lone, lone.points, lone.largest], [true, 0, false], reason: 'at 0 there is nothing to lose');
    expect(r.to(1).whereType<KaosviResult>().single.largest, isFalse);
    r.match.dispose();
  });

  testWidgets('reveal 8 s, then the next question; the target or the last question ends the game with session points', (t) async {
    final r = Rig(questions: 2, target: 100);
    for (var q = 1; q <= 2; q++) {
      expect(r.match.number, q);
      r.answers(['a', 'a', 'a', 'b', 'c']);
      r.match.onDone(1);
      await r.wait(t, 7);
      expect(r.match.stage, KaosviStageTv.reveal);
      await r.wait(t, 1);
    }
    expect(r.match.stage, KaosviStageTv.over);
    expect(r.result, {1: 2, 2: 2, 3: 2, 4: 0, 5: 0});
    expect(r.played, contains(Sound.fanfare));
    r.match.dispose();
  });

  testWidgets('a game that reaches the target stops early', (t) async {
    final r = Rig(questions: 12, target: 2);
    for (var q = 0; q < 2; q++) {
      r.answers(['a', 'a', 'a', 'b', 'c']);
      r.match.onDone(1);
      await r.wait(t, 8);
    }
    expect(r.match.stage, KaosviStageTv.over);
    r.match.dispose();
  });

  testWidgets('nobody answered: no merge, straight to the reveal with no points', (t) async {
    final r = Rig();
    await r.wait(t, 30);
    expect(r.match.stage, KaosviStageTv.reveal);
    expect(r.to(1).whereType<KaosviMerging>(), isEmpty);
    expect(r.to(1).whereType<KaosviResult>().single.points, 0);
    r.match.dispose();
  });

  testWidgets('a screen lock: drop, rejoin and the answer counts; a reload gets own answer back and nobody else\'s', (t) async {
    final r = Rig(n: 3);
    r.match.onAnswer(1, const KaosviAnswer('moj'));
    r.match.setAway(3, true);
    r.match.setAway(3, false);
    r.match.rejoin(3);
    expect(r.to(3).whereType<KaosviAsk>().length, 2);
    r.match.onAnswer(3, const KaosviAnswer('tvoj'));
    expect(r.match.sent, {1, 3});
    r.match.rejoin(1);
    expect(r.to(1).whereType<KaosviAsk>().last.sent, 'moj');
    r.match.rejoin(2);
    expect(r.to(2).whereType<KaosviAsk>().last.sent, isNull);
    expect(jsonEncode(r.to(2).map((m) => m.toJson()).toList()).contains('moj'), isFalse);
    r.match.dispose();
  });

  testWidgets('a reload in the merge: the host gets the groups again, the others an empty list; after the reveal, their own result', (t) async {
    final r = Rig(n: 3);
    r.answers(['a', 'b', 'c']);
    r.match.rejoin(1);
    expect(r.to(1).whereType<KaosviMerging>().last.groups.length, 3);
    r.match.rejoin(2);
    expect(r.to(2).whereType<KaosviMerging>().last.groups, isEmpty);
    r.match.onDone(1);
    final before = r.to(2).whereType<KaosviResult>().length;
    r.match.rejoin(2);
    expect(r.to(2).whereType<KaosviResult>().length, before + 1);
    r.match.dispose();
  });

  testWidgets('a merged group shows every spelling at the reveal, and the host\'s list is sorted by text', (t) async {
    final r = Rig();
    r.answers(['zebra', 'zebra', 'zebra', 'Banana', 'ananas']);
    final groups = r.to(1).whereType<KaosviMerging>().last.groups;
    expect(groups.map((g) => g.text), ['ananas', 'Banana', 'zebra'], reason: 'by text, not by size');
    r.match.onMerge(1, KaosviMerge(groups.firstWhere((g) => g.text == 'zebra').id, groups.firstWhere((g) => g.text == 'Banana').id));
    expect(r.to(1).whereType<KaosviMerging>().last.groups.map((g) => g.text), ['ananas', 'zebra · Banana']);
    r.match.onDone(1);
    final shown = r.match.reveal!.groups.first;
    expect(shown.texts, ['zebra', 'Banana']);
    expect(shown.members.length, 4);
    expect(r.to(4).whereType<KaosviResult>().single.answer, 'Banana', reason: 'a phone is told its OWN spelling');
    r.match.dispose();
  });

  testWidgets('the host changes in the middle of the merge: the new host gets the groups, the old one an empty list', (t) async {
    final r = Rig(n: 4);
    r.answers(['a', 'b', 'c', 'd']);
    expect(r.to(2).whereType<KaosviMerging>().last.groups, isEmpty);
    r.setHost(2);
    r.match.refreshHost();
    expect(r.to(2).whereType<KaosviMerging>().last.groups.length, 4);
    expect(r.to(2).whereType<KaosviMerging>().last.host, isTrue);
    expect(r.to(1).whereType<KaosviMerging>().last.groups, isEmpty);
    expect(r.to(1).whereType<KaosviMerging>().last.host, isFalse);
    // the new host can merge; the old one cannot any more
    final g = r.to(2).whereType<KaosviMerging>().last.groups;
    r.match.onMerge(1, KaosviMerge(g[0].id, g[1].id));
    expect(r.match.game.groups.length, 4);
    r.match.onMerge(2, KaosviMerge(g[0].id, g[1].id));
    expect(r.match.game.groups.length, 3);
    // nothing is resent when the host did not change
    final n = r.to(2).length, m = r.to(1).length;
    r.match.refreshHost();
    expect([r.to(2).length, r.to(1).length], [n, m]);
    r.match.dispose();
  });
}
