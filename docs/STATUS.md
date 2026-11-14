# CouchPlay status

Owner: PM (`product-pm@couchplay`). Plan: `docs/plans/2026-11-13-couchplay.md`.

## Tasks

| # | Task | State | Owner |
|---|---|---|---|
| 1 | Toolchain and workspace | done (4123738) | lead |
| 2 | Protocol | done (d4e99fd) | core |
| 3 | TV server and LAN address | done (583a11f, fix 9c29d02) | core |
| 4 | Curve simulation | done (f9f01df, 48c5b94, fix c2bf7f2) | app, lead |
| 5 | Curve end-to-end + **real-TV perf gate** | done (gate GO; frames pass; RTT accepted, see changelog) | lead; RTT: builder-2 |
| 5b | Curve: die on own old trail, countdown names + start arrow, 7 power-ups, smarter bots (person, 2026-11-14) | done (TV re-check 2026-11-14: person "looks great") | core + app |
| 6 | Session, lobby, QR join (+ host bot controls) | done on macOS (acad899 … 43697ff); design should-fixes go into Task 14 | core + app |
| 7 | Session scoring and results | done (f6b19f2, db5e1a5) | builder-2 |
| 8 | Shared effects | done (af1e3f5, 72090c5, 0d0a3b5, 5038006, 4efe2ea) | builder-2 |
| 9 | Quiz pack format | done (4b1cbdb, fix 01db6e3, merge a69cb6f) | builder-2 |
| 10 | Quiz round logic | done (0a679e8, fixes e6b6d64, eae0ec9) | builder-2 |
| 11 | Quiz screens | done on macOS (e0f899d, 4c9f22a, 8ba1b0c, a22faec); design review 2 in progress | core + app |
| 12 | Pack store and upload | done (3e49ecb, e5fcb49, 0606039, 729b9a9, e06c9fe) | builder-2 |
| 13 | Bundled packs (EN + HR) — **person reviews hr-medimurje** | built: 10 packs, 449 questions (4c17e2d, a99feee, cd0b775); waits on the person's hr-medimurje review | content |
| 14 | TV polish and release install | Steps 1–4 done (5d32880); Step 5 leftovers (3+ phones, Android Chrome) with the person | lead |
| 15 | Design pass to the reference screens (person, 2026-11-14) | done on macOS (ee77c55, 9cd8631, a7bbada, 7cf32db); see it on the TV next session | lead |
| 13b | Croatian content: all HR packs verified + harder; Croatian versions of the 6 English packs (person, 2026-11-14) | built (bf474df, e8ec4ed, 617240e, 6f1fe36, a408ee1): 16 packs, 759 questions; hr-medimurje waits on the person | content |
| 16 | Croatian user interface (person, 2026-11-14) | in progress | lead |

## Open questions for the person

- Task 14 Step 5 leftovers, on your own time (no adb needed; the app is installed): play with 3+ phones at once,
  including an Android phone in Chrome.
- Back on the results screen: exit the app (Android TV default, as now) or go to the lobby?
- Quiz: when everyone scores 0, everyone ties for first and gets confetti + session points (the plan's tie rule).
  Should a 0-point game award nothing instead?
- Task 13: review the `hr-medimurje` pack when it's ready.

Answered:
- 2026-11-13: Task 1 installs (Flutter cask, Android licenses, android-34 TV x86 image): **yes**.
- 2026-11-13: Local merges of team branches into main: **fine without asking**. Pushes, PRs, GitHub merges still ask.
- 2026-11-14: Task 5 gate: **GO**, with the RTT investigated alongside Task 5b.

## Plan notes (minor, not blocking)

- Task 1 Step 3 says `git init` and Step 6 says to add the spec and plan; the repo already exists and both are
  committed (`cff0b20`). Skip those parts.
- Flutter was already installed (fvm stable 3.47.7, Dart 3.13.5). Task 1's brew install was skipped; the plan's
  Global Constraints line is corrected.
- Task 3 note from Task 1 review: controller.zip has directory entries and `.last_build_id`, so
  `extractControllerZip` must skip directories and guard entry paths. Lead is passing this to core.

## Carry-overs (from reviews; check at acceptance)

- Task 5: renderer does moveTo at each segment start (segments skip gaps), skips dead heads, ids stay in 0..65534.
- Task 6: Session ignores TV→phone message types sent by a phone; range-check the Kick player id.
- Task 6: when ≤ 1 connected Curve player remains, Session calls `finishGame(sim.scores)` at once (with 0 left the
  sim never ends a round).
- Task 6 Step 6 (by hand): a phone that drops off Wi-Fi without closing is marked disconnected within ~10 s (5 s
  WS ping from Task 3 has no unit test), host passes on, Curve player dies.
- Task 11: broadcast `lastPoints` only at the reveal; drive `advance(now)` from one round clock on a 100 ms grid;
  Session calls `addPlayer` on rejoin and `removePlayer` on disconnect. (Answer range check is done in Task 10.)
- Disk: 12 GiB free on 2026-11-14 (the android-36 TV x86_64 image is 8.2 GB, not the ~2 GB estimated). QA stops
  under 8 GiB. Re-check before release builds.
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

| builder-2 | build-builder-2@couchplay | 2026-11-14 | **added**: RTT investigation, while core + app are on Task 5b |
| design | check-design@couchplay | 2026-11-14 | **added**: design review of Tasks 6, 11, 14 screens |
| content | build-content@couchplay | 2026-11-14 | **added**: Task 13 question packs |

Added seats: 3 of 3 (a 4th needs the person's yes). builder-2 goes when Task 14 no longer needs it.

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
- 2026-11-14: Task 3 accepted (review clean after ping fix 9c29d02; PM ran tv tests, 11/11). Plan boxes ticked.
  Tasks 1–4 done; Task 5 in progress.
- 2026-11-14: Task 5 review: 1 HIGH, 2 MEDIUM, all being fixed before the gate. PM: keep the plan's Path renderer
  (merge continuous segments); the ui.Image fallback only if the real TV drops frames. Person given TV dev-mode steps.
- 2026-11-14: TV in developer mode (Wireless debugging; address kept on the Task 5 queue row, not in git).
- 2026-11-14: Task 5 QA FAIL (macOS): phone sends correct Steer, but the TV line never turns; bots fine. Urgent
  root-cause task with core. Passed: URL shown, join, RTT, trails/gaps, debug frames 3–14 ms.
- 2026-11-14: QA re-run on 64efa9e: steering, full-game refusal, takeover, gaps pass. FAIL: steering ignored after
  page reload + re-join (urgent to core). Person approved the android-36 TV x86_64 emulator image and deleting the
  unusable android-34 x86 image; plan Task 1 Step 2 corrected.
- 2026-11-14: QA re-run on 5295a41 passes (long hold across rounds, reload + re-join + hold, release); review of the
  fix clean. 64-bit TV emulator installed (8.2 GB), old image deleted, 12 GiB free. Last check: QA on the emulator.
- 2026-11-14: Task 5 Steps 1–5 accepted (review clean; QA pass on macOS + emulator; PM re-ran tests: core 13, tv 21,
  controller 4). Renderer: per-player Path, one subpath per trail. Debug-build emulator raster max 110–194 ms is a
  warning, not gate data. Person said yes to adb for this session; Step 6 queued to lead.
- 2026-11-14: TV paired: Sony BRAVIA, Android 14, MediaTek MT9690, armeabi-v7a only (32-bit ARM), 3.7 GB RAM, UI
  1080p. Gate phone: the person's iPhone ("Snoopy") in Safari, first iPhone Safari check. Nothing installed on it.
- 2026-11-14: Scope change from the person during the gate. Spec and plan updated; new Task 5b before Task 6:
  (1) bug: you never die on your own old trail (curve_sim.dart:213-215 re-stamps own cells), (2) countdown dots with
  names above (countdown only), (3) power-ups: speed, thin, ghost, slow others, fat others, clear, wrap. Replaces
  "no power-ups in v1". Gets its own real-TV re-measure.
- 2026-11-14: **Task 5 gate results** (release build on the BRAVIA, 7 bots + person on iPhone Safari): steady play
  0 frames over 16 ms in ~14,600 frames, worst 4.9–5.6 ms, p50 ~3.8 ms (about 3× headroom); 3 frames just over
  16 ms (worst 16.9) around match start; Path renderer, no ui.Image fallback. Phone RTT 100+ ms (target ≤ 40 ms:
  miss). Steering "not immediate but okay"; no visible stutter at round restart; Safari fine. Person: GO, with
  the RTT investigated alongside. Added builder-2 for the RTT work (core + app on 5b). Task 5b queued.
- 2026-11-14: RTT root cause (builder-2): the TV's Wi-Fi power save. Mac→TV ping/pong p95 is 114 ms at 1 Hz and
  19 ms at 10 Hz. Not our code. PM approved a controller-only fix: ping at ~10–20 Hz during Curve to keep the radio
  awake (builder-2), re-measured on the iPhone in 5b Step 5.
- 2026-11-14: Person asked for a preview on the TV: release build of 9439899 (5b work before review/QA) installed.
- 2026-11-14: Scope change from the person: bots become a real feature (host adds/removes them in the lobby; Curve
  only; count toward the 8 and toward scoring) with "survive + power-ups" skill; countdown also shows each player's
  start direction. Spec and plan updated: smarter bots + arrow go into Task 5b, lobby bot controls into Task 6.
- 2026-11-14: 5b start arrow landed (9d38b3a); RTT keep-alive landed (8954fab, controller pings at 10 Hz in Curve).
  builder-2 moves to Task 9 early (independent pure-core work).
- 2026-11-14: 5b Step 5 build (872943a) live on the TV; all 5b review clean (2 LOW bot notes left: a fat bot can
  probe into its own fresh paint; probes can slip through thin diagonal trails). Task 9 built (4b1cbdb), in review.
  Plan fix: the pack class is `PackQuestion` (name clash with the wire message `QuizQuestion`); Task 9 also adds
  validation messages beyond the plan, documented in docs/quiz-pack-format.md.
- 2026-11-14: Task 9 accepted. Review HIGH fixed: a zip64 size of -1 bypassed the inflate cap (a 5 MB upload could
  inflate to ~5 GB and crash the TV). PM ran core tests, 54/54. Plan boxes ticked.
- 2026-11-14: Person asked to play the quiz on the TV. It needs Tasks 6, 10 and 11 (plus 13 for real packs).
  builder-2 starts Task 10 plus Task 7's pure scoring functions now.
- 2026-11-14: **5b TV re-measure** (872943a): frames PASS (worst 5.6–7.8 ms in steady play, ~3× headroom; one
  ~3 s hitch every few minutes, max 26.9 ms, likely the match restart). iPhone RTT ~10 ms typical, p95 50–60 ms
  (was 100+; target 40). Person: steering better; power-ups work; own-trail death and arrows work; bots look
  aimless and robotic. Next: 20 Hz keep-alive; bots get goals and human-like steering (plan updated).
- 2026-11-14: Plan Task 10 changed (PM, from review): QuizRound.addPlayer for mid-round rejoin (matches the spec)
  and a monotonic `now`. Task 10 + Task 7 scoring accepted (re-review clean; PM ran core tests, 74/74).
- 2026-11-14: Person done playing; adb to the TV disconnected. Tonight's TV session is over. The team continues.
- 2026-11-14: Task 5b accepted on macOS (PM ran tests: core 74, tv 36, controller 7; review clean; QA saw all 7
  power-ups, names, arrows, own-trail death; bots move like people but rarely take power-ups). Task 6 queued; Task 8's
  core widgets to builder-2 in parallel.
- 2026-11-14: Task 8 first half accepted (review clean; PM ran core tests, 85/85). builder-2 on PackStore (Task 12's
  first half).
- 2026-11-14: Task 6 accepted on macOS (PM ran tests: core 89, tv 83, controller 21; review fixes in; QA 12/12 incl.
  Review Focus #1-3). Its hand-back reached the PM ~3 h late (05:45 → 08:37); the team idled. Added check-design
  (Task 6 review: 0 must-fix, 6 should-fix → Task 14; palette kept, dots widened instead) and build-content (Task 13).
- 2026-11-14: Tasks 11, 12 (second half), 7 (rest) and 8 (wiring) accepted on macOS (PM ran tests: core 93, tv 116,
  controller 31; review and QA clean). The quiz is playable on macOS with a built-in test pack and uploaded packs.
  Task 14 Steps 1-4 + design fixes queued; design review 2 (quiz/results) queued.
- 2026-11-14: TV session 2 (build db68fb7, release, person's yes): frames: Curve 0 over 16 ms, worst 6.4–8.1 ms;
  quiz minute 0 over, worst 14.3 ms; startup minute 6 over (load). iPhone RTT at 20 Hz: typical ~10 ms, p95 ~50 ms
  (n=300), no better than 10 Hz, so the spikes are the TV's Wi-Fi, not our code. Person: "Looks great." PM: RTT
  accepted as-is (no TV network changes). Task 5b Step 5 closed. Task 14 Back fix + bundled packs build next.
- 2026-11-14: TV session 2 (cb9a287): the person confirmed the TV remote works (Back, dialog, focus), ▲◆●■ shapes and
  Croatian diacritics render on the TV and phones. BUG: no confetti in release builds. effects.dart:185 filled the
  particle tables inside an assert(), which release strips (since af1e3f5; tests and QA ran debug). Fix and reinstall
  approved; check-review greps for other release-vs-debug differences; QA effects/UI checks run in release/profile.
- 2026-11-14: Confetti fix (6b0378f) confirmed by the person on the TV and phones. Locking + unlocking a real phone
  reconnects it (Review Focus #1 verified). TV session 2 ended; adb disconnected. 3+ phones and Android Chrome left
  for the person to try on their own.
- 2026-11-14: Task 14 Steps 1-4 accepted (PM ran tests: core 94, tv 141, controller 34). Person asked for a design
  artifact and a design pass: canvas "CouchPlay screens" (https://claude.ai/artifact/SX8ertCTfhPyLpSpti4PKe), 9 screens,
  copy in docs/design/couchplay-screens/; spec + plan updated (Task 15); routed to lead.
- 2026-11-14: Person: review hr-medimurje later; first verify it online (Wikipedia etc.) and make it harder, as it's
  too easy for locals. Revision queued to content (sources file per question; Q5 Grad Zagreb fix).
- 2026-11-14: Scope change from the person: all Croatian packs verified + harder; Croatian versions of the 6 English
  packs (kept alongside); the whole UI in Croatian. Spec + plan updated (Tasks 13b, 16). 13b with content; 16 after 15.
- 2026-11-14: Task 13b built: 4 HR packs verified (sources files) and harder; 6 Croatian versions of the English packs.
  16 packs, 759 questions. PM ran the pack test and spot-read 12 questions. Open: the person's hr-medimurje review (least
  sure: Mohokos vs Kalec, tiblica, jurjevščak, Prelog speedway); a native skim of the translations is optional.
- 2026-11-14: Task 15 accepted on macOS (PM ran core 95, tv 159; controller green on the committed tree): every screen
  matches its mockup (QA, release builds), design signed off, the phone never shows the quiz pick, confetti cut to 20
  large pieces. Task 16 (Croatian UI) queued.
