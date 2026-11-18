# Pack Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A local tool on the Mac that lists every bundled pack in a browser page and lets the person fix answers and
add or delete questions, saving to the project's pack source files.

**Architecture:** A small Dart package `tool/pack_editor/` with a `dart:io` HTTP server on `localhost`. A pure library
(`lib/packs.dart`) finds, loads, validates and saves packs, using the parsers in `packages/core` so it applies the
TV's own rules. One plain HTML/JS page (`web/index.html`) talks to the server as JSON. No build step for the page.

**Tech Stack:** Dart 3.13 (via `fvm dart`), `dart:io`, `package:core` (path dependency), `package:test`; plain
HTML/JS.

**Spec:** `docs/specs/2026-11-18-pack-editor-design.md`

## Global Constraints

- The server binds to `InternetAddress.loopbackIPv4` only.
- Pack locations: quiz `tool/packs/hr-*.json` and `tool/packs/hr-*/hr-*.json` (folder packs); other games
  `apps/tv/assets/{objasni,koliko,blef,tkobi,kaosvi,uljez}/*.json`.
- Validation uses `parsePack` (quiz) and `ObjasniPack/KolikoPack/BlefPack/TkobiPack/KaosviPack/UljezPack.fromJson`.
- Rebuild only the edited quiz pack in `apps/tv/assets/packs/`: text pack copied, folder pack zipped with
  `zip -qrX <out>/<id>.zip .` run inside the folder. Never run `tool/pack_zip.sh`.
- Tests use temporary copies of pack files, never the real ones.
- Saving keeps the file's own layout (one question per line): an unedited save leaves the file byte-identical, and
  editing one question changes only its line. Every field the editor doesn't edit (`source`, `image`, any other key)
  stays untouched. Non-ASCII stays as UTF-8 (no `\u` escapes). (Changed 2026-11-18 from "2-space indent", lead's call:
  a reformat would rewrite whole files and clash with the content seats.)
- When a sources file can't be renumbered, the save reports a note instead of skipping silently.
- No commits by the tool. Commit the tool's own code by path. Don't commit pack edits made while testing.

## Review Focus

1. Deleting below a game's minimum (quiz 30 per the bundled test; Koliko 15 in the parser): save must be refused with
   the message, not written.
2. A file changed on disk after load (couchplay content seats): save refused with "reload", file untouched.
3. Croatian letters and quotes in text (č ć đ š ž, „ “): round-trip byte-for-byte unchanged when not edited.
4. A quiz pack with pictures: saving keeps `image` and the zip still contains its `img/`/`shapes/` files.
5. Sources renumbering when the `.sources.md` has a header paragraph before line `1.`: header kept, only numbered
   lines change.

---

### Task 1: Pack library (load, validate, save)

**Files:**
- Create: `tool/pack_editor/pubspec.yaml` (path dep `core: {path: ../../packages/core}`, dev `test`)
- Create: `tool/pack_editor/lib/packs.dart`
- Test: `tool/pack_editor/test/packs_test.dart`

**Interfaces:**
- Produces:
  - `enum Game { kviz, objasni, koliko, blef, tkobi, kaosvi, uljez }`
  - `class PackRef { Game game; String id; String title; String path; int count; }`
  - `List<PackRef> listPacks(String repoRoot)`
  - `class LoadedPack { PackRef ref; Map<String, dynamic> json; String stamp; }` — `stamp` = file's
    last-modified ms + length, as a string.
  - `LoadedPack loadPack(String repoRoot, Game game, String id)`
  - `sealed class SaveResult` with `SaveOk` and `SaveError(String message)`; `SaveStale extends SaveError`.
  - `SaveResult savePack(String repoRoot, Game game, String id, Map<String, dynamic> json, String stamp,
    {List<int> deleted = const [], int added = 0})` — `deleted`: 1-based question numbers removed (in the original
    order); `added`: how many were appended. Used only for the sources file.
  - `String renumberSources(String text, List<int> deleted, int added)` (pure, exported for tests).

- [ ] **Step 0: Check `package:core` resolves under plain Dart.** `cd tool/pack_editor && fvm dart pub get`, then a
  one-line `bin/` script importing `package:core/src/quiz_pack.dart` and `src/koliko.dart` runs with
  `fvm dart run`. If it fails because core needs Flutter, stop and tell the lead which import breaks; the lead picks
  the cheapest fix that still runs the same rules (for example importing the files by relative path).
- [ ] **Step 1: Write the failing tests** in `packs_test.dart`, each on a temp dir that copies the needed real files:
  - `lists_every_game`: `listPacks` on a copy of the repo's pack dirs returns 16 kviz packs and ≥1 for each other game;
    `hr-oblici` has `count == 50`.
  - `save_roundtrip_unchanged`: load `hr-oblici`, save with the same json and stamp → `SaveOk`, and the JSON file's
    parsed content equals the original; a string containing `čćđšž„“` survives byte-for-byte.
  - `save_rejects_invalid`: set one quiz question's `answer` to 4 → `SaveError` whose message is the
    `PackStrings` text for a bad answer; file unchanged.
  - `save_rejects_too_few`: Koliko pack cut to 14 questions → `SaveError`; file unchanged.
  - `save_stale`: touch/rewrite the file after load → `SaveStale`; file has the touched content.
  - `save_rebuilds_one_zip`: save a folder quiz pack → `apps/tv/assets/packs/<id>.zip` (in the temp tree) is newer and
    `parsePack` on it is `PackOk` with the picture files; another pack's zip mtime is unchanged.
  - `renumber_sources`: header text + lines `1.`..`4.`; `deleted: [2]`, `added: 1` → header unchanged, lines
    `1. a`, `2. c`, `3. d`, `4. (added in the editor, no source yet)`.
- [ ] **Step 2: Run** `cd tool/pack_editor && fvm dart test` — expected: FAIL (`packs.dart` symbols undefined).
- [ ] **Step 3: Implement `lib/packs.dart`.** Validate quiz packs by building the bytes the TV would load (JSON for a
  text pack; the zip of the folder for a folder pack) and calling `parsePack`; others with `fromJson` in a
  try/catch on `FormatException`, message = the exception's message. Also enforce the bundled test's quiz minimum of
  30 questions. Write the JSON to a temp file in the same folder and rename over the original.
- [ ] **Step 4: Run** `fvm dart test` — expected: all pass. Then from the repo root `cd apps/tv && fvm flutter test
  test/bundled_packs_test.dart test/pack_duplicates_test.dart` — expected: pass (real packs untouched).
- [ ] **Step 5: Commit** `git commit -- tool/pack_editor/pubspec.yaml tool/pack_editor/pubspec.lock
  tool/pack_editor/lib tool/pack_editor/test` (`feat(pack-editor): load, check and save packs`).

### Task 2: Server and page

**Files:**
- Create: `tool/pack_editor/bin/pack_editor.dart`
- Create: `tool/pack_editor/web/index.html`
- Test: `tool/pack_editor/test/server_test.dart`

**Interfaces:**
- Consumes: Task 1's `listPacks`, `loadPack`, `savePack`.
- Produces (HTTP, JSON bodies):
  - `GET /` → `web/index.html`
  - `GET /api/packs` → `[{game, id, title, count}]`
  - `GET /api/pack/<game>/<id>` → `{json, stamp}`
  - `GET /api/image/<id>/<path>` → the picture bytes from the quiz pack folder (path must stay inside it)
  - `POST /api/pack/<game>/<id>` body `{json, stamp, deleted, added}` → 200 `{ok:true, stamp}`, 409 for stale,
    422 `{message}` for invalid.
- Launch: `cd tool/pack_editor && fvm dart run bin/pack_editor.dart` prints the URL `http://localhost:8765` and opens
  it with `open`.

- [ ] **Step 1: Write the failing test** `server_test.dart` against a server started on a temp repo copy, port 0:
  `GET /api/packs` lists `hr-oblici`; `POST` with a bad answer → 422 with the message; `POST` with an old stamp → 409;
  `GET /api/image/hr-oblici/../../pubspec.yaml` → 404.
- [ ] **Step 2: Run** `fvm dart test test/server_test.dart` — expected: FAIL.
- [ ] **Step 3: Implement** `bin/pack_editor.dart` (`startServer(String repoRoot, {int port = 8765})` returning the
  `HttpServer`; `main` takes an optional `--root <dir>`, default the repo root as `../..` from the package) and `web/index.html`: packs grouped by game
  in a sidebar; the selected pack's questions as editable rows (fields per game from the spec, quiz: 4 choices with a
  radio for the right one, picture shown when `image` is set; Koliko/Blef: a `source` box); delete per row; "Dodaj
  pitanje" at the end; "Spremi" shows the server's message, or "Paket se promijenio, učitaj ponovno" on 409. UI text
  in Croatian.
- [ ] **Step 4: Run** `fvm dart test` — expected: all pass.
- [ ] **Step 5: By hand (QA)**, with `--root` on a scratch copy of the repo's pack folders, not the real ones: start the editor,
  open `hr-oblici`, `hr-fizika` (pictures), `objasni-hrana`, `hr-koliko-godine`, `uljez-hrana`; fix an answer, delete a
  question, add one, save; check the file diff and that the pack's zip opens in the TV tests. Screenshot the page.
- [ ] **Step 6: Commit** `git commit -- tool/pack_editor/bin tool/pack_editor/web tool/pack_editor/test`
  (`feat(pack-editor): local server and page`).
