# Couchplay — design

Working name. Date: 2026-11-13.

## Intent

A party-games console for the living room. An Android TV shows the game; everyone's phone is the controller. Friends join in seconds by scanning a QR code — nothing to install, no accounts. Built for the owner and their friends, not for store publishing.

## Goals (v1)

- Android TV app that hosts a lobby and two games: **Quiz** and **Curve** (Tron / Curve Fever style).
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

- Android TV: the target device model is unknown, and TVs with Android TV built in often have slow chips. So the first build step is a quick Curve performance test on the real TV: 8 trails at 60 Hz, with input-to-screen delay measured from a phone. Everything else waits on that test. If the TV can't keep up, reduce the rendering cost (for example, draw trails to a cached image) before building more. Menus must be usable with a D-pad remote, though phones drive most interaction.
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
4. The first player to join is the **host**: picks games, starts rounds, can kick players. If the host leaves, the next-oldest player becomes host.
5. Reconnect: the controller keeps a random player token in `localStorage`; reconnecting with the same token restores the player (name, color, score) if within the session.

### Session flow

Lobby (QR, players, running scoreboard) → host picks Quiz or Curve → game → results screen → back to lobby with the scoreboard updated. Scores persist for the session only.

- **Session scoreboard (Claude's call):** each game's raw points stay inside that game. After a game, players get placement points for the session board: 1st = N, 2nd = N−1, … last = 1 (N = players in that game), so Quiz and Curve count equally.
- **D-pad scope (Claude's call):** the remote only needs to move focus and quit/back out of a game. A phone host runs the session; there is no phone-free mode in v1.
- **Joining and leaving mid-game (Claude's call):** late joiners watch on their phone (“next game starts soon”) and enter at the next lobby. A Curve player who disconnects crashes on the spot; the win target stays fixed at the value set when the match began. A Quiz player who disconnects scores 0 for the questions they miss and keeps their points; reconnecting within the session restores them mid-game.

### Networking model

- The TV is authoritative for all game state. Phones only send input and render what the TV tells them.
- JSON messages over one WebSocket per phone, with a `type` field. Message types live in `packages/core`.
- Curve input is sent as state changes (`left down`, `left up`, …), not per frame, so traffic is tiny.

### Quiz

- Question on TV (text, optional picture); phone shows the answer buttons, color/shape-coded to match the TV. After a tap the phone hides the pick: it shows one neutral "Locked in" screen that looks the same whatever was chosen, so nobody nearby can copy it (user request, 2026-11-14).
- 4 choices, 20 s timer. Points: correct answers score 500–1000, scaled by how fast; wrong or no answer = 0.
- After each question: reveal the correct answer, show who picked what, update the scoreboard. Round = 10 questions from the chosen pack, shuffled.
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
  - on you: speed up, thin line, ghost (pass through trails, not walls)
  - on everyone else: slow down, fat line
  - on everyone: clear all trails, wrap (go through walls and come out the opposite side)

  Effects stack by restarting their timer. Exact timings, spawn rate and icons are left to the builder. The TV
  draws them; phones need nothing new.
- **Active power-ups are obvious (user request, 2026-11-14):** while an effect runs, the TV shows who has it and how
  long it has left. Wrap: a white border runs around the arena and shrinks as wrap runs out; when the border is
  gone, the walls are back. Effects on players: the power-up's icon, in its green/red/blue color, next to each
  affected line's head, with a ring that drains as the time runs out. Clear is instant and needs no timer. The Curve
  screen uses the reference-screen tokens below.

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
