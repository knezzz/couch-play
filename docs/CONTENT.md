# CouchPlay content backlog

Owner: content-lead@couchplay-content. Audit 2026-11-20 (counts by script over the pack files; nothing read item by
item yet). Status per line: open / routed / checking / done.

Known gaps across all games, from the earlier content seats' own hand-backs: **no native Croatian read** of the new
wording, and **quiz distractors not page-checked**. The content tests guard format and duplicates only, not facts.

## Kviz (22 bundled packs, 2,632 questions, 1,093 with pictures = 42%; ~55 MB of zips)

Sources in `tool/packs/` (`hr-*.json` or `hr-*/` folder + `hr-*.sources.md`); `tool/pack_zip.sh` copies/zips every
`hr-*` into `apps/tv/assets/packs/`. The English `film-music`, `general`, `geography`, `science`, `flags`, `shapes`
are no longer bundled.

| Pack | Questions | Pictures | Note |
|---|---|---|---|
| hr-opce-znanje | 397 | 141 | re-checked (08a5663); pictures 2c81dd5; 7.5 MB |
| hr-film-glazba | 130 | 41 | re-checked (fcbe960); pictures d86f716, a0d9944 |
| hr-hrana-pice | 99 | 49 | new 2026-11-20 (b2c179d), fact-checked; NEW tag (0fbf2b1) |
| hr-znanost | 129 | 64 | pictures 46daa7b (Q34 dropped as a ljudsko-tijelo duplicate) |
| hr-kultura-sport | 119 | 54 | re-checked (1543f98); pictures cc9cfe0 |
| hr-umjetnost | 122 | 59 | pictures 3397f81; 5.9 MB |
| hr-memeovi | 110 | 100 | re-checked (6eb4f71); pictures 5059cb5 (person asked ≥ 90%) |
| hr-matematika | 121 | 22 | pictures + 8 new picture questions 3877367 |
| hr-psihologija | 118 | 18 | pictures + 6 new picture questions db076ad |
| hr-povijest | 111 | 43 | pictures 3748e3b |
| hr-fizika | 107 | 36 | pictures a9ee33c |
| hr-ljudsko-tijelo | 106 | 48 | pictures e2a6470 (family-safe) |
| hr-zemljopis-svijeta | 102 | 43 | pictures a59cef2 |
| hr-geografija | 100 | 50 | Croatia only; pictures 5fba511; 5.5 MB |
| hr-medimurje | 83 | 2 | **person reviews every change**; 5 fact-check fixes approved (b1e0ca9) |
| hr-oblici | 50 | 50 | all generated SVG, script-checked |
| hr-zastave | 154 | 154 | grown 2026-11-20 (2b90db6); coat-of-arms SVGs untested on the TV |
| hr-zivotinje | 99 | 51 | new 2026-11-21 (325f919), fact-checked; NEW tag |
| hr-sport-svijet | 99 | 39 | new 2026-11-21 (325f919), world sport only; NEW tag |
| hr-jezik | 86 | 22 | new 2026-11-21 (325f919), two sources per fact, nothing political; Q43 accented e letters untested on the TV font; NEW tag |
| hr-pop-kultura | 99 | 0 | new 2026-11-21 (65f9172); facts that can change carry a year; person updates it when needed; NEW tag |
| hr-glazba-2000 | 91 | 7 | new 2026-11-21 (65f9172); same rule; split with pop-kultura (Croatian Eurovision and pre-2000 there); NEW tag |

Fix:
- [done: kultura-sport 1543f98, memeovi 6eb4f71, film-glazba fcbe960, opće znanje 08a5663] Fact re-check of the
  packs most likely to age. [open] The other 11 packs (znanost, umjetnost, povijest, ...) have not been re-checked.
- [open] Cross-pack duplicate clean-up (found during the picture checks): hr-ljudsko-tijelo Q37 = hr-znanost Q94
  (hemoglobin metal), Q32 ~ znanost Q95 (hormon rasta), Q33 ~ znanost Q28 (vitamin D); in-pack Q9 picture -> Q19
  (Ošit); hr-psihologija Q104 ~ hr-ljudsko-tijelo Q21 (hipokampus / morski konjić). pack_duplicates_test only
  catches identical text.
- [open] Native-language read (diacritics, awkward phrasing, giveaway distractors: one choice clearly a different
  kind from the other three).

Add:
- [done 2b90db6] hr-zastave: more flags (aim ~150; harder lookalikes: Chad/Romania, Indonesia/Monaco, etc.).
- [done: Hrana i piće b2c179d; Životinje, Sport u svijetu, Jezik i riječi 325f919; Hrvatska pop-kultura, Glazba
  2000+ 65f9172] New packs from pub-quiz topic lists (topics only, our own wording; person's yes 2026-11-21).
  [open] Keep hr-pop-kultura and hr-glazba-2000 current: re-check their year-tagged facts when the person asks
  (hosts, festival venues/names, "do 2026." records).
- [open, optional] Sources lists the pack editor can't renumber on a delete (build-lead, 8ab9510): it needs exactly
  one line per question above the first `## `. hr-geografija (82 of 100), hr-zemljopis-svijeta (91 of 102),
  hr-kultura-sport (partial list 112-119), hr-medimurje (82 of 84; person reviews). Safe as is.
- [done 2026-11-20] Pictures (person): hr-memeovi ≥ 90% (90%), every other pack ~50% (12 packs, 15-50%; packs
  where pictures would show the answer stayed lower rather than pad). Free licence only, checked on every Commons
  file page; no picture gives away an answer in any pack (checked both ways). Researcher lists in
  `tool/packs/<pack>.pictures.md`. Pack limit 10 MB since 748ce9c. hr-medimurje not done (person's call).
  [open, person] Second pass for packs under 40% (opće znanje, fizika, film-glazba, povijest): new picture
  questions from the unsearched questions listed in each pictures.md.
  [open, needs the person's yes] TV check: the TV loads every Kviz pack (~50 MB of zips now) into memory at start;
  check start time and memory on the BRAVIA (build-lead's risk note).

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
