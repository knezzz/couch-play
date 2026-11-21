# Couchplay — design

Working name. Date: 2026-11-13.

## Intent

A party-games console for the living room. An Android TV shows the game; everyone's phone is the controller. Friends join in seconds by scanning a QR code — nothing to install, no accounts. Built for the owner and their friends, not for store publishing.

## Goals (v1)

- Android TV app that hosts a lobby and three games: **Quiz**, **Curve** (Tron / Curve Fever style) **Vukodlak** (a werewolf-style social deduction game, added 2026-11-17) and **Uljez** (a hidden-word game, added 2026-11-17); plus **Objasni**, **Koliko?**, **Blef** and **Tko bi?**, specified in `2026-11-17-party-games-design.md` (approved 2026-11-17).
- Phones join by scanning a QR code on the TV and get a browser controller (Flutter Web) served by the TV itself.
- One Dart codebase: TV app, controller, and a shared package for protocol, theme, and visual effects, so the same effects (particles, color flashes, animations) can play on TV and phone.
- Quiz question packs in a simple, documented file format; ships with packs written by Claude, some with simple vector pictures (flags, shapes).

## Non-goals (v1)

- Remote / internet play. Tailcat was evaluated and rejected: Go-only with no mobile story, no API stability, rate-limited free relays with no SLA. Later option: remote players watch via Discord/FaceTime screen share. Nothing in v1 should block that, but nothing is built for it.
- Tilt / motion controls. Browsers only expose motion sensors on HTTPS, and the controller is served over plain HTTP from the LAN. Later: an optional native app build of the same controller code (Flutter iOS/Android) for tilt; browser players get a touch fallback.
- Haptics (not available in iOS Safari).
- Accounts, saved stats, store publishing, AI-generated content, other mini-games beyond those listed in Goals.

## Anti-goals

- Joining takes more than ~10 seconds or needs an install.
- Curve feels laggy: input-to-screen delay noticeable on home Wi-Fi.
- Adding a question pack requires rebuilding the app.

## Constraints

- Android TV: the target device model is unknown, and TVs with Android TV built in often have slow chips. So the first build step is a quick Curve performance test on the real TV: 8 trails at 60 Hz, with input-to-screen delay measured from a phone. Everything else waits on that test. If the TV can't keep up, reduce the rendering cost (for example, draw trails to a cached image) before building more. Menus must be usable with a D-pad remote, though phones drive most interaction. The TV stays awake while the app is open: phones drive the game, so the TV sees no remote input and must not go to its screensaver (user report, 2026-11-14).
- Phones: current iOS Safari and Android Chrome, plain HTTP on the LAN.
- Same Wi-Fi network for TV and phones.
- Flutter is not installed on the dev Mac yet; setup is part of the plan.
- Up to 8 players.

## Approaches considered

1. **Thin Android TV shell + web games (JS).** One language, fast iteration; weaker TV polish. Not chosen.
2. **Native Kotlin TV app.** Best performance, but every game written twice in two languages. Not chosen.
3. **Godot on TV.** Real engine, heavy toolchain, overkill for 2D party games. Not chosen.
4. **All Flutter (chosen by the user).** TV app in Flutter + Flame; controller in Flutter Web; shared Dart package. Chosen so effects and code are shared everywhere. Accepted cost: Flutter Web's first load on a phone is a few MB (fine over LAN, ~1–2 s).

## Design

### Pieces

- `packages/core` — shared Dart: protocol message types (JSON), player colors/theme, shared effect widgets, quiz pack model + parser.
- `apps/tv` — Flutter app for Android TV (also runs as a macOS app for development). Contains:
  - an HTTP + WebSocket server built on `dart:io` (no extra packages), serving the controller's web build from bundled assets and the `/ws` socket;
  - the lobby, Quiz, and Curve (Curve rendered with Flame).
- `apps/controller` — Flutter Web app. Its build output is copied into the TV app's assets at build time (a build script does this).

### Joining

1. TV starts the server on a fixed port (8080, falls back to next free) and finds its LAN IPv4 via `NetworkInterface.list()`.
2. TV shows a QR code for `http://<ip>:<port>/` and the URL in text.
3. Phone loads the controller, enters a name, is assigned a color, connects to `ws://<ip>:<port>/ws`.
4. The first player to join is the **host**: picks games, starts rounds, can kick players. If the host leaves, the next-oldest player becomes host. The game in progress keeps going: a host leaving never stops or ends it (user request, 2026-11-15).
5. **Characters (user request, 2026-11-16):** each player picks a character: one of about 16 simple, bold animal faces
   drawn for CouchPlay (SVG), tinted in the player's color. One per player; taken ones are greyed out. Picked on the
   join screen (a random free one is preselected) and changeable in the lobby. The TV shows the character next to the
   player's name everywhere it shows players: lobby, quiz scores and reveal, results, session board, and the Curve
   countdown. Bots get a free character too.
6. Reconnect: the controller keeps a random player token in `localStorage`; reconnecting with the same token restores the player (name, color, score) if within the session.

### Session flow

Home (one game full screen, QR, players, the "Večeras" strip) → host picks a game (Quiz, Curve, Vukodlak, Uljez) → game → results screen → back to the home with the evening's totals updated.

**Picking a game (user request, 2026-11-16):** the host's phone shows the games as a swipeable carousel of cards. Tapping a card opens its details: a short description and that game's settings (Quiz: pack, time per question, questions per game, time between questions; Curve: mode, pause before each round). While the host is on the details, the TV lobby shows the same game and its settings, so the room sees what's coming. A "Igraj" button on the details starts the game; Back returns to the carousel and the TV goes back to the plain lobby. Other phones see which game the host is looking at. Scores persist for the session only.

- **Session scoreboard (Claude's call):** each game's raw points stay inside that game. After a game, players get placement points for the session board: 1st = N−1, 2nd = N−2, … last = 0 (N = players in that game), so all games count equally. If everyone scored 0 in a game, everyone gets 0 placement points. (User choices, 2026-11-17; was 1st = N … last = 1.)
- **Back on the results screen (user choice, 2026-11-17):** closes the results and moves on: to the next round or game, or to the home screen when the game is over.
- **D-pad scope (Claude's call):** the remote only needs to move focus and quit/back out of a game. A phone host runs the session; there is no phone-free mode in v1.
- **Joining and leaving mid-game (Claude's call):** late joiners watch on their phone (“next game starts soon”) and enter at the next lobby. A Curve player who disconnects crashes on the spot; the win target stays fixed at the value set when the match began. A Quiz player who disconnects scores 0 for the questions they miss and keeps their points; reconnecting within the session restores them mid-game. Anyone who drops out mid-game, the host included, can come back into the same game: Quiz from the next question, Curve from the next round of the match, with what they missed scoring 0 and their earlier points kept. The host role stays with whoever has it during the game (user request, 2026-11-15). If a 2-player Curve match drops to one player, the match pauses and the TV shows "Čekamo da se <ime> vrati" for up to 30 s; it carries on if they come back and ends if they don't. A 2-player Quiz keeps going with the one player left (user answer, 2026-11-15). A 2-player Curve match that ends this way keeps its scores as they are, ties included (user answer, 2026-11-15). When nobody is connected, a game (Quiz or Curve) also waits 30 s, paused, with "Čekamo da se igrači vrate" on the TV, and ends only if nobody comes back (PM call within the user's request that games don't stop when people leave, 2026-11-15).

### Networking model

- The TV is authoritative for all game state. Phones only send input and render what the TV tells them.
- JSON messages over one WebSocket per phone, with a `type` field. Message types live in `packages/core`.
- Curve input is sent as state changes (`left down`, `left up`, …), not per frame, so traffic is tiny.

### Quiz

- Question on TV (text, optional picture); phone shows the answer buttons, color/shape-coded to match the TV. After a tap the phone hides the pick: it shows one neutral "Locked in" screen that looks the same whatever was chosen, so nobody nearby can copy it (user request, 2026-11-14).
- 4 choices, 20 s timer (default; see host settings below). Points: correct answers score 500–1000, scaled by how fast; wrong or no answer = 0.
- After each question: reveal the correct answer, show who picked what, update the scoreboard. Round = 10 questions from the chosen packs, shuffled.
- **Host settings (user request, 2026-11-16):** in the lobby the host can set the time per question, the number of questions per game, the time between questions (the reveal), and the pause before each Curve round. The TV remembers them across restarts and applies them from the next game.
- **Pack format:** one JSON file per pack:
  ```json
  {
    "format": 1,
    "id": "world-flags",
    "title": "World Flags",
    "questions": [
      {
        "q": "Which country's flag is this?",
        "image": "flags/japan.svg",
        "choices": ["Japan", "Bangladesh", "Palau", "South Korea"],
        "answer": 0
      }
    ]
  }
  ```
  `image` is optional, relative to the pack. A pack with images is a `.zip` of the JSON plus its SVGs; a text-only pack can be a bare `.json`.
- **Bundled packs** (written by Claude): roughly 6 packs, ~300 questions total, e.g. general knowledge, geography, science, film/music, flags (SVG), shapes/logic (SVG). Pictures are simple hand-made vectors (SVG rendered with `flutter_svg`).
- **Croatian packs** (user request, added after approval): four packs written in Croatian, also by Claude:
  - Međimurje (the focus): places, kajkavian words, food, customs and famous people
  - Croatian geography
  - Croatian history
  - Croatian culture and sport

  The app interface is in Croatian (changed 2026-11-14 at the user's request; it was English). Every bundled English pack also gets a Croatian version (same pictures for flags and shapes), and the Croatian packs aim at locals: verified facts, harder questions (user request, 2026-11-14). Local Međimurje facts are the hardest to verify, so the user reviews that pack before it's considered done. (Reviewed 2026-11-17: approved; dialect-word questions must not name the village, and only words a local would have to think about, no simple ones.)

  **Croatian packs only, and bigger (user request, 2026-11-15):** for now the TV ships only the Croatian packs; the English packs stay in `tool/packs/` but are not bundled. Every Croatian pack grows as far as verified questions can be found (Opće znanje most of all). Existing Croatian pub-quiz and Potjera material guides the topics, style and difficulty; question text is copied only where its licence allows it (the repo is public), otherwise the questions are our own wording of verified facts.

  **More packs and more pictures (user request, 2026-11-16):** new Croatian packs Umjetnost, Psihologija, Ljudsko tijelo,
  Memeovi, Fizika and Matematika, each a choice in the pack list; and more picture questions across the packs. Memes
  are mostly copyrighted images, so the Memeovi pack asks about memes in text (origin, catchphrase, year) and shows a
  picture only where the image is freely licensed.

  **Photo questions (user request, 2026-11-15):** questions like "Koji je ovo grad?" with a photo, and other picture questions (landmarks, places, people, things). The pack format accepts photos (JPEG, PNG or WebP) as well as SVG. Photos come only from freely licensed sources (e.g. Wikimedia Commons); the pack's `.sources.md` credits the author and licence of each one. On a picture question the TV gives the picture as much of the screen as it can, uncropped.
- **Packs are multi-select in every game (user request, 2026-11-18):** wherever the host picks a pack (Quiz, Uljez,
  Objasni, Koliko?, Blef, Tko bi?), the details screen shows every pack as a checklist, and **all packs are
  selected by default**, uploaded packs included. The game draws from all selected packs together, with no repeats in
  one game. At least one pack stays selected (the last one can't be unticked). The selection is remembered like the
  other host settings; a pack that appears later (new build or upload) starts selected. The TV lobby shows the
  selection ("Svi paketi" or the count).
**Adding packs without rebuilding:** the host can upload a pack file from the controller. The TV validates it and stores it in app storage, so it's there next time. Invalid packs are rejected with a readable error.

### Curve

- Each player is a continuously moving line with their color; steering is left/right only (two big buttons on the phone, hold to turn).
- Lines leave trails with short random gaps (you can slip through gaps). Hitting any trail or the wall kills you,
  including your own older trail (only the bit you just drew is safe).
- During the countdown before each round, every player shows as a dot in their color with their name above it, so
  people can find themselves. The names go away when the round starts; the dot stays as the line's head.
  (User request, 2026-11-14.) A short arrow from each dot shows the direction that line will start in.
  (User request, 2026-11-14.)
- **Bots (user request, 2026-11-14):** the phone host can add and remove bots in the lobby, so a small group gets a
  fuller board. Bots play Curve only, count toward the 8-player limit, get the next free color and a name like
  "Robot 1", and score like players: they take part in placement points and appear on the session scoreboard. Bot
  skill: look ahead and steer away from trails and walls, and sometimes go for a nearby power-up. They must stay
  cheap enough to run 7 of them at 60 Hz on the TV.
- Last one alive scores; every other surviving-longer player also gets points (points = number of players you outlived). First to `10 × (players − 1)` wins, as in Curve Fever.
- Simulation runs on the TV at a fixed 60 Hz tick; collision against a trail occupancy grid.
- **Power-ups (user request, 2026-11-14, replaces "no power-ups in v1"):** icons appear on the board from time to
  time; the first line to drive over one triggers it for a few seconds. Kinds (the list below is current):
  - on you: speed up, slow down, ghost (pass through trails, not walls; leaves no line while it lasts), cheese (your
    line gets many holes)
  - on everyone else: speed up, slow down, fat line (stacks: each pickup makes the lines fatter), reversed steering (left and right
    swap), square turns (they can only turn in 90° steps)

  (Changed 2026-11-17, user request: speed up and slow down each exist twice, one on you (green) and one on everyone
  else (red); cheese and square turns added. Earlier, 2026-11-16: slow down was yours and speed up hit everyone else; the fat line lasts a
  little longer than the other effects and stacks; ghost leaves no line; thin line removed, reversed steering added.)
  - on everyone: clear all trails, wrap (go through walls and come out the opposite side)

  Effects stack by restarting their timer. Exact timings, spawn rate and icons are left to the builder. The TV
  draws them; phones need nothing new.
- **Power-up look (user choice, 2026-11-17):** icons are version A on the canvas page "Curve pojačanja"
  (`PuIcons.dc.html`): snail (slow), ghost, lightning (speed others), thin-over-thick line (fat), opposite arrows
  (reverse), broom (clear), arrow through the edge (wrap), drawn in ink on the green/red/blue disc. Active effects on a
  player are option 1 (`PuActive.dc.html`): no icon, one ring per active effect around the head in its color, draining
  as time runs out; several effects are concentric rings. Wrap keeps the shrinking white border.
- **After each round** the TV shows the current scores (faces, points, the target) for a few seconds before the next
  countdown; no score bar during play (user choice, 2026-11-17).
- **Power-up legend:** ▼ on the Curve card on the home (and the host's Curve details on the phone) lists every power-up
  with its icon and one line on what it does (user choice, 2026-11-17).
- **Curve modes (user request, 2026-11-16):** the host picks a mode in the lobby settings:
  - Kaos: power-ups spawn often, many on the board at once
  - Uravnoteženo: today's rate (the default)
  - Mirno: no power-ups
  - Samo za tebe: only the power-ups that act on the picker (green: speed up, slow down, ghost, cheese)
- **Active power-ups are obvious (user request, 2026-11-14):** while an effect runs, the TV shows who has it and how
  long it has left. Wrap: a white border runs around the arena and shrinks as wrap runs out; when the border is
  gone, the walls are back. Effects on players: the power-up's icon, in its green/red/blue color, next to each
  affected line's head, with a ring that drains as the time runs out. Clear is instant and needs no timer. The Curve
  screen uses the reference-screen tokens below.

### Console redesign (user request, 2026-11-17)

Reference: the design canvas, page "Konzola i Vukodlak" (copy in `docs/design/couchplay-screens/V2*.dc.html`,
`Village.dc.html`, `WolfRoles.dc.html`).

- **Home:** after the first game a small "Večeras" strip along the bottom shows the evening's totals (user choice,
  2026-11-17). One game fills the screen with its own background art; its title is big in the middle with a one-line
  description and its current settings; the previous and next games just show at the left and right edges. ◀ ▶ changes
  game, OK plays, ▼ opens its settings, Back exits. The QR code and the join address sit in the top-left corner; the
  players' characters top right. The remote and the host's phone drive the same choice. Replaces the lobby layout.
- **Games full screen:** no frame or side panels; the quiz uses the whole screen.
- **Quiz ticker:** a 20-segment bar along the top edge loses one segment per second (red for the last 5), and the TV
  ticks for the whole question; in the last 5 s the ticking speeds up clearly (about twice as fast, then faster) and
  gets more intense (louder, higher, a heartbeat-like accent), ending on the time-up sound (user request, 2026-11-17). Only the bar: no ring countdown (user choice, 2026-11-17).

### Vukodlak (user request, 2026-11-17)

A werewolf-style social deduction game for 5–8 people (no bots). The TV tells the story; roles and actions are on
the phones. Folk-game roles in our own words; no names or roles from Town of Salem or other products.

- **TV:** the village: each player's house in a circle around the square, with their character and name; the story
  and the clock in the square. Night: dark, lit windows; morning: daylight. A player who is out: their house closes up
  (boarded, grey), with blood around it and a crow. Light animation: chimney smoke, flickering windows, stars,
  fireflies, drifting clouds, swaying trees (off with reduced motion). The day vote shows only how many have voted and then who is out; nobody sees who voted for whom or any count, so
  the Načelnik's double vote stays secret. Each phone shows only its own vote (user answer, 2026-11-17).
- **Phones:** the role is hidden by default and shows only while a finger is on the screen. At night every phone
  looks the same (grey, same layout, same button) whatever the role; only a short grey line of text differs. Everyone
  has a night task: roles with no night action get a simple sum (e.g. 7 × 8, as many answers as players still in, so the list is the same length as everyone else's) in the same grey list, so
  every phone looks busy (user request, 2026-11-17). On the TV only the houses of players who have not finished their
  task yet are lit; when a player finishes, their light goes out, but no light goes out in the first 15 s of the night, so the
  order does not give roles away (user answer, 2026-11-17). Day vote on the phones.
- **Roles (14):** Vukodlak, Vođa čopora, Vuk samotnjak; Seljanin, Vidovnjakinja, Ljekarnik, Tjelohranitelj, Travarica,
  Lovac, Starješina, Načelnik, Provodadžija, Seoska budala; Lutalica (descriptions in `WolfRoles.dc.html`).
- **Host settings:** switch on the possible roles (Vukodlak and Seljanin always on); the game draws the mix each game:
  1 werewolf for 5–6 players, 2 for 7–8; up to (players − werewolves − 2) special roles at random from those switched
  on; the rest Seljani; Vođa čopora / Vuk samotnjak may replace an ordinary werewolf. "Skrivene uloge" (on by default):
  a player who is out is not revealed; all roles are shown at the end.
- **No fixed timers (user request, 2026-11-18):** the day discussion has no clock: every living player's phone has an
  **Idemo glasati** toggle (can be undone), the TV shows how many want to vote, and the vote starts when more than half
  of the living players want it (connected or not; user answer, 2026-11-18). The day vote ends when every living player has voted (the host's kick moves on without someone who left); the night
  ends when every task is done (the 15 s minimum before lights go out stays: it hides roles, it is not a deadline).
  No day-discussion-time setting. Short TV story animations keep their own pace.
- **Players see every possible role** (all switched on, not only those drawn) and what each does, on a phone screen.
- **Rule choices (user answers, 2026-11-17):** Travarica cures by guessing whom to save (she is not shown the
  victim; one night step for everyone). Provodadžija picks two other players as the lovers on night 1, so night 1 has
  two picks on every phone (the others get a second dummy pick). Vuk samotnjak wins only as the last one alive;
  Lutalica wins alone when voted out. The other rule readings are build-core's (qitem-20261117093430-e04f231f).
- Win: the village when no werewolves are left; the werewolves when they equal the rest; solo roles as described.

### Uljez (user request, 2026-11-17)

A hidden-word party game in the "odd one out" genre, our own name and words. Reference: canvas page "Uljez"
(`UljezTv.dc.html`, `UljezPhone.dc.html`).

- 3–8 people, no bots. Everyone gets the same word (e.g. "Spužva Bob"); the impostor gets a similar word ("Pikachu")
  and does not know they are the impostor. 1 impostor for 3–6 players; for 7–8 the host picks 1 or 2.
- The word shows on the phone only while a finger is on the screen (as in Vukodlak).
- Clues: in turn, each player says one clue out loud; the TV shows whose turn it is (players around a table). **No
  timers** (user request, 2026-11-18): the speaker taps **Dao sam trag** on their phone and the turn passes; a speaker
  who has left is skipped only after the host kicks them. Clue rounds repeat. From the end of round 1, every phone has an **Idemo glasati** toggle
  (can be undone) and the TV shows how many want to vote; when more than half of the players still in the game want to vote (locked phones still count; user answer, 2026-11-18),
  the clues end and the vote on the phones starts. There is no separate timed discussion and no discussion-time
  setting: people talk during the rounds. The vote ends when everyone still in the game has voted; to go on without someone, the host kicks them.
- A caught impostor guesses the village's word from 4 options on their phone, with no timer; a right guess still wins.
- Village wins by catching the impostor; the impostor by surviving the vote or guessing. Placement points as usual.
- Word pairs in packs by theme (cartoons, food, animals, places, famous people…); the host picks the packs (multi-select, all by default). Croatian.

### Sound (user request, 2026-11-16)

The TV plays short sound effects from its speakers: Curve countdown, power-up pickup, crash, round and match win;
quiz question start, last seconds, reveal (right/wrong), winner. Phones stay silent. Extended 2026-11-17: sound in
every game and in the menus: menu move and confirm clicks; the quiz ticks for the whole question; Vukodlak night
ambience, a howl when the wolves choose, a rooster in the morning, a bell for the vote, a drum when someone is out. Sounds are freely licensed (CC0)
or made for the project, small, and mixed so they don't drown out talking.

### Shared effects

`packages/core` holds a small set of effect widgets (e.g., confetti/particle burst, color pulse, score pop) used by both the TV and the controller, so a win on TV can play the same effect on the winner's phone.

### Visual style

Simple, bold vector look: flat colors, 8 high-contrast player colors, rounded shapes, big type readable from the couch.

**Reference screens (user request, 2026-11-14):** the TV and phone screens are drawn in the design canvas "CouchPlay
screens" (https://claude.ai/artifact/SX8ertCTfhPyLpSpti4PKe), with a copy of its files in `docs/design/couchplay-screens/`.
The built screens follow it. Tokens: background #14141E, surface #1F1F2C, raised #2A2A3A, text #F4F4F8, muted #A9A9BC,
accent and focus #4DD9FF; Roboto; TV text at least 40 px, phone text at least 16 px, phone buttons at least 56–64 px.

### Phone home, live with the TV (person approved, 2026-11-21)

Reference: canvas "Phone Home Redesign" (https://claude.ai/artifact/KubYHAdsEemypKYNBZH8LK), copy in
`docs/design/phone-home/` (`Main.dc.html`: host phone, TV, guest phone; `GuestAll.dc.html`: the guest card per game).
Without Kao svi (removed). Packs stay the multi-select checklist (Task 46) where the canvas still shows one pack.

- **One state, three screens.** The host changes game with ‹ › on the phone or ◀ ▶ on the remote; every phone and the
  TV show the same game at once, with its background art, title, blurb, settings line and page dots.
- **Host phone:** the game card with prev/next edges, then "Postavke · svi ih vide": each setting inline on the home
  (− / + for numbers, ‹ › for choices, Da/Ne toggles; packs and roles open their screen), Igraj pinned at the bottom.
- **Guest phone:** the same card read-only with "Ana gleda" (plus "postavke" / "pakete" while the host is in them), the
  settings list, and while the host is in the pack screen, the same checklist read-only ("Ana bira pakete"). The
  footer says "Igru pokreće Ana". Promijeni lik stays.
- **Changes are visible.** The setting just changed is outlined in the accent on every phone and the TV; guests see
  the old value struck through next to the new one. Guests get a short list "Zadnje promjene" (newest first, last 5,
  with "mobitelom" / "daljinskim"; entries gender-neutral: "Odabrana igra: X", "Otvorene postavke: X", "Otvoreni
  paketi: X"), since the host can be anyone (2026-11-21; the board's "Što je Ana promijenila" / "Otvorila" are
  feminine).
- **TV:** when the host changes a setting (phone or ▼ on the remote) the TV opens its settings panel by itself under
  the title, with the changed row highlighted; Natrag or a game change closes it. In the pack screen the TV shows the
  pack grid with the count summary.

## Left to the builder

- Exact Flutter/Flame versions, folder details, build script.
- Exact effect set and animation timings.
- Exact layouts of the lobby, quiz, and Curve screens, within the visual style above.
- Exact Curve tuning (speed, turn rate, gap frequency).
