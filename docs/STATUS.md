# CouchPlay status

Owner: PM (`product-pm@couchplay`). Plan: `docs/plans/2026-11-13-couchplay.md`.

## Tasks

| # | Task | State | Owner |
|---|---|---|---|
| 1 | Toolchain and workspace | done (4123738) | lead |
| 2 | Protocol | done (d4e99fd) | core |
| 3 | TV server and LAN address | review: fix pending (WS ping 5 s, by core) | core |
| 4 | Curve simulation | done (f9f01df, 48c5b94, fix c2bf7f2) | app, lead |
| 5 | Curve end-to-end + **real-TV perf gate** | in progress: 689c1d0 (app), 5d55aa7 (bots); TV main.dart wiring next. Step 6 held for person's adb yes | core + app |
| 6 | Session, lobby, QR join | todo (waits on Task 5 gate) | — |
| 7 | Session scoring and results | todo | — |
| 8 | Shared effects | todo | — |
| 9 | Quiz pack format | todo | — |
| 10 | Quiz round logic | todo | — |
| 11 | Quiz screens | todo | — |
| 12 | Pack store and upload | todo | — |
| 13 | Bundled packs (EN + HR) — **person reviews hr-medimurje** | todo | — |
| 14 | TV polish and release install | todo | — |

## Open questions for the person

- Coming at Task 5 Step 6: yes to adb-connect to your TV this session (enable developer mode + network debugging
  on the TV first).

Answered:
- 2026-11-13: Task 1 installs (Flutter cask, Android licenses, android-34 TV x86 image): **yes**.
- 2026-11-13: Local merges of team branches into main: **fine without asking**. Pushes, PRs, GitHub merges still ask.

## Plan notes (minor, not blocking)

- Task 1 Step 3 says `git init` and Step 6 says to add the spec and plan; the repo already exists and both are
  committed (`cff0b20`). Skip those parts.
- Flutter was already installed (fvm stable 3.47.7, Dart 3.13.5). Task 1's brew install was skipped; the plan's
  Global Constraints line is corrected.
- Task 3 note from Task 1 review: controller.zip has directory entries and `.last_build_id`, so
  `extractControllerZip` must skip directories and guard entry paths. Lead is passing this to core.

## Carry-overs (from reviews; check at acceptance)

- Task 3: extractControllerZip skips directory entries and guards paths; cap each WebSocket frame's size.
- Task 5: renderer does moveTo at each segment start (segments skip gaps), skips dead heads, ids stay in 0..65534.
- Task 6: Session ignores TV→phone message types sent by a phone; range-check the Kick player id.
- Task 6: when ≤ 1 connected Curve player remains, Session calls `finishGame(sim.scores)` at once (with 0 left the
  sim never ends a round).
- Task 10/11: range-check the Answer index.
- Disk: 20 GiB free on 2026-11-13 (after Task 1). Re-check before emulator and release builds.
- avdmanager needs `JAVA_HOME` pointed at Android Studio's bundled jbr (env var only).

## Seats

| Seat | Session | Since | Note |
|---|---|---|---|
| PM | product-pm@couchplay | 2026-11-13 | starting seat |
| lead | build-lead@couchplay | 2026-11-13 | starting seat |
| core | build-core@couchplay | 2026-11-13 | starting seat |
| app | build-app@couchplay | 2026-11-13 | starting seat |
| qa | check-qa@couchplay | 2026-11-13 | starting seat |
| review | check-review@couchplay | 2026-11-13 | starting seat |

No added seats.

## Changelog

- 2026-11-13: STATUS created. Task 1 routed to lead, blocked on the person's install approval.
- 2026-11-13: Person approved the Task 1 installs. Task 1 unblocked.
- 2026-11-13: Kickoff received from setup-agent. Existing fvm Flutter used; brew step dropped. Only the Android TV
  system image and AVD get installed.
- 2026-11-13: Task 1 committed (4123738), in code review. Full team running. Tasks 2 and 4 queued to lead in
  parallel (both need only Task 1).
- 2026-11-13: Lead routed Task 2 → core (main), Task 4 → app (worktree, both edit packages/core). Person OK'd local
  merges.
- 2026-11-13: Task 1 accepted (tests shown for core/tv/controller, review clean, zip untracked). Plan boxes ticked.
- 2026-11-13: Task 2 built (d4e99fd), in review. Task 3 queued to lead for core.
- 2026-11-13: Task 2 accepted (review clean; PM re-ran protocol tests, 2/2 pass). Task 4 merged to main, awaiting
  hand-back.
- 2026-11-13: Task 3 built (583a11f, 64 KB WS frame cap), in review. Task 4 worktree removed, in review. Task 5
  queued (core: Bots + TV wiring; app: Flame renderer + controller). Reviewer told to stop `cd && git` prompts.
- 2026-11-14: Reviews found 1 medium issue each. Task 4: disconnected Curve player returned next round, fixed by
  lead (c2bf7f2), re-review. Task 3: no WS ping, so silent drops stay "connected"; core adding 5 s ping. Lead will
  no longer approve other seats' prompts.
- 2026-11-14: Task 4 accepted (re-review clean; PM ran core tests, 12/12). Plan boxes ticked.
