# hr-oblici: sources

No facts from outside: every question is a logic puzzle on a picture drawn for this project (shapes/*.svg, ours to
publish). Pub-quiz logic rounds were a guide to level and style only; nothing is copied.

Task 44 (2026-11-17) made the pack harder: 14 questions kept (hidden-triangle counts, the harder odd-one-out and
sequence questions), 36 replaced (plain counting, side counts, shape names, clocks, the easiest sequences and
odd-one-outs). Every new answer was checked by a script that builds the picture from the same data:
- rotation and mirror questions: exactly one option is a rotation (or the mirror image) of the reference shape,
  tested on the cell sets; every base shape has no symmetry of its own;
- counting: squares, rectangles and triangles counted by brute force over the drawn lines (the counter was first
  checked on known figures: 14 squares in a 3x3 grid, 8 triangles in a square with both diagonals);
- sequences: the rule's next item is exactly one of four distinct options;
- shape algebra: the equations have exactly one solution in 1..20;
- odd one out: exactly one shape lacks the shared property (symmetry, dots = sides, rotation not mirror,
  half shaded, drawable in one stroke by the odd-vertex rule);
- cube nets and dice: each net folded by simulation; valid only if the six squares land on six different faces;
  the opposite face is read from the fold.
