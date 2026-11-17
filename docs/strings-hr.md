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
| vukodlakSoon | Vukodlak još nije spreman na ovom televizoru. | Vukodlak is not ready on this TV yet. | Error on the phone until Task 33 |
| homeJoin | Skeniraj i pridruži se | Scan and join | TV home, next to the QR code |
| homeJoinOr | ili otvori u pregledniku: | or open in the browser: | TV home, above the address |
| playerCount | 1 igrač / N igrača | 1 player / N players | TV home, top right |
| homeNoPlayers | Čekamo igrače | Waiting for players | TV home, top right with nobody in |
| homeNeedPlayers | Prvo se netko mora pridružiti mobitelom. | Somebody has to join with a phone first. | TV home, when OK is pressed with nobody in |
| homeKeyOk / homeHelpPlay | OK igraj | OK play | TV home help line |
| homeHelpMove | igra | game (with the left/right arrows) | TV home help line |
| homeHelpSettings | postavke | settings (with the down arrow) | TV home help line |
| homeKeyBack / homeHelpBack | Natrag izlaz | Back exit | TV home help line |
| homeMeta | 2–8 igrača · Uravnoteženo · pauza 2 s | players · mode · pause | TV home, the line under the description |
| uljezSoon | Uljez još nije spreman na ovom televizoru. | Uljez is not ready on this TV yet. | Error on the phone until Task 35 |
| wolfNight / wolfMorning / wolfDay | NOĆ 2 / JUTRO 3 / DAN 3 | NIGHT 2 / MORNING 3 / DAY 3 | Vukodlak village, small caps line above the story |
| wolfVoteHeader / wolfVoteQuestion | DAN 3 · GLASANJE / Koga selo izbacuje? | DAY 3 · VOTE / Whom does the village throw out? | Vukodlak vote screen |
| wolfVoted | Glasalo 4 od 5 | 4 of 5 have voted | Vukodlak vote screen, top right (the only count shown) |
| wolfEndHeader / wolfTeam* | KRAJ IGRE / Selo / Vukodlaci / Sam | GAME OVER / Village / Werewolves / Alone | Vukodlak end screen (all roles shown) |
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

### Uljez (phone)

| key | Croatian | English | where it shows |
|---|---|---|---|
| uljezName | Uljez | Impostor | game card, details |
| gameBlurb (Uljez) | Svi imaju istu riječ, osim uljeza. Nađi ga. | Everyone has the same word except the impostor. Find them. | game card |
| uljezRound(n) | ULJEZ · RUNDA {n} | IMPOSTOR · ROUND {n} | word card, top right |
| yourWord | TVOJA RIJEČ | YOUR WORD | word card, held |
| wordHint | Tvoja riječ se vidi samo dok držiš. | Your word shows only while you hold. | word card, hidden |
| wordNote | Netko možda ima drugu riječ. Možda i ti. | Someone may have a different word. Maybe you. | word card, held (same for everyone) |
| uljezVoteHeader | GLASANJE | VOTE | vote |
| whoIsImpostor | Tko je uljez? | Who is the impostor? | vote title |
| caught | Uhvatili su te! | They caught you! | the caught impostor's guess |
| guessHeader | POGAĐANJE | GUESSING | the guess |
| caughtHint(w) | Tvoja riječ je bila {w}. Pogodi riječ sela i ipak pobjeđuješ. | Your word was {w}. Guess the village's word and you still win. | the guess |
| uljezWinner | Selo je uhvatilo uljeza. / Uljez je pobijedio. | The village caught the impostor. / The impostor won. | end |
| villageWord / impostorWord / impostorsAre | Riječ sela / Riječ uljeza / Uljez | Village word / Impostor word / Impostor | end |
| wordPack | Paket riječi | Word pack | host settings |
| impostorCount | Broj uljeza | Number of impostors | host settings, 7-8 players |
| impostors(n) | 1 uljez / 2 uljeza | 1 impostor / 2 impostors | host settings |
| sent | Poslano | Sent | night screen button after Potvrdi (same for every role) |
| nightSpecial | Iskoristi posebnu moć (ako je imaš) | Use your special power (if you have one) | night screen switch; the same on every phone, used by few roles |
| farewellHint | Više nisi u igri. Ako imaš još jedan potez, izaberi koga povlačiš sa sobom. | You are no longer in the game. If you have one more move, pick whom you take with you. | farewell screen, same for every player who is out |
| wolfMates(names) | Drugi vukodlaci: {names} | Other werewolves: {names} | role card, werewolves only |
| wolfWinner | Selo je pobijedilo. / Vukodlaci su pobijedili. / Vuk samotnjak je pobijedio. / Lutalica je pobijedila. / Nitko nije pobijedio. | The village won. / The werewolves won. / The lone wolf won. / The tramp won. / Nobody won. | end screen |

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

The TV reads one line at random per event, so a game doesn't repeat itself. Keys are the core engine's events (the session adds those marked "session"); `gameOver` uses `gameOver` + the winner (Village, Wolves, Lone, Tramp, Nobody). `{name}`, `{name2}` are player names (always where the nominative fits, and no past-tense verb on a player, so any name reads right), `{role}` a role name, `{count}` a number. An event that may carry a role has a `…Role` twin used only when roles are shown. "Names a role = yes": the line shows a role, by its own rule or because roles are shown; every "no" line is safe with hidden roles on. A stopped attack and a quiet night share the same lines on purpose.

| key | when | Croatian lines | English gist | names a role |
|---|---|---|---|---|
| firstNight | session: start of the first night | Prva noć u selu. Nitko još ne zna tko je tko.<br>Selo prvi put tone u san. Nitko još ne zna kome vjerovati.<br>Prva noć. Mjesec gleda odozgo i šuti.<br>Počinje priča o selu i vukovima. Zatvorite oči. | The first night; nobody knows who is who yet. | no |
| nightFalls | session: each night begins | Pada noć nad selom. Svi zatvaraju oči i škure.<br>Sunce je zašlo iza brda. Selo tone u san.<br>Mrak se spušta na krovove. Negdje u šumi zavija vuk.<br>Lampe se gase jedna po jedna. Počinje duga noć.<br>Mjesec izlazi nad trgom. Seljani se zavlače pod pokrivače.<br>Noć je pala. Tko ima posla, neka ga obavi tiho. | Night falls over the village; everyone closes their eyes. | no |
| morningNobody | morning, nobody out (also after a stopped attack) | Svanulo je. Na trgu su svi, živi i zdravi.<br>Pijetao kukuriče, a selo broji glave: nitko ne fali!<br>Mirno jutro. Dim se diže iz svih dimnjaka.<br>Sunce izlazi nad selom koje je noć prebrodilo bez gubitka.<br>Seljani otvaraju vrata i odahnu: svi su na broju. | Morning; everyone is alive and well. | no |
| morningDied | morning, a player is out (one event per player) | Jutro je. Seljani nalaze zatvorena vrata: {name} više nije s nama.<br>Pijetao kukuriče, ali jedna kuća šuti. Iz nje ne izlazi {name}.<br>Svanulo je, ali ne za sve. Noć je odnijela: {name}.<br>Na pragu tragovi šapa. {name} ne dočekuje jutro s nama.<br>Gavran sjeda na krov. {name} odlazi iz igre.<br>Selo se budi tužno: {name} ispada iz igre. | Morning; {name} is no longer with us. | no |
| morningDiedRole | same, roles shown | Jutro je, a {name} više nije s nama. Uloga: {role}.<br>Noć je odnijela: {name}. Bila je to uloga: {role}.<br>Gavran sjeda na krov. {name} odlazi, a uloga je bila: {role}.<br>Selo se budi tužno: {name} ispada. Uloga: {role}. | Morning; {name} is out. Role: {role}. | yes |
| loverDied | a lover follows the other out | Slomljeno srce ne kuca dugo. {name} odlazi za svojom ljubavi.<br>Zaljubljeni ne mogu jedno bez drugoga. Odlazi i {name}.<br>Od tuge za svojom ljubavi iz igre ispada i {name}.<br>Dvije kuće, jedno srce. Odlazi i {name}. | A broken heart: {name} follows their love. | no |
| loverDiedRole | same, roles shown | Slomljeno srce ne kuca dugo. Odlazi i {name}. Uloga: {role}.<br>Zaljubljeni ne mogu jedno bez drugoga. Odlazi {name}, uloga: {role}.<br>Od tuge ispada i {name}. Bila je to uloga: {role}. | A broken heart: {name} goes too. Role: {role}. | yes |
| playerLeft | a player left or was removed by the host | {name} napušta selo i odlazi svojim putem.<br>Jedna kuća ostaje prazna: {name} više ne igra.<br>Put zove: {name} izlazi iz igre.<br>{name} odlazi iz sela. Igra ide dalje. | {name} leaves the village; the game goes on. | no |
| playerLeftRole | same, roles shown | {name} napušta selo. Uloga: {role}.<br>Jedna kuća ostaje prazna: {name} više ne igra. Uloga: {role}.<br>{name} odlazi svojim putem. Bila je to uloga: {role}. | {name} leaves. Role: {role}. | yes |
| dayStarts | session: day discussion starts | Seljani se okupljaju na trgu. Vrijeme je za razgovor.<br>Sjednite oko zdenca i recite što ste vidjeli.<br>Dan je kratak, a sumnje duge. Raspravite!<br>Tko laže, a tko govori istinu? Selo ima malo vremena.<br>Pričajte, pitajte i gledajte se u oči. | The villagers gather on the square to talk. | no |
| voteStarts | session: the day vote starts | Dosta priče! Koga selo tjera iz sela?<br>Svatko neka pokaže prstom. Počinje glasanje.<br>Selo mora odlučiti. Glasajte na mobitelima.<br>Kucnuo je čas. Tko odlazi iz sela?<br>Glasanje počinje. Neka odluči većina. | Enough talk! Whom does the village send away? | no |
| voteOut | vote result, one player out | Selo je odlučilo: {name} napušta selo.<br>Većina je rekla svoje. {name} odlazi s trga.<br>Prsti su uprti u jednu kuću. {name} ispada iz igre.<br>Odluka je pala: {name} mora otići.<br>Selo zatvara jedna vrata. {name} više ne glasa s nama. | The village has decided: {name} leaves the village. | no |
| voteOutRole | same, roles shown | Selo je odlučilo: {name} odlazi. Uloga: {role}.<br>Odluka je pala: {name} mora otići. Bila je to uloga: {role}.<br>Većina je rekla svoje. {name} odlazi, a uloga je bila: {role}.<br>Selo zatvara jedna vrata: {name}. Uloga: {role}. | The village has decided: {name} leaves. Role: {role}. | yes |
| voteTie | vote result, a tie | Glasovi su se podijelili napola. Danas nitko ne odlazi.<br>Izjednačeno! Selo se ne može odlučiti, pa svi ostaju.<br>Vaga stoji na sredini. Nitko ne ispada, barem do noći.<br>Neriješeno. Vukodlaci se smiju u bradu. | A tie; nobody leaves today. | no |
| voteNobody | vote result, no votes (all skipped) | Nitko ne diže ruku. Danas nitko ne odlazi.<br>Selo šuti i ne odlučuje. Svi ostaju do noći.<br>Glasova je premalo. Danas nitko ne ispada.<br>Seljani preskaču glasanje. Noć dolazi brzo. | Nobody raises a hand; nobody leaves today. | no |
| hunterShot | the hunter shoots ({name} = hunter, {name2} = target) | Pucanj odjekne selom! Lovac {name} pogađa: {name2}.<br>Lovac {name} ne odlazi sam. Metak pogađa: {name2}.<br>Lovac {name} ispada, ali stigne opaliti. Pogodak: {name2}.<br>Zadnji hitac s lovačke puške. Odlazi i {name2}. | A shot! Hunter {name} hits {name2}. | yes |
| hunterShotRole | same, roles shown ({role} = the target's) | Pucanj odjekne selom! Lovac {name} pogađa: {name2}. Uloga: {role}.<br>Metak lovca pogađa: {name2}. Bila je to uloga: {role}.<br>Lovac {name} stigne opaliti. Pogodak: {name2}, uloga: {role}. | Hunter {name} hits {name2}. Role: {role}. | yes |
| foolSpared | the village voted out the fool | Selo je izglasalo seosku budalu! {name} ostaje, ali više ne glasa.<br>{name} je seoska budala: ostaje u selu, ali bez prava glasa.<br>Smijeh na trgu: {name} je seoska budala. Ostaje, ali više ne glasa.<br>Budalu se ne tjera iz sela. {name} ostaje, bez glasa. | {name} is the village fool: stays, but no longer votes. | yes |
| trampWins | the village voted out the tramp | Selo je izbacilo lutalicu! {name} odlazi pjevajući.<br>Lutalica {name} dobiva baš ono što želi.<br>Pogrešna kuća! {name} je lutalica.<br>Lutalica {name} maše selu s ceste. | The village threw out the tramp, {name}. | yes |
| wolvesLeft | session: werewolves still in play (roles shown) | Vukodlaka u selu još ima: {count}.<br>Broj vukodlaka koji se još skrivaju: {count}.<br>U selu se još skriva vukodlaka: {count}. | Werewolves still in the village: {count}. | yes |
| gameOverVillage | game over, the village wins | Posljednji vukodlak je otkriven. Selo slavi uz harmoniku!<br>Nema više vukova! Seljani zvone zvonom i pale krijes.<br>Selo je pobijedilo. Večeras se pleše kolo na trgu.<br>Mir se vraća u selo. Pobjeda pripada seljanima!<br>Šuma je opet tiha. Seljani su pobijedili. | The last werewolf is found; the village celebrates. | team only |
| gameOverWolves | game over, the werewolves win | Vukodlaka je sada koliko i seljana. Selo pripada čoporu!<br>Zavijanje odjekuje trgom. Pobijedili su vukodlaci.<br>Selo je palo pod šape. Vukodlaci slave pod punim mjesecom.<br>Prekasno je za seljane. Čopor je pobijedio.<br>Vukovi su nadmudrili selo. Pobjeda je njihova! | The werewolves equal the villagers; the pack wins. | team only |
| gameOverLone | game over, the lone wolf wins | Na trgu ostaje samo vuk samotnjak. Pobjeda je samo njegova.<br>Vuk samotnjak nadmudrio je i selo i čopor!<br>Čopora više nema. Vuk samotnjak slavi sam.<br>Posljednji je ostao vuk samotnjak. Pobjeda! | Only the lone wolf is left: victory. | yes |
| gameOverTramp | game over, the tramp wins | Lutalica je dobila što je htjela: put pod noge i pobjedu.<br>Selo je izbacilo lutalicu, a lutalica pobjeđuje!<br>Pobjeda pripada lutalici. Selo je nasjelo. | The tramp got what they wanted: the road and the win. | yes |
| gameOverNobody | game over, nobody is left | U selu nema više nikoga. Ova priča nema pobjednika.<br>Prazan trg i tihe kuće. Nitko ne slavi.<br>Ni seljana ni vukova. Samo gavrani ostaju na krovovima. | Nobody is left; this story has no winner. | team only |
| endReveal | session: end of game, all roles shown | Igra je gotova. Evo tko se krio iza koje uloge!<br>Maske padaju! Pogledajte sve uloge.<br>Kraj priče. Sad smijete vidjeti tko je što bio.<br>Sve se otkriva: uloge svih igrača. | Game over: here is who was who. | no |
