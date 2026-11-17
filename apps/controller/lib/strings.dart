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
  static const removed = 'Domaćin te uklonio iz igre.';
  static const ok = 'U redu';

  // Lobby
  static String waitingForHost(String? host) =>
      'Čekaš da ${host ?? 'domaćin'} pokrene igru.';
  static const pickGame = 'Odaberi igru';
  static const quiz = 'Kviz';
  static const curve = 'Curve';
  static const quizPack = 'Paket pitanja';
  static String packMeta(PackInfo p) => [
    questions(p.questionCount),
    if (p.pictures) 'slike',
    if (p.isNew) 'novo',
  ].join(' · ');
  static const pickPack = 'Odaberi paket';
  static const addPack = 'Dodaj svoj paket…';

  /// 1 pitanje, 21 pitanje, 2 pitanja, 94 pitanja, 401 pitanje.
  static String questions(int n) =>
      '$n ${n % 10 == 1 && n % 100 != 11 ? 'pitanje' : 'pitanja'}';
  static const settingsNote =
      'Postavke se vide na TV-u i vrijede od sljedeće igre. TV ih pamti.';
  static const bots = 'Roboti';
  static const fewerBots = 'Manje robota';
  static const moreBots = 'Više robota';
  static String others(int n) => 'Ostali · $n';
  static const away = ' (nije tu)';
  static const botTag = 'ROBOT';
  static const remove = 'Ukloni';
  static const keep = 'Zadrži';
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
  };
  static String gameBlurb(GameKind k) => switch (k) {
    GameKind.quiz => 'Pitanja s četiri odgovora. Odgovaraš na svom mobitelu.',
    GameKind.curve => 'Vozi svoju krivulju i ne udari u druge.',
    GameKind.vukodlak => 'Selo i vukodlaci. Uloga je tajna.',
    GameKind.uljez => 'Svi imaju istu riječ, osim uljeza. Nađi ga.',
  };
  static String watchingLabel(String? host) => '${host ?? 'Domaćin'} gleda:';
  static String startsWhen(String? host) =>
      'Igra počinje kad ${host ?? 'domaćin'} pritisne Igraj.';
  static const hostTag = '★ DOMAĆIN';
  static const youSuffix = ' (ti)';
  static String players(int n) => 'Igrači · $n';
  static String playerCount(int n) => '$n igrača';
  static const curveModeBlurb = {
    CurveMode.chaos: 'Puno pojačanja, sve odjednom',
    CurveMode.balanced: 'Kao do sada',
    CurveMode.peaceful: 'Bez pojačanja',
    CurveMode.onlyYou: 'Samo zelena: usporavanje i duh',
  };

  /// The settings of [k] in one line, as on the carousel card.
  static String settingsLine(
    GameKind k,
    GameSettings s,
    List<PackInfo> packs,
    List<PackInfo> uljezPacks,
  ) {
    String pack(List<PackInfo> l, String? id) =>
        (l.where((p) => p.id == id).firstOrNull ?? l.firstOrNull)?.title ?? '';
    return switch (k) {
      GameKind.quiz =>
        '${pack(packs, s.quizPackId)} · ${questions(s.quizQuestions)} · ${seconds(s.quizSeconds)}',
      GameKind.curve =>
        '$curveModeLabel: ${curveMode(s.curveMode)} · $curveCountdown: ${seconds(s.curveCountdown)}',
      GameKind.vukodlak =>
        '$possibleRoles: ${s.wolfRoles.length} · $discussion: ${minutes(s.wolfDiscussion)}',
      GameKind.uljez =>
        '${pack(uljezPacks, s.uljezPackId)} · $discussion: ${minutes(s.uljezDiscussion)} · ${impostors(s.uljezImpostors)}',
    };
  }

  static String watching(String? host, String game) =>
      '${host ?? 'Domaćin'} gleda: $game';

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
  static String possibleRolesCount(int n) => 'Moguće uloge · $n uključeno';
  static const rolesInThisGame = 'Uloge u ovoj igri';
  static const rolesLocked = ' (uvijek u igri)';
  static const hiddenRoles = 'Skrivene uloge';
  static const hiddenRolesHint =
      'Kad netko ispadne, uloga se ne otkriva. Sve uloge se vide tek na kraju igre.';
  static const discussion = 'Razgovor danju';
  static const shorter = 'Kraće';
  static const longer = 'Duže';
  static const save = 'Spremi';
  static const rulesHeader = 'Pravila';
  static String minutes(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  static const drawnByGame = 'Igra izvlači koje će biti.';
  static const howPlayersSeeIt = 'Kako to vide igrači';
  static String rolesPickIntro(
    int players,
    int wolves,
    int specials,
    int villagers,
  ) =>
      'Za $players igrača, vukodlaka: $wolves · posebnih uloga: $specials · seljana: $villagers. Svaka igra izvuče drugačije.';
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

  // Uljez
  static const uljezName = 'Uljez';
  static String uljezRound(int n) => 'ULJEZ · RUNDA $n';
  static const yourWord = 'TVOJA RIJEČ';
  static const wordHint = 'Tvoja riječ se vidi samo dok držiš.';
  static const wordNote = 'Netko možda ima drugu riječ. Možda i ti.';
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
  static const wordPack = 'Paket riječi';
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
