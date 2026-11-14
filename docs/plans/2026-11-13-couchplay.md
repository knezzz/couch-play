# Couchplay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An Android TV party console where phones join by QR code and play Quiz and Curve, all in Flutter.

**Architecture:** A Dart pub workspace with three members. `packages/core` holds the protocol, pure game logic, scoring, the pack parser, the theme and the effects. `apps/tv` is a Flutter Android TV app (it also runs on macOS for development) that hosts a `dart:io` HTTP + WebSocket server and is the single source of truth for game state. `apps/controller` is a Flutter Web app; its build output is zipped into the TV app's assets and served to phones.

**Tech Stack:** Flutter stable (Dart ≥ 3.6 for pub workspaces), Flame (Curve rendering), `qr_flutter`, `flutter_svg`, `archive`, `path_provider` (TV), `web_socket_channel` + `package:web` (controller).

**Spec:** `docs/specs/2026-11-13-couchplay-design.md`

## Global Constraints

- Local network only, plain HTTP on the LAN. No internet needed at runtime: build the controller with `--no-web-resources-cdn` so CanvasKit is served by the TV.
- The TV is authoritative. Phones send input only.
- Maximum 8 players. Player colors are fixed, in this order: `#FF4D6D #FFB020 #2ECC71 #22B8F0 #9B5CFF #FF7AD9 #F5E94B #FF7A2F`.
- Server port is 8080. If it is taken, try ports up to 8090.
- Quiz: 4 choices, 20 s per question, 10 questions per round. A correct answer scores 500–1000 points, depending on speed. A wrong answer or no answer scores 0.
- Curve: 60 Hz fixed tick, left/right steering, trails with random gaps, +1 point for each player you outlive. The match target is `10 × (players − 1)`, fixed when the match starts. You die on any trail, including your own older trail. Power-ups: see Task 5b.
- Session scoreboard: placement points after each game (1st = N, …, last = 1, where N = players in that game). Scores last only for the session.
- The D-pad only moves focus and backs out of a game. A phone host runs the session.
- Dev machine: Intel Mac (x86_64). Xcode and Android Studio are installed. Flutter 3.47.7 (Dart 3.13.5) is installed via fvm. `avdmanager` needs `JAVA_HOME` set to Android Studio's bundled jbr.
- Copy rules for UI text: plain words, active voice, and errors that say how to fix the problem.

## Review Focus

1. **A phone locks or the browser goes to the background mid-game.** The socket drops. The player must come back with the same name, color and score when the page wakes up (test in Task 6).
2. **Bad names.** Empty, whitespace-only, longer than 16 characters, emoji, or duplicates. Expect: trimmed, rejected if empty, cut to 16 characters, and duplicates get " 2", " 3" (test in Task 6).
3. **A 9th phone tries to join.** It gets "The game is full (8 players)." No one already playing is affected (test in Task 6).
4. **The TV has several network interfaces or none** (Ethernet + Wi-Fi, a VPN, Docker on the macOS dev machine). The QR code must point at the private LAN IPv4 address. If there is none, the TV shows "Connect the TV to Wi-Fi to play." (test in Task 3).
5. **A broken or hostile pack upload.** Not JSON, wrong schema, a file over 5 MB, `../` paths in the zip, a missing SVG, or an upload from a player who isn't the host. Expect: rejected with a readable reason and nothing stored (tests in Tasks 9 and 12).

---

## File Structure

```
couchplay/
  pubspec.yaml                      # workspace root: members below
  tool/build_controller.sh          # flutter build web → zip → apps/tv/assets/controller.zip
  packages/core/
    lib/core.dart                   # exports
    lib/src/protocol.dart           # Message sealed class + JSON codec
    lib/src/palette.dart            # playerColors, theme constants
    lib/src/names.dart              # cleanName, dedupeName
    lib/src/scoring.dart            # placementPoints, quizPoints
    lib/src/curve_sim.dart          # pure Curve simulation
    lib/src/quiz_pack.dart          # QuizPack model + parse/validate (json + zip)
    lib/src/quiz_round.dart         # pure quiz round state machine
    lib/src/effects.dart            # shared effect widgets (Flutter)
    test/…                          # one test file per src file
  apps/tv/
    lib/main.dart
    lib/server/lan_address.dart     # pickLanAddress
    lib/server/game_server.dart     # HTTP static + /ws + POST /packs
    lib/server/controller_files.dart# extract controller.zip, serve files
    lib/session/session.dart        # players, host, tokens, phases, routes messages
    lib/session/bots.dart           # debug bot players for perf testing
    lib/packs/pack_store.dart       # bundled + uploaded packs on disk
    lib/ui/lobby_screen.dart
    lib/ui/quiz_screen.dart
    lib/ui/results_screen.dart
    lib/ui/curve/curve_game.dart    # Flame game rendering CurveSim
    assets/controller.zip           # generated, git-ignored
    assets/packs/*.zip|*.json       # bundled packs (Task 13)
    android/…                       # leanback manifest, banner
    test/…
  apps/controller/
    lib/main.dart
    lib/connection.dart             # socket, token, reconnect
    lib/screens/join_screen.dart
    lib/screens/lobby_screen.dart   # includes host controls + pack upload
    lib/screens/quiz_screen.dart
    lib/screens/curve_screen.dart
    lib/screens/wait_screen.dart
    test/…
```

---

### Task 1: Toolchain and workspace

**Files:**
- Create: `pubspec.yaml`, `.gitignore`, `packages/core/`, `apps/tv/`, `apps/controller/`, `tool/build_controller.sh`

**Interfaces:**
- Produces: a workspace where `flutter test` passes in every member, plus `tool/build_controller.sh`, which writes `apps/tv/assets/controller.zip`.

- [x] **Step 1: Install Flutter.** Run `brew install --cask flutter`, then `flutter doctor`. Expected: the Flutter, Xcode and Android toolchain checks pass. If Android licenses are missing, run `flutter doctor --android-licenses`. Add `~/Library/Android/sdk/platform-tools` to PATH so `adb` works.
- [x] **Step 2: Create an Android TV emulator.** Run `sdkmanager "system-images;android-36;android-tv;x86_64"`, then `avdmanager create avd -n tv -k "system-images;android-36;android-tv;x86_64" -d tv_1080p`. Expected: `flutter emulators` lists `tv`. (Corrected 2026-11-14: Flutter 3.47 does not run on the 32-bit x86 image.)
- [x] **Step 3: Scaffold the workspace.**
  - `git init`.
  - `flutter create --platforms=android,macos --org dev.couchplay apps/tv`.
  - `flutter create --platforms=web apps/controller`.
  - `flutter create --template=package packages/core`.
  - Root `pubspec.yaml` with `workspace: [packages/core, apps/tv, apps/controller]`, and `resolution: workspace` in each member.
  - `core` is a Flutter package because `effects.dart` holds widgets.
  - `.gitignore`: `build/`, `.dart_tool/`, `apps/tv/assets/controller.zip`.
- [x] **Step 4: Write `tool/build_controller.sh`.** It runs `flutter build web --release --no-web-resources-cdn` in `apps/controller`, then zips `build/web/*` (paths relative to `build/web`) into `apps/tv/assets/controller.zip`. Use `set -euo pipefail`.
- [x] **Step 5: Verify.** Run `flutter pub get` at the root, then `flutter test` in each member, then `tool/build_controller.sh && unzip -l apps/tv/assets/controller.zip | grep -E "index.html|canvaskit"`. Expected: all pass, and the zip lists `index.html` and the `canvaskit/` files.
- [x] **Step 6: Commit.** Commit message: `chore: scaffold flutter workspace and controller build`. Also copy the spec and this plan into the commit.

---

### Task 2: Protocol

**Files:**
- Create: `packages/core/lib/src/protocol.dart`
- Test: `packages/core/test/protocol_test.dart`

**Interfaces:**
- Produces:
  - `sealed class Message { String encode(); static Message? decode(String raw); }`. `decode` returns `null` for malformed JSON, an unknown `type`, or wrong field types. It never throws.
  - Wire shape: `{"type": "<name>", ...fields}`.
  - Phone → TV:
    - `Join(name, token)` `"join"`
    - `Steer(left: bool, right: bool)` `"steer"`
    - `Answer(index: int)` `"answer"`
    - `StartGame(game: GameKind, packId: String?)` `"start"`
    - `Kick(playerId: int)` `"kick"`
    - `Ping(t: int)` `"ping"`
  - TV → phone:
    - `Welcome(playerId, colorIndex, token)` `"welcome"`
    - `LobbyState(players: List<PlayerInfo>, packs: List<PackInfo>, hostId: int)` `"lobby"`
    - `QuizQuestion(number, total, choices: List<String>, seconds: int)` `"quizQ"`
    - `QuizReveal(correctIndex, yourPoints, yourTotal)` `"quizReveal"`
    - `CurveStatus(alive: bool, score: int, target: int)` `"curve"`
    - `Results(placements: List<Placement>)` `"results"`
    - `Effect(name: String)` `"effect"`
    - `Pong(t)` `"pong"`
    - `Waiting(reason: String)` `"waiting"`
    - `ErrorMsg(message: String)` `"error"`
    - `Kicked()` `"kicked"`
  - Data classes:
    - `PlayerInfo(id, name, colorIndex, connected, sessionScore)`
    - `PackInfo(id, title, questionCount)`
    - `Placement(playerId, place, gameScore, sessionPoints)`
    - `enum GameKind { quiz, curve }`

- [x] **Step 1: Write the failing tests.**
  - `roundtrip_all_messages`: for one instance of every subclass, `Message.decode(m.encode()) == m`. Use `==` via a Dart 3 record-based equality or hand-written `==`.
  - `decode_rejects_garbage`: `decode('not json')`, `decode('{"type":"nope"}')` and `decode('{"type":"answer","index":"2"}')` are all `null`.
- [x] **Step 2: Run** `flutter test test/protocol_test.dart` in `packages/core`. Expected: FAIL (undefined).
- [x] **Step 3: Implement** `protocol.dart` as above and export it from `core.dart`.
- [x] **Step 4: Run** the tests. Expected: PASS.
- [x] **Step 5: Commit.** Message: `feat(core): wire protocol`.

---

### Task 3: TV server and LAN address

**Files:**
- Create: `apps/tv/lib/server/lan_address.dart`, `apps/tv/lib/server/controller_files.dart`, `apps/tv/lib/server/game_server.dart`
- Test: `apps/tv/test/lan_address_test.dart`, `apps/tv/test/game_server_test.dart`

**Interfaces:**
- Consumes: `Message` (Task 2).
- Produces:
  - `String? pickLanAddress(List<NetworkInterface> ifaces)`. It returns the first private IPv4 address (10/8, 172.16/12, 192.168/16) that isn't loopback or link-local. It prefers interface names starting with `wlan`, `eth` or `en`, and skips names containing `docker`, `vbox`, `utun`, `tun` or `bridge`. If nothing qualifies, it returns null.
  - `Future<Directory> extractControllerZip(Uint8List zip, Directory into)`.
  - `class GameServer { static Future<GameServer> start({required Directory webRoot, required void Function(PeerSocket) onPeer, required Future<String?> Function(String token, Uint8List body) onPackUpload, int firstPort = 8080, int lastPort = 8090}); int get port; Future<void> close(); }`.
  - `class PeerSocket { Stream<Message> get messages; void send(Message m); Future<void> get done; void close(); }`.
  - Routes:
    - `GET /` and static files are served from `webRoot`. Path traversal returns 404.
    - `/ws` upgrades to a WebSocket. Frames that fail to decode are dropped.
    - `POST /packs?token=…`: a body over 5 MB returns 413. Otherwise it calls `onPackUpload`, which returns null on success (200) or an error string (400 with that text as the body).

- [x] **Step 1: Write the failing tests.**
  - `picks_wlan_private_ipv4`: from fake interfaces `docker0 172.17.0.1`, `wlan0 192.168.1.20` and `lo 127.0.0.1`, it returns `192.168.1.20`.
  - `returns_null_without_lan`: only loopback gives null.
  - `serves_index_and_404s_traversal`: start on `firstPort: 0` with a temp webRoot containing `index.html`. `GET /` returns 200 with the contents. `GET /../secret` returns 404.
  - `falls_back_to_next_port`: hold port X open, then start with `firstPort: X`. Expect `port == X + 1`.
  - `ws_roundtrip`: a client connects to `/ws` and sends `Ping(5)`. `onPeer` echoes `Pong(5)` back, and the client receives it.
  - `pack_upload_too_big_413`.
- [x] **Step 2: Run** `flutter test` in `apps/tv`. Expected: FAIL.
- [x] **Step 3: Implement.** Use `HttpServer.bind(InternetAddress.anyIPv4, port)` and `WebSocketTransformer.upgrade`, with only `dart:io` and no extra packages. Content types come from the file extension: html, js, mjs, wasm (`application/wasm`), json, png, svg, css, ttf, otf.
- [x] **Step 4: Run** the tests. Expected: PASS.
- [x] **Step 5: Commit.** Message: `feat(tv): http/ws server and lan address`.

---

### Task 4: Curve simulation

**Files:**
- Create: `packages/core/lib/src/curve_sim.dart`
- Test: `packages/core/test/curve_sim_test.dart`

**Interfaces:**
- Produces:
  - `class CurveConfig` with defaults:
    - `arenaW 1600`, `arenaH 900`
    - `speed 140` units/s, `turnRate pi` rad/s
    - `lineWidth 6`, `cell 4`
    - `gapEveryMin 1.5`, `gapEveryMax 3.5`, `gapLength 0.25` (all seconds)
    - `selfGraceTicks 12`, `tickHz 60`
    - `countdown 2.0` (seconds)
  - `class CurveSim`:
    - constructor `CurveSim(List<int> playerIds, {CurveConfig config, Random? random})`
    - `void setInput(int id, {required bool left, required bool right})`
    - `void kill(int id)` (used on disconnect)
    - `List<CurveEvent> tick()` advances 1/60 s
    - `Map<int, int> scores`, `int target`, `bool roundOver`, `bool matchOver`, `int? winner`
    - `void startRound()`
    - `Iterable<CurveHead> heads` for rendering
    - `List<TrailSegment> takeNewSegments()` drains segments added since the last call, for rendering
  - `sealed class CurveEvent`: `Died(id)`, `RoundOver(survivorId?)`, `MatchOver(winnerId)`.
  - `CurveHead(id, x, y, heading, alive, inGap)`.
  - `TrailSegment(id, x1, y1, x2, y2)`.

- [x] **Step 1: Write the failing tests.** Use a seeded `Random(1)` and a small arena where useful.
  - `target_is_10_times_players_minus_one`: 3 players gives 20. The target stays 20 after `kill`.
  - `straight_line_hits_wall_and_dies`: one head aims at the wall with no input. It dies within the expected number of ticks (distance / speed × 60, ±2).
  - `turning_left_changes_heading_by_turnRate_per_second`: 60 ticks with left held change the heading by π (±0.01).
  - `crossing_another_trail_kills`: set up two players so A's path crosses B's painted trail. A dies and B gets +1.
  - `gap_lets_you_pass`: force B into a gap (test hook: `config` with `gapEveryMin = gapEveryMax = 0.1` and a long `gapLength`). A crosses and lives.
  - `own_fresh_trail_does_not_kill`: steady turning for 1 s doesn't kill a player via the cells it painted within the last `selfGraceTicks`.
  - `outlive_scoring`: with 4 players, the deaths of 1, 2 and 3 in order give scores 0, 1, 2, 3.
  - `match_over_at_target_with_unique_leader`: if two players reach the target in the same round with equal scores, `matchOver` stays false until there's a unique leader.
  - `countdown_freezes_movement`: heads don't move during the first `countdown × 60` ticks after `startRound`.
- [x] **Step 2: Run** the tests. Expected: FAIL.
- [x] **Step 3: Implement.**
  - Occupancy is a `Uint16List` grid of `(owner + 1)` plus a `Uint32List` grid of paint ticks.
  - Each tick, paint the cells under the new segment unless the player is in a gap.
  - Collision happens when a head's cell is the wall, or is painted by someone else, or is painted by itself more than `selfGraceTicks` ago.
  - Spawn points are at least 100 units from the walls and 150 units from each other, with a random heading.
  - Gap timing is random within the min–max range.
- [x] **Step 4: Run** the tests. Expected: PASS.
- [x] **Step 5: Commit.** Message: `feat(core): curve simulation`.

---

### Task 5: Curve playable end-to-end + **performance gate on the real TV**

**Files:**
- Create: `apps/tv/lib/ui/curve/curve_game.dart`, `apps/tv/lib/session/bots.dart`, `apps/controller/lib/connection.dart`, `apps/controller/lib/screens/curve_screen.dart`, `apps/controller/lib/screens/join_screen.dart`
- Modify: `apps/tv/lib/main.dart`, `apps/controller/lib/main.dart`, `apps/tv/pubspec.yaml` (flame, assets), `apps/tv/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes:
  - `GameServer`, `pickLanAddress`, `extractControllerZip` (Task 3)
  - `CurveSim` (Task 4)
  - `Message` (Task 2)
- Produces:
  - `class CurveGame extends FlameGame` with constructor `CurveGame(CurveSim sim, List<Color> colors)`. It runs `sim.tick()` on a fixed 60 Hz accumulator and draws the trail segments and heads.
  - `class Bots { Bots(CurveSim sim, List<int> ids, Random r); void tick(); }`. Bots pick random steering every 0.3–1 s and turn away when a wall is within 80 units.
  - `class Connection { Connection(Uri ws); Stream<Message> messages; void send(Message m); String token; }` in the controller. It reconnects with backoff of 0.5, 1, 2, 4 s, up to 4 s. The token is kept in `window.localStorage['couchplay.token']`, or created as 16 random hex chars.
  - Temporary wiring, replaced in Task 6:
    - The first `Join` starts a Curve match against `--dart-define=BOTS=n` bots. The default is 7.
    - The phone's `Steer` messages drive its line.
    - `Ping` is answered with `Pong`.
- [x] **Step 1: Manifest for Android TV.**
  - `<uses-feature android:name="android.software.leanback" android:required="false"/>`
  - `<uses-feature android:name="android.hardware.touchscreen" android:required="false"/>`
  - `LEANBACK_LAUNCHER` intent category on the main activity.
  - A 320×180 `android:banner` drawable: plain text "Couchplay" on a solid color.
  - `INTERNET` permission.
- [x] **Step 2: Wire the TV app.**
  - On start, extract `assets/controller.zip` to the app support dir, start the server, and show the `http://<ip>:<port>/` text.
  - If `pickLanAddress` is null, show "Connect the TV to Wi-Fi to play."
  - The trail renderer appends `takeNewSegments()` to one `Path` per player.
  - Enable `showPerformanceOverlay` behind `--dart-define=PERF=true`.
- [x] **Step 3: Wire the controller.**
  - The join screen has a name field and a Join button.
  - The Curve screen shows two full-height halves, ◀ and ▶. Pointer down/up on each half sends `Steer`, so multi-touch holding works.
  - It shows the round-trip time from a `Ping` sent every 1 s, as small text in a corner.
- [x] **Step 4: Widget smoke test.** `apps/controller/test/curve_screen_test.dart`: pressing the left half sends `Steer(left: true, right: false)` to a fake `Connection`, and releasing it sends `Steer(false, false)`.
- [x] **Step 5: Run on the Android TV emulator.**
  - `tool/build_controller.sh && cd apps/tv && flutter run -d emulator-… --dart-define=PERF=true`.
  - From a phone on the same Wi-Fi, open the URL the emulator shows (emulator networking may need `adb forward tcp:8080 tcp:8080` and the Mac's address). Steering must work.
- [x] **Step 6: GATE: run on the user's real Android TV.**
  - Enable developer mode and network debugging on the TV, then `adb connect <tv-ip>`.
  - `flutter run --release -d <tv> --dart-define=PERF=true --dart-define=BOTS=7`.
  - Pass criteria, measured over three 60-second rounds:
    - The performance overlay shows no frame over 16 ms in steady play, and no visible stutter.
    - Phone round-trip time is p95 ≤ 40 ms on home Wi-Fi.
    - The user plays one match and confirms steering feels immediate.
  - **If frames drop:** replace the per-player `Path` with an offscreen `ui.Image`. Each tick, draw only the new segments onto it with `PictureRecorder` → `toImageSync`. Re-measure.
  - **Stop here and report the numbers to the user** before starting Task 6.
- [x] **Step 7: Commit.** (Landed as per-change commits; no single commit.) Message: `feat: playable curve with bots and perf overlay`.

---

### Task 5b: Curve changes from the user (added 2026-11-14)

Starts after the user's go on the Task 5 gate. Runs before Task 6.

**Files:**
- Modify: `packages/core/lib/src/curve_sim.dart`, `apps/tv/lib/ui/curve/curve_game.dart`, `apps/tv/lib/session/bots.dart` (smarter bots, see below)
- Test: `packages/core/test/curve_sim_test.dart`, `packages/core/test/curve_powerups_test.dart`, `apps/tv/test/bots_test.dart`

**Interfaces:**
- Produces:
  - Self-collision fix: painting must not refresh the paint tick of a player's own cells that are older than `selfGraceTicks`. Today `curve_sim.dart:213-215` re-stamps them, so a line never dies on its own old trail.
  - `CurveSim.names: Map<int, String>`, passed to the constructor (`names:` named parameter). It's used only for rendering.
  - `enum PowerUpKind { speed, thin, ghost, slowOthers, fatOthers, clear, wrap }`.
  - `CurvePowerUp(id, kind, x, y)`, `Iterable<CurvePowerUp> get powerUps`, and a new event `PickedUp(playerId, kind)`.
  - `CurveConfig` additions, defaults left to the builder within these bounds:
    - `powerUpEveryMin`/`Max`: about 4–8 s
    - `powerUpMax`: about 3 on the board at once
    - `powerUpRadius`
    - `effectSeconds`: about 5
    - `powerUps: bool`: tests can turn them off; on by default
  - Rules:
    - The first head to come within `powerUpRadius` picks it up.
    - Speed and slow scale `speed`. Thin and fat scale `lineWidth` for both painting and collision.
    - Ghost skips trail collision but not wall collision, and still paints.
    - Clear wipes both occupancy grids and tells the renderer: `takeNewSegments` returns a `cleared` flag, or an equivalent the builder picks.
    - Wrap makes the walls wrap for everyone.
    - A second pickup of the same effect restarts its timer.
    - Nothing spawns during the countdown. All effects end with the round.
  - TV rendering:
    - During the countdown, each head is drawn as a dot in the player's color with the name above it, in large type readable from the couch. The names are hidden once the round runs.
    - During the countdown, a short arrow from each dot shows its starting heading (added 2026-11-14).
    - Power-ups are simple shape icons. Colors show who they affect: green is you, red is others, blue is everyone.
  - Smarter bots (added 2026-11-14). `Bots` becomes a real opponent, not just a test tool:
    - Each tick, it probes a few headings ahead (straight, left, right) at about 0.5–1 s of travel against the occupancy grid and the walls, and steers toward the clearest one.
    - If all three headings are clear and a power-up is within a short range, it steers toward the power-up.
    - It needs read access to the grid: a read-only `CurveSim.isBlocked(x, y)` or equivalent.
    - Cost budget: 7 bots at 60 Hz must keep the TV well under 16 ms (re-measured in Step 5).
    - Human-like play (user feedback 2026-11-14: bots looked aimless and robotic):
      - Bots pick a goal (open space or a power-up) and keep it for a while instead of re-deciding every tick.
      - They react with a delay of about 150–250 ms.
      - They steer in held bursts, with a little randomness and an occasional mistake.
      - Test: `bot_does_not_flip_steering_every_tick`.

- [x] **Step 1: Write the failing tests.**
  - `crossing_own_old_trail_kills`: drive a full circle back across your own trail from more than `selfGraceTicks` ago. You die.
  - `own_fresh_trail_does_not_kill` stays green.
  - One test per power-up kind, with a seeded `Random` and a power-up placed through a test hook in front of a head: the effect applies, then expires after `effectSeconds`.
  - `ghost_passes_trail_not_wall`, `wrap_comes_out_opposite_side`, `clear_empties_grid`.
  - `no_spawn_during_countdown`.
  - `bots_test.dart`:
    - `bot_turns_away_from_wall_ahead`
    - `bot_avoids_trail_ahead`
    - `bot_survives_longer_than_random`: over 20 seeded rounds, the mean survival time beats the old random bot.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** the sim changes, the bots, then the renderer (countdown names and arrows, icons, clear).
- [x] **Step 4: Run.** Expected: PASS. Then QA on macOS: names visible in the countdown, each power-up seen working.
- [ ] **Step 5: Re-measure on the real TV** (needs the user's adb yes for that session). Same setup as Task 5 Step 6, with power-ups on. Report the numbers to the user.
- [x] **Step 6: Commit.** Messages: `fix(core): die on your own old trail`, `feat: curve power-ups and countdown names`.

---

### Task 6: Session, lobby and joining by QR

**Files:**
- Create: `packages/core/lib/src/names.dart`, `packages/core/lib/src/palette.dart`, `apps/tv/lib/session/session.dart`, `apps/tv/lib/ui/lobby_screen.dart`, `apps/controller/lib/screens/lobby_screen.dart`, `apps/controller/lib/screens/wait_screen.dart`
- Modify: `apps/tv/lib/main.dart`, `apps/controller/lib/main.dart`
- Test: `packages/core/test/names_test.dart`, `apps/tv/test/session_test.dart`

**Interfaces:**
- Consumes: `PeerSocket` (Task 3), `Message` (Task 2), `CurveSim` (Task 4)
- Produces:
  - `String? cleanName(String raw)`: trims and collapses whitespace, then cuts to 16 characters (counted as user-perceived characters via `package:characters`). Returns null if the result is empty.
  - `String dedupeName(String name, Iterable<String> taken)`: returns `name`, `name 2`, `name 3` and so on.
  - `const List<Color> playerColors`: the 8 colors from Global Constraints.
  - `class Session`:
    - `void attach(PeerSocket p)`
    - `List<Player> get players`
    - `int? get hostId`
    - `Phase get phase` (`lobby | quiz | curve | results`)
    - `ValueListenable<int> changes`: bumped on every change, for UI rebuilds
    - `void Function(GameKind, String? packId)? onStart`
    - `Map<int,int> sessionScores`
  - `class Player { int id; String name; int colorIndex; String token; bool connected; PeerSocket? socket; }`.
  - Rules:
    - A `Join` with an unknown token creates a player, if there are fewer than 8. Otherwise it gets `ErrorMsg("The game is full (8 players).")`.
    - A `Join` with a known token re-attaches that player, keeping id, name, color and score, and sends `Welcome` again.
    - Each new player gets the lowest free color index.
    - The host is the oldest connected player. When the host disconnects, the role moves to the next-oldest connected player.
    - Players who join during a game get `Waiting("Next game starts soon.")` and enter at the next lobby.
    - Only the host's `StartGame` and `Kick` are accepted. Others get `ErrorMsg("Only the host can do that.")`.
    - `Kick` sends `Kicked` and removes the player.
    - A player who stays disconnected for more than 10 minutes while in the lobby is removed.
  - Bots in the lobby (added 2026-11-14):
    - New protocol message `SetBots(count: int)` `"bots"` (phone → TV). `PlayerInfo` gains `bot: bool`.
    - Only the host can send it. The count is clamped so players + bots ≤ 8.
    - Bots are `Player`s with no socket and no token, named "Bot 1", "Bot 2"… and given the lowest free colors.
    - A human who joins when the game is full takes a bot's seat; the newest bot is removed.
    - Bots play Curve only. In Curve they count toward the target and the placement points, and they appear on the session scoreboard. In Quiz they sit out.
    - The controller's host lobby gets "− Bots N +" buttons.
- [ ] **Step 1: Write the failing tests.** `session_test.dart` uses fake `PeerSocket`s.
  - `cleanName`: `"  Ana  "` → `"Ana"`. `"   "` → null. A 20-emoji string → 16 graphemes.
  - `dedupe`: "Ana" when "Ana" is taken → "Ana 2".
  - `ninth_player_gets_full_error`
  - `first_player_is_host_and_host_passes_on_disconnect`
  - `rejoin_with_token_restores_player`: same id, color and session score.
  - `late_joiner_waits_until_lobby`
  - `non_host_start_rejected`
  - `colors_reuse_lowest_free_after_kick`
  - `curve_disconnect_kills_player`: calls `CurveSim.kill`.
  - `host_sets_bots_clamped_to_eight`, `non_host_set_bots_rejected`, `human_join_replaces_newest_bot_when_full`, `bots_sit_out_quiz`.
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement** `names.dart`, `palette.dart` and `session.dart`. Move the Task 5 temporary wiring into `Session`: `onStart(curve)` creates the `CurveSim` from the connected players.
- [ ] **Step 4: Build the TV lobby screen.**
  - A QR code (`qr_flutter`) of `http://<ip>:<port>/` and the URL as text.
  - Player chips in their colors, with ★ on the host.
  - The session scoreboard, sorted by score.
- [ ] **Step 5: Build the controller lobby screen.**
  - The phone shows its name and color.
  - The host sees the game buttons Quiz and Curve, a pack picker for Quiz, and kick buttons.
  - `WaitScreen` shows the `Waiting` reason.
- [ ] **Step 6: Run** the tests. Expected: PASS. Then check by hand on the emulator with 2 phones (or 2 browser tabs): join, host handover by closing a tab, rejoin by reloading.
- [ ] **Step 7: Commit.** Message: `feat: session, lobby, qr join, host and reconnect`.

---

### Task 7: Session scoring and results screen

**Files:**
- Create: `packages/core/lib/src/scoring.dart`, `apps/tv/lib/ui/results_screen.dart`
- Modify: `apps/tv/lib/session/session.dart`, `apps/controller/lib/main.dart` (results view)
- Test: `packages/core/test/scoring_test.dart`

**Interfaces:**
- Produces:
  - `List<Placement> placementPoints(Map<int,int> gameScores)`. Players are sorted by score, descending. 1st gets N points, down to 1. Tied players share the better place and its points; the next place skips accordingly (scores 9, 9, 5 → places 1, 1, 3, points 3, 3, 1).
  - `int quizPoints({required bool correct, required Duration elapsed, Duration limit = const Duration(seconds: 20)})`. Correct: `(1000 - 500 × elapsed/limit).round()`, clamped to 500–1000. Otherwise 0.
  - `Session.finishGame(Map<int,int> gameScores)`: adds the placement points to `sessionScores`, broadcasts `Results`, shows the results screen for 8 s, then returns to the lobby.
- [ ] **Step 1: Write the failing tests.**
  - The ties case above.
  - A single player gets 1 point.
  - `quizPoints`: correct at 0 s = 1000, at 10 s = 750, at 20 s = 500, at 25 s = 500. Wrong = 0.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** When Curve reaches `matchOver`, call `finishGame(sim.scores)`.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit.** Message: `feat: placement scoring and results`.

---

### Task 8: Shared effects

**Files:**
- Create: `packages/core/lib/src/effects.dart`
- Modify: `apps/tv/lib/ui/results_screen.dart`, `apps/tv/lib/ui/curve/curve_game.dart`, `apps/controller/lib/main.dart`
- Test: `packages/core/test/effects_test.dart`

**Interfaces:**
- Produces:
  - `enum EffectName { confetti, colorPulse, scorePop }`.
  - `class EffectLayer extends StatefulWidget` with constructor `EffectLayer({required Widget child})` and static `void play(BuildContext, EffectName, {Color? color, String? text})`. Every effect respects `MediaQuery.disableAnimations`: it shows the end state with no motion.
  - The TV sends `Effect(name)` to a phone to play the same effect there:
    - the winner gets confetti on results
    - a Curve death gets a color pulse
    - a correct quiz answer gets a score pop
- [ ] **Step 1: Write the failing test.** `play_confetti_then_clears`: pump an `EffectLayer` and call `play(confetti)`. Particles appear, and after 3 s nothing is left in the tree. With `disableAnimations: true`, there are no animation tickers.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** the effects with `CustomPainter` and one `AnimationController` each. No new dependencies.
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit.** Message: `feat(core): shared effects on tv and phone`.

---

### Task 9: Quiz pack format

**Files:**
- Create: `packages/core/lib/src/quiz_pack.dart`, `docs/quiz-pack-format.md`
- Test: `packages/core/test/quiz_pack_test.dart`

**Interfaces:**
- Produces:
  - `class QuizPack { String id; String title; List<PackQuestion> questions; Map<String, Uint8List> images; }`.
  - `class PackQuestion { String q; String? image; List<String> choices; int answer; }`. (Renamed 2026-11-14 from `QuizQuestion`, which is the Task 2 wire message.)
  - `sealed class PackResult`: `PackOk(QuizPack)` | `PackError(String message)`.
  - `PackResult parsePack(Uint8List bytes)` detects zip by the magic bytes `PK\x03\x04`; otherwise it's JSON.
  - Validation, with messages exactly as written:
    - total size ≤ 5 MB → "The pack is larger than 5 MB."
    - valid UTF-8 JSON → "The pack isn't valid JSON."
    - `format == 1` → "Unsupported pack format. Use \"format\": 1."
    - `id` matches `^[a-z0-9-]{1,40}$` → "The pack id must be lowercase letters, digits or dashes."
    - non-empty `title`
    - at least 1 question
    - each question has non-empty `q`, exactly 4 non-empty `choices` and `answer` in 0–3 → "Question N: …"
    - `image` (optional) is a relative path that ends in `.svg`, has no `..`, doesn't start with `/`, and is present in the zip → "Question N: image flags/x.svg is missing from the zip."
    - a zip with exactly one `.json` at the root → "The zip must contain one .json pack file."
    - total uncompressed size ≤ 20 MB → "The pack is too large when unzipped."
- [x] **Step 1: Write the failing tests.**
  - The valid example JSON from the spec, as a zip with `flags/japan.svg`, gives `PackOk`.
  - One test per validation message: the JSON form for schema errors, and the zip form for `../x.svg`, the missing image, two `.json` files and the zip-bomb limit.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** with `package:archive`.
- [x] **Step 4: Run.** Expected: PASS.
- [x] **Step 5: Write `docs/quiz-pack-format.md`.** It covers the schema, the example, and the zip layout, for people writing packs.
- [x] **Step 6: Commit.** Message: `feat(core): quiz pack format and validation`.

---

### Task 10: Quiz round logic

**Files:**
- Create: `packages/core/lib/src/quiz_round.dart`
- Test: `packages/core/test/quiz_round_test.dart`

**Interfaces:**
- Consumes: `QuizPack` (Task 9), `quizPoints` (Task 7).
- Produces:
  - `class QuizRound`:
    - constructor `QuizRound(QuizPack pack, List<int> playerIds, {Random? random, int length = 10, Duration limit = 20 s, Duration reveal = 4 s})`. It picks `min(length, questions)` questions at random and shuffles each question's choices, tracking the correct index.
    - `QuizStep get step` (`asking | revealing | done`)
    - `int get number`, `int get total`
    - `ShownQuestion get current`: `(q, image, choices, correctIndex)`
    - Time (changed 2026-11-14): every call takes `Duration now`, a monotonic time since the round started. `QuizRound` tracks when each phase began, so callers never reset a clock.
    - `void answer(int playerId, int index, Duration now)`: the first answer counts; later ones are ignored. An index outside 0–3 is ignored.
    - `void removePlayer(int id)`: the player is inactive. They keep their total, and the round no longer waits for them.
    - `void addPlayer(int id)` (added 2026-11-14): re-activates a player who reconnects mid-round and keeps their total, so they answer from the current question on (the spec's "restored mid-game").
    - `void advance(Duration now)`: asking → revealing when time is up or every active player has answered; revealing → the next question after `reveal`, or done
    - `Map<int,int> totals`
    - `Map<int,int> lastPoints`: final only once the step is `revealing`. Task 11 broadcasts it at the reveal, never during asking.
- [x] **Step 1: Write the failing tests.**
  - `picks_min_of_length_and_pack_size`
  - `shuffle_keeps_correct_answer`: the shown choice at `correctIndex` equals the original `choices[answer]`.
  - `first_answer_locks`
  - `ends_early_when_all_answered`
  - `timeout_gives_zero`
  - `points_scale_with_speed`: an answer at 10 s gives 750.
  - `disconnected_player_keeps_points_and_scores_zero_after`
  - `rejoined_player_answers_again_and_keeps_total` (added 2026-11-14)
  - `instant_answer_on_every_question_scores_1000` and `reveal_lasts_full_reveal_duration`, both driven by one monotonic `now` (added 2026-11-14)
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement.**
- [x] **Step 4: Run.** Expected: PASS.
- [x] **Step 5: Commit.** Message: `feat(core): quiz round logic`.

---

### Task 11: Quiz screens

**Files:**
- Create: `apps/tv/lib/ui/quiz_screen.dart`, `apps/controller/lib/screens/quiz_screen.dart`
- Modify: `apps/tv/lib/session/session.dart`, `apps/tv/pubspec.yaml` (`flutter_svg`)

**Interfaces:**
- Consumes: `QuizRound` (Task 10), `Session.finishGame` (Task 7), `EffectLayer` (Task 8), `PackStore.get` (Task 12; until then, a test pack built in code).
- Produces:
  - When `Session` gets `StartGame(quiz, packId)`, it runs a `QuizRound` and drives `advance` from a 100 ms `Timer.periodic`. It sends:
    - `QuizQuestion` at each question
    - `QuizReveal` with per-player points at each reveal
    - `finishGame(round.totals)` when the round is done
  - TV layout:
    - the question in large type
    - the SVG (via `SvgPicture.memory`), if any
    - 4 answer tiles, each with a color and shape: ▲ `#FF4D6D`, ◆ `#22B8F0`, ● `#FFB020`, ■ `#2ECC71`
    - a countdown bar
    - "N of M answered"
    - on reveal: the correct tile highlighted and the other tiles dimmed, colored dots showing who picked what, and a mini scoreboard
  - Phone layout: the same 4 tiles with their shape and the choice text, filling the screen. After tapping, the phone shows "Locked in". On reveal it shows "+750" or "Not this time", plus its running total.
- [ ] **Step 1: Write the failing widget test.** `apps/controller/test/quiz_screen_test.dart`: given a `QuizQuestion`, it shows 4 tiles with the texts. Tapping tile 2 sends `Answer(2)` once, and a second tap sends nothing.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** both screens and the session wiring.
- [ ] **Step 4: Run.** Expected: PASS. Then play a full quiz on the emulator with 2 phones.
- [ ] **Step 5: Commit.** Message: `feat: quiz game screens`.

---

### Task 12: Pack store and upload

**Files:**
- Create: `apps/tv/lib/packs/pack_store.dart`
- Modify: `apps/tv/lib/main.dart`, `apps/tv/lib/session/session.dart`, `apps/controller/lib/screens/lobby_screen.dart`
- Test: `apps/tv/test/pack_store_test.dart`

**Interfaces:**
- Consumes: `parsePack` (Task 9), the `GameServer` `onPackUpload` hook (Task 3), `Session.hostId` (Task 6).
- Produces:
  - `class PackStore`:
    - `static Future<PackStore> load({required List<Uint8List> bundled, required Directory userDir})`. A bad user pack on disk is skipped and logged, never fatal.
    - `List<PackInfo> get infos`
    - `QuizPack? get(String id)`
    - `Future<String?> add(Uint8List bytes)` returns null on success or the error message. It stores the file as `<userDir>/<id>.pack` and replaces an existing user pack with the same id. Bundled ids can't be overwritten: "A built-in pack already uses the id 'x'. Pick another id."
  - Upload: `onPackUpload(token, body)` accepts only the current host's token. Otherwise it returns "Only the host can add packs." On success, the lobby is re-broadcast so the new pack shows up.
  - Controller: the host lobby has an "Add quiz pack" file picker (`<input type=file accept=".json,.zip">` via `package:web`). It POSTs the bytes and shows the server's message: "Added World Flags (40 questions)." on success, or the error text.
- [ ] **Step 1: Write the failing tests.**
  - `add_valid_pack_persists_and_reloads`
  - `invalid_pack_rejected_nothing_written`: the dir stays empty
  - `cannot_shadow_bundled_id`
  - `corrupt_file_on_disk_skipped_on_load`
  - `non_host_upload_rejected`: through `Session`
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** The user dir is `getApplicationSupportDirectory()/packs`.
- [ ] **Step 4: Run.** Expected: PASS. Then upload a pack from the host phone by hand.
- [ ] **Step 5: Commit.** Message: `feat: pack store and host upload`.

---

### Task 13: Bundled question packs (English + Croatian)

**Files:**
- Create in `apps/tv/assets/packs/`:
  - `general.json`, `geography.json`, `science.json`, `film-music.json` (text-only)
  - `hr-medimurje.json`, `hr-geografija.json`, `hr-povijest.json`, `hr-kultura-sport.json` (text-only)
  - `flags.zip` (with `flags/*.svg`)
  - `shapes.zip` (with `shapes/*.svg`)
- Create: `apps/tv/test/bundled_packs_test.dart`
- Modify: `apps/tv/pubspec.yaml` (assets)

**Interfaces:**
- Consumes: `parsePack` (Task 9), `PackStore.load` (Task 12).
- Produces:
  - 6 English packs with about 300 questions in total, 50 per pack. Ids: `general`, `geography`, `science`, `film-music`, `flags`, `shapes`.
  - 4 Croatian packs written in Croatian, at least 30 questions each:
    - `hr-medimurje` "Međimurje": places, kajkavian words ("What does *X* mean?"), food, customs, famous people
    - `hr-geografija` "Hrvatska – geografija"
    - `hr-povijest` "Hrvatska – povijest"
    - `hr-kultura-sport` "Hrvatska – kultura i sport"

    Use correct diacritics (č ć ž š đ). Check them on the TV and phone: the default font must render them.
  - **Stop and ask the user to review `hr-medimurje`** before marking this task done. Local facts are where mistakes are most likely.

Content rules:
- Facts must be stable: no "current" office holders or records likely to change.
- The wrong choices should be plausible.
- Flags: only flags simple enough to draw with basic shapes, such as Japan, France, Italy, Germany, Sweden, Switzerland, Greece and Bangladesh. Keep each SVG under 2 KB and use a `viewBox`.
- Shapes/logic: "how many triangles", "which comes next in the sequence", "which shape is the odd one out", with hand-written SVGs.
- Write the pack sources under `tool/packs/` and zip them with a small script (`tool/pack_zip.sh`) so they stay editable.

- [ ] **Step 1: Write the failing test.** `all_bundled_packs_valid`: every file in `assets/packs` gives `PackOk`, ids are unique, each English pack has ≥ 40 questions, each `hr-*` pack has ≥ 30, and the total is ≥ 400.
- [ ] **Step 2: Run.** Expected: FAIL (no packs yet).
- [ ] **Step 3: Write the packs and SVGs.**
- [ ] **Step 4: Run.** Expected: PASS. Also spot-check 10 random questions per pack for correctness by reading them.
- [ ] **Step 5: Commit.** Message: `content: six bundled quiz packs`.

---

### Task 14: TV polish and release install

**Files:**
- Modify: `apps/tv/lib/ui/*.dart`, `apps/tv/lib/main.dart`, `apps/tv/android/app/build.gradle*`
- Test: `apps/tv/test/dpad_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - D-pad behavior:
    - In the lobby, focusable "Quit" and "How to join" items.
    - Back (`LogicalKeyboardKey.goBack` or escape) during a game asks "End this game and return to the lobby?" with Yes and No (focus starts on No). Yes ends the game without placement points.
    - Focus is always visible: a 3 px outline in the accent color.
  - A release APK signed with the debug key, installed on the TV with `flutter install --release -d <tv>`. This is personal use, so no store signing.
- [ ] **Step 1: Write the failing test.** `back_during_game_confirms_then_returns_to_lobby`: simulate the `goBack` key, check the focus is on No, arrow to Yes, select, and check the phase is `lobby`.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** with `Shortcuts`/`Actions`/`FocusTraversalGroup`.
- [ ] **Step 4: Run all tests.** Run `flutter test` in every member. Expected: all pass.
- [ ] **Step 5: Final check on the real TV.**
  - Run `tool/build_controller.sh`, then `flutter build apk --release` and install it on the TV.
  - With at least 3 phones (iPhone Safari and Android Chrome), play one Quiz and one Curve game.
  - Lock one phone mid-game and unlock it. It must reconnect.
  - Confirm the results go back to the lobby with the session scoreboard updated.
- [ ] **Step 6: Commit.** Message: `feat(tv): d-pad navigation and release build`.
