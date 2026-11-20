# CouchPlay content backlog

Owner: content-lead@couchplay-content. Audit 2026-11-20 (counts by script over the pack files; nothing read item by
item yet). Status per line: open / routed / checking / done.

Known gaps across all games, from the earlier content seats' own hand-backs: **no native Croatian read** of the new
wording, and **quiz distractors not page-checked**. The content tests guard format and duplicates only, not facts.

## Kviz (16 bundled packs, ~2,050 questions)

Sources in `tool/packs/` (`hr-*.json` or `hr-*/` folder + `hr-*.sources.md`); `tool/pack_zip.sh` copies/zips every
`hr-*` into `apps/tv/assets/packs/`. The English `film-music`, `general`, `geography`, `science`, `flags`, `shapes`
are no longer bundled.

| Pack | Questions | Pictures | Note |
|---|---|---|---|
| hr-opce-znanje | 401 | 0 | biggest; text only |
| hr-film-glazba | 130 | 14 | |
| hr-znanost | 130 | 9 | |
| hr-kultura-sport | 119 | 8 | re-checked 2026-11-20: 3 dropped, 8 fixed, new zvončari photo |
| hr-umjetnost | 122 | 38 | |
| hr-memeovi | 119 | 0 | dated by nature; check what still lands |
| hr-matematika | 113 | 4 | made easier 2026-11-17 |
| hr-psihologija | 112 | 0 | |
| hr-povijest | 111 | 10 | |
| hr-fizika | 107 | 6 | made easier 2026-11-17 |
| hr-ljudsko-tijelo | 106 | 10 | |
| hr-zemljopis-svijeta | 102 | 11 | |
| hr-geografija | 100 | 18 | Croatia only |
| hr-medimurje | 84 | 2 | **person reviews every change** |
| hr-oblici | 50 | 50 | all generated SVG, script-checked |
| hr-zastave | 46 | 46 | smallest; ~150 more flags exist |

Fix:
- [routed 2026-11-20: kultura-sport -> fact-checker] Fact re-check pass, pack by pack, starting with the ones most
  likely to age: kultura-sport, memeovi,
  film-glazba, opće znanje ("current" holders, records, "najveći/najnoviji").
- [open] Native-language read (diacritics, awkward phrasing, giveaway distractors: one choice clearly a different
  kind from the other three).

Add:
- [open] hr-zastave: more flags (aim ~150; harder lookalikes: Chad/Romania, Indonesia/Monaco, etc.).
- [open] New packs from pub-quiz topic lists (topics only, our own wording). Candidates: Hrana i piće, Životinje,
  Sport (svijet), Jezik i riječi, Hrvatska pop-kultura, Glazba 2000+. Pick with the person.
- [open] More pictures where they help (logos are out: trademarks).

## Uljez (8 packs, 345 pairs)

`apps/tv/assets/uljez/`: crtici 43, hrana 44, kuca 44, mjesta 44, osobe 42, sport 42, zanimanja 42, zivotinje 44.
Test: `uljez_packs_test`.
- [open] Fix: read pairs for "too far apart" (impostor obvious) and "identical" (no game), e.g. Kruh/Pecivo is fine,
  Sir/Jogurt is weak.
- [open] Add: new themes (Glazba, Filmovi i serije, Hrvatska, Međimurje, Odjeća, Prijevoz).

## Objasni (7 packs, 865 words)

`apps/tv/assets/objasni/`: opcenito 123, hrana 137, zivotinje 123, osobe 137, mjesta 142, filmovi 102,
medimurje 101 (person approved: no village names, no easy ones). Rule: ≥ 100 words, no duplicates. Tests:
`objasni_packs_test`, `party_packs_test`.
- [open] Fix: filmovi is at the floor (102); hrana reuses Uljez words one to one.
- [open] Add: new themes (Sport, Zanimanja, Predmeti, Glazba, Hrvatska).

## Koliko? (4 packs, 139 questions)

`apps/tv/assets/koliko/`: godine 44, hrvatska 35, opcenito 30, znanost 30. Every question has a source. 10 per game,
so opcenito/znanost last 3 games before repeats.
- [open] Add: grow each to 60+; convert number questions from the Kviz packs (re-checked against the source each).
- [open] Fix: re-check values that change (populations, heights of buildings, records).

## Blef (2 packs, 63 facts)

`apps/tv/assets/blef/`: priroda 30, svijet 33. 7 per game: **the thinnest game**, repeats after ~9 games.
- [routed 2026-11-20: priroda -> party-writer; svijet next] Add: grow both to 60+; new pack (Povijest / Hrvatska / Ljudi i izumi).
- [open] Fix: check each answer is short and fake-able, and the fact is still true.

## Tko bi? (2 packs, 86 prompts)

`apps/tv/assets/tkobi/`: blago 45, ljuto 41. 10 per game, repeats after ~8 games. Rules: cheeky but kind; nothing on
looks, weight, health, money, relationships. Test: `tkobi_packs_test`.
- [open] Add: grow both to 80+.
- [open] Fix: read both against the rules.

## Vukodlak (story text, no pack)

`apps/tv/lib/vukodlak/story_hr.dart` (~145 lines of story text, in app code). Tests: `story_hr_test`,
`wolf_story_test`.
- [open] Read for variety and Croatian; edits here are Dart, so a text-only change is ours, anything structural goes
  to build-lead.

## Curve

No content beyond power-up labels (`packages/core/lib/src/powerup_texts.dart`). Nothing planned.
