# CouchPlay content backlog

Owner: content-lead@couchplay-content. Audit 2026-11-20 (counts by script over the pack files; nothing read item by
item yet). Status per line: open / routed / checking / done.

Known gaps across all games, from the earlier content seats' own hand-backs: **no native Croatian read** of the new
wording, and **quiz distractors not page-checked**. The content tests guard format and duplicates only, not facts.

## Kviz (17 bundled packs, 2,146 questions, 383 with pictures)

Sources in `tool/packs/` (`hr-*.json` or `hr-*/` folder + `hr-*.sources.md`); `tool/pack_zip.sh` copies/zips every
`hr-*` into `apps/tv/assets/packs/`. The English `film-music`, `general`, `geography`, `science`, `flags`, `shapes`
are no longer bundled.

| Pack | Questions | Pictures | Note |
|---|---|---|---|
| hr-opce-znanje | 397 | 0 | re-checked 2026-11-20 (08a5663): 401/401 right, 4 dropped, 7 reworded |
| hr-film-glazba | 130 | 14 | re-checked 2026-11-20 (fcbe960): Q76 fixed, 4 US-only-PD photos replaced |
| hr-hrana-pice | 99 | 49 | new 2026-11-20 (b2c179d), fact-checked; NEW tag (0fbf2b1) |
| hr-znanost | 130 | 9 | |
| hr-kultura-sport | 119 | 8 | re-checked 2026-11-20: 3 dropped, 8 fixed, new zvončari photo |
| hr-umjetnost | 122 | 38 | |
| hr-memeovi | 110 | 0 | re-checked 2026-11-20 (6eb4f71): 0 errors, 9 niche/duplicate cut |
| hr-matematika | 113 | 4 | made easier 2026-11-17 |
| hr-psihologija | 112 | 0 | |
| hr-povijest | 111 | 10 | |
| hr-fizika | 107 | 6 | made easier 2026-11-17 |
| hr-ljudsko-tijelo | 106 | 10 | |
| hr-zemljopis-svijeta | 102 | 11 | |
| hr-geografija | 100 | 18 | Croatia only |
| hr-medimurje | 84 | 2 | **person reviews every change** |
| hr-oblici | 50 | 50 | all generated SVG, script-checked |
| hr-zastave | 154 | 154 | grown 2026-11-20 (2b90db6); coat-of-arms SVGs untested on the TV |

Fix:
- [done: kultura-sport 1543f98, memeovi 6eb4f71, film-glazba fcbe960, opće znanje 08a5663] Fact re-check of the
  packs most likely to age. [open] The other 11 packs (znanost, umjetnost, povijest, ...) have not been re-checked.
- [open] Native-language read (diacritics, awkward phrasing, giveaway distractors: one choice clearly a different
  kind from the other three).

Add:
- [done 2b90db6] hr-zastave: more flags (aim ~150; harder lookalikes: Chad/Romania, Indonesia/Monaco, etc.).
- [Hrana i piće done b2c179d; open] New packs from pub-quiz topic lists (topics only, our own wording). Candidates
  left: Životinje, Sport (svijet), Jezik i riječi, Hrvatska pop-kultura, Glazba 2000+. Pick with the person.
- [routed 2026-11-20] Pictures (person): hr-memeovi ≥ 90%, every other pack ~50% (hr-medimurje only with the
  person's review). Free licence only (Commons; no screenshots, stock photos or logos), picture must not give the
  answer away. Researcher sources per pack (`tool/packs/<pack>.pictures.md`), writers wire them in. Pack limit
  is 10 MB since 748ce9c. In progress: memeovi (quiz writer), sourcing from opće znanje down (researcher).
  Risk (build-lead): the TV loads every Kviz pack into memory at start; check start time and memory on the TV once
  the picture packs land (needs the person's yes for the install).

## Uljez (10 packs, 436 pairs)

`apps/tv/assets/uljez/`: crtici 43, hrana 44, kuca 44, mjesta 44, osobe 42, sport 42, zanimanja 42, zivotinje 44,
odjeca 46, prijevoz 45 (new, cd76f01). Tests: `uljez_packs_test`, `session_uljez_test` (pins the pack count).
- [open] Fix: read pairs for "too far apart" (impostor obvious) and "identical" (no game), e.g. Kruh/Pecivo is fine,
  Sir/Jogurt is weak.
- [Odjeća, Prijevoz done cd76f01; open] Add: new themes (Glazba, Filmovi i serije, Hrvatska, Međimurje).

## Objasni (9 packs, 1,081 words)

`apps/tv/assets/objasni/`: opcenito 123, hrana 137, zivotinje 123, osobe 137, mjesta 142, filmovi 102,
medimurje 101 (person approved: no village names, no easy ones), sport 108, zanimanja 108 (new, cd76f01, f819f9e).
Rule: ≥ 100 words, no duplicates. Tests: `objasni_packs_test`, `party_packs_test`, `session_objasni_test` (count).
- [open] Fix: filmovi is at the floor (102); hrana reuses Uljez words one to one.
- [Sport, Zanimanja done cd76f01; open] Add: new themes (Glazba, Hrvatska).

## Koliko? (4 packs, 139 questions)

`apps/tv/assets/koliko/`: godine 44, hrvatska 35, opcenito 30, znanost 30. Every question has a source. 10 per game,
so opcenito/znanost last 3 games before repeats.
- [done 7a0962c: opcenito 62, znanost 63, hrvatska 62, godine 62] Add: grow each to 60+.
- [open] Fix: re-check values that change (populations, heights of buildings, records).

## Blef (3 packs, 178 facts)

`apps/tv/assets/blef/`: priroda 60, svijet 61, povijest 57 (new "Čudna povijest", 90e22b4). 7 per game.
`session_blef_test` pins the pack count.
- [done 2934dbc: priroda 60, svijet 61; done 90e22b4: Čudna povijest 57] Add: grow, third pack.
- [open] Fix: check each answer is short and fake-able, and the fact is still true.

## Tko bi? (2 packs, 86 prompts)

`apps/tv/assets/tkobi/`: blago 45, ljuto 41. 10 per game, repeats after ~8 games. Rules: cheeky but kind; nothing on
looks, weight, health, money, relationships. Test: `tkobi_packs_test`.
- [done a971e99: blago 79, ljuto 77] Add: grow both to 80+ (near-duplicates dropped instead of padding).
- [done a971e99] Fix: read both against the rules.

## Vukodlak (story text, no pack)

`apps/tv/lib/vukodlak/story_hr.dart` (~145 lines of story text, in app code). Tests: `story_hr_test`,
`wolf_story_test`.
- [open] Read for variety and Croatian; edits here are Dart, so a text-only change is ours, anything structural goes
  to build-lead.

## Curve

No content beyond power-up labels (`packages/core/lib/src/powerup_texts.dart`). Nothing planned.
