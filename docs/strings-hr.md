# CouchPlay: the Croatian interface, for review

Every text the TV and the phones show, in Croatian, with its English meaning and where it appears. Please correct any wording directly in the Croatian column (or note it beside the row); the engineers apply your corrections to the strings files.

Choices to confirm:
- informal "ti" everywhere
- bots are "Robot 1", "Robot 2", …
- the lobby is "početni zaslon"; Quit is "Izađi"
- the badge for a player who dropped off is "NEMA VEZE" (gender-neutral)
- places are written "1.", "2.", …

## TV (apps/tv/lib/strings.dart)

`{…}` marks a value filled in at run time. Ti-form throughout. "početni zaslon" is the lobby (the screen with the QR code).

| key | Croatian | English meaning | where it shows |
|---|---|---|---|
| noWifi | Spoji TV na Wi-Fi da možemo igrati. | Connect the TV to Wi-Fi so we can play. | TV lobby, in place of the QR code when the TV has no network |
| scanToJoin | Skeniraj kod mobitelom i pridruži se. | Scan the code with your phone and join. | TV lobby, right side, while nobody has joined |
| scanCaption | Skeniraj ili otvori u pregledniku: | Scan, or open in your browser: | TV lobby, under the QR code (the address follows) |
| players({n}) | Igrači · {n} od 8 | Players · {n} of 8 | TV lobby, above the player chips |
| badgeHost | DOMAĆIN | HOST | TV lobby, pill on the host's chip |
| badgeBot | ROBOT | BOT | TV lobby, pill on a bot's chip |
| badgeAway | NEMA VEZE | NO CONNECTION (player's phone is away) | TV lobby, pill on a chip whose phone lost the connection |
| scoreboard | Bodovi | Scores | TV lobby, scoreboard card heading |
| scoreboardEmpty | Bodovi se pojavljuju nakon prve igre. | Scores appear after the first game. | TV lobby, scoreboard card before any game was played |
| waitingForHost({name}) | Čekamo da {name} odabere igru. | Waiting for {name} to pick a game. | TV lobby, bottom right |
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
| nextGameSoon | Sljedeća igra uskoro počinje. | The next game starts soon. | Phone waiting screen for someone who joined mid-game |
| gameRunning | Igra je već u tijeku. | A game is already running. | Error on the phone |
| quizNotReady | Kviz još nije spreman. Za sada odaberi Curve. | The quiz is not ready yet. Pick Curve for now. | Error on the phone |
| packUnavailable | Taj paket nije dostupan. | That pack is not available. | Error on the phone (quiz pack missing) |
| curveNeedsTwo | Za Curve trebaju barem 2 igrača. Dodaj robota ili pozovi prijatelja. | Curve needs at least 2 players. Add a bot or invite a friend. | Error on the phone |
| noSuchPlayer | Tog igrača nema. | That player is not here. | Error on the phone (kick) |
| cannotKickSelf | Ne možeš izbaciti sam sebe. | You can't kick yourself. | Error on the phone (kick) |
| botsBetweenGames | Robote možeš mijenjati samo između igara. | You can change the bots only between games. | Error on the phone |
| lockedIn | Odgovor je zaključan. Gledaj TV. | Your answer is locked in. Watch the TV. | Phone, after answering a quiz question |
| onlyHostAddsPacks | Samo domaćin može dodavati pakete. | Only the host can add packs. | Message on the phone after a pack upload |
| packsNotReady | Paketi još nisu dostupni. | Packs are not available yet. | Message on the phone after a pack upload |
| packAdded({title}, {n}) | Dodano: {title} ({n} pitanje/pitanja). | Added: {title} ({n} questions). 1 and 21 take "pitanje", other numbers "pitanja". | Message on the phone after a successful pack upload |
| packTooBig | Paket je veći od 5 MB. | The pack is bigger than 5 MB. | Message on the phone after a pack upload |
| builtInPackId({id}) | Ugrađeni paket već koristi oznaku '{id}'. Odaberi drugu oznaku. | A built-in pack already uses the id '{id}'. Pick another id. | Message on the phone after a pack upload |
| packSaveFailed | TV nije mogao spremiti paket. Oslobodi malo mjesta na TV-u pa pokušaj ponovo. | The TV could not save the pack. Free some space on the TV, then try again. | Message on the phone after a pack upload |
| startFailed({error}) | Pokretanje nije uspjelo: {error} | Could not start: {error} | TV, full-screen error if the app cannot start |

Not translated on purpose: "CouchPlay" (the app name), "Curve" (the game's name), player names, quiz pack titles and questions (written in the packs).

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
| removed | Uklonjen si iz igre. | You were removed from the game. | screen after the host removes you |
| ok | U redu | OK | closes a red error bar |
| waitingForHost | Čekaš da {host} pokrene igru. (fallback: domaćin) | You are waiting for {host} to start the game. | lobby, for non-hosts |
| hostBadge | ★ DOMAĆIN | HOST | badge on your chip |
| pickGame | Odaberi igru | Pick a game | lobby, host only |
| quiz | Kviz | Quiz | lobby button |
| curve | Curve | Curve (game name, not translated) | lobby button |
| quizPack | Paket pitanja | Quiz pack | lobby, label of the pack list |
| addPack | Dodaj paket pitanja… | Add quiz pack… | lobby button, host only |
| bots | Roboti | Bots | lobby, stepper label |
| fewerBots | Manje robota | Fewer bots | accessibility label of the − button |
| moreBots | Više robota | More bots | accessibility label of the + button |
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
| crashed | Zabio si se. Pričekaj sljedeću rundu. | You crashed. Wait for the next round. | Curve, after you crash |
| rtt | rtt 20ms · p95 40ms · n=300 | (technical readout, not for players) | Curve, tiny top-right text |
| gameOver | Igra je gotova. | The game is over. | results, if you had no placement |
| placed | Završio si na {n}. mjestu | You finished in {n}th place | results |
| sessionPoints | +{n} bod / boda / bodova za ovu večer | +{n} points for this evening | results |

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
| badImage(N, X) | Pitanje N: slika X mora biti relativna putanja do .svg datoteke. | Question N: picture X must be a relative path to an .svg file. | upload error |
| missingImage(N, X) | Pitanje N: slike X nema u zipu. Dodaj je ili ukloni "image". | Question N: picture X is not in the zip. Add it or remove "image". | upload error |

Field names (`format`, `title`, `q`, `choices`, `answer`, `image`) stay English because they are keys in the JSON file.
