// Writes the TV's messages for each phone scene as JSON, for the screenshot
// server (tool/shot_server.py):
//   SCENES_OUT=/some/scenes.json fvm flutter test test/shots/scenes_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

final _out = Platform.environment['SCENES_OUT'];

LobbyState _lobby({
  GameKind? selected,
  int n = 4,
  GameSettings s = const GameSettings(),
}) => LobbyState(
  hostId: 0,
  selected: selected,
  settings: s,
  packs: const [
    PackInfo('a', 'Opće znanje', 401),
    PackInfo('b', 'Međimurje', 94, pictures: true),
  ],
  uljezPacks: const [PackInfo('u', 'Crtići', 40)],
  players: [
    for (var i = 0; i < n; i++)
      PlayerInfo(
        i,
        ['Luka', 'Ana', 'Marko', 'Ivana', 'Josip', 'Petra', 'Tin', 'Maja'][i],
        i,
        true,
        0,
        bot: i == 3 && n == 4,
        character: characterIds[i],
      ),
  ],
);

void main() {
  if (_out == null) {
    test('scenes skipped without SCENES_OUT', () {}, skip: 'set SCENES_OUT');
    return;
  }
  test('write scenes', () {
    List<Message> w(int me, LobbyState l, List<Message> more) => [
      Welcome(me, me, 'tok', character: characterIds[me]),
      l,
      ...more,
    ];
    const roleMsg = RoleMsg(
      WolfRole.seer,
      [],
      [WolfRole.wolf, WolfRole.villager, WolfRole.seer],
      hide: true,
    );
    final scenes = <String, List<Message>>{
      'PhoneJoin': [],
      'PhoneCarousel': w(0, _lobby(), []),
      'PhoneWatching': w(
        1,
        _lobby(
          selected: GameKind.curve,
          s: const GameSettings(curveMode: CurveMode.chaos),
        ),
        [],
      ),
      'PhoneQuizDetails': w(0, _lobby(selected: GameKind.quiz), []),
      'PhoneCurveDetails': w(0, _lobby(selected: GameKind.curve), []),
      'PhoneCurve': w(1, _lobby(), [
        const CurveStatus(alive: true, score: 12, target: 30),
      ]),
      'V2PhoneRole': w(1, _lobby(), [roleMsg]),
      'V2PhoneNight': w(1, _lobby(), [
        roleMsg,
        NightPrompt(
          night: 2,
          text: 'Koga posjećujete? Luka je odabrao Ivanu.'.padRight(120),
          choices: const ['Luka', 'Marko', 'Ivana', 'Josip', 'Petra'],
          ids: const [0, 2, 3, 4, 5],
        ),
      ]),
      'V2PhoneVote': w(1, _lobby(n: 5), [
        roleMsg,
        const VotePrompt(day: 3, seconds: 12, ids: [0, 1, 2, 3, 4]),
      ]),
      'V2PhoneWolfSettings': w(0, _lobby(selected: GameKind.vukodlak, n: 7), []),
      'UljezPhone_word': w(1, _lobby(), [
        const UljezWord('Pikachu'),
        const UljezTurn(round: 2, speaker: 0, seconds: 20, stage: 'clues'),
      ]),
      'UljezPhone_vote': w(1, _lobby(n: 5), [
        const UljezWord('Pikachu'),
        const VotePrompt(day: 1, seconds: 20, ids: [0, 1, 2, 3, 4]),
      ]),
      'UljezPhone_guess': w(1, _lobby(), [
        const UljezWord('Pikachu'),
        const UljezGuess(
          seconds: 15,
          options: ['Spužva Bob', 'Patrik', 'Garfield', 'Scooby-Doo'],
        ),
      ]),
    };
    File(_out!).writeAsStringSync(
      jsonEncode({
        for (final e in scenes.entries) e.key: [for (final m in e.value) m.encode()],
      }),
    );
  });
}
