import 'package:core/core.dart';

/// Every word the TV app shows or sends to phones, in Croatian. One file, no
/// i18n framework: the interface is Croatian only. Ti-form, plain words.
/// Review table: docs/strings-hr.md.
abstract final class Strings {
  // --- Lobby ---

  /// Instead of the QR code when the TV has no network.
  static const noWifi = 'Spoji TV na Wi-Fi da možemo igrati.';
  static const scanToJoin = 'Skeniraj kod mobitelom i pridruži se.';
  static const scanCaption = 'Skeniraj ili otvori u pregledniku:';
  static String players(int n) => 'Igrači · $n od 8';
  static const badgeBot = 'ROBOT';
  static const badgeAway = 'NEMA VEZE';
  static const scoreboard = 'Bodovi';
  static const scoreboardEmpty = 'Bodovi se pojavljuju nakon prve igre.';
  static String waitingForHost(String name) => 'Čekamo da $name odabere igru.';
  static String waitingForReturn(String name) => 'Čekamo da se $name vrati';
  static const waitingForPlayers = 'Čekamo da se igrači vrate';
  static const howToJoin ='Kako se pridružiti';
  static const quit = 'Izađi';
  static const howToJoinSteps = '1. Spoji mobitel na isti Wi-Fi kao i TV.\n'
      '2. Skeniraj kod ili upiši adresu u preglednik na mobitelu.\n'
      '3. Upiši ime i dodirni Pridruži se.';
  static const gotIt = 'U redu';

  /// The host's settings, one muted line at the bottom of the lobby. Same mode
  /// names as the phone (apps/controller/lib/strings.dart).
  static String curveModeName(CurveMode m) => switch (m) {
        CurveMode.chaos => 'Kaos',
        CurveMode.balanced => 'Uravnoteženo',
        CurveMode.peaceful => 'Mirno',
        CurveMode.onlyYou => 'Samo za tebe',
      };
  /// The host's game card on the lobby, same words as the phone's game details.
  static String gameName(GameKind k) => switch (k) { GameKind.quiz => 'Kviz', GameKind.curve => 'Curve', GameKind.vukodlak => 'Vukodlak', GameKind.uljez => 'Uljez' };
  static String gameBlurb(GameKind k) => switch (k) {
        GameKind.quiz => 'Pitanja s četiri odgovora. Odgovaraš na svom mobitelu.',
        GameKind.curve => 'Vozi svoju krivulju i ne udari u druge.',
        GameKind.vukodlak => 'Netko u selu nije ono što se čini.',
        GameKind.uljez => 'Svi imaju istu riječ, osim uljeza. Nađi ga.',
      };
  /// Bottom of the lobby while the host has a game's card open (the phones say the same).
  static String watching(String host, GameKind k) => '$host gleda: ${gameName(k)}';
  static const settingPack = 'Paket pitanja';
  static const settingQuestions = 'Broj pitanja';
  static const settingAnswerTime = 'Vrijeme za odgovor';
  static const settingReveal = 'Pauza između pitanja';
  static const settingMode = 'Način igre';
  static const settingCountdown = 'Pauza prije runde';
  static String settingsLine(GameSettings s) =>
      'Kviz: ${s.quizQuestions} pitanja · odgovor ${s.quizSeconds} s · pauza ${s.revealSeconds} s'
      '     Curve: ${curveModeName(s.curveMode)} · pauza prije runde ${s.curveCountdown} s';

  // --- Console home ---

  static const homeJoin = 'Skeniraj i pridruži se';
  static const homeJoinOr = 'ili otvori u pregledniku:';
  static String playerCount(int n) => n == 1 ? '1 igrač' : '$n igrača';
  static const homeNoPlayers = 'Čekamo igrače';
  static const homeNeedPlayers = 'Prvo se netko mora pridružiti mobitelom.';
  static const homeKeyOk = 'OK';
  static const homeKeyBack = 'Natrag';
  static const homeHelpMove = 'igra';
  static const homeHelpPlay = 'igraj';
  static const homeHelpSettings = 'postavke';
  static const homeHelpBack = 'izlaz';

  /// The line under the description: who can play and what is set.
  static String homeMeta(GameKind k, GameSettings s, String? pack) => switch (k) {
        GameKind.curve => '2–8 igrača · ${curveModeName(s.curveMode)} · pauza ${s.curveCountdown} s',
        GameKind.quiz => '1–8 igrača · ${pack ?? '–'} · ${s.quizQuestions} pitanja · ${s.quizSeconds} s',
        GameKind.vukodlak => '5–8 igrača · bez robota',
        GameKind.uljez => '3–8 igrača · bez robota',
      };

  // --- Vukodlak (the village on the TV) ---

  static String wolfNight(int n) => 'NOĆ $n';
  static String wolfMorning(int n) => 'JUTRO $n';
  static String wolfDay(int n) => 'DAN $n';
  static String wolfVoteHeader(int n) => 'DAN $n · GLASANJE';
  static const wolfVoteQuestion = 'Koga selo izbacuje?';
  static String wolfVoted(int x, int y) => 'Glasalo $x od $y';
  static const wolfEndHeader = 'KRAJ IGRE';
  static const wolfTeamVillage = 'Selo';
  static const wolfTeamWolves = 'Vukodlaci';
  static const wolfTeamSolo = 'Sam';

  /// Bots are named "Robot 1", "Robot 2", ...
  static String botName(int n) => 'Robot $n';

  // --- Back during a game ---

  static const endGameTitle = 'Prekinuti igru i vratiti se na početni zaslon?';
  static const no = 'Ne';
  static const yes = 'Da';

  // --- Quiz ---

  static String questionOf(int n, int total) => 'Pitanje $n od $total';
  static String answered(int n, int expected) => 'Odgovorilo: $n od $expected';
  static const answerIs = ' · Točan odgovor je';
  static const quizScores = 'Bodovi';

  // --- Results ---

  /// A placement whose player is no longer in the room.
  static const unknownPlayer = 'Igrač';
  static const gameOver = 'Kraj igre';
  static String wins(List<String> names) => switch (names.length) {
        0 => gameOver,
        1 => '${names[0]} pobjeđuje!',
        _ => '${names.sublist(0, names.length - 1).join(', ')} i ${names.last} pobjeđuju!',
      };
  static String place(int n) => '$n.';
  static const tonight = 'Večeras';
  static const gameCurve = 'Curve';
  static String gameQuiz(String packTitle) => 'Kviz · $packTitle';
  static String backToLobby(int seconds) => 'Povratak na početni zaslon za $seconds s';

  // --- Sent to phones (shown there as received) ---

  static const reloadPage = 'Osvježi stranicu i pokušaj ponovo.';
  static const typeName = 'Upiši ime da se pridružiš.';
  static const gameFull = 'Igra je puna (8 igrača).';
  static const onlyHost = 'To može samo domaćin.';
  static const nextGameSoon = 'Sljedeća igra uskoro počinje.';
  static const gameRunning = 'Igra je već u tijeku.';
  static const packUnavailable = 'Taj paket nije dostupan.';
  static const vukodlakSoon = 'Vukodlak još nije spreman na ovom televizoru.';
  static const uljezSoon = 'Uljez još nije spreman na ovom televizoru.';
  static const curveNeedsTwo = 'Za Curve trebaju barem 2 igrača. Dodaj robota ili pozovi prijatelja.';
  static const noSuchPlayer = 'Tog igrača nema.';
  static const cannotKickSelf = 'Ne možeš izbaciti sebe.';
  static const botsBetweenGames = 'Robote možeš mijenjati samo između igara.';
  static const lockedIn = 'Odgovor je zaključan. Gledaj TV.';
  static const characterTaken = 'Taj lik je već zauzet. Odaberi drugi.';

  // --- Adding a quiz pack from a phone ---

  static const onlyHostAddsPacks = 'Samo domaćin može dodavati pakete.';
  static const packsNotReady = 'Paketi još nisu dostupni.';
  static String packAdded(String title, int n) =>
      'Dodano: $title ($n ${n % 10 == 1 && n % 100 != 11 ? 'pitanje' : 'pitanja'}).';
  static String builtInPackId(String id) =>
      "Ugrađeni paket već koristi oznaku '$id'. Odaberi drugu oznaku.";
  static const packSaveFailed = 'TV nije mogao spremiti paket. Oslobodi malo mjesta na TV-u pa pokušaj ponovo.';

  // --- Start-up ---

  static String startFailed(Object error) => 'Pokretanje nije uspjelo: $error';
}
