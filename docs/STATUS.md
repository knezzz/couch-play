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
| 13 | Bundled packs (EN + HR) — **person reviews hr-medimurje** | done 2026-11-17: person reviewed; fixes in bbf0ff4 (94 → 84 questions) | content |
| 14 | TV polish and release install | Steps 1–4 done (5d32880); Step 5 leftovers (3+ phones incl. Android Chrome) still with the person | lead |
| 15 | Design pass to the reference screens (person, 2026-11-14) | done; on the TV | lead |
| 13b | Croatian content: all HR packs verified + harder; Croatian versions of the 6 English packs (person, 2026-11-14) | built (bf474df, e8ec4ed, 617240e, 6f1fe36, a408ee1): 16 packs, 759 questions; hr-medimurje waits on the person | content |
| 16 | Croatian user interface (person, 2026-11-14) | done; on the TV | lead |
| 17 | Show active power-ups and time left; wrap = shrinking white border (person, 2026-11-14) | done; replaced by Task 34 rings; on the TV | lead |
| 18 | Keep the TV awake while the app is open (screensaver started mid-game; person, 2026-11-14) | built (9541811); on the TV; screensaver check still to do | lead |
| 19 | Curve: a phone button sometimes stops reacting (person, 2026-11-15) | done on macOS (edd0ca4; cause: a crash reset the per-button finger count, the late lift sent it to -1); real phones next session | lead |
| 20 | Game keeps going when the host leaves; dropped players come back in (person, 2026-11-15) | done on macOS (696669b … 9d7e1bf); real phones + TV next session | lead |
| 21 | Croatian packs only, all as big as verified questions allow; pub-quiz/Potjera as a guide (person, 2026-11-15) | done (59588ed … 0b07659): 10 packs, ~1,245 questions, all sourced; 52 new Međimurje ones wait on the person | lead + content |
| 22 | Photo questions ("Koji je ovo grad?"), pictures as big as possible on the TV (person, 2026-11-15) | done; on the TV | lead + content |
| 23 | Host game settings: quiz time per question, questions per game, time between questions; Curve pause between rounds (person, 2026-11-16) | done; on the TV in a286dc2 | lead |
| 24 | Curve modes (Kaos, Uravnoteženo, Mirno, Samo za tebe); speed up hits others, slow down is yours; thin/fat last longer (person, 2026-11-16) | done; on the TV in a286dc2 (Kaos tuned by guess) | lead |
| 25 | Fat stacks, ghost leaves no line, thin removed, reverse-others added (person, 2026-11-16) | done on macOS; fat stacking, ghost line return, the swap itself unit-tested only; on the TV in a286dc2 | lead |
| 26 | Sound effects on the TV (person, 2026-11-16) | built; nobody has heard it yet; on the TV in a286dc2 | lead |
| 27 | Host picks a game from a carousel; details with settings, mirrored on the TV; Igraj starts it (person, 2026-11-16) | done; on the TV since a286dc2 (polish 3ec57e3 next install) | lead |
| 28 | Six new packs (Umjetnost, Psihologija, Ljudsko tijelo, Memeovi, Fizika, Matematika) + more picture questions (person, 2026-11-16) | done (5fa5fb3): 16 packs, ~2,000 questions, 89 new photos; most on the TV in ecf8eb9 | lead + content |
| 29 | Player characters: ~16 drawn animals, one each, shown on the TV (person, 2026-11-16) | done; on the TV since a286dc2 (chip contrast 9826952 next install); join screen does not grey taken faces | lead |
| 30 | Console home (one game full screen, neighbours at the edges, QR top left), games full screen (person, 2026-11-17) | done; on the TV in fd838d6 | lead |
| 31 | Quiz ticker (person, 2026-11-17) | done; on the TV in fd838d6 | lead |
| 32 | Sound in every game and the menus (person, 2026-11-17) | done; on the TV; not heard by QA | lead |
| 33 | Vukodlak: werewolf-style game, village on the TV, roles on phones (person, 2026-11-17) | done (QA pass with 5/6/8 phones, privacy side by side); rejoin "Poslano" fix in progress; night village cost on the BRAVIA to measure | lead + content |
| 34 | Power-up icons version A, active effects as rings only (person, 2026-11-17) | done; on the TV in fd838d6 | lead |
| 35 | Uljez: hidden-word game, impostor gets a similar word without knowing (person, 2026-11-17) | done (QA pass 3/6/8 phones); right-guess + 10 s end screen in QA batch 2 | lead + content |
| 36 | Power-ups: cheese (your line gets holes), square turns for others, speed up yours / slow down others again (person, 2026-11-17) | done; on the TV (682e883); QA release run waits for 8080 | lead |
| 37 | Design-audit decisions: scores between Curve rounds, Večeras strip, power-up legend, fat icon, night switch (person, 2026-11-17) | done; on the TV | lead |
| 38 | Placement points last = 0; all-zero game = 0; Back on results moves on; Međimurje words without villages, no easy ones (person, 2026-11-17) | done; on the TV (682e883) | lead + content |
| 39–42 | Party games: Objasni, Koliko?, Blef, Tko bi?, with new packs (person, 2026-11-17) | done (QA pass with real browser phones; Blef typing proven on Android + iPhone); on the TV in ee00641 | lead + content |
| 43 | Kao svi: match the herd (person, 2026-11-17) | done (QA pass 3/5/8 phones); next TV install | lead + content |
| 44 | Difficulty: Oblici harder, Matematika/Fizika easier, pub-quiz level (person, 2026-11-17) | done (0713aa3, e430b0e): Oblici 36 new; Matematika 113, Fizika 107; next TV install | content |
| 45 | Uljez and Vukodlak without fixed timers: Dao sam trag, Idemo glasati majority (person, 2026-11-18) | done (review clean after 7 rounds, QA pass 3-8 phones; kicks from host phone by day and TV Back menu any time); next TV install | lead |
| 46 | Multi-select packs in every game, all selected by default (person, 2026-11-18) | done (review 2 must-fixes fixed, QA pass all 7 games; 41ff6dd); next TV install | lead |
| 47 | Remove Kao svi (person, 2026-11-19) | done (review clean, suites green; visual QA skipped by the person: no screen recording); next TV install | lead |
| 48 | Phone home live with the TV: guests see the host's card and settings, changes marked and listed, TV settings panel (person, 2026-11-21) | done (review clean after 2 must-fixes, QA pass phones, TV from PNGs; remote on the real TV); next TV install | lead |
| 49 | Uljez impostor never the same person twice in a row (person, 2026-11-21) | done (a889bd1, review clean); on the TV since a889bd1 | lead |
| 50 | Hide sent answers and typed text on phones behind the hold card, all games (person, 2026-11-21) | done (3ccc3a5 + c34c2b7, review clean x2, QA pass macOS release 360 px; Kviz already shows only "Odgovor je zaključan", Uljez guess ends the round); not on the TV | lead |
| 51 | Vukodlak: role card + Spreman before night 1; one sum per night; night-1 second list reworked after UX review + field test (person, 2026-11-21) | done (480cd32, f33de4e, 68b8311, 2e927a0, 715d501, bc22ba6; review clean after 4 must-fix rounds; QA field test 8 phones pass; person chose the Provodadžija-only second pick); open: power-switch wording (person), 8 rows scroll at 360x640 (later); not on the TV | lead |
| 52 | Curve: names along the bottom in line colors during play; clear round-winner moment; UX pass on a whole round (person, 2026-11-21) | done (483f782, f36538a, f615c3b, 4328237, 5ac2510, 4890ca7; review clean after 1 must-fix; QA phones pass; TV from 1080p renders); not on the TV, frame rate with 8 trails unchecked | lead |
| 53 | Vukodlak phone: role card first, then the action, back to the role card after sending (person, 2026-11-22) | done (24296d6 + 9ba8421, review clean after 1 must-fix, QA 8 phones 3 days pass; switch only Travarica and Vođa čopora while the power is left); not on the TV | lead |
| 54 | Vukodlak: 8 players fit a 360x640 phone without scrolling (person, 2026-11-22) | done (126a5d5, review clean; fits a 640 px browser viewport, a real 360x640 phone in Chrome still scrolls ~1.5 rows: person chose keep as is, 2026-11-22) | lead |
| 55 | Sumo: push others off a ring (person, 2026-11-27; spec 2026-11-27-action-games-design.md) | routed: design boards first | lead |
| 56 | Tenkovi: everyone aims, all fire at once (person, 2026-11-27; same spec) | routed: design boards first | lead |

## Open questions for the person

- Task 14 Step 5 leftovers: play with 3+ phones at once, including an Android phone in Chrome.
- TV A/B for the frame-time fix: reconnect adb when convenient (~10 min).

Answered:
- 2026-11-17: Back on results moves on (next round/game, or home when the game is over); an all-zero game gives
  everyone 0; placement points last = 0. hr-medimurje approved with changes. (Task 38.)
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
| design | (removed 2026-11-14) | 2026-11-14 | added for design reviews of Tasks 6, 11, 14, 15; removed when done |
| content | build-content@couchplay | 2026-11-14 | **added**: Task 13 question packs |
| content-2 | build-content-2@couchplay | 2026-11-15 | **added**: Task 21 packs (template rigs/seats/content-2.member.yaml) |

Added seats running: 3 of 3 (builder-2, content, content-2). Each goes when its work is done.

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
- 2026-11-14: check-design removed (reviews done, nothing queued). Task 16 strings (docs/strings-hr.md, ~104): person chose
  neutral wording instead of masculine forms, keep "Curve", Robot/NEMA VEZE OK, ship without a full read (checks on TV).
- 2026-11-14: Task 16 accepted (PM ran core 96, tv 163, controller 46; no masculine forms or dead strings left; QA
  fit check on release builds). Everything in the plan is built. Waiting on the person: hr-medimurje review (Task 13),
  a TV session (see Tasks 15/16, confetti PERF, 3+ phones incl. Android Chrome), Back on results, the 0-point quiz rule.
- 2026-11-14: Person approved the design and asked for obvious active power-ups with time left (wrap: a white border
  that shrinks; walls back when it is gone). Spec + plan Task 17; routed to lead.
- 2026-11-14: Person: the TV goes to its screensaver during a game. Spec + plan Task 18 (keep the screen on while the
  app is in the foreground); routed to lead.
- 2026-11-14: Task 18 built (9541811, FLAG_KEEP_SCREEN_ON in MainActivity; PM ran tv 169 and read the diff; arm
  release APK compiles). Still to check on the TV. A Sony sleep timer / auto power-off in the TV menu is separate.
- 2026-11-14: Task 17 accepted on macOS (PM ran core 101, tv 169, controller 46; looked at the QA screenshots of the
  wrap border and the slowed icons). QA saw slowed, fat, thin and wrap by eye; speed, ghost, clear, wall-crash after wrap
  are covered by tests only. TV: readability from the couch and frame times still to check.
- 2026-11-15: Person said push all: main pushed to github.com/knezzz/couch-play (public). The lobby mockup now uses a sample
  address; the TV address stays in the history of c1c5c1d (a home-network address only).
- 2026-11-15: Person: Curve buttons sometimes stop reacting (often one); the game must not stop when the host leaves,
  and the host (anyone) can come back in, missing what they missed. Spec + plan Tasks 19, 20; routed to lead.
- 2026-11-15: Person (Task 20): the stop happened with 2 people, in both Quiz and Curve. Rule: a 2-player Curve match
  pauses up to 30 s for the one who left, then ends; a 2-player Quiz keeps going.
- 2026-11-15: Task 19 accepted on macOS (PM ran core 102, tv 190, controller 47; QA 7 cases pass on release). Task 20:
  quiz stop seen by the person = the Results screen after the host closed the tab; likely both phones dropped at once
  (nobody connected ends a game at once). PM call: nobody connected waits 30 s in both games. Person: a 2-player
  Curve match ended by the wait keeps its scores, ties included.
- 2026-11-15: Task 20 accepted on macOS (PM ran core 102, tv 205, controller 47; review clean after 9d7e1bf; QA 11/11
  nobody-connected cases on release). To watch on the TV: the pause text partly covers a long question's 2nd line; a
  "Sudar!" 1.5 s after both came back to Curve (read as the passive head crashing).
- 2026-11-15: Person: Croatian quizzes only for now; all packs as big as questions can be found; use pub-quiz and
  Potjera material. PM: copy text only where the licence allows (public repo). Spec + plan Task 21; routed to lead.
- 2026-11-15: Added seat content-2 (3 of 3; template rigs/seats/content-2.member.yaml, a copy of content) for Task 21
  at the lead's request: about 1000 verified questions is too much for one writer. It takes the seven packs other than
  Opće znanje.
- 2026-11-15: Person (typed in content-2's pane): photo questions like "what is this city", more picture questions,
  pictures as big as possible on the TV. PM: photos (JPEG/PNG/WebP) join the format, freely licensed only, credited
  per photo. Spec + plan Task 22; routed to lead.
- 2026-11-15: Task 22 accepted on macOS (PM ran core 103, tv 218, controller 47; looked at QA's geografija screens).
  Photo credits stay in the packs' .sources.md (the repo copy is credited); no credit line in the app for home use.
  Revisit if the app is ever shared. TV: decode time, memory and frame times with photos still to check.
- 2026-11-15: Task 21 accepted (PM ran tv 218; sampled opće znanje). ~1,245 questions (opće znanje 401). No openly
  licensed Croatian pub-quiz/Potjera set exists (HKS: no commercial use; HRT etc. all rights reserved): used for
  style only, all wording ours. A duplicate test guards the packs. Not done: a native read of ~850 new questions.
- 2026-11-16: Person asked for host settings. Chosen: time per question, questions per game, time between questions,
  and the Curve pause between rounds (not the results hold). PM: session-only, ranges in plan Task 23; routed to lead.
- 2026-11-16: Person: Curve modes (chaos / balanced / peaceful / only your power-ups), speed up on others and slow
  down on you, thickness lasts longer. PM: both thin and fat ~1.5x; mode in Task 23's host settings. Task 24.
- 2026-11-16: Person: yes, remember the host settings (and the Curve mode) across restarts. Added to Tasks 23/24.
- 2026-11-16: TV session: 49e10cd installed on the BRAVIA (person asked). Person: fat should stack, ghost leaves no
  line, drop thin and add reverse-others; add sound effects (TV only). Tasks 25, 26.
- 2026-11-16: Person: game carousel on the host phone, details view with settings mirrored on the TV, then Igraj. Task 27
  (settings move from Task 23's area into each game's details).
- 2026-11-16: Person: more picture questions; new packs umjetnost, psihologija, ljudsko tijelo, memes, fizika,
  matematika. PM: memes as text unless the image is freely licensed (public repo). Task 28.
- 2026-11-16: Person: players choose a character, shown on the TV. Chosen: drawn animals, one per player. Task 29.
- 2026-11-16: The 49e10cd TV session has no PERF numbers (built without --dart-define=PERF=true). The next install
  (tv-install2, on the first Task 28 pack) is built with PERF on and checked for PERF lines in the first minute.
- 2026-11-16: a286dc2 on the TV (PERF on; first new pack hr-psihologija 112). Tasks 23, 24, 25 accepted on macOS,
  Task 26 built (lead ran core 132, tv 281, controller 66 on a286dc2; PM ran core 132, controller 67 on main; tv not
  re-run: another seat has uncommitted lobby edits). PERF overlay covered the TV; person chose a log-only PERF and a
  reinstall.
- 2026-11-16: Tasks 27 and 29 accepted (lead ran core 132, tv 281, controller 66 at ecf8eb9; review clean; QA pass).
  ecf8eb9 on the TV (PERF log-only; new packs matematika, memeovi, fizika, umjetnost, ljudsko-tijelo); TV was in
  standby. Design canvas updated with Curve, power-ups, characters and game picker screens (19ef448).
- 2026-11-17: Task 28 accepted (lead ran core 132, tv 283, controller 67 on 5fa5fb3; PM sampled memeovi, matematika,
  psihologija). APK 40.6 MB. Photo credits stay in .sources.md (home use), as decided in Task 22.
- 2026-11-17: Person asked for a console-style redesign (full-screen games, like a retro console front end), sound
  in every game, a ticker on quizzes, and a new social-deduction game (Vukodlak: story on the TV, roles and actions
  on phones). "Make an artifact first": canvas page "Konzola i Vukodlak" drawn (8 screens + notes). Nothing routed
  yet; waiting for the person's comments.
- 2026-11-17: Person approved the design page "Konzola i Vukodlak" ("odlično", QR moved top left). Spec + plan Tasks
  30-33; routed to lead.
- 2026-11-17: Person: power-up icons are not obvious; asked for several versions to choose from, and active power-ups
  shown as a ring around the player without the icon. Canvas page "Curve pojačanja": icons A/B/C, indicators 1/2/3.
  Waiting for the choice; nothing routed.
- 2026-11-17: Person chose power-up icons A and ring-only active effects 1. Task 34.
- 2026-11-17: Person asked for a word game where the impostor gets a similar word without knowing (Spužva Bob vs
  Pikachu), and both new games on the home screen. Canvas page "Uljez"; Task 35.
- 2026-11-17: Person gave a standing yes for TV installs today whenever something new is ready (green commit,
  BRAVIA only). bd9ff83 on the TV.
- 2026-11-17: Task 31 accepted (bar only, segment = limit/20; faster ending with urgent tick, heartbeat, time-up;
  review clean, QA pass). Not heard yet.
- 2026-11-17: fd838d6 on the TV (console home, ticker, new icons + rings, Vukodlak and Uljez playable but not yet
  QA'd with 5-8 phones). Task 34 accepted (review clean, QA pass).
- 2026-11-17: Task 30 accepted (idle home p95 ~7 ms on the Mac after the fix; hatched text gone; the session scoreboard
  is no longer on the home). If hatched text returns, Skia is the fallback and needs the person's yes.
- 2026-11-17: TV ran at ~half speed on fd838d6 (person: "a bit" choppy, on the home screen); Curve end-of-game crash.
  Both with builder-2. Person: Vukodlak night screens stay as they are (no hold-to-see for the task); TV A/B later.
- 2026-11-17: Person answered the long-open questions: Međimurje pack approved with changes (no village in word
  questions, no easy words); Back on results moves on; all-zero quiz gives 0; placement points shift down (last = 0).
  Task 38.
- 2026-11-17: Person approved docs/specs/2026-11-17-party-games-design.md: build all four with new packs; skip −1,
  Prekršaj kept, Tko bi? counts. Tasks 39–42.
- 2026-11-17: Design audit done (3 reads of every board; all gaps fixed or intended; list in the lead's hand-back).
  d378cf3 on the TV. QA visual pass waits for 8080 (the person's Mac test).
- 2026-11-17: Task 38 accepted (PM sampled hr-medimurje: no village names left, 84 questions). Task 13 done.
- 2026-11-17: Tasks 32 and 33 accepted. Watch: the night village is the heaviest scene (Mac p95 up to 44 ms).
- 2026-11-17: Person joined QA's Mac run from their iPhone on purpose: "all works as intended". ee00641 on the TV (not launched).
- 2026-11-17: Person allowed their Pixel 6a (28051JEGR09026) for testing, installs included ("anything for testing").
  Lifts the CLAUDE.md "never touch the Pixel" rule for test work. PM limits: no reset, no changes to their apps,
  accounts, settings or data; uninstall what we install. Seat configs still deny adb to it.
- 2026-11-17: Blef typing test passed on the Pixel 6a (Chrome, all 8 steps). iPhone Safari not run separately.
- 2026-11-17: Person confirmed Blef typing with Croatian letters works on the iPhone too. Typing risk closed.
- 2026-11-17: Person (via product-pm@web-editor): Oblici too easy, Matematika/Fizika too hard; middle spot, pub-quiz level. Task 44.
  Another rig (web-editor) is building a Mac pack editor; it tells the PM before writing pack files.
- 2026-11-18: Tasks 37, 39–42 and the play feedback (Oblici labels, Koliko?/Blef reveals) accepted; QA pass on 36 and
  38 too. Kao svi: review clean, QA running.
- 2026-11-18: Task 43 accepted. Everything routed is handed back. Next TV install waits for the person (yesterday's
  standing yes was for 2026-11-17).
- 2026-11-18: c5d194d installed on the TV, not opened (person: will play later today); lead's log capture running.
- 2026-11-18: Person (via product-pm@update-and-simplify): no fixed timers in Uljez, a hint button passes the turn, majority vote ends the rounds after round 1; same for Vukodlak. Task 45.
- 2026-11-18: Choppy home found from the person's play logs: the sound player (audioplayers, low latency) never reports done on Android, so its ticker redraws the home every frame (~27 ms) all session. Fix in builder-2's row tv-sfx-frames; confirm at the next TV install. Games smooth (p95 5-10 ms, quiz ~22 ms).
- 2026-11-18: Person: keep-phones-awake trick, forget it for now. Task 45: locked phones count as still in (person chose a).
- 2026-11-18: Person: all packs multi-select, all selected by default. Task 46.
- 2026-11-19: a0f53f5 (Tasks 45, 46) installed on the TV, not opened; capture running. The 6e0fb3c capture file was lost.
- 2026-11-19: Person (to the lead): a Windows .exe of the TV app via one GitHub Actions workflow, triggered only by the person pushing the `build-win` tag; exception to the no-CI rule. Committed bc9ce8c (apps/tv/windows, build-win.yml, Wi-Fi-first LAN address). Windows build not run yet. The tag push uploads the tagged commit and its history; pushing main is a separate choice.
- 2026-11-19: Person: remove Kao svi. Task 47.
- 2026-11-19: Seats' terminal app (Pocket Rig) lost Screen Recording; Accessibility re-granted works. Screen Recording needs a Pocket Rig restart (stops all seats); person to pick a quiet moment. Open: fresh phones showed 'Sljedeća igra uskoro počinje.' instead of the carousel in a blocked QA run; check at the next play or visual QA.
- 2026-11-19: 0792735 (Task 47) installed on the TV, not opened. Phone check: the 'Sljedeća igra uskoro počinje' line did not reproduce; a fresh phone gets the lobby with 8 games (likely QA's second app copy).
- 2026-11-20: content-lead (couchplay-content rig), fact-checked, content tests pass, not on the TV yet: 1543f98 Kviz hr-kultura-sport re-checked 122→119 (3 dropped, 8 fixed, new zvončari photo); 2934dbc Blef priroda 30→60, svijet 33→61; a971e99 Tko bi? blago 45→79, ljuto 41→77. Backlog: docs/CONTENT.md (280f52e).
- 2026-11-20: content-lead, fact-checked, content tests pass, not on the TV yet: 6eb4f71 Kviz hr-memeovi re-checked 119→110 (0 errors, 9 niche/duplicate cut); 2b90db6 Kviz hr-zastave 46→154 flags (Commons PD); 7a0962c Koliko? all four packs 60+ (62/63/62/62). Check at the next install: the big coat-of-arms SVGs (up to 281 KB) on the TV, load time and look.
- 2026-11-20: content-lead: cd76f01, 4 new party themes, checked against HJP, uljez/objasni/party pack tests pass, not played on the TV yet: Uljez Odjeća i obuća (46 pairs), Prijevoz (45); Objasni Sport (108), Zanimanja (108). Next from content: Kviz hr-hrana-pice, Blef Čudna povijest, film-glazba and opće znanje re-checks.
- 2026-11-20: Lead: Kviz pack size limit 5→10 MB (person's ask via content-lead), 748ce9c, core tests green. cd76f01 had turned main red (Objasni/Uljez pack counts in two TV tests; content ran only pack tests); fixed in 75329ba. Check at the next TV install once picture-heavy Kviz packs land: start time and memory in a Kviz round (all Kviz packs load at start, could reach ~150 MB).
- 2026-11-20: content-lead: b2c179d new Kviz pack hr-hrana-pice 'Hrana i piće' (99 q, 49 photos, 2.2 MB, fact-checked); f819f9e Objasni Krupije→Krupje. Full TV (720) and core (422) suites run. Lead commits the 17-pack test and NEW tag next. Not checked: the photos on the TV.
- 2026-11-20: content-lead: 90e22b4 third Blef pack 'Čudna povijest' (57 sourced facts, 16 Croatian, fact-checked), with its count test in the same commit; full TV and core suites run. Blef now 3 packs, 178 facts. Not checked on the TV.
- 2026-11-20: content-lead: 08a5663 Kviz hr-opce-znanje re-checked, all 401 right, 4 dropped (giveaway/duplicates), 7 reworded → 397 q. Kviz pack tests run; full TV and core run by the writer.
- 2026-11-20: content-lead: fcbe960 Kviz hr-film-glazba re-checked: 1 wrong wording fixed (Q76), 4 photos free only in the US replaced with EU-free ones (Elvis is now a Graceland question), 6 small fixes. Kviz pack and picture tests; full TV run by the writer. Content round 3 done; next: pictures for memes (≥90%) and ~50% pictures elsewhere.
- 2026-11-20: content-lead: 5059cb5 Kviz hr-memeovi pictures on 100/110 questions (91%; person asked ≥90%), free licences only, fact-checked (9 swaps); now a 4.87 MB folder pack (same id, old .json removed). Full TV and core suites run by the writer. Not checked on the TV.
- 2026-11-20: content-lead: 2c81dd5 Kviz hr-opce-znanje (the default pack) pictures on 141/397 (36%; pictures that give the answer away were dropped), 7.5 MB folder pack, fact-checked. One full TV suite run exited 1 with the failing test cut off; reruns passed (720). Possible flaky test, passed to the lead. Lead's run at main: 720 passed, not reproduced; if seen again, rerun with --reporter failures-only.
- 2026-11-20: content-lead: 46daa7b Kviz hr-znanost pictures on 64/129 (50%), fact-checked; 1 duplicate of hr-ljudsko-tijelo dropped. Full TV and core suites run. Picture status: memeovi 91%, hrana 49%, opće znanje 36%, znanost 50%; film-glazba next, 8 packs to go.
- 2026-11-20: content-lead: d86f716 Kviz hr-film-glazba pictures on 41/130 (32%; no pictures that give the answer away), all EU-free licences, fact-checked. Full TV and core suites run. kultura-sport next.
- 2026-11-20: content-lead: cc9cfe0 Kviz hr-kultura-sport pictures on 54/119 (45%), fact-checked, plus 2 older cross-question giveaways fixed; a0d9944 film-glazba Q107 picture swapped (it answered a hr-geografija question). Full TV and core suites run. 5 of 12 picture packs done; povijest next.
- 2026-11-20: content-lead: 3748e3b Kviz hr-povijest pictures on 43/111 (39%), fact-checked; one hr-kultura-sport giveaway fixed (Judita question no longer names Marulić). Full TV and core suites run. 6 of 12 picture packs done; ljudsko-tijelo next.
- 2026-11-20: e7b8283 installed on the TV, not opened (person: "put new version to tv"). Tests core 422, controller 293, TV 720. APK 70.8 MB, was 44.5 MB at 0792735 (+59%, today's pictures). Lead's captures running: start time (until the server listens) and memory during a Kviz round, read at the next play. Mac disk down to 10 GB free (37 GB yesterday).
- 2026-11-20: content-lead: a9ee33c Kviz hr-fizika pictures on 36/107 (34%), fact-checked (3 question fixes, Njutn spelling). Full TV and core suites run. Not on the TV (after e7b8283). 7 of 12 picture packs done; ljudsko-tijelo, zemljopis-svijeta, geografija in progress.
- 2026-11-20: content-lead: e2a6470 Kviz hr-ljudsko-tijelo pictures on 48/106 (45%), family-safe, fact-checked; one hr-psihologija line fixed. Full TV and core suites run. Not on the TV.
- 2026-11-20: content-lead: a59cef2 Kviz hr-zemljopis-svijeta pictures on 43/102 (42%), fact-checked. Full TV and core suites run. Not on the TV. Picture work (~50% list): 8 of 12 done (opće znanje, znanost, film-glazba, kultura-sport, povijest, ljudsko-tijelo, fizika, zemljopis-svijeta); to go: geografija, matematika, psihologija, umjetnost. Separately done: memeovi (91%), hrana-pice (49%). Not in the picture work: medjimurje, oblici, zastave.
- 2026-11-20: content-lead: 5fba511 Kviz hr-geografija pictures on 50/100 (50%), 5.48 MB, fact-checked across packs. Full TV and core suites run. Not on the TV. Picture work 9 of 12; to go: matematika, psihologija, umjetnost.
- 2026-11-20: TV-suite flake likely found (lead): kick_menu_test 'Asset shaders/ink_sparkle.frag not found' when two seats run the TV suite at once in the main checkout (both rewrite apps/tv/build/unit_test_assets). Not a code fault; rerun is fine.
- 2026-11-20: content-lead: db076ad Kviz hr-psihologija pictures on 18/118 (15%) incl. 6 new picture questions (112→118), now a folder pack, fact-checked. Full TV and core suites run. Not on the TV. Picture work 10 of 12; to go: matematika, umjetnost.
- 2026-11-20: content-lead: 3877367 Kviz hr-matematika pictures on 22/121 (18%) incl. 8 new picture questions (113→121), fact-checked. Full TV and core suites run. Not on the TV. Picture work 11 of 12; umjetnost left.
- 2026-11-20: content-lead: picture work done. 3397f81 umjetnost 48%; e968e2d CONTENT.md. Kviz pictures 383→974 of 2,159 questions (45%); bundled Kviz zips ~50 MB. Full TV (720) and core (422) suites pass on the final state. Not on the TV (after e7b8283). Open for the person (docs/CONTENT.md): hr-medimurje changes (person reviews each), a second picture pass for packs under 40% (opće znanje, fizika, film-glazba, povijest), new pack topics.
- 2026-11-21: Person: "You can add new packs." Routed to content-lead (content-newpacks-20261121): Kviz candidates from CONTENT.md, tell PM before a pack over ~5 MB. Second picture pass and hr-medimurje changes still unanswered.
- 2026-11-21: content-lead claimed it: hr-zivotinje, hr-sport-svijet, hr-jezik first (~100 q, ~50% pictures, under 4 MB each); pop-kultura and Glazba 2000+ later. hr-medimurje: person told content-lead "all five" on 2026-11-20; the five fixes (84→83 q, new castle photo, sources note) are in the working tree, suites green, uncommitted until the person reviews them. Second picture pass waiting.
- 2026-11-21: Person asked about the "mobile redesign". Found canvas "Phone Home Redesign" (https://claude.ai/artifact/KubYHAdsEemypKYNBZH8LK, 2026-11-18/19): guests see the host's full game card with settings live, changes light up and list on guests, TV opens its settings panel when the host edits. Never in the plan or routed; only bits exist (carousel Task 27, "Ana gleda" line). Asked the person whether to build it.
- 2026-11-21: Person: "yes build it without kao svi game". Spec section, Task 48, boards copied to docs/design/phone-home/; routed to lead.
- 2026-11-21: Person played on e7b8283 (2026-11-20 evening: Kviz, Krivulja, Uljez, Objasni, Koliko). Lead's TV numbers: first frame 2.1 s, server ready (QR, all packs loaded) ~3 s; memory 205 MB on the home, 222-237 MB in a Kviz round, one 266 MB peak; no low-memory kill; Kviz frames p50 7.8 ms, p95 19.4 ms (as before). 10 MB packs fine for now; check again if packs roughly double.
- 2026-11-21: Same capture: idle home 22-46 frames/min (was ~3650; 6e0fb3c fix confirmed on the TV). No errors all night; 4 Uljez games ended normally (no game events in the log, so Dao sam trag / Idemo glasati not seen directly). New: the Uljez TV screen draws at 60 fps all game (cheap frames, heat/power only); fix routed as uljez-tv-frames, low priority after Task 48.
- 2026-11-21: uljez-tv-frames accepted, 67174e5: the speaker ring's pulse looped forever; now 3 pulses when the speaker changes, then still. New uljez_frames_test, TV 721 green, lead read the diff. Not checked: frames on the real TV (next install), other Uljez screens on a device.
- 2026-11-21: Task 48 accepted (cf0525d…6e29e6c; core 426, TV 756, controller 308 + known flaky join_screen test). Review clean after 2 must-fixes (remote on an empty TV; panel rows for every setting). QA pass on phones at 360/390 px; TV checked from rendered PNGs (no Screen Recording). Settings inline on the home. Differs from the board: neutral wording, Natrag on the pack screen, player lists and Curve legend kept, title stays put, TV pack grid opaque with 5 columns and 36/30 px tile text (below the 40 px rule). Can-stays: Uljez 2 impostors under 7 players shows 2 with both buttons off; TV panel read-only; 40+ uploaded packs overflow 8 px. Not checked: the remote and live TV visuals (next install), Uljez impostors at 7+, Koliko?/Blef at 360 px one by one, a Vukodlak or Curve round, real phones. Pack editor count tests now read packs from disk (fa4a696).
- 2026-11-21: Pack editor suite green on main (fa4a696, 8ab9510; 50/50). Real fix: since the 11-20 '## Photos' sections, deleting a question didn't renumber the sources ('izvori nisu prenumerirani'); an unedited save no longer rewrites hand-spaced lines. Short review running (writes the person's files). The running pack editor gets it on its next start.
- 2026-11-21: Review of the pack editor fix clean. 4 packs' sources aren't one-per-question (geografija, zemljopis-svijeta, medimurje, kultura-sport), so they still only get the note; optional tidy-up with content.
- 2026-11-21: content-newpacks accepted: 325f919 new Kviz packs hr-sport-svijet (99 q, 39 pictures, 2.3 MB), hr-zivotinje (99/51, 3.7 MB), hr-jezik (86/22, 1.7 MB), fact-checked; TV 756, core 426, pack editor 50 green. Kviz now 20 packs, 2,443 q, 44% pictures, ~55 MB zips. Not on the TV; check jezik Q43 accents (è ê ě ë) in the TV font. Pop-kultura and Glazba 2000+ left out (living people, few free photos); asked the person.
- 2026-11-21: Person told content-lead "push all to main"; content-lead pushed 76f2b92..49355d5 (82 commits, no tags). PM scan of that range: no TV address, pairing code or controller.zip. hr-medimurje fixes not pushed (uncommitted, person's review).
- 2026-11-21: Person: clear caches. PM deleted ~/.gradle/caches (8.6 GB; next Android build re-downloads, slower). Free 15 GB. Xcode ModuleCache (3.8 GB) left: other projects' builds were running. Person's old Flutter versions in ~/fvm (7.2 GB) not touched; asked.
- 2026-11-21: Person approved the five hr-medimurje fixes ("commit and push", to content-lead): b1e0ca9 (84→83 q), c873e07 docs, pushed. Scan clean. Not on the TV yet.
- 2026-11-21: Person: in Uljez "always the same person was the uljez" (2026-11-20 play, 4 games). Checked: no bug; each game shuffles with the session's unseeded Random; 1,200 games per player count 3-6 give each player ~1/N, repeats ~1/N; Vukodlak deal uniform too. Guard test 400a238. By chance, one person impostor in 3+ of 4 games: 33% (3 players), 20% (4). Offered the person "never the same impostor twice in a row" (slightly predictable).
- 2026-11-21: Person: "yes to all. We will update the pop pack if we will need to keep it to be up to date." So: Task 49 (no repeat impostor) and a TV install (not opened) after it, to the lead; Hrvatska pop-kultura and Glazba 2000+ packs and the second picture pass for packs under 40%, to content-lead.
- 2026-11-21: Task 49 accepted (a889bd1, review clean; 1,200 games per player count, no repeat, even spread). a889bd1 installed on the TV, not opened (person: yes to all). Carries Task 48, the Uljez frames fix, Task 49, the 3 new Kviz packs (20 packs), Medjimurje fixes. Tests core 426, controller 309, TV 761. APK 89.0 MB (was 70.8). Captures running: Uljez frames, errors, start, memory. The remote on the new home: the person's word at the next play.
- 2026-11-21: Person asked for a new Windows build: build-win tag moved to d40fb8c (person pushed it). Run 44913959186 green (controller + windows 4m), artifact CouchPlay-windows. Not checked on a real PC.
- 2026-11-21: content-lead: 65f9172 new Kviz packs hr-pop-kultura (99 q, no pictures) and hr-glazba-2000 (91 q, 7 pictures); changeable facts carry their year; fact-checked; TV 761, core 426, pack editor 50 green. Kviz now 22 packs, 2,632 q, ~55 MB. Not on the TV (after a889bd1). Picture pass 2 still running.
- 2026-11-21: content-lead: picture pass 2, pack 1 of 4: 2479fd7 hr-opce-znanje 397 -> 402 q, 141 -> 161 pictures (40%), zip 8.0 MB (under the 8.5 MB cap); fact-check 18/20, 2 wording fixes applied; TV 761, core 426, pack editor 50 green. Kviz ~57 MB. Not on the TV. Fizika, film-glazba, povijest with the fact-checker.
- 2026-11-21: content-lead: picture pass 2 done. 147bf73 hr-fizika 107 -> 110 q, 36 -> 40 pictures (1.5 MB); bbc58de hr-film-glazba 130 -> 135 q, 41 -> 50 (3.4 MB); 7c86231 hr-povijest 111 -> 112 q, 43 -> 49 (3.4 MB); docs 9a86f2a. Fact-check fixes applied (charter crop showed the answer, Musikverein wording, Hubble picture dropped as a name hint). Whole pass +39 pictures, 14 new picture questions. Kviz 2,646 q, 43% pictures, ~57 MB. TV 761, core 426, pack editor 50 green. Not on the TV. content-pop-pictures-20261121 closed.
- 2026-11-21: Windows app: the person couldn't download the GitHub artifact (not signed in); PM zipped run 44913959186's CouchPlay-windows and shared it by a 72 h Litterbox link (person asked for a file link). Still not checked on a real PC.
- 2026-11-21: Person feedback after playing: hide sent answers behind the hold card in every game (Task 50); Vukodlak role first with Spreman, one sum per night, rework the confusing night-1 second list after a UX review and field test (Task 51). Spec and plan updated; routed as task50-51-20261121.
- 2026-11-21: Person on Curve: names always visible (bottom, line colors) and a clear round winner; a close finish left the room unsure, which UX should have caught. Task 52, routed as task52-20261121 with a UX pass over a whole round first.
- 2026-11-21: Task 51 steps 1-2 in (480cd32: Spreman, one sum; core 426, TV 779, controller 311 green; in review). Task 50 part 1 in (3ccc3a5, in review), Vukodlak votes next. Night-1 recommendation (Provodadžija picks one lover per night) with the person; build starts 23:15Z unless they say no. Until step 3 lands, main shows two lists on night 1 only for action roles (leaks roles): no TV install before step 3. Curve: A+B with builder-2; extras 3-8 with the person.
- 2026-11-21: Person: Curve no crash mark; winner screen lists every player's points for the round. PM took the lead's recommendation for the rest: tie-at-top line, countdown contrast, 36 px texts to 40+ (builder-2, task52b-b2-20261121); phone round-end message next (build-app, task52-app-20261121); no head ring. Vukodlak night-1 step 3 on HOLD: the person said "No" (to one pick per night, unconfirmed); options 1-3 with the person.
- 2026-11-22: Person picked option 2 for Vukodlak night 1: one list on every phone, then a second pick on the Provodadžija's phone only (accepted risk: a neighbour may see it reopen). Hold lifted; spec updated. Task 50 accepted earlier (8fbb950). Curve: must-fix re-review clean (4328237), phone text "Sudar! Gledaj TV." (5ac2510), QA phones pass; TV side from 1080p PNGs (QA can't see the Mac window).
- 2026-11-22: Tasks 51-53 accepted (Task 53: role card first and back to it after sending, day vote alike; power switch only for Travarica and Vođa čopora, person's call). Farewell header DAN n (f0737ae). Task 54 accepted as is (person: keep it; real Chrome still scrolls ~1.5 rows). TV install of 913e2ca (code = 126a5d5) by the lead, person said "install but don't run": APK 90.7 MB (+1.7), adb Success, not started, TV left asleep. Carries Tasks 50-54, the 2 new Kviz packs and picture pass 2 (22 packs). Logcat + sampler running. Next play confirms: PERF line, memory with 22 packs, Uljez frames, Curve with 8 lines, Vukodlak TV screens, the new home with the remote.
- 2026-11-24: The person stopped the TV logcat capture and memory sampler on purpose; none running, so the next play is unrecorded unless the person asks.
- 2026-11-27: Person asked for two new real-time games: Sumo and Tenkovi (artillery, all fire at once, no aiming hints, wind, Moon). Person's choices: tanks 100 HP, no moving, maps Zemlja / Mjesec / Mars; Sumo with Dash, shrinking ring, ice map and power-ups. Spec `docs/specs/2026-11-27-action-games-design.md`, plan Tasks 55-56, routed to the lead with design boards first.
- 2026-11-27: Sumo i Tenkovi boards (359ec5b, 17 boards) approved by the person as drawn ("Looks good, go"): floating joystick + right-half Dash, kettlebell/arrows/lightning icons, slider + −/+ aim (0° right, 180° left), no barrels while aiming, names on tanks. Build started.
