import 'dart:convert';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/blef_match.dart';
import 'package:tv/sound/sfx.dart';

BlefPack pack() => BlefPack('p', 'P', [for (var i = 0; i < 12; i++) BlefQuestion('pitanje $i?', 'Istina$i', 'https://example.org')]);

class _Sfx implements Sfx {
  _Sfx(this.log);
  final List<Sound> log;
  @override
  void play(Sound s) => log.add(s);
}

class Rig {
  Rig({int n = 4, int questions = 2, int seed = 1}) {
    match = BlefMatch(
      ids: [for (var i = 1; i <= n; i++) i],
      pack: pack(),
      settings: GameSettings(blefQuestions: questions),
      send: (id, m) => (sent[id] ??= []).add(m),
      clock: () => at,
      random: Random(seed),
      sfx: _Sfx(played),
      onOver: (s) => result = s,
    )..start();
  }
  late final BlefMatch match;
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

  String get truth => match.game.current.answer;
  void fakes() {
    for (final id in match.ids) {
      match.onFake(id, BlefFake('Moja laž $id'));
    }
  }

  List<Message> to(int id) => sent[id] ?? [];
}

void main() {
  testWidgets('every phone gets the question, and the true answer is nowhere in it', (t) async {
    final r = Rig();
    for (final id in r.match.ids) {
      final w = r.to(id).whereType<BlefWrite>().single;
      expect([w.number, w.total, w.seconds, w.sent], [1, 2, 60, null]);
      expect(w.q, r.match.q);
      expect(jsonEncode(w.toJson()).contains(r.truth), isFalse);
    }
    r.match.dispose();
  });

  testWidgets('during writing nobody learns another player\'s fake: not the TV, not another phone', (t) async {
    final r = Rig();
    r.match.onFake(1, const BlefFake('Tajna laž'));
    expect(r.match.sent, {1});
    for (final id in r.match.ids) {
      for (final m in r.to(id)) {
        if (id == 1) continue;
        expect(jsonEncode(m.toJson()).contains('Tajna'), isFalse, reason: 'player $id: ${m.encode()}');
      }
    }
    expect(r.to(1).whereType<BlefWrite>().last.sent, 'Tajna laž', reason: 'the sender gets its own ack');
    expect(r.match.listTexts, isEmpty);
    expect(r.match.shown, isEmpty);
    r.match.dispose();
  });

  testWidgets('the true answer is refused with the message; a bad fake is told why; nothing is stored', (t) async {
    final r = Rig();
    r.match.onFake(1, BlefFake(r.truth.toUpperCase()));
    expect((r.to(1).last as ErrorMsg).message, BlefText.truth);
    r.match.onFake(1, const BlefFake('   '));
    expect((r.to(1).last as ErrorMsg).message, BlefText.empty);
    r.match.onFake(1, BlefFake('x' * 41));
    expect((r.to(1).last as ErrorMsg).message, BlefText.tooLong);
    expect(r.match.sent, isEmpty);
    r.match.onFake(1, const BlefFake('Dobra laž'));
    expect(r.match.sent, {1});
    r.match.dispose();
  });

  testWidgets('writing ends early when everyone has sent; otherwise after 60 s', (t) async {
    final r = Rig();
    r.match.onFake(1, const BlefFake('a'));
    r.match.onFake(2, const BlefFake('b'));
    r.match.onFake(3, const BlefFake('c'));
    expect(r.match.stage, BlefStageTv.write);
    r.match.onFake(4, const BlefFake('d'));
    expect(r.match.stage, BlefStageTv.pick);
    final s = Rig(seed: 2);
    s.match.onFake(1, const BlefFake('a'));
    await s.wait(t, 59);
    expect(s.match.stage, BlefStageTv.write);
    await s.wait(t, 1);
    expect(s.match.stage, BlefStageTv.pick);
    r.match.dispose();
    s.match.dispose();
  });

  testWidgets('the list: every phone gets all entries but its own fake; no writers, nothing marks the truth', (t) async {
    final r = Rig();
    r.fakes();
    expect(r.match.stage, BlefStageTv.pick);
    final all = r.match.listTexts;
    expect(all.length, 5);
    expect(all.toSet(), containsAll([for (var i = 1; i <= 4; i++) 'Moja laž $i', r.truth]));
    for (final id in r.match.ids) {
      final l = r.to(id).whereType<BlefList>().single;
      expect(l.options.length, 4);
      expect(l.options, isNot(contains('Moja laž $id')));
      expect(l.options.length, l.ids.length);
      expect(l.seconds, 20);
      final j = jsonEncode(l.toJson());
      expect(j.contains('writers'), isFalse);
    }
    // the same entry has the same id on every phone
    final a = r.to(1).whereType<BlefList>().single, b = r.to(2).whereType<BlefList>().single;
    for (var i = 0; i < a.ids.length; i++) {
      final j = b.ids.indexOf(a.ids[i]);
      if (j >= 0) expect(b.options[j], a.options[i]);
    }
    r.match.dispose();
  });

  testWidgets('picking ends when everyone picked or after 20 s; your own fake cannot be picked', (t) async {
    final r = Rig();
    r.fakes();
    final l1 = r.to(1).whereType<BlefList>().single;
    final ownId = r.match.game.entries.indexWhere((e) => e.writers.contains(1));
    r.match.onPick(1, BlefPick(ownId));
    expect(r.match.picked, isEmpty);
    for (final id in r.match.ids) {
      final l = r.to(id).whereType<BlefList>().single;
      r.match.onPick(id, BlefPick(l.ids.first));
    }
    expect(r.match.stage, BlefStageTv.reveal);
    expect(l1.ids.contains(ownId), isFalse);
    r.match.dispose();

    final s = Rig(seed: 2);
    s.fakes();
    await s.wait(t, 19);
    expect(s.match.stage, BlefStageTv.pick);
    await s.wait(t, 1);
    expect(s.match.stage, BlefStageTv.reveal);
    s.match.dispose();
  });

  testWidgets('the reveal goes entry by entry, 4 s each, the fakes first and the true answer last, then points', (t) async {
    final r = Rig(questions: 1);
    r.fakes();
    final truthId = r.match.game.entries.indexWhere((e) => e.isTruth);
    for (final id in r.match.ids) {
      final l = r.to(id).whereType<BlefList>().single;
      r.match.onPick(id, BlefPick(l.ids.contains(truthId) ? truthId : l.ids.first));
    }
    expect(r.match.stage, BlefStageTv.reveal);
    expect(r.match.shown.length, 1);
    expect(r.match.shown.first.isTruth, isFalse);
    expect(r.match.questionPoints, isNull);
    for (var k = 1; k < 5; k++) {
      await r.wait(t, 4);
      if (k < 4) expect(r.match.shown.length, k + 1);
    }
    expect(r.match.stage, BlefStageTv.reveal, reason: 'the last entry shows for its 4 s');
    expect(r.match.shown.last.isTruth, isTrue);
    expect(r.match.questionPoints, isNotNull);
    expect(r.to(1).whereType<BlefResult>().length, 1);
    await r.wait(t, 4);
    expect(r.match.stage, BlefStageTv.over);
    expect(r.result, isNotNull);
    r.match.dispose();
  });

  testWidgets('points to the right phones: +1000 for the truth, +500 for each fooled; each phone gets only its own', (t) async {
    final r = Rig(n: 3, questions: 1);
    r.fakes();
    final entries = r.match.game.entries;
    int idx(int w) => entries.indexWhere((e) => e.writers.contains(w));
    final truthId = entries.indexWhere((e) => e.isTruth);
    r.match.onPick(1, BlefPick(truthId));
    r.match.onPick(2, BlefPick(idx(3)));
    r.match.onPick(3, BlefPick(idx(2)));
    await r.wait(t, 4 * 4);
    final r1 = r.to(1).whereType<BlefResult>().single;
    final r2 = r.to(2).whereType<BlefResult>().single;
    final r3 = r.to(3).whereType<BlefResult>().single;
    expect([r1.points, r1.foundTruth, r1.fooled], [1000, true, 0]);
    expect([r2.points, r2.foundTruth, r2.fooled], [500, false, 1]);
    expect([r3.points, r3.foundTruth, r3.fooled], [500, false, 1]);
    r.match.dispose();
  });

  testWidgets('a reload restores the phone\'s own fake, own list and pick, and nothing of anyone else\'s', (t) async {
    final r = Rig();
    r.match.onFake(1, const BlefFake('Moja laž 1'));
    r.match.rejoin(1);
    expect(r.to(1).whereType<BlefWrite>().last.sent, 'Moja laž 1');
    r.match.rejoin(2);
    expect(r.to(2).whereType<BlefWrite>().last.sent, isNull);
    expect(jsonEncode(r.to(2).map((m) => m.toJson()).toList()).contains('Moja laž 1'), isFalse);
    r.match.onFake(2, const BlefFake('b'));
    r.match.onFake(3, const BlefFake('c'));
    r.match.onFake(4, const BlefFake('d'));
    final l = r.to(1).whereType<BlefList>().single;
    r.match.onPick(1, BlefPick(l.ids.first));
    r.match.rejoin(1);
    final again = r.to(1).whereType<BlefList>().last;
    expect(again.picked, l.ids.first);
    expect(again.options, isNot(contains('Moja laž 1')));
    r.match.dispose();
  });

  testWidgets('a player who drops out is not waited for and scores 0', (t) async {
    final r = Rig(n: 3);
    r.match.onFake(1, const BlefFake('a'));
    r.match.onFake(2, const BlefFake('b'));
    r.match.setAway(3, true);
    expect(r.match.stage, BlefStageTv.pick, reason: 'the only one missing is away');
    r.match.dispose();
  });

  testWidgets('the game ends after the last question with session points', (t) async {
    final r = Rig(n: 3, questions: 2);
    for (var q = 0; q < 2; q++) {
      r.fakes();
      final truthId = r.match.game.entries.indexWhere((e) => e.isTruth);
      for (final id in r.match.ids) {
        final l = r.to(id).whereType<BlefList>().last;
        r.match.onPick(id, BlefPick(id == 1 && l.ids.contains(truthId) ? truthId : l.ids.last));
      }
      await r.wait(t, 4 * 4 + 4);
    }
    expect(r.match.stage, BlefStageTv.over);
    expect(r.result!.keys.toSet(), {1, 2, 3});
    expect(r.played, contains(Sound.fanfare));
    r.match.dispose();
  });

  testWidgets('a screen lock during writing: drop, rejoin, and the fake counts; the same during picking', (t) async {
    final r = Rig(n: 3);
    r.match.onFake(1, const BlefFake('a'));
    r.match.setAway(3, true);
    r.match.setAway(3, false);
    r.match.rejoin(3);
    expect(r.to(3).whereType<BlefWrite>().length, 2);
    r.match.onFake(3, const BlefFake('moja'));
    expect(r.match.sent, {1, 3});
    r.match.onFake(2, const BlefFake('b'));
    expect(r.match.stage, BlefStageTv.pick);
    r.match.setAway(2, true);
    r.match.setAway(2, false);
    r.match.rejoin(2);
    final l = r.to(2).whereType<BlefList>().last;
    r.match.onPick(2, BlefPick(l.ids.first));
    expect(r.match.picked, {2});
    r.match.dispose();
  });

  testWidgets('a fake with a trailing dot is still the true answer; 40 characters are counted as characters', (t) async {
    final r = Rig();
    r.match.onFake(1, BlefFake('${r.truth}.'));
    expect((r.to(1).last as ErrorMsg).message, BlefText.truth);
    r.match.onFake(1, BlefFake('😀' * 40));
    expect(r.match.sent, {1});
    r.match.onFake(2, BlefFake('😀' * 41));
    expect((r.to(2).last as ErrorMsg).message, BlefText.tooLong);
    r.match.dispose();
  });
}
