# Pack editor design

Approved by the person on 2026-11-18. Rig: web-editor (PM `product-pm@web-editor`).

## Why

The person wants to go through the question packs in the app, check the answers, fix wrong ones, and delete or add
questions, without hand-editing JSON. Changes reach the TV with the next install.

## What it is

A local tool on the Mac. One command starts it, and it opens a page in the browser on `localhost`.

- **Shows** every bundled pack, grouped by game: Kviz (all `hr-*` packs, from `tool/packs/`), Objasni, Koliko?,
  Blef, Tko bi?, Kao svi and Uljez (from `apps/tv/assets/<game>/`). Each pack lists its questions. A quiz question
  with a picture shows the picture.
- **Edit:** question text and answers. Quiz: the 4 choices and which one is right. Koliko?: number and unit. Blef: the
  answer. Objasni, Tko bi?, Kao svi: the word or prompt. Uljez: both words of the pair.
- **Delete** a question. **Add** a question (text only, no picture) at the end of a pack.
- **Save** writes the pack's source JSON. Before writing, it:
  - checks the pack with the same rules the TV uses (the pack parsers in `packages/core`); a pack that fails is not
    saved and the message is shown;
  - re-reads the file, and refuses with "reload" if it changed since it was loaded (the couchplay content seats edit
    the same files).
- For a quiz pack, after saving it also rebuilds **only that pack's** file in `apps/tv/assets/packs/` (a text pack is
  copied, a folder pack is zipped with the same `zip -qrX` command as `tool/pack_zip.sh`). Never runs the whole
  `pack_zip.sh`: it rewrites every pack.
- **Sources:** where a quiz pack has `tool/packs/<id>.sources.md` with numbered lines in pack order, deleting
  question N removes line N and renumbers the rest; adding appends `N. (added in the editor, no source yet)`.
  Koliko? and Blef questions carry a required `source` field (their parsers reject a question without one), so the
  editor shows it as a text box on those questions. Nothing else about sources.

## Not in it

New packs, adding pictures, editing sources or credits, sending anything to the TV, English packs, committing. The
person (or a seat they ask) commits edits by path.

## Constraints

- Everything stays on the Mac; the server listens on `localhost` only.
- Keep the existing pack tests green after an edit (`apps/tv/test/*pack*_test.dart`: bundled packs, duplicates,
  per-game loads).
- Field names per game are what the files use today (`questions`, `words`, `prompts`, `pairs`; Koliko `answer` +
  `unit`; Blef `answer`; optional `source` on a question is kept as is).
- The couchplay PM (`product-pm@couchplay`) is told before any build step writes a pack file for testing; tests write
  to temporary copies, not the real packs.

## Approaches considered

- **A. Editor on the TV** (edits saved to the TV, TV accepts uploads for every game): rejected by the person; edits
  would not reach the project.
- **B. Local editor on the Mac editing the project files** (chosen by the person).
- **C. Both:** twice the work; only if B is not enough.

## Left to the builder

- Server and page tech. PM's default: a small Dart program (`dart:io` server) plus one plain HTML/JS page, no build
  step. Risk to check first: `packages/core` depends on Flutter; the server needs the pure-Dart pack parsers without
  `dart:ui`. If it can't import them, choose the cheapest way that still runs the same rules, and say which.
- Where it lives (suggested: `tool/pack_editor/`) and its launch command.
- Layout of the page.
