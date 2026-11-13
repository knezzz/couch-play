# CouchPlay status

Owner: PM (`product-pm@couchplay`). Plan: `docs/plans/2026-11-13-couchplay.md`.

## Tasks

| # | Task | State | Owner |
|---|---|---|---|
| 1 | Toolchain and workspace | blocked (needs person's yes to install Flutter + Android TV system image) | lead |
| 2 | Protocol | todo | — |
| 3 | TV server and LAN address | todo | — |
| 4 | Curve simulation | todo | — |
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

1. **Installs for Task 1 (blocking).** OK to run `brew install --cask flutter`, accept Android licenses
   (`flutter doctor --android-licenses`), and install the SDK image `system-images;android-34;android-tv;x86` via
   `sdkmanager`?

## Plan notes (minor, not blocking)

- Task 1 Step 3 says `git init` and Step 6 says to add the spec and plan; the repo already exists and both are
  committed (`cff0b20`). Skip those parts.

## Seats

| Seat | Session | Since | Note |
|---|---|---|---|
| PM | product-pm@couchplay | 2026-11-13 | starting seat |
| lead | build-lead@couchplay | 2026-11-13 | starting seat |
| core, app, qa, review | — | — | starting seats; roster still building at 2026-11-13 |

No added seats.

## Changelog

- 2026-11-13: STATUS created. Task 1 routed to lead, blocked on the person's install approval.
