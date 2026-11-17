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
      const SetSettings(GameSettings(quizPackId: 'hr-povijest')),
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
        settings: GameSettings(quizPackId: 'flags'),
      ),
      const QuizQuestion(1, 10, ['a', 'b', 'c', 'd'], 20),
      const QuizReveal(2, 750, 1500),
      const CurveStatus(alive: true, score: 3, target: 10),
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
      expect(const GameSettings().quizPackId, isNull);
      expect(const GameSettings(quizPackId: 'x', quizSeconds: 999).clamped().quizPackId, 'x');
      final m = Message.decode(const SetSettings(GameSettings(quizPackId: 'x')).encode());
      expect((m as SetSettings).settings.quizPackId, 'x');
      expect(Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2}'),
          const SetSettings(GameSettings()));
      expect(Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2,"quizPackId":5}'), isNull);
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
        const NightPrompt(night: 2, text: 'x', choices: ['Ana', 'Ivo'], ids: [1, 2], picks: 2, picked: 2, picked2: 3, special: true),
        const NightPrompt(night: 1, text: '', choices: ['12', '40'], ids: [0, 1]),
        const Morning(2, 'Vidjela si'),
        const VotePrompt(day: 1, seconds: 120, ids: [1, 2, 3], canVote: false, picked: 3),
        const Farewell(seconds: 15, ids: [1, 2]),
        const WolfEnd(WolfWinner.lone, {1: WolfRole.lone, 2: WolfRole.seer}),
        const SetSettings(GameSettings(wolfRoles: {WolfRole.wolf, WolfRole.villager, WolfRole.cupid}, wolfHideRoles: false, wolfDiscussion: 60)),
      ];
      for (final m in ms) {
        expect(Message.decode(m.encode()), m, reason: m.encode());
      }
    });

    test('wolf settings: defaults, an old settings message, and clamping', () {
      const d = GameSettings();
      expect(d.wolfRoles, GameSettings.defaultWolfRoles);
      expect(d.wolfHideRoles, isTrue);
      expect(d.wolfDiscussion, 120);
      final old = Message.decode('{"type":"settings","quizSeconds":20,"quizQuestions":10,"revealSeconds":4,"curveCountdown":2}');
      expect((old as SetSettings).settings, const GameSettings());
      final c = const GameSettings(wolfRoles: {WolfRole.seer}, wolfDiscussion: 1000).clamped();
      expect(c.wolfRoles, {WolfRole.seer, WolfRole.wolf, WolfRole.villager}, reason: 'wolf and villager are always on');
      expect(c.wolfDiscussion, 300);
      expect(const GameSettings(wolfDiscussion: 10).clamped().wolfDiscussion, 30);
      expect(const GameSettings(wolfDiscussion: 100).clamped().wolfDiscussion, 90);
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
}
