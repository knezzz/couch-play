# Couchplay — design

Working name. Date: 2026-11-13.

## Intent

A party-games console for the living room. An Android TV shows the game; everyone's phone is the controller. Friends join in seconds by scanning a QR code — nothing to install, no accounts. Built for the owner and their friends, not for store publishing.

## Goals (v1)

- Android TV app that hosts a lobby and three games: **Quiz**, **Curve** (Tron / Curve Fever style) and **Vukodlak** (a werewolf-style social deduction game, added 2026-11-17).
- Phones join by scanning a QR code on the TV and get a browser controller (Flutter Web) served by the TV itself.
- One Dart codebase: TV app, controller, and a shared package for protocol, theme, and visual effects, so the same effects (particles, color flashes, animations) can play on TV and phone.
- Quiz question packs in a simple, documented file format; ships with packs written by Claude, some with simple vector pictures (flags, shapes).

## Non-goals (v1)

- Remote / internet play. Tailcat was evaluated and rejected: Go-only with no mobile story, no API stability, rate-limited free relays with no SLA. Later option: remote players watch via Discord/FaceTime screen share. Nothing in v1 should block that, but nothing is built for it.
- Tilt / motion controls. Browsers only expose motion sensors on HTTPS, and the controller is served over plain HTTP from the LAN. Later: an optional native app build of the same controller code (Flutter iOS/Android) for tilt; browser players get a touch fallback.
- Haptics (not available in iOS Safari).
- Accounts, saved stats, store publishing, AI-generated content, other mini-games.

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

Lobby (QR, players, running scoreboard) → host picks Quiz or Curve → game → results screen → back to lobby with the scoreboard updated.

**Picking a game (user request, 2026-11-16):** the host's phone shows the games as a swipeable carousel of cards. Tapping a card opens its details: a short description and that game's settings (Quiz: pack, time per question, questions per game, time between questions; Curve: mode, pause before each round). While the host is on the details, the TV lobby shows the same game and its settings, so the room sees what's coming. A "Igraj" button on the details starts the game; Back returns to the carousel and the TV goes back to the plain lobby. Other phones see which game the host is looking at. Scores persist for the session only.

- **Session scoreboard (Claude's call):** each game's raw points stay inside that game. After a game, players get placement points for the session board: 1st = N, 2nd = N−1, … last = 1 (N = players in that game), so Quiz and Curve count equally.
- **D-pad scope (Claude's call):** the remote only needs to move focus and quit/back out of a game. A phone host runs the session; there is no phone-free mode in v1.
- **Joining and leaving mid-game (Claude's call):** late joiners watch on their phone (“next game starts soon”) and enter at the next lobby. A Curve player who disconnects crashes on the spot; the win target stays fixed at the value set when the match began. A Quiz player who disconnects scores 0 for the questions they miss and keeps their points; reconnecting within the session restores them mid-game. Anyone who drops out mid-game, the host included, can come back into the same game: Quiz from the next question, Curve from the next round of the match, with what they missed scoring 0 and their earlier points kept. The host role stays with whoever has it during the game (user request, 2026-11-15). If a 2-player Curve match drops to one player, the match pauses and the TV shows "Čekamo da se <ime> vrati" for up to 30 s; it carries on if they come back and ends if they don't. A 2-player Quiz keeps going with the one player left (user answer, 2026-11-15). A 2-player Curve match that ends this way keeps its scores as they are, ties included (user answer, 2026-11-15). When nobody is connected, a game (Quiz or Curve) also waits 30 s, paused, with "Čekamo da se igrači vrate" on the TV, and ends only if nobody comes back (PM call within the user's request that games don't stop when people leave, 2026-11-15).

### Networking model

- The TV is authoritative for all game state. Phones only send input and render what the TV tells them.
- JSON messages over one WebSocket per phone, with a `type` field. Message types live in `packages/core`.
- Curve input is sent as state changes (`left down`, `left up`, …), not per frame, so traffic is tiny.

### Quiz

- Question on TV (text, optional picture); phone shows the answer buttons, color/shape-coded to match the TV. After a tap the phone hides the pick: it shows one neutral "Locked in" screen that looks the same whatever was chosen, so nobody nearby can copy it (user request, 2026-11-14).
- 4 choices, 20 s timer (default; see host settings below). Points: correct answers score 500–1000, scaled by how fast; wrong or no answer = 0.
- After each question: reveal the correct answer, show who picked what, update the scoreboard. Round = 10 questions from the chosen pack, shuffled.
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

  The app interface is in Croatian (changed 2026-11-14 at the user's request; it was English). Every bundled English pack also gets a Croatian version (same pictures for flags and shapes), and the Croatian packs aim at locals: verified facts, harder questions (user request, 2026-11-14). Local Međimurje facts are the hardest to verify, so the user reviews that pack before it's considered done.

  **Croatian packs only, and bigger (user request, 2026-11-15):** for now the TV ships only the Croatian packs; the English packs stay in `tool/packs/` but are not bundled. Every Croatian pack grows as far as verified questions can be found (Opće znanje most of all). Existing Croatian pub-quiz and Potjera material guides the topics, style and difficulty; question text is copied only where its licence allows it (the repo is public), otherwise the questions are our own wording of verified facts.

  **More packs and more pictures (user request, 2026-11-16):** new Croatian packs Umjetnost, Psihologija, Ljudsko tijelo,
  Memeovi, Fizika and Matematika, each a choice in the pack list; and more picture questions across the packs. Memes
  are mostly copyrighted images, so the Memeovi pack asks about memes in text (origin, catchphrase, year) and shows a
  picture only where the image is freely licensed.

  **Photo questions (user request, 2026-11-15):** questions like "Koji je ovo grad?" with a photo, and other picture questions (landmarks, places, people, things). The pack format accepts photos (JPEG, PNG or WebP) as well as SVG. Photos come only from freely licensed sources (e.g. Wikimedia Commons); the pack's `.sources.md` credits the author and licence of each one. On a picture question the TV gives the picture as much of the screen as it can, uncropped.
- **Adding packs without rebuilding:** the host can upload a pack file from the controller. The TV validates it and stores it in app storage, so it's there next time. Invalid packs are rejected with a readable error.

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
  "Bot 1", and score like players: they take part in placement points and appear on the session scoreboard. Bot
  skill: look ahead and steer away from trails and walls, and sometimes go for a nearby power-up. They must stay
  cheap enough to run 7 of them at 60 Hz on the TV.
- Last one alive scores; every other surviving-longer player also gets points (points = number of players you outlived). First to `10 × (players − 1)` wins, as in Curve Fever.
- Simulation runs on the TV at a fixed 60 Hz tick; collision against a trail occupancy grid.
- **Power-ups (user request, 2026-11-14, replaces "no power-ups in v1"):** icons appear on the board from time to
  time; the first line to drive over one triggers it for a few seconds. Seven kinds:
  - on you: slow down, ghost (pass through trails, not walls; leaves no line while it lasts)
  - on everyone else: speed up, fat line (stacks: each pickup makes the lines fatter), reversed steering (left and right
    swap)

  (Changed 2026-11-16, user request: slow down is now yours and speed up hits everyone else; the fat line lasts a
  little longer than the other effects and stacks; ghost leaves no line; thin line removed, reversed steering added.)
  - on everyone: clear all trails, wrap (go through walls and come out the opposite side)

  Effects stack by restarting their timer. Exact timings, spawn rate and icons are left to the builder. The TV
  draws them; phones need nothing new.
- **Curve modes (user request, 2026-11-16):** the host picks a mode in the lobby settings:
  - Kaos: power-ups spawn often, many on the board at once
  - Uravnoteženo: today's rate (the default)
  - Mirno: no power-ups
  - Samo za tebe: only the power-ups that act on the picker (green)
- **Active power-ups are obvious (user request, 2026-11-14):** while an effect runs, the TV shows who has it and how
  long it has left. Wrap: a white border runs around the arena and shrinks as wrap runs out; when the border is
  gone, the walls are back. Effects on players: the power-up's icon, in its green/red/blue color, next to each
  affected line's head, with a ring that drains as the time runs out. Clear is instant and needs no timer. The Curve
  screen uses the reference-screen tokens below.

### Console redesign (user request, 2026-11-17)

Reference: the design canvas, page "Konzola i Vukodlak" (copy in `docs/design/couchplay-screens/V2*.dc.html`,
`Village.dc.html`, `WolfRoles.dc.html`).

- **Home:** one game fills the screen with its own background art; its title is big in the middle with a one-line
  description and its current settings; the previous and next games just show at the left and right edges. ◀ ▶ changes
  game, OK plays, ▼ opens its settings, Back exits. The QR code and the join address sit in the top-left corner; the
  players' characters top right. The remote and the host's phone drive the same choice. Replaces the lobby layout.
- **Games full screen:** no frame or side panels; the quiz uses the whole screen.
- **Quiz ticker:** a 20-segment bar along the top edge loses one segment per second (red for the last 5), a large ring
  countdown shows the seconds, and the TV ticks for the whole question, faster at the end.

### Vukodlak (user request, 2026-11-17)

A werewolf-style social deduction game for 5–8 people (no bots). The TV tells the story; roles and actions are on
the phones. Folk-game roles in our own words; no names or roles from Town of Salem or other products.

- **TV:** the village: each player's house in a circle around the square, with their character and name; the story
  and the clock in the square. Night: dark, lit windows; morning: daylight. A player who is out: their house closes up
  (boarded, grey), with blood around it and a crow. Light animation: chimney smoke, flickering windows, stars,
  fireflies, drifting clouds, swaying trees (off with reduced motion). The day vote shows who voted for whom.
- **Phones:** the role is hidden by default and shows only while a finger is on the screen. At night every phone
  looks the same (grey, same layout, same button) whatever the role; only a short grey line of text differs; villagers
  also pick (whom they suspect) so every phone looks busy. Day vote on the phones.
- **Roles (14):** Vukodlak, Vođa čopora, Vuk samotnjak; Seljanin, Vidovnjakinja, Ljekarnik, Tjelohranitelj, Travarica,
  Lovac, Starješina, Načelnik, Provodadžija, Seoska budala; Lutalica (descriptions in `WolfRoles.dc.html`).
- **Host settings:** switch on the possible roles (Vukodlak and Seljanin always on); the game draws the mix each game:
  1 werewolf for 5–6 players, 2 for 7–8; up to (players − werewolves − 2) special roles at random from those switched
  on; the rest Seljani; Vođa čopora / Vuk samotnjak may replace an ordinary werewolf. "Skrivene uloge" (on by default):
  a player who is out is not revealed; all roles are shown at the end. Day discussion time.
- **Players see every possible role** (all switched on, not only those drawn) and what each does, on a phone screen.
- Win: the village when no werewolves are left; the werewolves when they equal the rest; solo roles as described.

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

## Left to the builder

- Exact Flutter/Flame versions, folder details, build script.
- Exact effect set and animation timings.
- Exact layouts of the lobby, quiz, and Curve screens, within the visual style above.
- Exact Curve tuning (speed, turn rate, gap frequency).
