import 'package:core/core.dart';

/// Every user-facing text on the phone, in Croatian (informal "ti").
/// Texts the TV sends (ErrorMsg, Waiting) are shown as received.
abstract final class Strings {
  // Join
  static const appTitle = 'CouchPlay';
  static const joinHelper = 'Upiši svoje ime da se pridružiš igri na TV-u.';
  static const nameLabel = 'Tvoje ime';
  static const nameLimit = 'Najviše 16 znakova.';
  static const join = 'Pridruži se';
  static const animals = {
    'fox': 'Lisica',
    'owl': 'Sova',
    'frog': 'Žaba',
    'bear': 'Medvjed',
    'cat': 'Mačka',
    'dog': 'Pas',
    'rabbit': 'Zec',
    'penguin': 'Pingvin',
    'lion': 'Lav',
    'panda': 'Panda',
    'pig': 'Svinja',
    'koala': 'Koala',
    'mouse': 'Miš',
    'tiger': 'Tigar',
    'duck': 'Patka',
    'monkey': 'Majmun',
  };
  static String animal(String id) => animals[id] ?? '';
  static const taken = ' (zauzet)';
  static const pickCharacter = 'Odaberi svoj lik';
  static const changeCharacter = 'Promijeni lik';
  static const joinAgain = 'Pridruži se ponovno';
  static const emptyName = 'Upiši ime da se pridružiš.';
  static const removed = 'Više nisi u ovoj igri.';
  static const ok = 'U redu';

  // Lobby
  static String waitingForHost(String? host) =>
      'Čekaš da ${host ?? 'domaćin'} pokrene igru.';
  static const quiz = 'Kviz';
  static const curve = 'Curve';
  static String packMeta(PackInfo p) => [
    questions(p.questionCount),
    if (p.pictures) 'slike',
    if (p.isNew) 'novo',
  ].join(' · ');
  static const powerUps = 'Pojačanja';
  static const puYou = 'na tebe';
  static const puOthers = 'na sve ostale';
  static const puAll = 'na sve';
  // Objasni
  static const team1 = 'Tim 1';
  static const team2 = 'Tim 2';
  static String teamName(int t) => t == 0 ? team1 : team2;
  static const teamsTitle = 'Ekipe';
  static String yourTeam(int t) => 'Tvoj tim: ${teamName(t)}';
  static const reshuffle = 'Promiješaj';
  static const ready = 'Spreman?';
  static const go = 'Kreni';
  static String explainsNow(String name) => '$name objašnjava.';
  static String onTurn(String name) => '$name je na redu.';
  static const right = 'Točno';
  static const skip = 'Preskoči';
  static const foul = 'Prekršaj';
  static const guessAloud = 'Pogađaj naglas!';
  static const explainTitle = 'Objasni riječ';
  static const watchTitle = 'Pazi na pravila';
  static const turnOver = 'Kraj poteza';
  static const turnSeconds = 'Vrijeme po potezu';
  static String scoreText(int n) => '$n ${points(n)}';

  // Koliko?
  static String questionOf(int n, int total) => 'Pitanje $n od $total';
  static const waitTv = 'Gledaj TV.';
  static const sentHint = 'Poslano. Gledaj TV.\nOdgovor se vidi samo dok držiš.';
  static const yourAnswerCaps = 'TVOJ ODGOVOR';
  static const yourNumberCaps = 'TVOJ BROJ';
  static const yourVoteCaps = 'TVOJ GLAS';
  static const yourPickCaps = 'TVOJ ODABIR';
  static const correctAnswer = 'Točan odgovor';
  static const yourNumber = 'Tvoj broj';
  static const noNumber = 'Bez odgovora';
  static const exactHit = 'Točno!';
  static const closest = 'Najbliže!';
  static String place(int n) => 'Mjesto: $n';
  static String plusPoints(int n) => '+$n ${points(n)}';
  static String totalScore(int n) => 'Ukupno: $n';
  static const del = 'Obriši';

  // Blef
  static const blefWriteTitle = 'Smisli lažan odgovor';
  static const blefPickTitle = 'Koji je odgovor točan?';
  static const truthFound = 'Točan odgovor: pronađen';
  static const truthMissed = 'Točan odgovor: promašen';
  static String fooledN(int n) => 'Prevarenih: $n';

  // Tko bi?
  static const tkobiRight = 'Pogodak! Tvoj glas je pogodio krunu.';
  static const tkobiWrong = 'Ovaj put bez pogotka.';
  static const crowned = 'Pobjednik';

  static const send = 'Pošalji';
  static const blefHint = 'Tvoj odgovor';
  static const blefSpikeTitle = 'Blef: probno tipkanje';
  static const blefSpikeTry =
      'Upiši riječi sa č ć š ž đ (npr. „Čačkalica, ćevapi, šljiva, žaba, đak”), pa Pošalji. Ispod se vidi što je stiglo i kodovi znakova.';
  static const allPacks = 'Svi paketi';
  static const packMustStay = 'mora ostati';
  static const lastPackStays = 'Barem jedan paket mora ostati uključen.';
  static String packCount(int on, int all) => on >= all
      ? allPacks
      : '$on ${on % 10 == 1 && on % 100 != 11 ? 'paket' : 'paketa'}';
  static const addPack = 'Dodaj svoj paket…';

  /// 1 pitanje, 21 pitanje, 2 pitanja, 94 pitanja, 401 pitanje.
  static String questions(int n) =>
      '$n ${n % 10 == 1 && n % 100 != 11 ? 'pitanje' : 'pitanja'}';
  static const bots = 'Roboti';
  static String others(int n) => 'Ostali · $n';
  static const away = ' (nije tu)';
  static const botTag = 'ROBOT';
  static const remove = 'Ukloni';
  static const keep = 'Zadrži';
  static const removePlayer = 'Ukloni igrača';
  static String removeAway(int n) => 'Ukloni igrača · nije tu: $n';
  static const noConnection = 'nije tu';
  static String day(int n) => 'DAN $n';
  static String removeTitle(String name) => 'Ukloniti igrača $name?';
  static String removeBody(String name) =>
      '$name izlazi iz igre i može se ponovno pridružiti sa svog mobitela.';

  // Games (host's carousel and details)
  static const back = 'Natrag';
  static const play = 'Igraj';
  static String gameName(GameKind k) => switch (k) {
    GameKind.quiz => quiz,
    GameKind.curve => curve,
    GameKind.vukodlak => wolfName,
    GameKind.uljez => uljezName,
    GameKind.objasni => 'Objasni',
    GameKind.koliko => 'Koliko?',
    GameKind.blef => 'Blef',
    GameKind.tkobi => 'Tko bi?',
  };
  static String gameBlurb(GameKind k) => switch (k) {
    GameKind.quiz => 'Pitanja s četiri odgovora. Odgovaraš na svom mobitelu.',
    GameKind.curve => 'Vozi svoju krivulju i ne udari u druge.',
    GameKind.vukodlak => 'Selo i vukodlaci. Uloga je tajna.',
    GameKind.uljez => 'Svi imaju istu riječ, osim uljeza. Nađi ga.',
    GameKind.objasni => 'Objasni riječ svojoj ekipi, a da je ne izgovoriš.',
    GameKind.koliko => 'Pogodi broj. Tko je najbliže, nosi bodove.',
    GameKind.blef => 'Izmisli lažan odgovor i pronađi pravi.',
    GameKind.tkobi => 'Tko bi se najvjerojatnije...? Glasaj za nekoga u sobi.',
  };
  static const hostTag = '★ DOMAĆIN';

  // Phone home, live with the TV (Task 48)
  static const quizPacks = 'Paketi pitanja';
  static const wordPacks = 'Paketi riječi';
  static const yes = 'Da';
  static const no = 'Ne';
  static const rolesInGame = 'Uloge u igri';
  static String rolesCount(int n) =>
      '$n ${n % 10 == 1 && n % 100 != 11 ? 'uloga' : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14) ? 'uloge' : 'uloga')}';
  static const targetPoints = 'Bodova do pobjede';
  static const settingsForAll = 'Postavke · svi ih vide';
  static const settingsTitle = 'Postavke';
  static String playGame(String game) => 'Igraj $game';
  static String prevGame(String game) => 'Prethodna igra: $game';
  static String nextGame(String game) => 'Sljedeća igra: $game';
  static String watches(String host) => '$host gleda';
  static const watchesSettings = ' postavke';
  static const watchesPacks = ' pakete';
  static String picksPacks(String host) => '$host bira pakete';
  static String startedBy(String host) => 'Igru pokreće $host';
  static const changesTitle = 'Zadnje promjene';
  static String changesEmpty(String host) =>
      'Još ništa. Promjene se pojave ovdje čim ih $host napravi.';
  static const byPhone = 'mobitelom';
  static const byRemote = 'daljinskim';
  static String changedGame(String game) => 'Odabrana igra: $game';
  static String changedSettings(String game) => 'Otvorene postavke: $game';
  static String changedPacks(String game) => 'Otvoreni paketi: $game';
  static String changedSetting(String game, String label, String old, String now) =>
      '$game · $label: $old → $now';
  static const youSuffix = ' (ti)';
  static String players(int n) => 'Igrači · $n';


  // Settings (inside a game's details)
  static const quizSeconds = 'Vrijeme za odgovor';
  static const quizQuestions = 'Broj pitanja';
  static const revealSeconds = 'Pauza između pitanja';
  static const curveCountdown = 'Pauza prije runde';
  static const curveModeLabel = 'Način igre';
  static String curveMode(CurveMode m) => switch (m) {
    CurveMode.chaos => 'Kaos',
    CurveMode.balanced => 'Uravnoteženo',
    CurveMode.peaceful => 'Mirno',
    CurveMode.onlyYou => 'Samo za tebe',
  };
  static String seconds(int n) => '$n s';
  static String lessOf(String label) => 'Manje: $label';
  static String moreOf(String label) => 'Više: $label';

  // Vukodlak
  static const wolfName = 'Vukodlak';
  static const holdHere = 'Drži prst ovdje';
  static const holdHint = 'Uloga se vidi samo dok držiš.\nPusti i nestaje.';
  static const yourRole = 'TVOJA ULOGA';
  static String night(int n) => 'NOĆ $n';
  static const nightTitle = 'Noćna odluka';
  static const confirm = 'Potvrdi';
  static const sent = 'Poslano';
  static const farewellHint =
      'Više nisi u igri. Ako imaš još jedan potez, izaberi koga povlačiš sa sobom.';
  static String wolfMates(String names) => 'Drugi vukodlaci: $names';
  static String wolfWinner(WolfWinner w) => switch (w) {
    WolfWinner.village => 'Selo je pobijedilo.',
    WolfWinner.wolves => 'Vukodlaci su pobijedili.',
    WolfWinner.lone => 'Vuk samotnjak je pobijedio.',
    WolfWinner.tramp => 'Lutalica je pobijedila.',
    WolfWinner.nobody => 'Nitko nije pobijedio.',
  };
  static const nightSpecial = 'Iskoristi posebnu moć (ako je imaš)';
  static String voteHeader(int day) => 'DAN $day · GLASANJE';
  static const voteTitle = 'Koga izbacujete?';
  static const skipVote = 'Preskoči glasanje';
  static const vote = 'Glasaj';
  static const you = 'ti';
  static const possibleRoles = 'Moguće uloge';
  static const rolesInThisGame = 'Uloge u ovoj igri';
  static const rolesLocked = ' (uvijek u igri)';
  static const hiddenRoles = 'Skrivene uloge';
  static const save = 'Spremi';
  static const rulesHeader = 'Pravila';
  static String minutes(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  static const drawnByGame = 'Igra izvlači koje će biti.';
  static const howPlayersSeeIt = 'Kako to vide igrači';
  static const rolesPickIntroLead =
      'Ti biraš koje uloge smiju biti u igri. Igra sama izvlači koje će biti i koliko.';

  /// 1 vukodlak, 2 vukodlaka.
  static String wolvesN(int n) => n == 1 ? '1 vukodlak' : '$n vukodlaka';

  /// 1 posebna uloga, 3 posebne uloge, 5 posebnih uloga.
  static String specialsN(int n) => switch (n) {
    1 => '1 posebna uloga',
    2 || 3 || 4 => '$n posebne uloge',
    _ => '$n posebnih uloga',
  };

  /// do 1 posebne uloge, do 3 posebne uloge, do 5 posebnih uloga.
  static String specialsUpTo(int n) => switch (n) {
    1 => 'do 1 posebne uloge',
    2 || 3 || 4 => 'do $n posebne uloge',
    _ => 'do $n posebnih uloga',
  };
  static String villagersN(int n) => n == 1 ? '1 seljanin' : '$n seljana';
  static String rolesPickMix(
    int players,
    int wolves,
    int specials,
    int villagers,
  ) =>
      'Za $players igrača: ${wolvesN(wolves)}, ${specialsN(specials)} od uključenih, ${villagersN(villagers)}. Svaka igra izvuče drugačije.';
  static String rolesInfoIntro(int wolves, int specials) => specials == 0
      ? '${wolvesN(wolves)}. Ostali su Seljani. Svi vide isti popis.'
      : '${wolvesN(wolves)} i ${specialsUpTo(specials)} s ovog popisa. Ne mora svaka biti u igri. Ostali su Seljani. Svi vide isti popis.';
  static const groupWolves = 'VUKODLACI';
  static const groupVillage = 'SELO';
  static const groupSolo = 'SAMI ZA SEBE';

  /// id, name, description, group (0 wolves, 1 village, 2 solo), always on.
  static const wolfRoles = <(String, String, String, int, bool)>[
    (
      'wolf',
      'Vukodlak',
      'Noću s ostalim vukodlacima bira jednu žrtvu. Danju glumi seljana.',
      0,
      true,
    ),
    (
      'alpha',
      'Vođa čopora',
      'Vukodlak. Jednom u igri može žrtvu pretvoriti u vukodlaka umjesto da je ubije.',
      0,
      false,
    ),
    (
      'lone',
      'Vuk samotnjak',
      'Ubija s čoporom, ali pobjeđuje samo ako ostane zadnji živ.',
      0,
      false,
    ),
    (
      'villager',
      'Seljanin',
      'Nema noćnu moć. Danju sluša, pita i glasa.',
      1,
      true,
    ),
    (
      'seer',
      'Vidovnjakinja',
      'Svake noći sazna ulogu jednog igrača.',
      1,
      false,
    ),
    (
      'doc',
      'Ljekarnik',
      'Svake noći štiti jednog igrača od vukodlaka. Ne isti dvije noći zaredom.',
      1,
      false,
    ),
    (
      'guard',
      'Tjelohranitelj',
      'Čuva jednog igrača. Ako ga vukodlaci napadnu, strada tjelohranitelj umjesto njega.',
      1,
      false,
    ),
    (
      'herb',
      'Travarica',
      'Ima jedan lijek (spašava žrtvu noći) i jedan otrov (ubija nekoga). Svaki jednom u igri.',
      1,
      false,
    ),
    (
      'hunter',
      'Lovac',
      'Kad ispadne, odmah izbacuje još jednog igrača po izboru.',
      1,
      false,
    ),
    ('elder', 'Starješina', 'Preživi prvi napad vukodlaka.', 1, false),
    (
      'mayor',
      'Načelnik',
      'Glas mu se broji dvostruko. Ako je izjednačeno, on odlučuje.',
      1,
      false,
    ),
    (
      'cupid',
      'Provodadžija',
      'Prve noći spoji dvoje zaljubljenih. Ako jedno ispadne, ispada i drugo.',
      1,
      false,
    ),
    (
      'fool',
      'Seoska budala',
      'Ako ga selo izglasa, ostaje u igri, ali više ne smije glasati.',
      1,
      false,
    ),
    ('tramp', 'Lutalica', 'Pobjeđuje sam ako ga selo izglasa van.', 2, false),
  ];

  // Vukodlak, before night 1
  static const readyButton = 'Spreman';
  static const readyDone = 'Spreman ✓';
  static String readyCount(int count, int total) => 'Spremni: $count / $total';

  // Uljez and the day discussion
  static const clueDone = 'Dao sam trag';
  static const letsVote = 'Idemo glasati';
  static const letsVoteOn = 'Idemo glasati ✓';
  static String wishCount(int want, int needed) =>
      'Glasati žele $want · treba ih $needed';
  static const uljezName = 'Uljez';
  static String uljezRound(int n) => 'ULJEZ · RUNDA $n';
  static const yourWord = 'TVOJA RIJEČ';
  static const wordHint = 'Tvoja riječ se vidi samo dok držiš.';
  static const wordNote = 'Netko možda ima drugu riječ. Možda i ti.';
  static String uljezStage(String stage) => switch (stage) {
    'clues' => 'Tragovi',
    _ => '',
  };
  static const uljezVoteHeader = 'GLASANJE';
  static const whoIsImpostor = 'Tko je uljez?';
  static const caught = 'Uhvatili su te!';
  static const guessHeader = 'POGAĐANJE';
  static String caughtHint(String word) =>
      'Tvoja riječ je bila $word. Pogodi riječ sela i ipak pobjeđuješ.';
  static String uljezWinner(UljezWinner w) => switch (w) {
    UljezWinner.village => 'Selo je uhvatilo uljeza.',
    UljezWinner.impostors => 'Uljez je pobijedio.',
  };
  static const villageWord = 'Riječ sela';
  static const impostorWord = 'Riječ uljeza';
  static const impostorsAre = 'Uljez';
  static const impostorCount = 'Broj uljeza';
  static String impostors(int n) => n == 1 ? '1 uljez' : '$n uljeza';

  // Pack upload
  static const tvProblem = 'TV ima problem. Pokušaj ponovno.';
  static const tvUnreachable =
      'Ne mogu doći do TV-a. Provjeri Wi-Fi i pokušaj ponovno.';

  // Quiz
  static String questionHeader(int n, int total) =>
      'Pitanje $n od $total · gledaj TV';
  static const locked = 'Odgovor je zaključan. Gledaj TV.';
  static const correct = 'Točno';
  static const notThisTime = 'Ovaj put ne';
  static const yourTotal = 'Tvoj ukupni rezultat';

  // Curve
  static const crashed = 'Sudar! Pričekaj sljedeću rundu.';

  static const steerLeft = 'Lijevo';
  static const steerRight = 'Desno';
  static String curveScore(int n) => '$n ${points(n)}';
  static String curveRoundScore(int round, int n) =>
      'Runda $round · ${curveScore(n)}';
  static const curveHint =
      'Drži za skretanje. Kad te zahvati „Obrnuto”, lijevo i desno se zamijene: na TV-u uz tvoju liniju vidiš crvene strelice.';

  // Results
  static const gameOver = 'Igra je gotova.';
  static String placed(int place) => 'Tvoje mjesto: $place.';
  static String sessionPoints(int n) => '+$n ${points(n)} za ovu večer';

  /// bod, boda, bodova
  static String points(int n) {
    final t = n % 100, o = n % 10;
    if (o == 1 && t != 11) return 'bod';
    if (o >= 2 && o <= 4 && (t < 12 || t > 14)) return 'boda';
    return 'bodova';
  }
}
