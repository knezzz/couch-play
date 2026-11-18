import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('roundtrip_all_messages', () {
    final messages = <Message>[
      const Join('Ana', 'tok'),
      const Join('Ana', 'tok', character: 'owl'),
      const SetCharacter('frog'),
      const Welcome(1, 2, 'tok', character: 'fox'),
      const Steer(left: true, right: false),
      const Answer(2),
      const StartGame(GameKind.quiz, 'pack1'),
      const StartGame(GameKind.curve, null),
      const Kick(3),
      const SetBots(4),
      const SelectGame(null),
      const SelectGame(GameKind.quiz),
      const SelectGame(GameKind.curve),
      const SetSettings(GameSettings(quizOffPacks: {'hr-povijest'})),
      const SetSettings(GameSettings(quizSeconds: 30, quizQuestions: 15, revealSeconds: 6, curveCountdown: 3, curveMode: CurveMode.chaos)),
      const Ping(123),
      const Welcome(1, 2, 'tok'),
      const LobbyState(
        players: [
          PlayerInfo(1, 'Ana', 0, true, 5),
          PlayerInfo(2, 'Bot 1', 1, true, 0, bot: true, character: 'bear'),
        ],
        packs: [PackInfo('p', 'Pack', 10)],
        hostId: 1,
      ),
      const LobbyState(
        players: [],
        packs: [],
        hostId: 1,
        settings: GameSettings(quizSeconds: 45, quizQuestions: 5, revealSeconds: 2, curveCountdown: 10),
      ),
      const LobbyState(
        players: [],
        packs: [],
        hostId: 1,
        selected: GameKind.curve,
        settings: GameSettings(quizOffPacks: {'flags'}),
      ),
      const QuizQuestion(1, 10, ['a', 'b', 'c', 'd'], 20),
      const QuizReveal(2, 750, 1500),
      const CurveStatus(alive: true, score: 3, target: 10),
      const CurveStatus(alive: false, score: 12, target: 30, round: 4),
      const Results([Placement(1, 1, 7, 3)]),
      const Effect('confetti'),
      const Pong(123),
      const Waiting('Waiting for the host.'),
      const ErrorMsg('The game is full (8 players).'),
      const Kicked(),
    ];
    for (final m in messages) {
      expect(Message.decode(m.encode()), m, reason: m.encode());
    }
  });

  test('decode_rejects_garbage', () {
    expect(Message.decode('not json'), isNull);
    expect(Message.decode('{"type":"nope"}'), isNull);
    expect(Message.decode('{"type":"answer","index":"2"}'), isNull);
    expect(Message.decode('[1]'), isNull);
    expect(Message.decode('{"type":"bots","count":"3"}'), isNull);
    expect(Message.decode('{"type":"bots"}'), isNull);
    expect(Message.decode('{"type":"start","game":"chess"}'), isNull);
    expect(Message.decode('{"type":"lobby","players":[1],"packs":[],"hostId":1}'),
        isNull);
  });

  test('player_info_without_bot_field_is_a_human', () {
    final m = Message.decode(
        '{"type":"lobby","players":[{"id":1,"name":"Ana","colorIndex":0,'
        '"connected":true,"sessionScore":0}],"packs":[],"hostId":1}');
    expect((m as LobbyState).players.single.bot, isFalse);
  });

  group('characters', () {
    test('sixteen_unique_ids', () {
      expect(characterIds, hasLength(16));
      expect(characterIds.toSet(), hasLength(16));
      expect(characterIds.first, 'fox');
    });

    test('isCharacter_knows_only_the_ids', () {
      expect(isCharacter('fox'), isTrue);
      expect(isCharacter('Fox'), isFalse);
      expect(isCharacter(''), isFalse);
    });

    test('old_messages_without_a_character_still_decode', () {
      expect(Message.decode('{"type":"join","name":"Ana","token":"t"}'), const Join('Ana', 't'));
      expect((Message.decode('{"type":"join","name":"Ana","token":"t"}') as Join).character, isNull);
      expect(Message.decode('{"type":"welcome","playerId":1,"colorIndex":2,"token":"t"}'),
          const Welcome(1, 2, 't'));
      final lobby = Message.decode(
          '{"type":"lobby","players":[{"id":1,"name":"A","colorIndex":0,"connected":true,"sessionScore":0}],"packs":[],"hostId":1}');
      expect((lobby as LobbyState).players.single.character, '');
    });

    test('a_wrong_typed_character_is_null', () {
      expect(Message.decode('{"type":"character","id":5}'), isNull);
      expect(Message.decode('{"type":"character"}'), isNull);
      expect(Message.decode('{"type":"join","name":"A","token":"t","character":3}'), isNull);
    });
  });

  group('game settings', () {
    test('defaults', () {
      const d = GameSettings();
      expect([d.quizSeconds, d.quizQuestions, d.revealSeconds, d.curveCountdown], [20, 10, 4, 2]);
      expect(d.curveMode, CurveMode.balanced);
    });

    test('clamped_snaps_to_the_steps_and_the_range', () {
      GameSettings g(int a, int b, int c, int d) =>
          GameSettings(quizSeconds: a, quizQuestions: b, revealSeconds: c, curveCountdown: d).clamped();
      expect(g(-5, 0, -1, 0), const GameSettings(quizSeconds: 10, quizQuestions: 5, revealSeconds: 2, curveCountdown: 1));
      expect(g(999, 999, 999, 999), const GameSettings(quizSeconds: 60, quizQuestions: 30, revealSeconds: 15, curveCountdown: 10));
      expect(g(22, 12, 4, 2), const GameSettings(quizSeconds: 20, quizQuestions: 10, revealSeconds: 4, curveCountdown: 2));
      expect(g(23, 13, 4, 2), const GameSettings(quizSeconds: 25, quizQuestions: 15, revealSeconds: 4, curveCountdown: 2));
    });

    test('clamped_keeps_the_mode', () {
      for (final m in CurveMode.values) {
        expect(GameSettings(curveMode: m, quizSeconds: 999).clamped().curveMode, m);
      }
    });

    test('every_mode_round_trips_and_a_missing_mode_is_balanced_and_an_unknown_one_is_null', () {
      for (final m in CurveMode.values) {
        final msg = SetSettings(GameSettings(curveMode: m));
        expect(Message.decode(msg.encode()), msg);
      }
      expect(
          (Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2}')
                  as SetSettings)
              .settings
              .curveMode,
          CurveMode.balanced);
      expect(
          Message.decode(
              '{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2,"curveMode":"wild"}'),
          isNull);
    });

    test('the_pack_is_part_of_the_settings_and_survives_clamping', () {
      expect(const GameSettings().quizOffPacks, isEmpty);
      expect(const GameSettings(quizOffPacks: {'x'}, quizSeconds: 999).clamped().quizOffPacks, {'x'});
      final m = Message.decode(const SetSettings(GameSettings(quizOffPacks: {'x'})).encode());
      expect((m as SetSettings).settings.quizOffPacks, {'x'});
      expect(Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2}'),
          const SetSettings(GameSettings()));
      expect(Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2,"quizOffPacks":5}'), isNull);
    });

    test('selection_defaults_to_none_and_a_bad_game_name_is_null', () {
      final m = Message.decode('{"type":"lobby","players":[],"packs":[],"hostId":1}');
      expect((m as LobbyState).selected, isNull);
      expect(Message.decode('{"type":"select","game":"chess"}'), isNull);
      expect(Message.decode('{"type":"select"}'), const SelectGame(null));
    });

    test('a_lobby_without_settings_decodes_to_the_defaults', () {
      final m = Message.decode('{"type":"lobby","players":[],"packs":[],"hostId":1}');
      expect((m as LobbyState).settings, const GameSettings());
    });

    test('a_settings_message_with_a_wrong_type_is_null', () {
      expect(Message.decode('{"type":"settings","quizSeconds":"20","quizQuestions":10,"revealSeconds":4,"curveCountdown":2}'), isNull);
      expect(Message.decode('{"type":"settings"}'), isNull);
    });
  });

  group('vukodlak', () {
    test('every new message round trips', () {
      final ms = <Message>[
        const StartGame(GameKind.vukodlak, null),
        const SelectGame(GameKind.vukodlak),
        const NightPick(3, special: true, second: 4),
        const NightPick(null),
        const Vote(2),
        const Vote(null),
        const Shoot(4),
        const RoleMsg(WolfRole.wolf, [2], [WolfRole.wolf, WolfRole.villager, WolfRole.seer], hide: true),
        const NightPrompt(night: 2, text: 'x', choices: ['Ana', 'Ivo'], ids: [1, 2], choices2: ['12', '40'], ids2: [0, 1], picks: 2, picked: 2, picked2: 3, special: true, done: true),
        const NightPrompt(night: 1, text: '', choices: ['12', '40'], ids: [0, 1]),
        const Morning(2, 'Vidjela si'),
        const VotePrompt(day: 1, seconds: 120, ids: [1, 2, 3], canVote: false, picked: 3),
        const Farewell(seconds: 15, ids: [1, 2]),
        const WolfEnd(WolfWinner.lone, {1: WolfRole.lone, 2: WolfRole.seer}),
        const SetSettings(GameSettings(wolfRoles: {WolfRole.wolf, WolfRole.villager, WolfRole.cupid}, wolfHideRoles: false)),
      ];
      for (final m in ms) {
        expect(Message.decode(m.encode()), m, reason: m.encode());
      }
    });

    test('pack selection: off-sets default to empty (all ticked), round-trip, old messages and old single ids decode', () {
      const d = GameSettings();
      for (final g in GameKind.values) {
        expect(d.offPacks(g), isEmpty, reason: g.name);
      }
      const s = GameSettings(quizOffPacks: {'b', 'a'}, uljezOffPacks: {'u1'}, kaosviOffPacks: {'k'});
      final back = (Message.decode(const SetSettings(s).encode()) as SetSettings).settings;
      expect(back, s);
      expect(back.offPacks(GameKind.quiz), {'a', 'b'});
      expect(back.clamped().offPacks(GameKind.uljez), {'u1'}, reason: 'clamping keeps the selection');
      expect(s.toJson()['quizOffPacks'], ['a', 'b'], reason: 'sorted: equal sets are equal messages');
      final old = Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2,"quizPackId":"x","uljezPackId":"y"}');
      // the old single ids are gone: the keys are ignored and every pack stays ticked
      final o = (old as SetSettings).settings;
      expect([o.quizOffPacks, o.uljezOffPacks], [isEmpty, isEmpty]);
      expect(Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2,"quizOffPacks":[1]}'), isNull);
    });

    test('wolf settings: defaults, an old settings message, and clamping', () {
      const d = GameSettings();
      expect(d.wolfRoles, GameSettings.defaultWolfRoles);
      expect(d.wolfHideRoles, isTrue);
      final old = Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2}');
      expect((old as SetSettings).settings, const GameSettings());
      final c = const GameSettings(wolfRoles: {WolfRole.seer}).clamped();
      expect(c.wolfRoles, {WolfRole.seer, WolfRole.wolf, WolfRole.villager}, reason: 'wolf and villager are always on');
      final oldKeys = Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2,"wolfDiscussion":60,"uljezDiscussion":120}');
      expect((oldKeys as SetSettings).settings, const GameSettings(), reason: 'old discussion times are ignored');
    });

    test('the roles come out in the canvas order whatever the set order', () {
      final j = const GameSettings(wolfRoles: {WolfRole.tramp, WolfRole.wolf, WolfRole.seer}).toJson();
      expect(j['wolfRoles'], ['wolf', 'seer', 'tramp']);
    });

    test('wrong types and unknown roles are null', () {
      expect(Message.decode('{"type":"nightPick","target":"3","special":false}'), isNull);
      expect(Message.decode('{"type":"nightPick","target":3}'), isNull);
      expect(Message.decode('{"type":"vote","target":"x"}'), isNull);
      expect(Message.decode('{"type":"role","role":"dragon","mates":[],"possible":[],"hide":true}'), isNull);
      expect(Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2,"wolfRoles":["dragon"]}'), isNull);
      expect(Message.decode('{"type":"start","game":"chess","packId":null}'), isNull);
    });
  });

  group('uljez', () {
    test('every new message round trips', () {
      final ms = <Message>[
        const StartGame(GameKind.uljez, null),
        const SelectGame(GameKind.uljez),
        const Guess(2),
        const UljezWord('Pikachu'),
        const UljezDone(),
        const ReadyToVote(true),
        const VoteWish(open: true, ready: false, want: 2, needed: 3),
        const UljezTurn(round: 1, speaker: 3, seconds: 20, stage: 'clues'),
        const UljezTurn(round: 2, speaker: null, seconds: 90, stage: 'discussion'),
        const UljezGuess(seconds: 15, options: ['a', 'b', 'c', 'd']),
        const UljezEnd(UljezWinner.village, 'Spužva Bob', 'Pikachu', [2, 5]),
        const SetSettings(GameSettings(uljezOffPacks: {'uljez-hrana'}, uljezImpostors: 2)),
        const LobbyState(players: [], packs: [], hostId: 1, uljezPacks: [PackInfo('uljez-hrana', 'Hrana', 40)]),
      ];
      for (final m in ms) {
        expect(Message.decode(m.encode()), m, reason: m.encode());
      }
    });

    test('uljez settings: defaults, an old message, clamping', () {
      const d = GameSettings();
      expect([d.uljezOffPacks, d.uljezImpostors], [isEmpty, 1]);
      final old = Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2}');
      expect((old as SetSettings).settings, const GameSettings());
      final c = const GameSettings(uljezImpostors: 5).clamped();
      expect(c.uljezImpostors, 2);
      expect(const GameSettings(uljezImpostors: 0).clamped().uljezImpostors, 1);
    });

    test('an old lobby has no uljez packs', () {
      final m = Message.decode('{"type":"lobby","players":[],"packs":[],"hostId":1}');
      expect((m as LobbyState).uljezPacks, isEmpty);
    });

    test('wrong types are null', () {
      expect(Message.decode('{"type":"guess","index":"1"}'), isNull);
      expect(Message.decode('{"type":"uljezWord"}'), isNull);
      expect(Message.decode('{"type":"uljezEnd","winner":"nobody","village":"a","impostor":"b","impostors":[]}'), isNull);
    });
  });

  group('pack tags', () {
    test('PackInfo carries pictures and isNew, and round trips', () {
      const p = PackInfo('a', 'A', 12, pictures: true, isNew: true);
      expect(PackInfo.fromJson(p.toJson()), p);
      expect(p.toJson()['pictures'], true);
      expect(p.toJson()['isNew'], true);
      const lobby = LobbyState(players: [], packs: [PackInfo('a', 'A', 12, pictures: true), PackInfo('b', 'B', 3, isNew: true)], hostId: 1);
      expect(Message.decode(lobby.encode()), lobby);
    });

    test('old packs without the tags decode as false', () {
      final p = PackInfo.fromJson({'id': 'a', 'title': 'A', 'questionCount': 5});
      expect([p.pictures, p.isNew], [false, false]);
      expect(p, const PackInfo('a', 'A', 5));
    });

    test('a wrong type for a tag is an error, not a silent false', () {
      expect(() => PackInfo.fromJson({'id': 'a', 'title': 'A', 'questionCount': 5, 'pictures': 'yes'}), throwsA(anything));
    });
  });

  group('party games: objasni', () {
    test('new messages round trip', () {
      final ms = <Message>[
        const StartGame(GameKind.objasni, null),
        const StartGame(GameKind.koliko, null),
        const StartGame(GameKind.blef, null),
        const StartGame(GameKind.tkobi, null),
        const SelectGame(GameKind.tkobi),
        const Reshuffle(),
        const Go(),
        const ObjasniAction(ObjasniAct.correct),
        const ObjasniAction(ObjasniAct.skip, wordNo: 7),
        const ObjasniAction(ObjasniAct.foul, wordNo: 12),
        const ObjasniTeams(team: 1, teams: [[1, 2], [3, 4, 5]]),
        const ObjasniTurn(stage: ObjasniStage.play, role: ObjasniRole.explain, team: 0, explainer: 2, word: 'kuća', wordNo: 5, seconds: 60, scores: [3, -1]),
        const ObjasniTurn(stage: ObjasniStage.play, role: ObjasniRole.guess, team: 0, explainer: 2, word: null, seconds: 40, scores: [0, 0]),
        const ObjasniTurn(stage: ObjasniStage.summary, role: ObjasniRole.watch, team: 1, explainer: 4, word: null, seconds: 5, scores: [10, 12]),
      ];
      for (final m in ms) {
        expect(Message.decode(m.encode()), m, reason: m.encode());
      }
    });

    test('settings: defaults, an old message, and clamping to the allowed values', () {
      const d = GameSettings();
      expect([d.objasniSeconds, d.objasniTarget, d.objasniOffPacks], [60, 30, isEmpty]);
      expect([d.kolikoSeconds, d.kolikoQuestions, d.kolikoOffPacks], [30, 10, isEmpty]);
      expect([d.blefQuestions, d.blefOffPacks], [7, isEmpty]);
      expect([d.tkobiPrompts, d.tkobiOffPacks], [10, isEmpty]);
      final old = Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2}');
      expect((old as SetSettings).settings, const GameSettings());
      final c = const GameSettings(objasniSeconds: 70, objasniTarget: 100, kolikoSeconds: 5, kolikoQuestions: 12, blefQuestions: 8, tkobiPrompts: 1).clamped();
      expect([c.objasniSeconds, c.objasniTarget], [60, 50]);
      expect([c.kolikoSeconds, c.kolikoQuestions], [20, 10]);
      expect(c.blefQuestions, 7);
      expect(c.tkobiPrompts, 5);
      expect(const GameSettings(objasniSeconds: 80).clamped().objasniSeconds, 90);
      const s = GameSettings(objasniSeconds: 90, objasniTarget: 20, objasniOffPacks: {'a'}, kolikoSeconds: 45, kolikoQuestions: 15, kolikoOffPacks: {'b'}, blefQuestions: 10, blefOffPacks: {'c'}, tkobiPrompts: 15, tkobiOffPacks: {'d'});
      expect(Message.decode(SetSettings(s).encode()), const SetSettings(s));
      expect(s.clamped(), s);
    });

    test('an old lobby has no party packs; the lists round trip', () {
      final m = Message.decode('{"type":"lobby","players":[],"packs":[],"hostId":1}') as LobbyState;
      expect([m.objasniPacks, m.kolikoPacks, m.blefPacks, m.tkobiPacks], [isEmpty, isEmpty, isEmpty, isEmpty]);
      const l = LobbyState(
          players: [],
          packs: [],
          hostId: 1,
          objasniPacks: [PackInfo('o', 'O', 120)],
          kolikoPacks: [PackInfo('k', 'K', 30)],
          blefPacks: [PackInfo('b', 'B', 33)],
          tkobiPacks: [PackInfo('t', 'T', 45)]);
      expect(Message.decode(l.encode()), l);
    });

    test('wrong types and unknown names are null', () {
      expect(Message.decode('{"type":"objasniAction","act":"fly"}'), isNull);
      expect(Message.decode('{"type":"objasniTurn","stage":"x","role":"explain","team":0,"explainer":1,"word":null,"seconds":1,"scores":[0,0]}'), isNull);
      expect(Message.decode('{"type":"objasniTeams","team":"a","teams":[]}'), isNull);
    });
  });

  group('party games: koliko', () {
    test('messages round trip', () {
      final ms = <Message>[
        const NumberAnswer(1234567.5),
        const NumberAnswer(0),
        const KolikoAsk(number: 2, total: 10, seconds: 30, q: 'Koliko je visok Eiffelov toranj?', unit: 'm'),
        const KolikoAsk(number: 3, total: 10, seconds: 12, q: 'x', unit: '', sent: 330),
        const KolikoResult(answer: 330, value: 300, rank: 2, points: 750, total: 1750, unit: 'm'),
        const KolikoResult(answer: 330, value: null, rank: null, points: 0, total: 0),
      ];
      for (final m in ms) {
        expect(Message.decode(m.encode()), m, reason: m.encode());
      }
    });

    test('an integer and a decimal both decode as a number; a string does not', () {
      expect(Message.decode('{"type":"number","value":5}'), const NumberAnswer(5));
      expect(Message.decode('{"type":"number","value":5.25}'), const NumberAnswer(5.25));
      expect(Message.decode('{"type":"number","value":"5"}'), isNull);
      expect(Message.decode('{"type":"number"}'), isNull);
    });
  });

  test('a curve status without a round (an older TV) decodes with round null', () {
    final m = Message.decode('{"type":"curve","alive":true,"score":3,"target":10}') as CurveStatus;
    expect(m.round, isNull);
    expect((Message.decode(const CurveStatus(alive: true, score: 1, target: 10, round: 2).encode()) as CurveStatus).round, 2);
    expect(Message.decode('{"type":"curve","alive":true,"score":3,"target":10,"round":"2"}'), isNull);
  });

  group('party games: blef', () {
    test('messages round trip', () {
      final ms = <Message>[
        const BlefFake('Tri sata'),
        const BlefPick(2),
        const BlefWrite(number: 1, total: 7, seconds: 60, q: 'Koliko dugo?', sent: null),
        const BlefWrite(number: 2, total: 7, seconds: 40, q: 'x', sent: 'Moja laž'),
        const BlefList(seconds: 20, options: ['a', 'b', 'c'], ids: [0, 2, 3], picked: 2),
        const BlefList(seconds: 20, options: ['a'], ids: [1]),
        const BlefResult(points: 1500, total: 2500, foundTruth: true, fooled: 1),
        const BlefResult(points: 0, total: 0, foundTruth: false, fooled: 0),
      ];
      for (final m in ms) {
        expect(Message.decode(m.encode()), m, reason: m.encode());
      }
    });

    test('wrong types are null', () {
      expect(Message.decode('{"type":"blefFake","text":5}'), isNull);
      expect(Message.decode('{"type":"blefPick","index":"2"}'), isNull);
      expect(Message.decode('{"type":"blefList","seconds":1,"options":["a"],"ids":["x"],"picked":null}'), isNull);
    });
  });

  group('party games: tko bi', () {
    test('messages round trip', () {
      final ms = <Message>[
        const TkobiAsk(number: 1, total: 10, seconds: 15, text: 'Tko bi zaspao?', ids: [1, 2, 3]),
        const TkobiAsk(number: 2, total: 10, seconds: 9, text: 'x', ids: [1, 2], picked: 2),
        const TkobiResult(counts: {1: 0, 2: 3, 3: 1}, crowned: [2], votedRight: true, points: 1, total: 4),
        const TkobiResult(counts: {1: 0}, crowned: [], votedRight: false, points: 0, total: 0),
      ];
      for (final m in ms) {
        expect(Message.decode(m.encode()), m, reason: m.encode());
      }
    });

    test('wrong types are null', () {
      expect(Message.decode('{"type":"tkobiAsk","number":1,"total":1,"seconds":1,"text":5,"ids":[],"picked":null}'), isNull);
      expect(Message.decode('{"type":"tkobiResult","counts":{"a":1},"crowned":[],"votedRight":false,"points":0,"total":0}'), isNull);
    });
  });

  test('Objasni word numbers: absent means 0 / null (older phones and TVs)', () {
    final a = Message.decode('{"type":"objasniAction","act":"foul"}') as ObjasniAction;
    expect(a.wordNo, isNull);
    final t = Message.decode('{"type":"objasniTurn","stage":"play","role":"watch","team":0,"explainer":1,"word":"x","seconds":5,"scores":[0,0]}') as ObjasniTurn;
    expect(t.wordNo, 0);
    expect(Message.decode('{"type":"objasniAction","act":"foul","wordNo":"3"}'), isNull);
  });

  test('a KolikoResult without a unit (an older TV) decodes with an empty unit', () {
    final m = Message.decode('{"type":"kolikoResult","answer":3,"value":null,"rank":null,"points":0,"total":0}') as KolikoResult;
    expect(m.unit, '');
  });

  test('a NightPrompt without done (an older TV) decodes as not done', () {
    final m = Message.decode('{"type":"night","night":1,"text":"x","choices":[],"ids":[],"choices2":[],"ids2":[],"picks":1,"picked":null,"picked2":null,"special":false}') as NightPrompt;
    expect(m.done, isFalse);
  });

  group('party games: kao svi', () {
    test('messages round trip', () {
      final ms = <Message>[
        const StartGame(GameKind.kaosvi, null),
        const SelectGame(GameKind.kaosvi),
        const KaosviAnswer('Jabuka'),
        const KaosviMerge(1, 3),
        const KaosviDone(),
        const KaosviAsk(number: 1, total: 12, seconds: 30, q: 'Navedi voće.', sent: null),
        const KaosviAsk(number: 2, total: 12, seconds: 11, q: 'x', sent: 'Kruška'),
        const KaosviMerging(seconds: 15, groups: [KaosviMergeItem(0, 'jabuka'), KaosviMergeItem(2, 'jabuke')], host: true),
        const KaosviMerging(seconds: 15, groups: [], host: false),
        const KaosviResult(answer: 'jabuka', size: 3, points: 1, total: 4, largest: true, lone: false),
        const KaosviResult(answer: null, size: 0, points: 0, total: 0, largest: false, lone: false),
        const SetSettings(GameSettings(kaosviQuestions: 16, kaosviTarget: 10, kaosviOffPacks: {'k'})),
        const LobbyState(players: [], packs: [], hostId: 1, kaosviPacks: [PackInfo('k', 'K', 60)]),
      ];
      for (final m in ms) {
        expect(Message.decode(m.encode()), m, reason: m.encode());
      }
    });

    test('settings: defaults, an old message, clamping to the allowed values', () {
      const d = GameSettings();
      expect([d.kaosviQuestions, d.kaosviTarget, d.kaosviOffPacks], [12, 8, isEmpty]);
      final old = Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2}');
      expect((old as SetSettings).settings, const GameSettings());
      final c = const GameSettings(kaosviQuestions: 13, kaosviTarget: 1).clamped();
      expect([c.kaosviQuestions, c.kaosviTarget], [12, 5]);
      expect(const GameSettings(kaosviQuestions: 99, kaosviTarget: 99).clamped().kaosviQuestions, 16);
    });

    test('an old lobby has no kao svi packs; wrong types are null', () {
      expect((Message.decode('{"type":"lobby","players":[],"packs":[],"hostId":1}') as LobbyState).kaosviPacks, isEmpty);
      expect(Message.decode('{"type":"kaosviAnswer","text":5}'), isNull);
      expect(Message.decode('{"type":"kaosviMerge","a":"1","b":2}'), isNull);
    });
  });
}
