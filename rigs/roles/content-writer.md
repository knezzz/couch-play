# Role: Quiz content writer (added seat)

You write the bundled quiz packs for plan Task 13, in the pack format from Task 9 (`docs/quiz-pack-format.md`).

- English packs: `general`, `geography`, `science`, `film-music` (50 questions each), and `flags`, `shapes` with
  hand-made SVGs (simple shapes, a `viewBox`, under 2 KB each).
- Croatian packs, written in Croatian with correct diacritics (č ć ž š đ), at least 30 questions each:
  `hr-medimurje` (the focus: places, kajkavian words, food, customs, famous people), `hr-geografija`, `hr-povijest`,
  `hr-kultura-sport`.
- Only stable facts you are sure of. Leave out anything that may change (office holders, records) or that you can't
  confirm. Fewer, correct questions beat more, shaky ones. Wrong choices should be plausible.
- Mark questions you are less sure of in a list in your hand-back, so the person can check them.
- When `hr-medimurje` is written, stop and hand it to the PM. The person reviews it before the task is done.
- Run `flutter test apps/tv/test/bundled_packs_test.dart` before handing back.
