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
  objasniPacks: const [PackInfo('o', 'Općenito', 120)],
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
    const roleMsg = RoleMsg(WolfRole.seer, [], [
      WolfRole.wolf,
      WolfRole.villager,
      WolfRole.seer,
    ], hide: true);
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
      'V2PhoneWolfSettings': w(
        0,
        _lobby(selected: GameKind.vukodlak, n: 7),
        [],
      ),
      'ObjasniSetupHost': w(0, _lobby(), [
        const ObjasniTeams(
          team: 0,
          teams: [
            [0, 1],
            [2, 3],
          ],
        ),
      ]),
      'ObjasniExplain': w(1, _lobby(), [
        const ObjasniTeams(
          team: 0,
          teams: [
            [0, 1],
            [2, 3],
          ],
        ),
        const ObjasniTurn(
          stage: ObjasniStage.play,
          role: ObjasniRole.explain,
          team: 0,
          explainer: 1,
          word: 'Kišobran',
          seconds: 47,
          scores: [12, 9],
        ),
      ]),
      'ObjasniWatch': w(2, _lobby(), [
        const ObjasniTeams(
          team: 1,
          teams: [
            [0, 1],
            [2, 3],
          ],
        ),
        const ObjasniTurn(
          stage: ObjasniStage.play,
          role: ObjasniRole.watch,
          team: 0,
          explainer: 1,
          word: 'Kišobran',
          seconds: 47,
          scores: [12, 9],
        ),
      ]),
      'ObjasniGuess': w(0, _lobby(), [
        const ObjasniTeams(
          team: 0,
          teams: [
            [0, 1],
            [2, 3],
          ],
        ),
        const ObjasniTurn(
          stage: ObjasniStage.play,
          role: ObjasniRole.guess,
          team: 0,
          explainer: 1,
          word: null,
          seconds: 47,
          scores: [12, 9],
        ),
      ]),
      'ObjasniReady': w(1, _lobby(), [
        const ObjasniTeams(
          team: 0,
          teams: [
            [0, 1],
            [2, 3],
          ],
        ),
        const ObjasniTurn(
          stage: ObjasniStage.ready,
          role: ObjasniRole.explain,
          team: 0,
          explainer: 1,
          word: null,
          seconds: 60,
          scores: [12, 9],
        ),
      ]),
      'KolikoAsk': w(1, _lobby(), [
        const KolikoAsk(
          number: 2,
          total: 10,
          seconds: 24,
          q: 'Koliko je visok Eiffelov toranj?',
          unit: 'm',
        ),
      ]),
      'KolikoSent': w(1, _lobby(), [
        const KolikoAsk(
          number: 2,
          total: 10,
          seconds: 12,
          q: 'Koliko je visok Eiffelov toranj?',
          unit: 'm',
          sent: 1234567,
        ),
      ]),
      'KolikoResult': w(1, _lobby(), [
        const KolikoAsk(
          number: 2,
          total: 10,
          seconds: 12,
          q: 'Koliko je visok Eiffelov toranj?',
          unit: 'm',
        ),
        const KolikoResult(
          answer: 330,
          value: 320,
          rank: 1,
          points: 1000,
          total: 1750,
        ),
      ]),
      'BlefWrite': w(1, _lobby(), [
        const BlefWrite(
          number: 3,
          total: 7,
          seconds: 48,
          q: 'Koliko je trajao najkraći rat u povijesti?',
          sent: null,
        ),
      ]),
      'BlefSent': w(1, _lobby(), [
        const BlefWrite(
          number: 3,
          total: 7,
          seconds: 31,
          q: 'Koliko je trajao najkraći rat u povijesti?',
          sent: '38 minuta',
        ),
      ]),
      'BlefList': w(1, _lobby(), [
        const BlefWrite(
          number: 3,
          total: 7,
          seconds: 31,
          q: 'Koliko je trajao najkraći rat u povijesti?',
          sent: '38 minuta',
        ),
        const BlefList(
          seconds: 17,
          options: ['2 sata', '45 minuta', '3 dana', '1 tjedan'],
          ids: [5, 8, 2, 9],
        ),
      ]),
      'BlefResult': w(1, _lobby(), [
        const BlefWrite(
          number: 3,
          total: 7,
          seconds: 31,
          q: 'Q',
          sent: '38 minuta',
        ),
        const BlefResult(
          points: 1500,
          total: 2500,
          foundTruth: true,
          fooled: 1,
        ),
      ]),
      'TkobiAsk': w(1, _lobby(n: 5), [
        const TkobiAsk(
          number: 4,
          total: 10,
          seconds: 12,
          text: 'Tko bi najvjerojatnije zaspao na vlastitom rođendanu?',
          ids: [0, 1, 2, 3, 4],
        ),
      ]),
      'TkobiResult': w(1, _lobby(n: 5), [
        const TkobiAsk(
          number: 4,
          total: 10,
          seconds: 12,
          text: 'Q',
          ids: [0, 1, 2, 3, 4],
        ),
        const TkobiResult(
          counts: {0: 1, 1: 3, 2: 0, 3: 1, 4: 0},
          crowned: [1],
          votedRight: true,
          points: 1,
          total: 4,
        ),
      ]),
      'KaosviAsk': w(1, _lobby(), [
        const KaosviAsk(
          number: 3,
          total: 12,
          seconds: 22,
          q: 'Navedi voće.',
          sent: null,
        ),
      ]),
      'KaosviSent': w(1, _lobby(), [
        const KaosviAsk(
          number: 3,
          total: 12,
          seconds: 14,
          q: 'Navedi voće.',
          sent: 'jabuka',
        ),
      ]),
      'KaosviMergeHost': w(0, _lobby(), [
        const KaosviAsk(
          number: 3,
          total: 12,
          seconds: 14,
          q: 'Navedi voće.',
          sent: 'jabuka',
        ),
        const KaosviMerging(
          seconds: 11,
          host: true,
          groups: [
            KaosviMergeItem(1, 'jabuka'),
            KaosviMergeItem(2, 'jabuke'),
            KaosviMergeItem(3, 'kruška'),
            KaosviMergeItem(4, 'banana'),
            KaosviMergeItem(5, 'ananas'),
          ],
        ),
      ]),
      'KaosviWait': w(1, _lobby(), [
        const KaosviAsk(
          number: 3,
          total: 12,
          seconds: 14,
          q: 'Navedi voće.',
          sent: 'jabuka',
        ),
        const KaosviMerging(seconds: 11, host: false, groups: []),
      ]),
      'KaosviResult': w(1, _lobby(), [
        const KaosviAsk(
          number: 3,
          total: 12,
          seconds: 14,
          q: 'Navedi voće.',
          sent: 'jabuka',
        ),
        const KaosviResult(
          answer: 'jabuka',
          size: 3,
          points: 1,
          total: 4,
          largest: true,
          lone: false,
        ),
      ]),
      'KaosviLone': w(1, _lobby(), [
        const KaosviAsk(
          number: 3,
          total: 12,
          seconds: 14,
          q: 'Navedi voće.',
          sent: 'ananas',
        ),
        const KaosviResult(
          answer: 'ananas',
          size: 1,
          points: -1,
          total: 2,
          largest: false,
          lone: true,
        ),
      ]),
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
        for (final e in scenes.entries)
          e.key: [for (final m in e.value) m.encode()],
      }),
    );
  });
}
