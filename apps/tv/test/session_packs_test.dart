import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/packs/pack_store.dart';
import 'package:tv/session/party_text.dart';
import 'package:tv/session/session.dart';

import 'session_test.dart' show FakePeer, join;

/// Task 46: packs are multi-select; the session keeps the OFF packs, draws
/// from the union of the ticked ones and keeps at least one ticked.
UljezPack uljez(String id, {int n = 6, String prefix = ''}) =>
    UljezPack(id, 'T $id', [for (var i = 0; i < n; i++) WordPair('$prefix$i-a', '$prefix$i-b')]);

Uint8List quizBytes(String id, List<String> qs) => Uint8List.fromList(utf8.encode(jsonEncode({
      'format': 1,
      'id': id,
      'title': 'Q $id',
      'questions': [for (final q in qs) {'q': q, 'choices': ['a', 'b', 'c', 'd'], 'answer': 0}],
    })));

void main() {
  late Session s;
  late List<FakePeer> ps;

  void setUpSession({int n = 3}) {
    s = Session(random: Random(1))..uljezTvReady = true;
    s.uljezPacks = [uljez('one'), uljez('two', prefix: 'x'), uljez('three', prefix: 'y')];
    ps = [for (var i = 0; i < n; i++) join(s, 'P$i', token: 't$i')];
  }

  test('by default every pack is ticked and the game draws from all of them, without repeats', () {
    setUpSession();
    expect(s.packSelection(GameKind.uljez), (ticked: 3, total: 3));
    expect(s.settings.uljezOffPacks, isEmpty);
    ps[0].say(const StartGame(GameKind.uljez, null));
    final p = s.uljez!.pack;
    expect(p.pairs.length, 18);
    expect(p.title, PartyText.allPacks);
    s.dispose();
  });

  test('a pack the same in two packs is drawn once (the same pair in the other order too)', () {
    setUpSession();
    s.uljezPacks = [
      UljezPack('one', 'One', [for (var i = 0; i < 5; i++) WordPair('w$i', 'v$i')]),
      UljezPack('two', 'Two', [const WordPair('V0', 'W0'), for (var i = 5; i < 8; i++) WordPair('w$i', 'v$i')]),
    ];
    ps[0].say(const StartGame(GameKind.uljez, null));
    expect(s.uljez!.pack.pairs.length, 8, reason: '5 + 3 new; "V0 W0" is "w0 v0" reversed');
    s.dispose();
  });

  test('unticked packs are left out; one ticked pack plays as itself; the line is "n od N"', () {
    setUpSession();
    ps[0].say(const SetSettings(GameSettings(uljezOffPacks: {'one'})));
    expect(s.packSelection(GameKind.uljez), (ticked: 2, total: 3));
    ps[0].say(const StartGame(GameKind.uljez, null));
    expect(s.uljez!.pack.pairs.length, 12);
    expect(s.uljez!.pack.title, PartyText.somePacks(2, 3));
    s.dispose();
    setUpSession();
    ps[0].say(const SetSettings(GameSettings(uljezOffPacks: {'one', 'three'})));
    ps[0].say(const StartGame(GameKind.uljez, null));
    expect(s.uljez!.pack.id, 'two');
    s.dispose();
  });

  test('the last pack cannot be unticked: that change is ignored for the game, the rest of the message applies', () {
    setUpSession();
    ps[0].say(const SetSettings(GameSettings(uljezOffPacks: {'one', 'two'}, kolikoSeconds: 45)));
    expect(s.settings.uljezOffPacks, {'one', 'two'});
    ps[0].say(const SetSettings(GameSettings(uljezOffPacks: {'one', 'two', 'three'}, kolikoSeconds: 20)));
    expect(s.settings.uljezOffPacks, {'one', 'two'}, reason: 'unticking the last one keeps the previous selection');
    expect(s.settings.kolikoSeconds, 20);
    expect(s.packSelection(GameKind.uljez), (ticked: 1, total: 3));
    ps[0].say(const SetSettings(GameSettings(uljezOffPacks: {'zzz-gone', 'one', 'two', 'three'})));
    expect(s.settings.uljezOffPacks, {'one', 'two'});
    s.dispose();
  });

  test('the selection is remembered, and a pack that appears later starts ticked', () {
    final dir = Directory.systemTemp.createTempSync('packsel');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/settings.json');
    setUpSession();
    s.loadSettings(file);
    ps[0].say(const SetSettings(GameSettings(uljezOffPacks: {'two'})));
    s.dispose();
    s = Session(random: Random(1))..uljezTvReady = true;
    s.uljezPacks = [uljez('one'), uljez('two', prefix: 'x'), uljez('three', prefix: 'y'), uljez('new', prefix: 'n')];
    s.loadSettings(file);
    expect(s.settings.uljezOffPacks, {'two'});
    expect(s.tickedPackIds(GameKind.uljez), ['one', 'three', 'new'], reason: 'the new pack is ticked');
    expect(s.packSelection(GameKind.uljez), (ticked: 3, total: 4));
    s.dispose();
  });

  test('old settings with one pack id mean "only that pack"; an id the TV does not have means all', () {
    setUpSession();
    ps[0].say(const SetSettings(GameSettings(uljezPackId: 'two')));
    expect(s.settings.uljezPackId, isNull);
    expect(s.settings.uljezOffPacks, {'one', 'three'});
    expect(s.tickedPackIds(GameKind.uljez), ['two']);
    ps[0].say(const SetSettings(GameSettings(uljezPackId: 'gone', kolikoSeconds: 45)));
    expect(s.settings.uljezOffPacks, isEmpty);
    expect(s.settings.kolikoSeconds, 45, reason: 'the other settings are kept');
    s.dispose();
    // an old file read before the packs were loaded is decided once they are
    final dir = Directory.systemTemp.createTempSync('oldsel');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/s.json')
      ..writeAsStringSync(jsonEncode(const GameSettings(uljezPackId: 'three').toJson()));
    s = Session(random: Random(1))..uljezTvReady = true;
    s.loadSettings(file);
    s.uljezPacks = [uljez('one'), uljez('two', prefix: 'x'), uljez('three', prefix: 'y')];
    expect(s.tickedPackIds(GameKind.uljez), ['three'], reason: 'decided at the first use after the packs load');
    ps = [for (var i = 0; i < 3; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.uljez, null));
    expect(s.uljez!.pack.id, 'three');
    s.dispose();
  });

  test('the lobby the phones get carries the selection', () {
    setUpSession();
    ps[0].say(const SetSettings(GameSettings(uljezOffPacks: {'one'})));
    expect(ps[0].last<LobbyState>()!.settings.uljezOffPacks, {'one'});
    s.dispose();
  });

  test('quiz: uploaded packs are ticked by default too, and the quiz draws from the union without repeats', () async {
    final dir = Directory.systemTemp.createTempSync('quizsel');
    addTearDown(() => dir.deleteSync(recursive: true));
    final a = quizBytes('pa', [for (var i = 0; i < 12; i++) 'a$i']);
    final b = quizBytes('pb', ['A0', 'a1', 'a2', 'a3', for (var i = 0; i < 8; i++) 'b$i']);
    s = Session(random: Random(1));
    s.packStore = await PackStore.load(bundled: [a, b], userDir: dir);
    ps = [for (var i = 0; i < 2; i++) join(s, 'P$i', token: 't$i')];
    expect(s.packSelection(GameKind.quiz), (ticked: 2, total: 2));
    ps[0].say(const SetSettings(GameSettings(quizQuestions: 30)));
    ps[0].say(const StartGame(GameKind.quiz, null));
    expect(s.quiz!.total, 20, reason: '12 + 8 new; four repeats drawn once');
    expect(s.quizTitle, PartyText.allPacks);
    s.returnToLobby();
    ps[0].say(const SetSettings(GameSettings(quizQuestions: 30, quizOffPacks: {'pa'})));
    ps[0].say(const StartGame(GameKind.quiz, null));
    expect(s.quiz!.total, 12);
    expect(s.quizTitle, 'Q pb');
    // an upload arrives: it starts ticked
    s.returnToLobby();
    final c = quizBytes('pc', [for (var i = 0; i < 5; i++) 'c$i']);
    expect(await s.packStore!.add(c), isNull);
    expect(s.tickedPackIds(GameKind.quiz).contains('pc'), isTrue);
    expect(s.packSelection(GameKind.quiz), (ticked: 2, total: 3));
    s.dispose();
  });
}
