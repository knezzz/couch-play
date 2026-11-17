/// Vukodlak: the story the TV tells in the village square, in Croatian.
///
/// Each event has several lines; the TV picks one at random so a game doesn't
/// repeat itself. Placeholders: {name} and {name2} are player names, {role} a
/// role name, {count} a number. Every placeholder stands where the nominative
/// fits, so any name works unchanged, and no line puts a past-tense verb on a
/// player, so it reads right for anyone. Review table: docs/strings-hr.md.
///
/// Hidden roles ("Skrivene uloge", on by default): lines in [storyNamesRole]
/// name a role or show one by what they say; the TV uses them only when that
/// role is shown anyway (hidden roles off, or the role is public by its own
/// rule: the hunter's shot, the fool, the mayor, the tramp's win, the lone
/// wolf's win). Every other key is role-free.
const Map<String, List<String>> storyHr = {
  // --- Night ---
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

  // --- Morning ---
  'morningNoneOut': [
    'Svanulo je. Na trgu su svi, živi i zdravi.',
    'Pijetao kukuriče, a selo broji glave: nitko ne fali!',
    'Jutro je mirno. Noćas vukodlaci nisu imali sreće.',
    'Sunce izlazi nad selom koje je noć prebrodilo bez gubitka.',
    'Seljani otvaraju vrata i odahnu: svi su na broju.',
  ],
  'morningOneOut': [
    'Jutro je. Seljani nalaze zatvorena vrata: {name} više nije s nama.',
    'Pijetao kukuriče, ali jedna kuća šuti. Iz nje ne izlazi {name}.',
    'Svanulo je, ali ne za sve. Noć je odnijela: {name}.',
    'Na pragu tragovi šapa. {name} ne dočekuje jutro s nama.',
    'Gavran sjeda na krov. {name} odlazi iz igre.',
    'Selo se budi tužno: {name} ispada iz igre.',
  ],
  'morningTwoOut': [
    'Teško jutro: iz igre ispadaju {name} i {name2}.',
    'Dvije kuće ostaju zatvorene: {name} i {name2} ispadaju.',
    'Noć je bila gladna. Odlaze {name} i {name2}.',
    'Na dva krova sjede gavrani: {name} i {name2} više nisu s nama.',
  ],
  'someoneProtected': [
    'Vukodlaci su noćas pokucali, ali vrata su izdržala.',
    'U blatu tragovi šapa, a nitko nije stradao. Netko je bdio.',
    'Napad je bio, žrtve nema. Selo ima tajnog čuvara.',
    'Vukovi su otišli praznih šapa. Netko je čuvao pravu kuću.',
  ],
  'attackSurvived': [
    'Vukodlaci su ugrizli, ali žrtva je bila tvrđa od njih.',
    'Netko je noćas odolio vukodlaku. Selo ne zna tko.',
    'Napad u mraku, a ujutro nitko ne fali. Čudna noć!',
    'Vuk je zagrizao u tvrdu koru. Svi su ujutro na nogama.',
  ],

  // --- Day ---
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
  'voteOut': [
    'Selo je odlučilo: {name} napušta selo.',
    'Većina je rekla svoje. {name} odlazi s trga.',
    'Prsti su uprti u jednu kuću. {name} ispada iz igre.',
    'Odluka je pala: {name} mora otići.',
    'Selo zatvara jedna vrata. {name} više ne glasa s nama.',
  ],
  'voteNone': [
    'Glasovi su se podijelili. Danas nitko ne odlazi.',
    'Selo se nije složilo. Svi ostaju, barem do noći.',
    'Nema većine, nema odluke. Noć dolazi brzo.',
    'Svađa bez kraja: danas nitko ne ispada.',
    'Selo okleva, a vukodlaci se smiju u bradu.',
  ],

  // --- Lines that name a role (see [storyNamesRole]) ---
  'outRevealRole': [
    'Pokazalo se: {name} je {role}.',
    'Kad su se vrata zatvorila, saznalo se: {name} je {role}.',
    'Tajna je otkrivena. {name} je {role}.',
    'Selo sada zna: {name} je {role}.',
  ],
  'wolvesLeft': [
    'Vukodlaka u selu još ima: {count}.',
    'Broj vukodlaka koji se još skrivaju: {count}.',
    'U selu se još skriva vukodlaka: {count}.',
  ],
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
  'loverFollows': [
    'Slomljeno srce ne kuca dugo. {name} odlazi za svojom ljubavi.',
    'Zaljubljeni ne mogu jedno bez drugoga. Odlazi i {name}.',
    'Od tuge za svojom ljubavi iz igre ispada i {name}.',
    'Provodadžija ih je spojio, a sudbina rastavila. Odlazi {name}.',
  ],
  'mayorDouble': [
    'Načelnik {name} ima dvostruki glas.',
    'Glas načelnika broji se dvaput. Tako je od davnina.',
    'Načelnik {name} glasa, a selo broji dvaput.',
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

  // --- Wins ---
  'winVillage': [
    'Posljednji vukodlak je otkriven. Selo slavi uz harmoniku!',
    'Nema više vukova! Seljani zvone zvonom i pale krijes.',
    'Selo je pobijedilo. Večeras se pleše kolo na trgu.',
    'Mir se vraća u selo. Pobjeda pripada seljanima!',
    'Šuma je opet tiha. Seljani su pobijedili.',
  ],
  'winWolves': [
    'Vukodlaka je sada koliko i seljana. Selo pripada čoporu!',
    'Zavijanje odjekuje trgom. Pobijedili su vukodlaci.',
    'Selo je palo pod šape. Vukodlaci slave pod punim mjesecom.',
    'Prekasno je za seljane. Čopor je pobijedio.',
    'Vukovi su nadmudrili selo. Pobjeda je njihova!',
  ],
  'winLoneWolf': [
    'Na trgu ostaje samo vuk samotnjak {name}. Pobjeda!',
    'Vuk samotnjak {name} nadmudruje i selo i čopor. Pobjeda!',
    'Posljednji na nogama je vuk samotnjak: {name}.',
    'Čopora više nema, a vuk samotnjak {name} slavi bez društva.',
  ],
  'winTramp': [
    'Selo je izbacilo lutalicu! {name} odlazi pjevajući i pobjeđuje.',
    'Lutalica {name} dobiva što želi: put pod noge i pobjedu.',
    'Izbacili ste lutalicu. Pobjeđuje {name}!',
    'Pobjeda pripada lutalici: {name}.',
  ],
  'endReveal': [
    'Igra je gotova. Evo tko se krio iza koje uloge!',
    'Maske padaju! Pogledajte sve uloge.',
    'Kraj priče. Sad smijete vidjeti tko je što bio.',
    'Sve se otkriva: uloge svih igrača.',
  ],
};

/// Keys whose lines name a role or give one away. Never use them for a player
/// whose role is still hidden.
const Set<String> storyNamesRole = {
  'outRevealRole',
  'wolvesLeft',
  'hunterAims',
  'hunterShot',
  'loverFollows',
  'mayorDouble',
  'mayorBreaksTie',
  'foolSpared',
  'winLoneWolf',
  'winTramp',
};
