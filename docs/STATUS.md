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
| 43 | Kao svi: match the herd (person, 2026-11-17) | built; review clean; QA running | lead + content |
| 44 | Difficulty: Oblici harder, Matematika/Fizika easier, pub-quiz level (person, 2026-11-17) | done (0713aa3, e430b0e): Oblici 36 new; Matematika 113, Fizika 107; next TV install | content |

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
