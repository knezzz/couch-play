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
- Quiz: 4 choices, 20 s per question, 10 questions per round (defaults; the host can change them, Task 23). A correct answer scores 500–1000 points, depending on speed. A wrong answer or no answer scores 0.
- Curve: 60 Hz fixed tick, left/right steering, trails with random gaps, +1 point for each player you outlive. The match target is `10 × (players − 1)`, fixed when the match starts. You die on any trail, including your own older trail. Power-ups: see Task 5b.
- Session scoreboard: placement points after each game (1st = N−1, …, last = 0, where N = players in that game; everyone 0 if everyone scored 0). Scores last only for the session.
- The D-pad only moves focus and backs out of a game. A phone host runs the session.
- Dev machine: Intel Mac (x86_64). Xcode and Android Studio are installed. Flutter 3.47.7 (Dart 3.13.5) is installed via fvm. `avdmanager` needs `JAVA_HOME` set to Android Studio's bundled jbr.
- Copy rules for UI text: plain words, active voice, and errors that say how to fix the problem. All UI text is in Croatian (changed 2026-11-14, Task 16).

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
- [x] **Step 5: Re-measure on the real TV** (needs the user's adb yes for that session). Same setup as Task 5 Step 6, with power-ups on. Report the numbers to the user.
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
- [x] **Step 1: Write the failing tests.**
  - The ties case above.
  - A single player gets 1 point.
  - `quizPoints`: correct at 0 s = 1000, at 10 s = 750, at 20 s = 500, at 25 s = 500. Wrong = 0.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement.** When Curve reaches `matchOver`, call `finishGame(sim.scores)`.
- [x] **Step 4: Run.** Expected: PASS.
- [x] **Step 5: Commit.** Message: `feat: placement scoring and results`.

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
- [x] **Step 1: Write the failing test.** `play_confetti_then_clears`: pump an `EffectLayer` and call `play(confetti)`. Particles appear, and after 3 s nothing is left in the tree. With `disableAnimations: true`, there are no animation tickers.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** the effects with `CustomPainter` and one `AnimationController` each. No new dependencies.
- [x] **Step 4: Run.** Expected: PASS.
- [x] **Step 5: Commit.** Message: `feat(core): shared effects on tv and phone`.

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
  - Phone layout: the same 4 tiles with their shape and the choice text, filling the screen. After tapping, the phone shows "Locked in" on a neutral screen that never shows which tile was picked (changed 2026-11-14: dimming the other tiles gave the answer away). On reveal it shows "+750" or "Not this time", plus its running total.
- [x] **Step 1: Write the failing widget test.** `apps/controller/test/quiz_screen_test.dart`: given a `QuizQuestion`, it shows 4 tiles with the texts. Tapping tile 2 sends `Answer(2)` once, and a second tap sends nothing.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** both screens and the session wiring.
- [x] **Step 4: Run.** Expected: PASS. Then play a full quiz on the emulator with 2 phones.
- [x] **Step 5: Commit.** Message: `feat: quiz game screens`.

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
- [x] **Step 1: Write the failing tests.**
  - `add_valid_pack_persists_and_reloads`
  - `invalid_pack_rejected_nothing_written`: the dir stays empty
  - `cannot_shadow_bundled_id`
  - `corrupt_file_on_disk_skipped_on_load`
  - `non_host_upload_rejected`: through `Session`
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement.** The user dir is `getApplicationSupportDirectory()/packs`.
- [x] **Step 4: Run.** Expected: PASS. Then upload a pack from the host phone by hand.
- [x] **Step 5: Commit.** Message: `feat: pack store and host upload`.

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
- [x] **Step 1: Write the failing test.** `back_during_game_confirms_then_returns_to_lobby`: simulate Back as Android TV sends it, `binding.handlePopRoute()` (changed 2026-11-14: the remote's Back arrives as a system pop, not a key; also cover Back during Curve, where Flame takes key events), check the focus is on No, arrow to Yes, select, and check the phase is `lobby`.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** with `Shortcuts`/`Actions`/`FocusTraversalGroup`.
- [x] **Step 4: Run all tests.** Run `flutter test` in every member. Expected: all pass.
- [ ] **Step 5: Final check on the real TV.**
  - Run `tool/build_controller.sh`, then `flutter build apk --release` and install it on the TV.
  - With at least 3 phones (iPhone Safari and Android Chrome), play one Quiz and one Curve game.
  - Lock one phone mid-game and unlock it. It must reconnect.
  - Confirm the results go back to the lobby with the session scoreboard updated.
- [ ] **Step 6: Commit.** Message: `feat(tv): d-pad navigation and release build`.

---

### Task 15: Design pass to the reference screens (added 2026-11-14, user request)

**Files:**
- Modify: `apps/tv/lib/ui/lobby_screen.dart`, `quiz_screen.dart`, `results_screen.dart`, `apps/controller/lib/screens/*.dart`, `packages/core/lib/src/effects.dart` (confetti)
- Reference: `docs/design/couchplay-screens/*.dc.html` (HTML mockups; the px values are TV 1920×1080 and phone 390×844 logical px)

**Interfaces:** none new. Layout and style only; no protocol or game-logic changes.

- [x] **Step 1: TV lobby** (Main.dc.html): title, QR on a white card with a 4-module quiet zone, URL caption + one-line URL, How to join / Quit buttons; player chips as a 2-column pill grid with HOST / AWAY / BOT pill badges; "Players · N of 8"; a scoreboard card; "Waiting for <host> to pick a game."
- [x] **Step 2: TV quiz + reveal** (TvQuiz, TvReveal): header row (question N of M · pack title · answered count), accent progress bar, 80 px question with the picture card on the right, 168 px tiles; reveal: the correct tile large with a white outline, ✓ and its voters; the wrong tiles as a row of 25 % tints with their voters; a scores panel with +points.
- [x] **Step 3: TV results** (TvResults): "<name> wins!", the winner row in their color, the others on surface rows with +session points, a "Tonight" session panel, a back-to-lobby countdown bar. Confetti: few large pieces (about 16–24, 22×36 px at 1080p), so it stays cheap on the TV GPU (it cost about 1/3 of frames for 2.5 s on the BRAVIA).
- [x] **Step 4: Phone** (PhoneJoin, PhoneLobby, PhoneKick, PhoneQuiz, PhoneReveal): background #14141E (as the TV); join helper text; host lobby with your own chip on top and "Others · N" below (you are not listed twice), 56 px bot steppers, Remove buttons that open the bottom sheet "Remove <name>?" (Remove / Keep); the quiz header with your total; after a tap, one neutral "Locked in. Watch the TV." screen that never shows the pick (no dimmed tiles, no shape or color of the answer); the reveal as a full-color result screen.
- [x] **Step 5: Check.** All tests pass in every member; update widget tests that pinned old layout. QA compares each screen with its mockup on a release/profile build (macOS + Chrome) and lists differences; check-design signs off. The person sees it on the TV at their next session.
- [x] **Step 6: Commit** by path: `style: design pass to the reference screens`.

---

### Task 13b: Croatian content, harder and verified (added 2026-11-14, user request)

- [x] **Step 1:** Verify every question in `hr-medimurje`, `hr-geografija`, `hr-povijest` and `hr-kultura-sport` online (hr.wikipedia.org, enciklopedija.hr, official sites); a `tool/packs/<id>.sources.md` per pack lists the source for each question. Fix or drop what can't be confirmed.
- [x] **Step 2:** Make the four Croatian packs harder for locals: at most about a third easy questions; plausible wrong answers.
- [x] **Step 3:** Add Croatian versions of the six English packs: ids `hr-opce-znanje`, `hr-zemljopis-svijeta`, `hr-znanost`, `hr-film-glazba`, `hr-zastave`, `hr-oblici` (the flags and shapes versions reuse the same SVGs). Natural Croatian, not word-for-word; swap culture questions only where the English one makes no sense in Croatian.
- [ ] **Step 4:** The bundled pack test covers the new ids (≥ 30 questions each). The user reviews `hr-medimurje` (and may look at the others) before this is done.
- [x] **Step 5: Commit** by path.

---

### Task 16: Croatian user interface (added 2026-11-14, user request)

Starts after Task 15 (same screens).

- [x] **Step 1:** Every user-facing string on the TV and the phone in Croatian, following the copy rules (plain words, active voice, errors that say how to fix the problem): lobby, join, quiz, results, Curve, dialogs, kick, pack upload, "Locked in", waiting and error messages, and the pack validation messages from Task 9/12 (update their tests and `docs/quiz-pack-format.md`). No language switch; Croatian only. No i18n framework: one strings file per app is enough.
- [x] **Step 2:** The person (a native speaker) reads the full list of strings before it ships: put them in one file they can review.
- [x] **Step 3:** Tests updated and green in every member; QA checks every screen in a release/profile build, including the longest Croatian strings fitting at 1080p and on a 390-wide phone.
- [x] **Step 4: Commit** by path: `feat: croatian interface`.

---

### Task 17: Show active power-ups and their time left (added 2026-11-14, user request)

The person approved the reference screens and wants Curve to match them, with the active power-ups easy to see.

**Files:**
- Modify: `packages/core/lib/src/curve_sim.dart` (read-only access to the running effects), `apps/tv/lib/ui/curve/curve_game.dart`
- Test: `packages/core/test/curve_powerups_test.dart`

**Interfaces:**
- Produces: a read-only way for the renderer to get, for each running effect, the kind, the affected players (or everyone) and the fraction of time left (1 → 0). The builder picks the shape.
- TV rendering:
  - **Wrap:** a white border around the arena while wrap runs. It shrinks along the edge as the time runs out (like a timer bar wrapped around the arena). When it is gone, the walls are back. A second wrap pickup restarts it full.
  - **Effects on players** (speed, thin, ghost, slowed, fat): next to each affected head, the power-up's icon in its color (green = you, red = others, blue = everyone) with a ring that drains as the time runs out. Several effects on one line sit side by side. Readable from the couch at 1080p; doesn't hide the line's path ahead.
  - **Clear:** instant, no timer.
  - Colors and type follow the reference-screen tokens (spec, Visual style).
- Cost: still cheap on the TV (one draw per effect per frame, no per-frame allocation, no text layout per frame).

- [x] **Step 1: Failing tests:** `effect_time_left_drains_to_zero` (a picked-up effect reports 1.0, then about 0.5 halfway, then is gone after `effectSeconds`); `second_pickup_restarts_time_left`; `wrap_reports_everyone`.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** the sim getter, then the renderer.
- [x] **Step 4: Run.** Expected: PASS in every member. QA on a macOS release build: each of the 7 power-ups picked up, the indicator seen and seen running out; the wrap border shrinks and the walls come back when it is gone (a line hits the wall after it).
- [x] **Step 5: Commit** by path: `feat(tv): show active power-ups and time left`.
- [ ] **Step 6:** The person sees it on the TV at their next session (with the frame times).

---

### Task 18: Keep the TV awake while CouchPlay is open (added 2026-11-14, user request)

The TV goes into its screensaver during a game: players use their phones, so the TV sees no remote input.

- [x] **Step 1:** Keep the screen on while CouchPlay is in the foreground (lobby, games and results), and let the TV sleep normally once the app is closed or in the background. Smallest fix: `FLAG_KEEP_SCREEN_ON` on the activity window in `MainActivity.kt`; no new package.
- [ ] **Step 2: Check.** All tv tests pass. On the real TV (next session, with the person's adb yes): leave a game or the lobby running longer than the TV's screensaver delay; the screensaver doesn't start. After leaving the app, it does.
- [x] **Step 3: Commit** by path: `fix(tv): keep the screen on while the app is open`.

---

### Task 19: Curve steering stops reacting on the phone (added 2026-11-15, user report)

The person: "Sometimes the curve game stops reacting to buttons on phone (often just one button stops)." The cause is not known yet.

- [x] **Step 1: Reproduce and find the root cause** (systematic debugging, no guess-patches). Check at least: a press whose release is lost (finger slides off the button, a second finger, pointer cancel, the page scrolling or zooming); both buttons held at once; iOS Safari and Android Chrome; the TV side (the input state for that player, messages arriving after a reconnect or a new round).
- [x] **Step 2: Failing test** for the cause found, then fix it at the root.
- [x] **Step 3: Check.** All tests pass. QA on a release build with a real phone browser: hold, release, slide off, two fingers, both buttons, many rounds; no stuck or dead button.
- [x] **Step 4: Commit** by path.

---

### Task 20: The game keeps going when the host leaves; anyone can come back in (added 2026-11-15, user request)

- [x] **Step 1: Failing tests** (session): the host disconnects mid-Curve and mid-Quiz: the game keeps running and the next-oldest connected human is host (their phone gets the host controls). The old host reconnects: back in the same game (Quiz from the next question, Curve from the next round), missed questions or rounds score 0, earlier points kept; the new host stays host until the game ends. The same for a non-host player.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement.** Today a Curve player who disconnects is out for the whole match (`_dropFromGame`), and a Quiz player is removed from the round; change that to "out for this round/question, back in after reconnecting". A 2-player Curve match that drops to 1 pauses for up to 30 s ("Čekamo da se <ime> vrati" on the TV) and ends only if nobody comes back; a 2-player Quiz keeps going with the one left (person, 2026-11-15). A game still ends when no human is connected. The person saw the stop in a 2-person Quiz too: reproduce that case. A Curve match ended by the 30 s wait keeps its scores (ties included). When nobody is connected, Quiz and Curve pause for 30 s ("Čekamo da se igrači vrate") instead of ending at once.
- [x] **Step 4: Run.** Expected: PASS. QA on macOS release with 3 phones: close the host's tab mid-Curve and mid-Quiz, keep playing, reopen it.
- [x] **Step 5: Commit** by path.

---

### Task 21: Croatian packs only, and as big as they can get (added 2026-11-15, user request)

The person: "Let's just have Croatian quizzes for now. Increase general knowledge questions for all. Use existing pub quiz and Potjera data if you can find them." Asked how big: "all of them as big as you can find questions".

- [x] **Step 1: Bundle only the Croatian packs.** Remove the six English packs from `apps/tv/assets/packs/` (keep their sources in `tool/packs/`). Update `bundled_packs_test.dart` and `pack_store_test.dart`. The default pack stays `hr-opce-znanje`.
- [x] **Step 2: Research sources.** Look for Croatian pub-quiz (kviz) question sets and Potjera (HRT) material online. Use them for topics, style and difficulty. Copy question text only where the licence allows it (the repo is public), and record the licence; otherwise write our own wording of the verified fact. Report what was found and under what licence.
- [x] **Step 3: Grow every Croatian pack**, Opće znanje first and most (aim for several hundred), then the others (aim for 100+ each where verified facts allow). Same rules as Task 13b: every question verified with a source in the pack's `.sources.md`, stable facts only, no duplicates within or across packs, plausible wrong answers, at most about a third easy. Commit in batches so the TV gets bigger packs early.
- [x] **Step 4: Check.** The bundled pack test passes; no duplicate questions (a test or a check script); the pack files still load fast on the TV (size noted).
- [ ] **Step 5:** New Međimurje questions join the person's review of that pack (Task 13).

---

### Task 22: Photo questions, and pictures as big as possible on the TV (added 2026-11-15, user request)

The person: "Also add some questions like what is this city and show an image. Add image questions as well. Update TV UI to show as much of image as possible."

**Files:**
- Modify: `packages/core/lib/src/quiz_pack.dart` (+ tests), `docs/quiz-pack-format.md`, `packages/core/lib/strings.dart` (the image error message), `apps/tv/lib/ui/quiz_screen.dart` (+ the reveal), `tool/pack_zip.sh` if needed
- Content: `tool/packs/*.json`, `tool/packs/<id>.sources.md`, the image files

- [x] **Step 1: Format (core).** `image` may be `.svg`, `.jpg`/`.jpeg`, `.png` or `.webp`. Keep the existing size limits (5 MB pack, 20 MB unzipped) unless they block the content; say so first if they do. Failing tests first: a zip with a `.jpg` loads; an unknown extension is rejected with the Croatian message. Update the doc.
- [x] **Step 2: TV layout.** On a picture question, the picture gets as much of the screen as the layout allows: the question text and the answer tiles shrink to fit around it, and the picture is shown whole (fit, never cropped). The same on the reveal. Text-only questions keep today's layout. QA on a macOS release build with a tall photo, a wide photo and an SVG.
- [x] **Step 3: Content.** Photo questions in the Croatian packs: "Koji je ovo grad?" (Croatian cities in `hr-geografija`, world cities in `hr-zemljopis-svijeta`), plus landmarks, places and other picture questions where they fit (Međimurje too; those join the person's review). Only freely licensed photos (Wikimedia Commons or similar); the `.sources.md` lists author, licence and URL per photo. Re-encode to a sensible size (e.g. 1280 px on the long side) so packs stay inside the limit. No photo that shows the answer as text (signs, captions). Packs with pictures become `.zip`.
- [x] **Step 4: Check.** All tests pass; the bundled pack test loads every picture; QA sees several photo questions on the release build.
- [x] **Step 5: Commit** by path.

---

### Task 23: Host game settings (added 2026-11-16, user request)

The person: "Can we have host set the quiz duration and wait times between the rounds?" Chosen: time per question, questions per game, time between questions, and the pause between Curve rounds.

**Interfaces:**
- The phone host's lobby gets a small settings area (steppers, 56 px+ touch targets, Croatian, on the reference tokens):
  - Quiz: time per question 10–60 s in 5 s steps (default 20); questions per game 5–30 in 5s (default 10; never more than the pack has); time between questions (the reveal) 2–15 s (default 4).
  - Curve: pause before each round (the countdown with names and arrows) 1–10 s (default 2).
- The TV is authoritative: the host sends the values, the TV clamps them, keeps them for the session and shows them to everyone in the lobby. Only the host can change them, and only in the lobby. They apply from the next game.
- Speed scoring stays 500–1000, scaled to the chosen time per question.
- The TV remembers the settings across app restarts (a small JSON file next to the user packs, read and clamped at start; person, 2026-11-16). The Curve mode from Task 24 is remembered the same way.

- [x] **Step 1: Failing tests:** protocol round-trip of the settings message; the session clamps out-of-range values and ignores a non-host; a quiz uses the set count, limit and reveal; speed points scale to the set limit; a Curve match uses the set countdown; changes mid-game apply only from the next game.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** core (protocol, `QuizRound`/`CurveConfig` already take these values), TV session, phone lobby UI; add the strings to the strings files and `docs/strings-hr.md`.
- [x] **Step 4: Run.** Expected: PASS in every member. QA on macOS release + the release web controller: set each value to its min and max and see it in play; a non-host phone sees the values but can't change them; fit at 360–390 px.
- [x] **Step 5: Commit** by path.

---

### Task 24: Curve modes and power-up changes (added 2026-11-16, user request)

The person: "For curve add more modes (Chaos where a lot of powerups spawn, balanced current one, and peaceful with no powerups, or some with just powerups for you, stuff like that). Also speed down should be you only powerup, and speed up should speed up everybody else. Make the thickness powerup last a little longer."

Builds on Task 23's host settings (same lobby settings area, same session-only rules).

**Interfaces:**
- Power-ups: `speed` (on you, green) becomes **speed up everyone else** (red); `slowOthers` (red) becomes **slow down you** (green). Rename the enum values to match (e.g. `speedOthers`, `slow`). Icons and colors follow (green = you, red = others); the active-effect indicators from Task 17 follow too.
- Thin and fat last a little longer than the other effects (about 1.5× `effectSeconds`; the builder picks the value).
- Curve mode, picked by the host in the lobby, applies from the next match:
  - **Kaos:** power-ups spawn much more often, and more on the board at once.
  - **Uravnoteženo:** today's rate. Default.
  - **Mirno:** no power-ups.
  - **Samo za tebe:** only green power-ups (slow you, thin, ghost) spawn.
  The mode is a set of `CurveConfig` values (spawn interval, max on board, allowed kinds); the builder tunes Kaos so it is fun, not unplayable. Bots keep working in every mode.
- Croatian names as above (the person may rename them); strings in the strings files and `docs/strings-hr.md`.

- [x] **Step 1: Failing tests:** the swapped speed/slow effects hit the right players; thin/fat last longer than the rest; Mirno spawns nothing; Samo za tebe spawns only green kinds; Kaos spawns more than Uravnoteženo over the same seeded time; the session passes the host's mode to the match; a non-host can't change it.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** core (config, kinds), TV (icons, indicators, session), phone (mode picker in the host settings).
- [x] **Step 4: Run.** Expected: PASS in every member. QA on macOS release + release web controller: each mode played with bots; the new speed/slow seen working with their colors and indicators; thin/fat run longer; Kaos frame times still fine.
- [x] **Step 5: Commit** by path. Kaos gets its own frame-time check on the real TV at the next session.

---

### Task 25: Power-up changes from the TV session (added 2026-11-16, user request)

The person, after playing on the TV: "thick powerups should stack; when you are a ghost you don't leave a line; remove thin powerup, add something else." Replacement chosen: reversed steering for everyone else.

- Fat stacks: each fat pickup makes the others' lines fatter again (with a sensible cap, e.g. 3 stacks); each stack keeps the longer fat duration. The Task 17 indicator shows the stack count.
- Ghost leaves no line while it lasts (a gap in your trail, nothing painted, nothing in the grid); it still can't pass walls.
- Thin is removed (enum, icon, bots, modes, tests).
- New: **reverse others** (red): everyone else's left and right swap for `effectSeconds`; stacks by restarting its timer. Icon and indicator like the others. Bots handle it (their steering is reversed too). Samo za tebe keeps only green kinds (slow, ghost).

- [x] **Step 1: Failing tests:** fat twice is fatter than once (and capped); ghost paints nothing and leaves no grid cells; no thin kind spawns; reverse others swaps left/right for the others only, then expires.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** core, TV icons/indicators, bots.
- [x] **Step 4: Run.** Expected: PASS in every member. QA on macOS release: each change seen.
- [x] **Step 5: Commit** by path.

---

### Task 26: Sound effects on the TV (added 2026-11-16, user request)

The person: "Add sound effects." TV only (person's choice); phones stay silent.

- Sounds: Curve countdown beeps, power-up pickup, crash, round win, match win; quiz question start, last-5-seconds tick, reveal right/wrong, winner fanfare; lobby join blip.
- Freely licensed (CC0) or made for the project; list each file's source and licence in `apps/tv/assets/sounds/SOURCES.md`. Small files (short OGG/WAV).
- Use an existing small audio package only if Flutter has none built in; low latency on Android TV; sounds must never stall the 60 Hz game loop. Preload at start.
- [x] **Step 1:** pick and add the sounds; a failing test that the session triggers the right sound for each event (through a fake player).
- [x] **Step 2:** implement; tests pass.
- [ ] **Step 3:** QA on macOS release (hear each one; nothing too loud); then on the real TV with the person (latency, volume, frame times).
- [x] **Step 4: Commit** by path.

---

### Task 27: Game carousel and details on the host's phone, mirrored on the TV (added 2026-11-16, user request)

The person: "Also have the host select a game from the carousel. When game is selected show details view with settings and show on TV. Then you click on play game."

Replaces Task 23's settings area: the settings move into each game's details.

- **Phone (host):** the games as a horizontal carousel of big cards (Kviz, Curve; name, one-line description, an icon or picture). Tap → details: description, that game's settings (Kviz: pack, time per question, questions per game, time between questions; Curve: mode, pause before each round), and a large "Igraj" button. Back → carousel. Reference tokens; 56 px+ targets; fits 360–390 px.
- **Phone (others):** "<host> gleda: Kviz" (or similar), read-only.
- **TV:** while the host is on a game's details, the lobby shows that game's card with its current settings, large enough to read from the couch (players and QR stay visible). On the carousel or Back, the plain lobby. Settings changes show on the TV at once.
- **Protocol:** the host's current selection (none / quiz / curve) goes to the TV; the TV is authoritative and broadcasts it with the settings. Start stays host-only.
- The TV lobby settings line from Task 23 goes away if the game card replaces it (builder's call, say which).

- [x] **Step 1: Failing tests:** protocol round-trip of the selection; only the host can select; the TV lobby shows the selected game's card and its settings; a non-host phone sees the selection read-only; Igraj starts the selected game with its settings.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** core protocol, TV session + lobby, phone carousel/details; Croatian strings into the strings files and `docs/strings-hr.md`.
- [x] **Step 4: Run.** Expected: PASS in every member. QA on macOS release + release web controller: the whole flow, settings mirror on the TV, Back, non-host view, fit at 360–390 px, D-pad still fine on the TV lobby.
- [x] **Step 5: Commit** by path.

---

### Task 28: Six new packs and more picture questions (added 2026-11-16, user request)

The person: "Put more questions with images. Dodaj umjetnost, psihologija, ljudsko tijelo. I dodaj neki kviz sa memeovima. I fiziku i matematiku dodaj kao opciju."

- New Croatian packs, each a choice in the pack list (ids `hr-umjetnost`, `hr-psihologija`, `hr-ljudsko-tijelo`, `hr-memeovi`, `hr-fizika`, `hr-matematika`), aiming at 100+ questions each, same rules as Tasks 13b/21 (a source per question, stable facts, our own wording, plausible wrong answers, mostly not easy, no duplicates across packs; the duplicate test covers them).
  - Umjetnost: lots of pictures: public-domain artworks from Wikimedia Commons ("Tko je naslikao ovu sliku?", style, period), Croatian art included.
  - Ljudsko tijelo: pictures where they help (freely licensed diagrams, or SVG drawn for the project).
  - Fizika and Matematika: SVG diagrams where they help (a circuit, a graph, a shape); questions answerable in your head in 20 s.
  - Memeovi: text questions about memes (where it came from, the catchphrase, the year, the film or show behind it). A meme picture only if it is freely licensed on Commons or similar; most meme images are copyrighted, and the repo is public.
  - Psihologija: well-established findings and terms, not pop myths.
- More picture questions in the existing packs where a picture makes a better question (Povijest: people, buildings; Kultura i sport: athletes, venues; Znanost: animals, plants; Film i glazba: only freely licensed images), with licences in the `.sources.md` as in Task 22. Keep every pack inside the 5 MB limit.
- [x] Check: bundled pack and duplicate tests pass; the new packs show in the pack list; pack sizes noted.

---

### Task 29: Player characters (added 2026-11-16, user request)

The person: "Add a way for players to choose a character. Show characters on TV as well." Chosen: drawn animals; one per player.

- About 16 original animal faces (fox, owl, frog, bear, …) drawn for CouchPlay as simple bold SVGs in `packages/core` (shared by TV and phone), tinted with the player's color, readable at small sizes. No copies of existing characters.
- Join screen: a grid of characters, a random free one preselected; taken ones greyed out. In the lobby a player can change theirs. The TV is authoritative (a taken pick is refused, the phone shows why). Reconnect keeps it. Bots get a free one.
- TV shows the character next to the name everywhere players appear: lobby chips, quiz header/scores/reveal voters, results, session board, Curve countdown (the dot stays the line head; the character goes with the name label).
- Phone shows your own character in the header.

- [x] **Step 1: Failing tests:** protocol round-trip of the pick; the TV refuses a taken character; reconnect keeps it; bots get a free one; the lobby/results widgets show the character.
- [x] **Step 2: Run.** Expected: FAIL.
- [x] **Step 3: Implement** core (SVGs + protocol), TV session + screens, phone join/lobby; strings into the strings files and `docs/strings-hr.md`.
- [x] **Step 4: Run.** Expected: PASS in every member. QA on macOS release + release web: 8 players and bots, every screen with characters, fit at 360–390 px, characters readable on the TV.
- [x] **Step 5: Commit** by path.

---

### Task 30: Console home and full-screen games (added 2026-11-17, user request)

Reference: canvas page "Konzola i Vukodlak", `V2Home.dc.html` (and `V2Quiz.dc.html` for the full-screen look). The spec's "Console redesign".

- [x] **Step 1:** TV home replaces the lobby layout: one game full screen with its background art, big centred title, description and current settings; neighbours peek at the edges; ◀ ▶ / OK / ▼ / Back on the remote; the same selection from the host's phone (Task 27's selection protocol). QR + address top left, characters top right. Background art drawn in code (no new assets unless licensed and credited). Light animation where cheap; respects reduced motion.
- [x] **Step 2:** games full screen (no side panels): quiz and results first; Curve already is.
- [x] **Step 3:** tests (widget: home shows the selected game, ◀ ▶ changes it, phone selection mirrors); QA on macOS release; frame times on the TV next session.
- [x] **Step 4: Commit** by path.

### Task 31: Quiz ticker (added 2026-11-17, user request)

Reference: `V2Quiz.dc.html`.
- [x] 20-segment bar along the top losing one per second (red in the last 5), no ring countdown (person, 2026-11-17), ticking sound for the whole question, faster in the last 5 s. Follows the host's time per question. Tests + QA; commit.

### Task 32: Sound in every game and the menus (added 2026-11-17, user request)

- [ ] Menu move/confirm clicks on the TV home; quiz ticking (Task 31); Curve as Task 26; Vukodlak: night ambience, howl, rooster, vote bell, drum. Self-made or CC0, listed in `apps/tv/assets/sounds/SOURCES.md`; never stalls the game loop; mixed below talking volume. Tests through the fake player; QA by ear on the TV.

### Task 33: Vukodlak (added 2026-11-17, user request)

Reference: canvas page "Konzola i Vukodlak" (`Village.dc.html`, `V2WolfNight/Day/Vote`, `V2PhoneRole`, `V2PhoneNight`, `V2PhoneVote`, `V2PhoneWolfSettings`, `V2PhoneWolfRolesPick`, `V2PhoneRolesInfo`, `WolfRoles.dc.html`), and the spec's "Vukodlak".

- [ ] **Step 1: Core (pure Dart, tests first):** roles and teams; the mix draw from the enabled roles and player count (seeded); night resolution (wolf choice by agreement/majority, protection, bodyguard, herbalist cure/poison, elder, alpha conversion, lovers); day vote (mayor double, fool, hunter's shot, tramp win); win checks; hidden-roles option. A test per role rule.
- [ ] **Step 2: Protocol + session:** game kind `vukodlak`, host settings (possible roles, hidden roles, discussion time), private per-phone messages (role, night prompt, results) that never go to other phones; 5–8 humans, no bots.
- [ ] **Step 3: TV:** the animated village (houses in a circle, story and clock in the square, closed house with blood and a crow for players who are out), night/morning/vote/end screens (at night only the houses of players still on their task are lit; added 2026-11-17); story lines in Croatian (a content seat writes varied lines for each event).
- [ ] **Step 4: Phones:** hold-to-see role; one grey night screen for every role (roles with no night action get a simple sum in the same list; added 2026-11-17); vote; host settings with the possible-roles screen; everyone's "possible roles" list.
- [ ] **Step 5: Check:** tests in all members; QA on macOS release with 5–8 browser phones: a full game for several role mixes; nothing on a phone (colour, layout, timing) reveals a role; review checks that no private message reaches the wrong phone.
- [ ] **Step 6: Commit** by path.

---

### Task 34: New power-up icons and ring-only active effects (added 2026-11-17, user choice)

Reference: canvas page "Curve pojačanja": icons version **A** (`PuIcons.dc.html`), active effects option **1** (`PuActive.dc.html`).

- [x] **Step 1:** Redraw the 7 power-up glyphs in `curve_game.dart` as version A (snail, ghost, lightning, thin-over-thick, opposite arrows, broom, arrow through the edge), ink on the green/red/blue disc, readable at board size from the couch. Same in the power-up sheet if one exists in the app.
- [x] **Step 2:** Replace the Task 17 indicator (icon + ring beside the head) with rings only: one ring per active effect, centred on the head, in its color (green on you, red from others), draining as time runs out; several effects as concentric rings, outer = longest left. Fat stacks: keep a small dot per stack on its ring. Wrap keeps the white border.
- [x] **Step 3:** Update the pixel tests that pinned the old indicator; QA on macOS release; frame times next TV session.
- [x] **Step 4: Commit** by path.

---

### Task 35: Uljez, the hidden-word game (added 2026-11-17, user request)

Reference: canvas page "Uljez"; the spec's "Uljez". Same privacy rules as Vukodlak (hold to see, same screen for everyone, private messages only to their phone).

- [ ] **Step 1: Core (tests first):** pairs, the draw (who is the impostor, which side of the pair), clue turn order, vote (plurality; tie = nobody out), the impostor's guess (4 options: the right word + 3 decoys from the same pack), wins, scoring into placement points.
- [ ] **Step 2: Protocol + session:** game kind `uljez`, host settings (pack, discussion time, 1 or 2 impostors at 7–8), private word per phone.
- [ ] **Step 3: TV:** players around a table, whose turn and the clock, vote result, both words at the end; console look (Task 30).
- [ ] **Step 4: Phones:** hold-to-see word, vote, the impostor's guess; host settings in the game's details.
- [ ] **Step 5: Content:** Croatian word-pair packs (similar but different pairs; at least 6 themes, 40+ pairs each; no offensive pairs).
- [ ] **Step 6: Check:** tests in all members; QA with 3–8 browser phones; review of private messages. Commit by path.

Both new games (Vukodlak, Uljez) appear on the console home (Task 30) as their own cards.

---

### Task 36: Two new power-ups and the speed swap back (added 2026-11-17, user request)

The person: "Cheese, one where you are getting a lot of holes. 90 deg, where others can turn only in 90 deg angles. Swap speedups again: speed up is you only, slow down is others."

- **Speed and slow, both ways (person, 2026-11-17, replacing the swap back):** four power-ups: speed up you (green), speed up others (red), slow down you (green), slow down others (red). Lightning and snail on the matching disc colour.
- **Cheese (green, on you):** while it lasts your trail gets many gaps (much more often and longer than the normal random gaps). Icon in the version-A style: a cheese wedge with holes.
- **Square turns (red, on everyone else):** while it lasts, their steering turns in sharp 90° steps (a held button turns 90° once, then goes straight until pressed again). Icon: a right-angle arrow. Bots cope (they steer in 90° steps too).
- Both get the ring-only active indicator (Task 34) and spawn in Kaos/Uravnoteženo; Samo za tebe = speed up, slow down, ghost, cheese. Effect durations: the default `effectSeconds` unless it plays badly.

- [ ] **Step 1: Failing tests:** speed up only on the picker, slow down only on the others; cheese gives far more trail gaps than normal and no gaps after it ends; square turns: a held button turns exactly 90° once, then straight; only the others are hit; bots don't crash immediately under square turns.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** core, TV icons/rings, bots, mode lists.
- [ ] **Step 4: Run.** Expected: PASS. QA on macOS release: each seen working.
- [ ] **Step 5: Commit** by path.

### Task 37: Design-audit decisions (added 2026-11-17, user choices)

- [ ] Curve: after each round, show the current scores (faces, points, target) for a few seconds before the next countdown; no bar during play.
- [ ] Home: a small "Večeras" strip with the evening's totals along the bottom after the first game.
- [ ] Power-up legend: ▼ on the Curve card on the home and the host's Curve details on the phone: every power-up, its icon, one line.
- [ ] Fat icon: keep the two diagonal bars.
- [ ] Vukodlak night: keep the shared "Iskoristi posebnu moć (ako je imaš)" switch (PM).

---

### Task 38: The person's open answers (added 2026-11-17)

- [ ] **Placement points:** 1st = N−1 … last = 0; a game where everyone scored 0 gives everyone 0. Update the session tests and the results/"Večeras" text.
- [ ] **Back on the results screen:** closes the results and moves on (next round/game, or the home screen when the game is over). A remote test.
- [ ] **hr-medimurje (Task 13 review):** approved. Dialect-word questions no longer name the village ("u selu X"), and the easy words go: keep only words a local would have to think about. Mark the easy ones in the sources file and drop or replace them; the pack stays ≥ 30 questions and the tests pass.

