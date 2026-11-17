# CouchPlay: the Croatian interface, for review

Every text the TV and the phones show, in Croatian, with its English meaning and where it appears. Please correct any wording directly in the Croatian column (or note it beside the row); the engineers apply your corrections to the strings files.

The person's decisions (2026-11-14): neutral wording for every text that addresses the player (no masculine past tense); "Curve" stays; "Robot n", ROBOT and NEMA VEZE stay; informal "ti", "početni zaslon", "Izađi" and "1." places stand. quizNotReady was deleted (dead string).

Choices that were put to the person:
- informal "ti" everywhere
- bots are "Robot 1", "Robot 2", …
- the lobby is "početni zaslon"; Quit is "Izađi"
- the badge for a player who dropped off is "NEMA VEZE" (gender-neutral)
- places are written "1.", "2.", …
- gendered verbs: some texts address the player with a masculine past tense (e.g. "Završio si na 4. mjestu"). Options: keep it, use both forms ("Završio/la si"), or rephrase neutrally ("Tvoje mjesto: 4."). Your call.
- kept in English on purpose: the app name "CouchPlay" and the game name "Curve" (say if Curve should get a Croatian name)

## TV (apps/tv/lib/strings.dart)

`{…}` marks a value filled in at run time. Ti-form throughout. "početni zaslon" is the lobby (the screen with the QR code).

| key | Croatian | English meaning | where it shows |
|---|---|---|---|
| noWifi | Spoji TV na Wi-Fi da možemo igrati. | Connect the TV to Wi-Fi so we can play. | TV lobby, in place of the QR code when the TV has no network |
| scanToJoin | Skeniraj kod mobitelom i pridruži se. | Scan the code with your phone and join. | TV lobby, right side, while nobody has joined |
| scanCaption | Skeniraj ili otvori u pregledniku: | Scan, or open in your browser: | TV lobby, under the QR code (the address follows) |
| players({n}) | Igrači · {n} od 8 | Players · {n} of 8 | TV lobby, above the player chips |
| badgeBot | ROBOT | BOT | TV lobby, pill on a bot's chip |
| badgeAway | NEMA VEZE | NO CONNECTION (player's phone is away) | TV lobby, pill on a chip whose phone lost the connection |
| scoreboard | Bodovi | Scores | TV lobby, scoreboard card heading |
| scoreboardEmpty | Bodovi se pojavljuju nakon prve igre. | Scores appear after the first game. | TV lobby, scoreboard card before any game was played |
| waitingForHost({name}) | Čekamo da {name} odabere igru. | Waiting for {name} to pick a game. | TV lobby, bottom right |
| curveModeName(mode) | Kaos / Uravnoteženo / Mirno / Samo za tebe | Chaos / Balanced / Peaceful / Only for you | TV lobby settings line (same names as the phone) |
| gameName(quiz / curve) | Kviz / Curve | Quiz / Curve | TV lobby, game card heading |
| gameBlurb(quiz) | Pitanja s četiri odgovora. Odgovaraš na svom mobitelu. | Questions with four answers. You answer on your phone. | TV lobby, game card (same words as the phone) |
| gameBlurb(curve) | Vozi svoju krivulju i ne udari u druge. | Steer your curve and do not hit the others. | TV lobby, game card (same words as the phone) |
| watching(host, game) | {host} gleda: {game} | {host} is looking at: {game} | TV lobby, bottom right, replaces "waiting for host" while a game card is shown (same words as the phone) |
| settingPack / settingQuestions / settingAnswerTime / settingReveal | Paket pitanja / Broj pitanja / Vrijeme za odgovor / Pauza između pitanja | Question pack / Number of questions / Time to answer / Pause between questions | TV lobby, Kviz card: label before the value (same as the phone) |
| settingMode / settingCountdown | Način igre / Pauza prije runde | Game mode / Pause before each round | TV lobby, Curve card: label before the value (same as the phone) |
| settingsLine(s) | Kviz: {n} pitanja · odgovor {a} s · pauza {r} s     Curve: {mode} · pauza prije runde {c} s | Quiz: {n} questions · answer {a} s · pause {r} s     Curve: {mode} · pause before each round {c} s | TV lobby, bottom right under "waiting for host": one small muted line, the host's settings; hidden while a game card is shown |
| waitingForReturn({name}) | Čekamo da se {name} vrati | Waiting for {name} to come back | 2-player Curve paused (up to 30 s): TV over the arena, and the other player's phone |
| waitingForPlayers | Čekamo da se igrači vrate | Waiting for the players to come back | Quiz or Curve paused (up to 30 s) because nobody is connected: TV over the game |
| howToJoin | Kako se pridružiti | How to join | TV lobby button, and the title of its dialog |
| quit | Izađi | Quit | TV lobby button (closes the app) |
| howToJoinSteps | 1. Spoji mobitel na isti Wi-Fi kao i TV.<br>2. Skeniraj kod ili upiši adresu u preglednik na mobitelu.<br>3. Upiši ime i dodirni Pridruži se. | 1. Put your phone on the same Wi-Fi as the TV. 2. Scan the code or type the address into your phone's browser. 3. Type a name and tap Join. | "Kako se pridružiti" dialog. "Pridruži se" must match the phone's join button |
| gotIt | U redu | OK | Button that closes the "Kako se pridružiti" dialog |
| botName({n}) | Robot {n} | Bot {n} | Name of a bot player everywhere (Robot 1, Robot 2, …) |
| endGameTitle | Prekinuti igru i vratiti se na početni zaslon? | End the game and go back to the start screen? | TV dialog when you press Back during a game |
| no | Ne | No | Dialog button (focused first) |
| yes | Da | Yes | Dialog button |
| questionOf({n}, {total}) | Pitanje {n} od {total} | Question {n} of {total} | TV quiz, top left, and in the reveal |
| answered({n}, {expected}) | Odgovorilo: {n} od {expected} | Answered: {n} of {expected} | TV quiz, top right while the question is open |
| answerIs | · Točan odgovor je | · The correct answer is | TV quiz reveal, after "Pitanje n od m" (the answer is the big tile below) |
| quizScores | Bodovi | Scores | TV quiz reveal, panel heading |
| gameOver | Kraj igre | Game over | TV results headline when nobody placed |
| wins(1 name) | {a} pobjeđuje! | {a} wins! | TV results headline |
| wins(2+ names) | {a}, {b} i {c} pobjeđuju! | {a}, {b} and {c} win! (a tie) | TV results headline |
| place({n}) | {n}. | {n}th place | TV results, before each row (1., 2., 3., …) |
| tonight | Večeras | Tonight | TV results, panel with the session scores |
| gameCurve | Curve | Curve (the game's name) | TV results, next to the headline |
| gameQuiz({title}) | Kviz · {title} | Quiz · {title} | TV results, next to the headline |
| backToLobby({s}) | Povratak na početni zaslon za {s} s | Back to the start screen in {s} s | TV results, under the countdown bar |
| reloadPage | Osvježi stranicu i pokušaj ponovo. | Reload the page and try again. | Error on the phone (bad join token) |
| typeName | Upiši ime da se pridružiš. | Type a name to join. | Error on the phone (empty name) |
| gameFull | Igra je puna (8 igrača). | The game is full (8 players). | Error on the phone |
| onlyHost | To može samo domaćin. | Only the host can do that. | Error on the phone |
| characterTaken | Taj lik je već zauzet. Odaberi drugi. | That character is taken. Pick another. | Error on the phone (lobby character change refused) |
| nextGameSoon | Sljedeća igra uskoro počinje. | The next game starts soon. | Phone waiting screen for someone who joined mid-game |
| gameRunning | Igra je već u tijeku. | A game is already running. | Error on the phone |
| packUnavailable | Taj paket nije dostupan. | That pack is not available. | Error on the phone (quiz pack missing) |
| curveNeedsTwo | Za Curve trebaju barem 2 igrača. Dodaj robota ili pozovi prijatelja. | Curve needs at least 2 players. Add a bot or invite a friend. | Error on the phone |
| noSuchPlayer | Tog igrača nema. | That player is not here. | Error on the phone (kick) |
| cannotKickSelf | Ne možeš izbaciti sebe. | You can't kick yourself. | Error on the phone (kick) |
| botsBetweenGames | Robote možeš mijenjati samo između igara. | You can change the bots only between games. | Error on the phone |
| lockedIn | Odgovor je zaključan. Gledaj TV. | Your answer is locked in. Watch the TV. | Phone, after answering a quiz question |
| onlyHostAddsPacks | Samo domaćin može dodavati pakete. | Only the host can add packs. | Message on the phone after a pack upload |
| packsNotReady | Paketi još nisu dostupni. | Packs are not available yet. | Message on the phone after a pack upload |
| packAdded({title}, {n}) | Dodano: {title} ({n} pitanje/pitanja). | Added: {title} ({n} questions). 1 and 21 take "pitanje", other numbers "pitanja". | Message on the phone after a successful pack upload |
| builtInPackId({id}) | Ugrađeni paket već koristi oznaku '{id}'. Odaberi drugu oznaku. | A built-in pack already uses the id '{id}'. Pick another id. | Message on the phone after a pack upload |
| packSaveFailed | TV nije mogao spremiti paket. Oslobodi malo mjesta na TV-u pa pokušaj ponovo. | The TV could not save the pack. Free some space on the TV, then try again. | Message on the phone after a pack upload |
| startFailed({error}) | Pokretanje nije uspjelo: {error} | Could not start: {error} | TV, full-screen error if the app cannot start |

Not translated on purpose: "CouchPlay" (the app name), "Curve" (the game's name), player names, quiz pack titles and questions (written in the packs).

Also: unknownPlayer = Igrač (Player), TV results, name of a placement whose player left (rare). The pack-size message (413) is core's PackStrings.tooBig, reviewed in core's section.

## Phone (apps/controller/lib/strings.dart)

Informal "ti". `{x}` is filled in by the app.

| key | Croatian | English meaning | where it shows |
|---|---|---|---|
| appTitle | CouchPlay | CouchPlay | join screen title, browser tab |
| joinHelper | Upiši svoje ime da se pridružiš igri na TV-u. | Type your name to join the game on the TV. | join screen |
| nameLabel | Tvoje ime | Your name | join screen, above the field |
| nameLimit | Najviše 16 znakova. | Up to 16 characters. | join screen, under the field |
| join | Pridruži se | Join | join button |
| joinAgain | Pridruži se ponovno | Join again | button after you were removed |
| emptyName | Upiši ime da se pridružiš. | Type a name to join. | join screen, name empty |
| removed | Domaćin te uklonio iz igre. | The host removed you from the game. | screen after the host removes you |
| ok | U redu | OK | closes a red error bar |
| waitingForHost | Čekaš da {host} pokrene igru. (fallback: domaćin) | You are waiting for {host} to start the game. | lobby, for non-hosts |
| pickGame | Odaberi igru | Pick a game | lobby, host only |
| quiz | Kviz | Quiz | lobby button |
| curve | Curve | Curve (game name, not translated) | lobby button |
| quizPack | Paket pitanja | Quiz pack | lobby, label of the pack list |
| addPack | Dodaj paket pitanja… | Add quiz pack… | lobby button, host only |
| bots | Roboti | Bots | lobby, stepper label |
| fewerBots | Manje robota | Fewer bots | accessibility label of the − button |
| moreBots | Više robota | More bots | accessibility label of the + button |
| pickCharacter | Odaberi svoj lik | Pick your character | join screen label above the character grid; title of the change sheet |
| changeCharacter | Promijeni lik | Change character | lobby, button under your chip (opens the grid) |
| back | Natrag | Back | game details, button at the top (returns to the game carousel) |
| play | Igraj | Play | game details, big button that starts the game |
| gameBlurb(quiz) | Pitanja s četiri odgovora. Odgovaraš na svom mobitelu. | Questions with four answers. You answer on your phone. | game card and details, one-line description |
| gameBlurb(curve) | Vozi svoju krivulju i ne udari u druge. | Steer your curve and do not hit the others. | game card and details, one-line description |
| watching(host, game) | host gleda: game | host is looking at: game | guest lobby, while the host has a game's details open |
| quizSeconds | Vrijeme za odgovor | Time to answer | game details, label of the stepper (10-60 s) |
| quizQuestions | Broj pitanja | Number of questions | game details, label of the stepper (5-30) |
| revealSeconds | Pauza između pitanja | Pause between questions | game details, label of the stepper (2-15 s) |
| curveCountdown | Pauza prije runde | Pause before the round | game details, label of the Curve stepper (1-10 s) |
| curveModeLabel | Način igre | Game mode | game details, heading above the Curve modes |
| curveMode(chaos) | Kaos | Chaos (lots of power-ups) | game details, Curve mode option |
| curveMode(balanced) | Uravnoteženo | Balanced (the normal game, default) | game details, Curve mode option |
| curveMode(peaceful) | Mirno | Peaceful (no power-ups) | game details, Curve mode option |
| curveMode(onlyYou) | Samo za tebe | Only for you (power-ups only for you) | game details, Curve mode option |
| seconds(n) | n s | n s | game details, the value next to a stepper |
| lessOf(label) | Manje: label | Less: label | accessibility label of a − button in Postavke |
| moreOf(label) | Više: label | More: label | accessibility label of a + button in Postavke |
| others | Ostali · {n} | Others · {n} | lobby list header |
| away | (nije tu) | (away) | after a name whose phone is disconnected |
| botTag | ROBOT | BOT | tag on a bot row |
| remove | Ukloni | Remove | button on a player row; button in the sheet |
| keep | Zadrži | Keep | button in the sheet |
| removeTitle | Ukloniti igrača {name}? | Remove player {name}? | bottom sheet title |
| removeBody | {name} izlazi iz igre i može se ponovno pridružiti sa svog mobitela. | {name} leaves the game and can join again from their phone. | bottom sheet text |
| tvProblem | TV ima problem. Pokušaj ponovno. | The TV had a problem. Try again. | after a failed pack upload |
| tvUnreachable | Ne mogu doći do TV-a. Provjeri Wi-Fi i pokušaj ponovno. | Can't reach the TV. Check the Wi-Fi and try again. | after a pack upload with no connection |
| questionHeader | Pitanje {n} od {total} · gledaj TV | Question {n} of {total} · look at the TV | quiz, top line |
| locked | Odgovor je zaključan. Gledaj TV. | Your answer is locked. Look at the TV. | quiz, after you tap |
| correct | Točno | Correct | quiz result, green |
| notThisTime | Ovaj put ne | Not this time | quiz result, red |
| yourTotal | Tvoj ukupni rezultat | Your total | quiz result |
| crashed | Sudar! Pričekaj sljedeću rundu. | Crash! Wait for the next round. | Curve, after you crash |
| rtt | rtt 20ms · p95 40ms · n=300 | (technical readout, not for players) | Curve, tiny top-right text |
| gameOver | Igra je gotova. | The game is over. | results, if you had no placement |
| placed | Tvoje mjesto: {n}. | Your place: {n}th | results |
| sessionPoints | +{n} bod / boda / bodova za ovu večer | +{n} points for this evening | results |

### Vukodlak (phone)

The role texts are the ones in the design (`WolfRoles.dc.html`); the 14 role names and descriptions are `Strings.wolfRoles` and are not repeated here.

| key | Croatian | English | where it shows |
|---|---|---|---|
| holdHere | Drži prst ovdje | Hold your finger here | role card, hidden |
| holdHint | Uloga se vidi samo dok držiš. Pusti i nestaje. | The role shows only while you hold. Let go and it disappears. | role card, hidden |
| yourRole | TVOJA ULOGA | YOUR ROLE | role card, shown |
| night(n) | NOĆ {n} | NIGHT {n} | role card, night screen |
| nightTitle | Noćna odluka | Night decision | night screen (same for every role) |
| confirm | Potvrdi | Confirm | night screen button |
| voteHeader(n) | DAN {n} · GLASANJE | DAY {n} · VOTE | day vote |
| voteTitle | Koga izbacujete? | Whom do you throw out? | day vote |
| skipVote | Preskoči glasanje | Skip the vote | day vote |
| vote | Glasaj | Vote | day vote button |
| you | ti | you | day vote, your own row |
| possibleRoles | Moguće uloge | Possible roles | host: role switches |
| possibleRolesCount(n) | Moguće uloge · {n} uključeno | Possible roles · {n} on | host: Vukodlak settings |
| drawnByGame | Igra izvlači koje će biti. | The game draws which will be in play. | host: Vukodlak settings |
| howPlayersSeeIt | Kako to vide igrači | How the players see it | host: Vukodlak settings |
| rolesPickIntro | Za {n} igrača, vukodlaka: {a} · posebnih uloga: {b} · seljana: {c}. Svaka igra izvuče drugačije. | For {n} players, werewolves: {a} · special roles: {b} · villagers: {c}. Every game draws differently. | host: role switches |
| rolesInThisGame | Uloge u ovoj igri | Roles in this game | everyone's roles list |
| rolesLocked | (uvijek u igri) | (always in the game) | host: Vukodlak and Seljanin rows |
| hiddenRoles | Skrivene uloge | Hidden roles | host: Vukodlak settings |
| hiddenRolesHint | Kad netko ispadne, uloga se ne otkriva. Sve uloge se vide tek na kraju igre. | When someone is out, their role is not revealed. All roles show only at the end. | host: Vukodlak settings |
| discussion | Razgovor danju | Day discussion | host: Vukodlak settings |
| shorter / longer | Kraće / Duže | Shorter / Longer | discussion − and + (screen reader) |
| save | Spremi | Save | host: role switches |
| rulesHeader | Pravila | Rules | host: Vukodlak settings |
| groupWolves / groupVillage / groupSolo | VUKODLACI / SELO / SAMI ZA SEBE | WEREWOLVES / VILLAGE / ALONE | roles list headings |

Also shown as received from the TV (builder-2's section): error messages and "waiting" lines such as "Sljedeća igra uskoro počinje."
Open questions for the person: keep "Curve" as the game name? "Roboti" for bots? "Domaćin" for host?

## packages/core: pack check messages (`packages/core/lib/strings.dart`, `PackStrings`)

Shown on the phone (host uploads a pack) as received from the TV. N = question number, X = image file name.

| key | Croatian | English meaning | where it shows |
|---|---|---|---|
| tooBig | Paket je veći od 5 MB. Smanji ga ili izbaci neke slike pa pokušaj ponovno. | The pack is over 5 MB. Make it smaller or drop some pictures and try again. | upload error |
| notJson | Paket nije ispravan JSON. Provjeri da je datoteka tekst (UTF-8) i da počinje znakom {. | The pack isn't valid JSON. Check it is UTF-8 text and starts with {. | upload error |
| badFormat | Nepodržan format paketa. Upiši "format": 1. | Unsupported pack format. Write "format": 1. | upload error |
| badId | Oznaka paketa smije imati samo mala slova, brojke i crtice (1 do 40 znakova). | The pack id may only have lowercase letters, digits and dashes (1 to 40 characters). | upload error |
| needTitle | Paketu treba naslov. Upiši ga u "title". | The pack needs a title. Put it in "title". | upload error |
| titleTooLong | Naslov paketa smije imati najviše 60 znakova. | The pack title may have at most 60 characters. | upload error |
| needQuestion | Paket mora imati barem jedno pitanje. | The pack must have at least one question. | upload error |
| zipNeedsJson | Zip mora na vrhu sadržavati točno jednu .json datoteku paketa. | The zip must hold exactly one pack .json file at its top level. | upload error |
| unzippedTooBig | Paket je prevelik kad se raspakira (najviše 20 MB). Smanji slike. | The pack is too big once unzipped (20 MB max). Make the pictures smaller. | upload error |
| unreadable | Paket se ne može pročitati. Provjeri da datoteka nije oštećena. | The pack can't be read. Check the file isn't damaged. | upload error |
| notObject(N) | Pitanje N: mora biti objekt s poljima q, choices i answer. | Question N: must be an object with the fields q, choices and answer. | upload error |
| emptyQuestion(N) | Pitanje N: tekst pitanja je prazan. Upiši ga u "q". | Question N: the question text is empty. Put it in "q". | upload error |
| badChoices(N) | Pitanje N: treba točno 4 odgovora i nijedan ne smije biti prazan. | Question N: needs exactly 4 answers and none may be empty. | upload error |
| badAnswer(N) | Pitanje N: "answer" mora biti 0, 1, 2 ili 3. | Question N: "answer" must be 0, 1, 2 or 3. | upload error |
| badImage(N, X) | Pitanje N: slika X mora biti relativna putanja do .svg, .jpg, .png ili .webp datoteke. | Question N: picture X must be a relative path to an .svg, .jpg, .png or .webp file. | upload error |
| missingImage(N, X) | Pitanje N: slike X nema u zipu. Dodaj je ili ukloni "image". | Question N: picture X is not in the zip. Add it or remove "image". | upload error |

Field names (`format`, `title`, `q`, `choices`, `answer`, `image`) stay English because they are keys in the JSON file.

## Vukodlak story on the TV (`apps/tv/lib/vukodlak/story_hr.dart`)

The TV reads one line at random per event, so a game doesn't repeat itself. `{name}`, `{name2}` are player names (always where the nominative fits, and no past-tense verb on a player, so any name reads right), `{role}` a role name, `{count}` a number. "Names a role = yes" lines are used only when that role is shown anyway; every "no" line is safe with hidden roles on. Event keys are drafts until the engine's list is final.

| key | when | Croatian lines | English gist | names a role |
|---|---|---|---|---|
| firstNight | start of the first night | Prva noć u selu. Nitko još ne zna tko je tko.<br>Selo prvi put tone u san. Nitko još ne zna kome vjerovati.<br>Prva noć. Mjesec gleda odozgo i šuti.<br>Počinje priča o selu i vukovima. Zatvorite oči. | The first night; nobody knows who is who yet. | no |
| nightFalls | each night begins | Pada noć nad selom. Svi zatvaraju oči i škure.<br>Sunce je zašlo iza brda. Selo tone u san.<br>Mrak se spušta na krovove. Negdje u šumi zavija vuk.<br>Lampe se gase jedna po jedna. Počinje duga noć.<br>Mjesec izlazi nad trgom. Seljani se zavlače pod pokrivače.<br>Noć je pala. Tko ima posla, neka ga obavi tiho. | Night falls over the village; everyone closes their eyes. | no |
| nightWait | while the phones make their night choices | Selo spava, a netko u mraku ipak bdije.<br>Iz šume se čuju koraci. Nitko ne viri kroz prozor.<br>Tišina. Samo sova zna što se noćas događa.<br>Psi su utihnuli. Nešto se šulja između kuća.<br>Svijeće trepere. Odluke se donose u tami. | The village sleeps, but someone is awake in the dark. | no |
| morningNoneOut | morning, nobody is out | Svanulo je. Na trgu su svi, živi i zdravi.<br>Pijetao kukuriče, a selo broji glave: nitko ne fali!<br>Jutro je mirno. Noćas vukodlaci nisu imali sreće.<br>Sunce izlazi nad selom koje je noć prebrodilo bez gubitka.<br>Seljani otvaraju vrata i odahnu: svi su na broju. | Morning; everyone is alive and well. | no |
| morningOneOut | morning, one player is out | Jutro je. Seljani nalaze zatvorena vrata: {name} više nije s nama.<br>Pijetao kukuriče, ali jedna kuća šuti. Iz nje ne izlazi {name}.<br>Svanulo je, ali ne za sve. Noć je odnijela: {name}.<br>Na pragu tragovi šapa. {name} ne dočekuje jutro s nama.<br>Gavran sjeda na krov. {name} odlazi iz igre.<br>Selo se budi tužno: {name} ispada iz igre. | Morning; {name} is no longer with us. | no |
| morningTwoOut | morning, two players are out | Teško jutro: iz igre ispadaju {name} i {name2}.<br>Dvije kuće ostaju zatvorene: {name} i {name2} ispadaju.<br>Noć je bila gladna. Odlaze {name} i {name2}.<br>Na dva krova sjede gavrani: {name} i {name2} više nisu s nama. | A hard morning: {name} and {name2} are out. | no |
| someoneProtected | morning, an attack was stopped by a protector | Vukodlaci su noćas pokucali, ali vrata su izdržala.<br>U blatu tragovi šapa, a nitko nije stradao. Netko je bdio.<br>Napad je bio, žrtve nema. Selo ima tajnog čuvara.<br>Vukovi su otišli praznih šapa. Netko je čuvao pravu kuću. | The wolves knocked, but the door held; someone kept watch. | no |
| attackSurvived | morning, the victim survived the attack on their own | Vukodlaci su ugrizli, ali žrtva je bila tvrđa od njih.<br>Netko je noćas odolio vukodlaku. Selo ne zna tko.<br>Napad u mraku, a ujutro nitko ne fali. Čudna noć!<br>Vuk je zagrizao u tvrdu koru. Svi su ujutro na nogama. | Someone withstood the werewolf tonight. | no |
| dayStarts | day discussion starts | Seljani se okupljaju na trgu. Vrijeme je za razgovor.<br>Sjednite oko zdenca i recite što ste vidjeli.<br>Dan je kratak, a sumnje duge. Raspravite!<br>Tko laže, a tko govori istinu? Selo ima malo vremena.<br>Pričajte, pitajte i gledajte se u oči. | The villagers gather on the square to talk. | no |
| voteStarts | the day vote starts | Dosta priče! Koga selo tjera iz sela?<br>Svatko neka pokaže prstom. Počinje glasanje.<br>Selo mora odlučiti. Glasajte na mobitelima.<br>Kucnuo je čas. Tko odlazi iz sela?<br>Glasanje počinje. Neka odluči većina. | Enough talk! Whom does the village send away? | no |
| voteOut | vote result, one player out | Selo je odlučilo: {name} napušta selo.<br>Većina je rekla svoje. {name} odlazi s trga.<br>Prsti su uprti u jednu kuću. {name} ispada iz igre.<br>Odluka je pala: {name} mora otići.<br>Selo zatvara jedna vrata. {name} više ne glasa s nama. | The village has decided: {name} leaves the village. | no |
| voteNone | vote result, nobody out (tie or no majority) | Glasovi su se podijelili. Danas nitko ne odlazi.<br>Selo se nije složilo. Svi ostaju, barem do noći.<br>Nema većine, nema odluke. Noć dolazi brzo.<br>Svađa bez kraja: danas nitko ne ispada.<br>Selo okleva, a vukodlaci se smiju u bradu. | The votes split; nobody leaves today. | no |
| outRevealRole | hidden roles off: the role of the player who is out | Pokazalo se: {name} je {role}.<br>Kad su se vrata zatvorila, saznalo se: {name} je {role}.<br>Tajna je otkrivena. {name} je {role}.<br>Selo sada zna: {name} je {role}. | It turned out: {name} is {role}. | yes |
| wolvesLeft | hidden roles off: werewolves still in play | Vukodlaka u selu još ima: {count}.<br>Broj vukodlaka koji se još skrivaju: {count}.<br>U selu se još skriva vukodlaka: {count}. | Werewolves still in the village: {count}. | yes |
| hunterAims | the hunter is out and picks a target | Lovac {name} podiže pušku. Koga će povući sa sobom?<br>Lovac {name} odlazi, ali prije toga nišani.<br>Tišina na trgu. Lovac {name} bira metu. | Hunter {name} raises the gun. | yes |
| hunterShot | the hunter shoots ({name} = hunter, {name2} = target) | Pucanj odjekne selom! Lovac {name} pogađa: {name2}.<br>Lovac {name} ne odlazi sam. Metak pogađa: {name2}.<br>Lovac {name} ispada, ali stigne opaliti. Pogodak: {name2}.<br>Zadnji hitac s lovačke puške. Odlazi i {name2}. | A shot! Hunter {name} hits {name2}. | yes |
| loverFollows | a lover follows the other out | Slomljeno srce ne kuca dugo. {name} odlazi za svojom ljubavi.<br>Zaljubljeni ne mogu jedno bez drugoga. Odlazi i {name}.<br>Od tuge za svojom ljubavi iz igre ispada i {name}.<br>Provodadžija ih je spojio, a sudbina rastavila. Odlazi {name}. | A broken heart: {name} follows their love. | yes |
| mayorDouble | during the vote: the mayor counts twice | Načelnik {name} ima dvostruki glas.<br>Glas načelnika broji se dvaput. Tako je od davnina.<br>Načelnik {name} glasa, a selo broji dvaput. | Mayor {name}'s vote counts twice. | yes |
| mayorBreaksTie | tie broken by the mayor | Izjednačeno! Odlučuje načelnik {name}.<br>Glasovi su jednaki, pa zadnju riječ ima načelnik {name}.<br>Vaga stoji na sredini. Načelnik {name} odlučuje kamo će pasti. | A tie! Mayor {name} decides. | yes |
| foolSpared | the village voted out the fool | Selo je izglasalo seosku budalu! {name} ostaje, ali više ne glasa.<br>{name} je seoska budala: ostaje u selu, ali bez prava glasa.<br>Smijeh na trgu: {name} je seoska budala. Ostaje, ali više ne glasa.<br>Budalu se ne tjera iz sela. {name} ostaje, bez glasa. | {name} is the village fool: stays, but no longer votes. | yes |
| winVillage | the village wins | Posljednji vukodlak je otkriven. Selo slavi uz harmoniku!<br>Nema više vukova! Seljani zvone zvonom i pale krijes.<br>Selo je pobijedilo. Večeras se pleše kolo na trgu.<br>Mir se vraća u selo. Pobjeda pripada seljanima!<br>Šuma je opet tiha. Seljani su pobijedili. | The last werewolf is found; the village celebrates. | team only |
| winWolves | the werewolves win | Vukodlaka je sada koliko i seljana. Selo pripada čoporu!<br>Zavijanje odjekuje trgom. Pobijedili su vukodlaci.<br>Selo je palo pod šape. Vukodlaci slave pod punim mjesecom.<br>Prekasno je za seljane. Čopor je pobijedio.<br>Vukovi su nadmudrili selo. Pobjeda je njihova! | The werewolves equal the villagers; the pack wins. | team only |
| winLoneWolf | the lone wolf wins | Na trgu ostaje samo vuk samotnjak {name}. Pobjeda!<br>Vuk samotnjak {name} nadmudruje i selo i čopor. Pobjeda!<br>Posljednji na nogama je vuk samotnjak: {name}.<br>Čopora više nema, a vuk samotnjak {name} slavi bez društva. | Only the lone wolf {name} is left: victory. | yes |
| winTramp | the tramp is voted out and wins | Selo je izbacilo lutalicu! {name} odlazi pjevajući i pobjeđuje.<br>Lutalica {name} dobiva što želi: put pod noge i pobjedu.<br>Izbacili ste lutalicu. Pobjeđuje {name}!<br>Pobjeda pripada lutalici: {name}. | The village threw out the tramp; {name} wins. | yes |
| endReveal | end of game, all roles shown | Igra je gotova. Evo tko se krio iza koje uloge!<br>Maske padaju! Pogledajte sve uloge.<br>Kraj priče. Sad smijete vidjeti tko je što bio.<br>Sve se otkriva: uloge svih igrača. | Game over: here is who was who. | no |
