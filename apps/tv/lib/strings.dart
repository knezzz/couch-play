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
  static String pauseSub(int seconds) => 'Igra je zaustavljena. Još $seconds s, onda završava.';
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
  static String gameName(GameKind k) => switch (k) { GameKind.quiz => 'Kviz', GameKind.curve => 'Curve', GameKind.vukodlak => 'Vukodlak', GameKind.uljez => 'Uljez', GameKind.objasni => 'Objasni', GameKind.koliko => 'Koliko?', GameKind.blef => 'Blef', GameKind.tkobi => 'Tko bi?' };
  /// 2000 -> '2 000' (no-break space).
  static String _g(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '\u00A0');

  /// 1 paket, 2 paketa, 5 paketa (Croatian counting: 21 paket, 12 paketa).
  static String packsWord(int n) => '${_g(n)} ${n % 10 == 1 && n % 100 != 11 ? 'paket' : 'paketa'}';

  /// 1 pitanje, 2 pitanja, 2 000 pitanja.
  static String questionsWord(int n) => '${_g(n)} ${n % 10 == 1 && n % 100 != 11 ? 'pitanje' : 'pitanja'}';

  /// The line under a game's name (V2Home). The Kviz one says how much there is to play, when known.
  static String gameBlurb(GameKind k, {int packs = 0, int questions = 0}) => switch (k) {
        GameKind.quiz => packs > 0
            ? '${packsWord(packs)}, ${questionsWord(questions)}. Odgovaraš na mobitelu.'
            : 'Pitanja s četiri odgovora. Odgovaraš na mobitelu.',
        GameKind.curve => 'Vozi svoju krivulju i ne udari ni u koga.',
        GameKind.vukodlak => 'Netko u selu nije ono što se čini.',
        GameKind.uljez => 'Svi imaju istu riječ, osim uljeza. Nađi ga.',
        GameKind.objasni => 'Objasni riječ svojoj ekipi, a da je ne izgovoriš.',
        GameKind.koliko => 'Pogodi broj. Tko je najbliže, nosi bodove.',
        GameKind.blef => 'Izmisli lažan odgovor i pronađi pravi.',
        GameKind.tkobi => 'Tko bi se najvjerojatnije...? Glasaj za nekoga u sobi.',
      };
  /// Bottom of the lobby while the host has a game's card open (the phones say the same).
  static String watching(String host, GameKind k) => '$host gleda: ${gameName(k)}';
  static const settingPack = 'Paket pitanja';
  static const settingQuestions = 'Broj pitanja';
  static const settingAnswerTime = 'Vrijeme za odgovor';
  static const settingReveal = 'Pauza između pitanja';
  static const settingMode = 'Način igre';
  static const settingCountdown = 'Pauza prije runde';
  static const settingDiscussion = 'Vrijeme razgovora';
  static const settingHideRoles = 'Skrivene uloge';
  static const settingImpostors = 'Broj uljeza';
  static String settingsLine(GameSettings s) =>
      'Kviz: ${s.quizQuestions} pitanja · odgovor ${s.quizSeconds} s · pauza ${s.revealSeconds} s'
      '     Curve: ${curveModeName(s.curveMode)} · pauza prije runde ${s.curveCountdown} s';

  // --- Console home ---

  static String curveBreakTitle(int round) => 'Rezultat nakon runde $round';
  static String curveBreakTarget(int target) => 'Pobjeđuje tko prvi dosegne $target';
  static String curveBreakNext(int seconds) => 'Sljedeća runda za $seconds s';
  static const curveCountdownHint = 'Pronađi svoju točku. Strelica pokazuje kamo kreneš.';

  static String objasniTeam(int t) => 'Tim ${t + 1}';
  static String objasniTarget(int n) => 'Pobjeđuje tko prvi dosegne $n';
  static const objasniSetupHint = 'Domaćin može promiješati ekipe na mobitelu. Onda Kreni.';
  static const objasniNextExplains = 'Sljedeći objašnjava';
  static const objasniExplains = 'Objašnjava';
  static const objasniReadyHint = 'Spreman? Dodirni Kreni na svom mobitelu.';
  static const objasniGuessAloud = 'Pogađajte naglas!';
  static const objasniTurnOver = 'Vrijeme je isteklo';
  static const objasniNoWords = 'Nijedna riječ ovaj put.';
  static String objasniNextIn(int s) => 'Sljedeći krug za $s s';
  static String objasniWins(int t) => 'Pobjeđuje ${objasniTeam(t)}!';
  static const objasniFoul = 'prekršaj';
  static const legendTitle = 'Pojačanja';
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
        GameKind.objasni => '4–8 igrača · dvije ekipe · bez robota',
        GameKind.koliko => '2–8 igrača · bez robota',
        GameKind.blef => '3–8 igrača · bez robota',
        GameKind.tkobi => '3–8 igrača · bez robota',
      };

  // --- Vukodlak (the village on the TV) ---

  static String wolfNight(int n) => 'NOĆ $n';
  static String wolfMorning(int n) => 'JUTRO $n';
  static String wolfDay(int n) => 'DAN $n';
  static String wolfVoteHeader(int n) => 'DAN $n · GLASANJE';
  static const wolfVoteQuestion = 'Koga selo izbacuje?';
  static String wolfVoted(int x, int y) => 'Glasalo $x od $y';
  static const wolfEndHeader = 'KRAJ IGRE';
  static const wolfRolePrefix = 'Uloga:';
  /// At night, under the story: the lit windows are the ones still deciding.
  static String wolfLightsLeft(int n) => 'Svjetlo gori dok netko još nije odlučio: još $n.';
  static const wolfTeamVillage = 'Selo';
  static const wolfTeamWolves = 'Vukodlaci';
  static const wolfTeamSolo = 'Sam';

  // --- Uljez (the table on the TV) ---

  static String uljezRoundClues(int n) => 'RUNDA $n · TRAGOVI';
  static String uljezClueFor(String name) => '$name, reci trag.';
  static const uljezClueClock = 'Za trag';
  static const uljezClueHint = 'Svatko kaže jedan trag o svojoj riječi.\nNe reci riječ!';
  static const uljezNow = 'Sad ti!';
  static const uljezSaidClue = 'trag dan';
  static const uljezDiscussKicker = 'RAZGOVOR';
  static const uljezWho = 'Tko je uljez?';
  static const uljezDiscussClock = 'Do glasanja';
  static const uljezDiscussHint = 'Raspravite i potražite uljeza.';
  static const uljezVoteKicker = 'GLASANJE';
  static String uljezVoted(int x, int y) => 'Glasalo $x od $y';
  static String uljezCaught(String name) => 'Uhvatili ste uljeza: $name!';
  static String uljezGuesses(String name) => '$name pogađa vašu riječ';
  static String uljezNotImpostor(String name) => '$name ispada, ali nije uljez.';
  static const uljezNobodyOut = 'Nitko ne ispada.';
  static const uljezRoundOver = 'KRAJ RUNDE';
  static const uljezEndKicker = 'KRAJ IGRE';
  static const uljezVillageWins = 'Selo je pobijedilo!';
  static const uljezImpostorWins = 'Pobjeda uljeza!';
  static const uljezVillageWord = 'Riječ sela';
  static const uljezImpostorWord = 'Uljezova riječ';
  static const uljezTag = 'Uljez';
  static String uljezVotes(int n) => n == 1 ? '1 glas' : (n <= 4 ? '$n glasa' : '$n glasova');

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
