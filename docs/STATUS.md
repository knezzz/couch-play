# CouchPlay status

Owner: PM (`product-pm@couchplay`). Plan: `docs/plans/2026-11-13-couchplay.md`.

## Tasks

| # | Task | State | Owner |
|---|---|---|---|
| 1 | Toolchain and workspace | done (4123738) | lead |
| 2 | Protocol | review (d4e99fd) | core |
| 3 | TV server and LAN address | in progress | core |
| 4 | Curve simulation | in progress (worktree `../CouchPlay-task4`, branch `task4-curve`) | app |
| 5 | Curve end-to-end + **real-TV perf gate** | todo | — |
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

None open.

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
