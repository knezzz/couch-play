// Writes PNGs of the phone screens at 390 x 844 with the real Roboto, next to
// the boards in docs/design/couchplay-screens. Not part of the normal run:
//   SHOTS_DIR=/some/dir fvm flutter test test/shots/shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:controller/screens/curve_screen.dart';
import 'package:controller/screens/join_screen.dart';
import 'package:controller/screens/lobby_screen.dart';
import 'package:controller/screens/pack_grid.dart';
import 'package:controller/screens/sumo_screen.dart';
import 'package:controller/screens/uljez_screens.dart';
import 'package:controller/screens/wolf_screens.dart';
import 'package:controller/theme.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_connection.dart';

final _dir = Platform.environment['SHOTS_DIR'];

Future<void> _fonts() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      '/Users/llama/fvm/versions/3.47.7';
  Future<ByteData> read(String f) async => ByteData.view(
    File('$root/bin/cache/artifacts/material_fonts/$f')
        .readAsBytesSync()
        .buffer,
  );
  final roboto = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
    roboto.addFont(read('Roboto-$f.ttf'));
  }
  await roboto.load();
  // Button labels set no font family, and flutter_test's default is Ahem:
  // give that name the real glyphs too, for these screenshots only.
  for (final name in ['FlutterTest', 'sans-serif', 'Arial', 'Helvetica', 'system-ui', '.SF Pro Text', 'Noto Sans']) {
    final l = FontLoader(name);
    for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
      l.addFont(read('Roboto-$f.ttf'));
    }
    await l.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> _shot(
  WidgetTester t,
  String name,
  Widget w, {
  double h = 844,
  double width = 390,
}) async {
  t.view.physicalSize = Size(width * 2, h * 2);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  final key = GlobalKey();
  await t.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
        ),
        home: w,
      ),
    ),
  );
  await t.pumpAndSettle();
  await t.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

LobbyState _lobby({
  GameKind? selected,
  int host = 0,
  GameSettings s = const GameSettings(),
  int n = 4,
}) => LobbyState(
  hostId: host,
  selected: selected,
  settings: s,
  packs: const [
    PackInfo('a', 'Opće znanje', 401),
    PackInfo('b', 'Međimurje', 94, pictures: true),
    PackInfo('c', 'Geografija', 100, pictures: true),
    PackInfo('d', 'Zemljopis svijeta', 102, pictures: true),
    PackInfo('e', 'Povijest', 111, pictures: true),
    PackInfo('f', 'Kultura i sport', 114),
    PackInfo('g', 'Psihologija', 112, isNew: true),
    PackInfo('h', 'Umjetnost', 130, pictures: true, isNew: true),
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
  setUpAll(_fonts);
  if (_dir == null) {
    test('screenshots skipped without SHOTS_DIR', () {}, skip: 'set SHOTS_DIR');
    return;
  }
  Directory(_dir!).createSync(recursive: true);

  testWidgets('shots', (t) async {
    await _shot(
      t,
      'PhoneJoin',
      JoinScreen(FakeConnection(), onJoined: () {}, initialCharacter: 'fox'),
    );
    await _shot(t, 'PhoneCarousel', LobbyScreen(FakeConnection(), _lobby(), 0));
    await _shot(
      t,
      'PhoneWatching',
      LobbyScreen(
        FakeConnection(),
        _lobby(
          selected: GameKind.curve,
          s: const GameSettings(curveMode: CurveMode.chaos),
        ),
        1,
      ),
    );
    await _shot(
      t,
      'PhoneQuizDetails',
      LobbyScreen(FakeConnection(), _lobby(selected: GameKind.quiz), 0),
    );
    await _shot(
      t,
      'PhoneCurveDetails',
      LobbyScreen(FakeConnection(), _lobby(selected: GameKind.curve), 0),
    );
    await _shot(
      t,
      'PhonePacks',
      PackGridScreen(
        packs: _lobby().packs,
        ticked: const {'a', 'c'},
        onToggle: (_) {},
        onBack: () {},
        addPack: () async => null,
      ),
    );
    await _shot(
      t,
      'PhoneCurve',
      CurveScreen(
        FakeConnection(),
        name: 'Ana',
        character: 'owl',
        colorIndex: 2,
        score: 12,
      ),
    );
    await _shot(
      t,
      'V2PhoneRole',
      const RoleHoldScreen(
        name: 'Petra',
        night: 1,
        role: 'Vidovnjakinja',
        description: 'Svake noći saznaš ulogu jednog igrača.',
      ),
    );
    await _shot(
      t,
      'V2PhoneNight',
      NightScreen(
        night: 2,
        hint: 'Koga posjećujete? Luka je odabrao Ivanu.',
        targets: const [
          NightItem(1, 'Ana'),
          NightItem(2, 'Ivana'),
          NightItem(3, 'Josip'),
          NightItem(4, 'Luka'),
          NightItem(5, 'Maja'),
        ],
        onConfirm: (_, _) {},
      ),
    );
    await _shot(
      t,
      'V2PhoneVote',
      VoteScreen(
        day: 3,
        selfId: 1,
        targets: const [
          WolfTarget(0, 'Luka', 'fox', 0),
          WolfTarget(1, 'Ana', 'owl', 1),
          WolfTarget(2, 'Petra', 'cat', 2),
          WolfTarget(3, 'Josip', 'bear', 3),
          WolfTarget(4, 'Maja', 'mouse', 4),
        ],
        onVote: (_) {},
        onSkip: () {},
      ),
    );
    await _shot(
      t,
      'V2PhoneWolfSettings',
      LobbyScreen(
        FakeConnection(),
        _lobby(selected: GameKind.vukodlak, n: 7),
        0,
      ),
    );
    await _shot(
      t,
      'V2PhoneWolfRolesPick',
      WolfRolesPickScreen(
        players: 7,
        enabled: const {'seer', 'doc', 'hunter', 'herb', 'mayor'},
        onToggle: (_) {},
        onBack: () {},
      ),
      h: 1500,
    );
    await _shot(
      t,
      'V2PhoneRolesInfo',
      WolfRolesInfoScreen(
        players: 7,
        enabled: const {'seer', 'doc', 'hunter', 'herb'},
        onBack: () {},
      ),
      h: 1300,
    );
    await _shot(
      t,
      'UljezPhone_word',
      const UljezWordScreen(
        name: 'Petra',
        round: 2,
        word: 'Pikachu',
        stage: 'clues',
      ),
    );
    await _shot(
      t,
      'UljezPhone_vote',
      UljezVoteScreen(
        targets: const [
          NightItem(1, 'Luka'),
          NightItem(2, 'Ana', enabled: false, note: 'ti'),
          NightItem(3, 'Marko'),
        ],
        onVote: (_) {},
      ),
    );
    await _shot(
      t,
      'UljezPhone_guess',
      UljezGuessScreen(
        word: 'Pikachu',
        options: const [
          NightItem(0, 'Spužva Bob'),
          NightItem(1, 'Patrik'),
          NightItem(2, 'Garfield'),
          NightItem(3, 'Scooby-Doo'),
        ],
        onGuess: (_) {},
      ),
    );
  });

  // Task 55: the Sumo controls, next to the boards SumoPhone (390x844) and SumoPhoneSmall (360x640).
  testWidgets('sumo shots', (t) async {
    Widget sumo() => SumoScreen(FakeConnection(), name: 'Ana', character: 'owl', colorIndex: 1, score: 12, round: 3);
    await _shot(t, 'SumoPhone', sumo());
    await _shot(t, 'SumoPhoneSmall', sumo(), h: 640, width: 360);
    // Mid-drag with the Dash recharging, the picture the board draws.
    await _shot(t, 'SumoPhone_out', SumoScreen(FakeConnection(), alive: false, name: 'Ana', character: 'owl', colorIndex: 1, score: 12, round: 3));
  });
}
