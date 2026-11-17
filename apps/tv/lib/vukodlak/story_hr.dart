/// Vukodlak: the story the TV tells in the village square, in Croatian.
///
/// One list of lines per story event; the TV picks one at random so a game
/// doesn't repeat itself. Keys match the core engine's events (93f1bd6) and the
/// session's (marked "session"). An event that may carry a role has two keys:
/// `xxx` without it and `xxxRole` with `{role}`; the engine sends the role only
/// when roles are shown. Placeholders: {name}, {name2} player names, {role} a
/// role name, {count} a number. Every placeholder stands where the nominative
/// fits and no line puts a past-tense verb on a player, so any name reads right.
/// Review table: docs/strings-hr.md.
const Map<String, List<String>> storyHr = {
  // --- Night (session) ---
  'firstNight': [
    'Prva noć u selu. Nitko još ne zna tko je tko.',
    'Selo prvi put tone u san. Nitko još ne zna kome vjerovati.',
    'Prva noć. Mjesec gleda odozgo i šuti.',
    'Počinje priča o selu i vukovima. Zatvorite oči.',
  ],
  'nightFalls': [
    'Pada noć nad selom. Svi zatvaraju oči i škure.',
    'Sunce je zašlo iza brda. Selo tone u san.',
    'Mrak se spušta na krovove. Negdje u šumi zavija vuk.',
    'Lampe se gase jedna po jedna. Počinje duga noć.',
    'Mjesec izlazi nad trgom. Seljani se zavlače pod pokrivače.',
    'Noć je pala. Tko ima posla, neka ga obavi tiho.',
  ],
  'nightWait': [
    'Selo spava, a netko u mraku ipak bdije.',
    'Iz šume se čuju koraci. Nitko ne viri kroz prozor.',
    'Tišina. Samo sova zna što se noćas događa.',
    'Psi su utihnuli. Nešto se šulja između kuća.',
    'Svijeće trepere. Odluke se donose u tami.',
  ],

  // --- Morning (engine) ---
  // A quiet night and a stopped attack look the same: no line hints at an attack.
  'morningNobody': [
    'Svanulo je. Na trgu su svi, živi i zdravi.',
    'Pijetao kukuriče, a selo broji glave: nitko ne fali!',
    'Mirno jutro. Dim se diže iz svih dimnjaka.',
    'Sunce izlazi nad selom koje je noć prebrodilo bez gubitka.',
    'Seljani otvaraju vrata i odahnu: svi su na broju.',
  ],
  'morningDied': [
    'Jutro je. Seljani nalaze zatvorena vrata: {name} više nije s nama.',
    'Pijetao kukuriče, ali jedna kuća šuti. Iz nje ne izlazi {name}.',
    'Svanulo je, ali ne za sve. Noć je odnijela: {name}.',
    'Na pragu tragovi šapa. {name} ne dočekuje jutro s nama.',
    'Gavran sjeda na krov. {name} odlazi iz igre.',
    'Selo se budi tužno: {name} ispada iz igre.',
  ],
  'morningDiedRole': [
    'Jutro je, a {name} više nije s nama. Uloga: {role}.',
    'Noć je odnijela: {name}. Bila je to uloga: {role}.',
    'Gavran sjeda na krov. {name} odlazi, a uloga je bila: {role}.',
    'Selo se budi tužno: {name} ispada. Uloga: {role}.',
  ],
  'loverDied': [
    'Slomljeno srce ne kuca dugo. {name} odlazi za svojom ljubavi.',
    'Zaljubljeni ne mogu jedno bez drugoga. Odlazi i {name}.',
    'Od tuge za svojom ljubavi iz igre ispada i {name}.',
    'Dvije kuće, jedno srce. Odlazi i {name}.',
  ],
  'loverDiedRole': [
    'Slomljeno srce ne kuca dugo. Odlazi i {name}. Uloga: {role}.',
    'Zaljubljeni ne mogu jedno bez drugoga. Odlazi {name}, uloga: {role}.',
    'Od tuge ispada i {name}. Bila je to uloga: {role}.',
  ],

  // --- Day (session) ---
  'dayStarts': [
    'Seljani se okupljaju na trgu. Vrijeme je za razgovor.',
    'Sjednite oko zdenca i recite što ste vidjeli.',
    'Dan je kratak, a sumnje duge. Raspravite!',
    'Tko laže, a tko govori istinu? Selo ima malo vremena.',
    'Pričajte, pitajte i gledajte se u oči.',
  ],
  'voteStarts': [
    'Dosta priče! Koga selo tjera iz sela?',
    'Svatko neka pokaže prstom. Počinje glasanje.',
    'Selo mora odlučiti. Glasajte na mobitelima.',
    'Kucnuo je čas. Tko odlazi iz sela?',
    'Glasanje počinje. Neka odluči većina.',
  ],

  // --- Vote (engine) ---
  'voteOut': [
    'Selo je odlučilo: {name} napušta selo.',
    'Većina je rekla svoje. {name} odlazi s trga.',
    'Prsti su uprti u jednu kuću. {name} ispada iz igre.',
    'Odluka je pala: {name} mora otići.',
    'Selo zatvara jedna vrata. {name} više ne glasa s nama.',
  ],
  'voteOutRole': [
    'Selo je odlučilo: {name} odlazi. Uloga: {role}.',
    'Odluka je pala: {name} mora otići. Bila je to uloga: {role}.',
    'Većina je rekla svoje. {name} odlazi, a uloga je bila: {role}.',
    'Selo zatvara jedna vrata: {name}. Uloga: {role}.',
  ],
  'voteTie': [
    'Glasovi su se podijelili napola. Danas nitko ne odlazi.',
    'Izjednačeno! Selo se ne može odlučiti, pa svi ostaju.',
    'Vaga stoji na sredini. Nitko ne ispada, barem do noći.',
    'Neriješeno. Vukodlaci se smiju u bradu.',
  ],
  'voteNobody': [
    'Nitko ne diže ruku. Danas nitko ne odlazi.',
    'Selo šuti i ne odlučuje. Svi ostaju do noći.',
    'Glasova je premalo. Danas nitko ne ispada.',
    'Seljani preskaču glasanje. Noć dolazi brzo.',
  ],

  // --- Events that show a role by their nature (see [storyNamesRole]) ---
  'hunterAims': [
    'Lovac {name} podiže pušku. Koga će povući sa sobom?',
    'Lovac {name} odlazi, ali prije toga nišani.',
    'Tišina na trgu. Lovac {name} bira metu.',
  ],
  'hunterShot': [
    'Pucanj odjekne selom! Lovac {name} pogađa: {name2}.',
    'Lovac {name} ne odlazi sam. Metak pogađa: {name2}.',
    'Lovac {name} ispada, ali stigne opaliti. Pogodak: {name2}.',
    'Zadnji hitac s lovačke puške. Odlazi i {name2}.',
  ],
  'hunterShotRole': [
    'Pucanj odjekne selom! Lovac {name} pogađa: {name2}. Uloga: {role}.',
    'Metak lovca pogađa: {name2}. Bila je to uloga: {role}.',
    'Lovac {name} stigne opaliti. Pogodak: {name2}, uloga: {role}.',
  ],
  'mayorBreaksTie': [
    'Izjednačeno! Odlučuje načelnik {name}.',
    'Glasovi su jednaki, pa zadnju riječ ima načelnik {name}.',
    'Vaga stoji na sredini. Načelnik {name} odlučuje kamo će pasti.',
  ],
  'foolSpared': [
    'Selo je izglasalo seosku budalu! {name} ostaje, ali više ne glasa.',
    '{name} je seoska budala: ostaje u selu, ali bez prava glasa.',
    'Smijeh na trgu: {name} je seoska budala. Ostaje, ali više ne glasa.',
    'Budalu se ne tjera iz sela. {name} ostaje, bez glasa.',
  ],
  'trampWins': [
    'Selo je izbacilo lutalicu! {name} odlazi pjevajući.',
    'Lutalica {name} dobiva baš ono što želi.',
    'Pogrešna kuća! {name} je lutalica.',
    'Lutalica {name} maše selu s ceste.',
  ],
  'wolvesLeft': [
    'Vukodlaka u selu još ima: {count}.',
    'Broj vukodlaka koji se još skrivaju: {count}.',
    'U selu se još skriva vukodlaka: {count}.',
  ],

  // --- Game over (engine: gameOver{winner}) ---
  'gameOverVillage': [
    'Posljednji vukodlak je otkriven. Selo slavi uz harmoniku!',
    'Nema više vukova! Seljani zvone zvonom i pale krijes.',
    'Selo je pobijedilo. Večeras se pleše kolo na trgu.',
    'Mir se vraća u selo. Pobjeda pripada seljanima!',
    'Šuma je opet tiha. Seljani su pobijedili.',
  ],
  'gameOverWolves': [
    'Vukodlaka je sada koliko i seljana. Selo pripada čoporu!',
    'Zavijanje odjekuje trgom. Pobijedili su vukodlaci.',
    'Selo je palo pod šape. Vukodlaci slave pod punim mjesecom.',
    'Prekasno je za seljane. Čopor je pobijedio.',
    'Vukovi su nadmudrili selo. Pobjeda je njihova!',
  ],
  'gameOverLone': [
    'Na trgu ostaje samo vuk samotnjak. Pobjeda je samo njegova.',
    'Vuk samotnjak nadmudrio je i selo i čopor!',
    'Čopora više nema. Vuk samotnjak slavi sam.',
    'Posljednji je ostao vuk samotnjak. Pobjeda!',
  ],
  'gameOverTramp': [
    'Lutalica je dobila što je htjela: put pod noge i pobjedu.',
    'Selo je izbacilo lutalicu, a lutalica pobjeđuje!',
    'Pobjeda pripada lutalici. Selo je nasjelo.',
  ],
  'gameOverNobody': [
    'U selu nema više nikoga. Ova priča nema pobjednika.',
    'Prazan trg i tihe kuće. Nitko ne slavi.',
    'Ni seljana ni vukova. Samo gavrani ostaju na krovovima.',
  ],
  'endReveal': [
    'Igra je gotova. Evo tko se krio iza koje uloge!',
    'Maske padaju! Pogledajte sve uloge.',
    'Kraj priče. Sad smijete vidjeti tko je što bio.',
    'Sve se otkriva: uloge svih igrača.',
  ],
};

/// Keys whose lines name a role. `xxxRole` keys are used only when roles are
/// shown; the others belong to events that show the role by their nature (the
/// hunter shoots, the fool stays, the mayor decides, the tramp or lone wolf
/// wins) or, for wolvesLeft, only when roles are shown.
const Set<String> storyNamesRole = {
  'morningDiedRole',
  'loverDiedRole',
  'voteOutRole',
  'hunterShotRole',
  'hunterAims',
  'hunterShot',
  'mayorBreaksTie',
  'foolSpared',
  'trampWins',
  'wolvesLeft',
  'gameOverLone',
  'gameOverTramp',
};
