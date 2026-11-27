# Action games: Sumo and Tenkovi (person request, 2026-11-27)

Two new real-time games for the TV, like Curve: **Sumo** (push the others off a ring) and **Tenkovi** (artillery: everyone
aims at once, all tanks fire together). "Sumo" and "Tenkovi" are working names; the person can rename them.
Original games in a known genre: our own look, characters and names, nothing copied from an existing game.

Both games use what the console already has: player colors and characters, the home card and phone carousel, host
settings on the phone home (Task 48), sounds from the existing set plus a few new ones, Curve's "names always visible"
and "clear round winner" screens, and the session board. Choices marked *(person)* are the person's answers of
2026-11-27; the rest are PM calls the person can change.

## Sumo (2–8 players)

- **Board:** a round ring seen from above, on the console look. Each player is a round wrestler in their color with
  their character's face; names stay along the bottom edge as in Curve.
- **Phone:** a joystick on the left half (drag anywhere to push in that direction; harder drag = more force) and a
  big **Dash** button on the right. Input goes as state changes (direction quantised, e.g. 16 steps, and force in a
  few steps), not per frame, so traffic stays as small as Curve's.
- **Physics:** wrestlers have momentum and mass and bounce off each other; leaving the ring's edge means out for the
  round. Simulation on the TV at a fixed 60 Hz tick, like Curve.
- **Dash *(person)*:** a short, strong push in the joystick direction, then about 2 s to recharge; the button shows the
  recharge as a draining ring.
- **Ring shrinks *(person)*:** after about 20 s the ring starts to shrink, so a round ends in about 60 s.
- **Maps *(person)*:** Klasični (normal grip) and Led (ice: wrestlers slide and are hard to stop). Host setting: Klasični,
  Led or Nasumično (random each round).
- **Power-ups *(person)*:** icons appear on the ring from time to time; the first wrestler to touch one gets it for a few
  seconds: Težak (heavier, hard to push), Velik (bigger), Brz (faster). Shown on the TV like Curve's active effects (a
  ring around the wrestler that drains). Host setting like Curve's modes: with or without power-ups. Icons, timings and
  spawn rate are left to the builder, in the Curve icon style.
- **Scoring:** as Curve: points = number of players you outlived in the round; first to `10 × (players − 1)` wins.
  Clear round winner, then every player's round points, as in Curve.
- **Drop-outs:** a player who disconnects is out for that round and comes back from the next one (Curve's rules).
- Left out for now: bots.

## Tenkovi (2–8 players)

- **Board:** a side view of hilly ground across the full TV width; tanks in player colors with the character's face
  and name, spread evenly in a random order each round. Craters stay where shots land; a tank whose ground is blown
  away drops onto what is below (no fall damage).
- **Health *(person)*:** 100 HP, a bar above each tank. Damage falls off with distance from the blast: a direct hit about
  50, near misses less. Your own shots hurt you too. A tank at 0 is out for the round.
- **No moving *(person)*:** tanks stay where they were placed.
- **A turn:** every living player sets **angle** (0–180°), **power** (0–100) and **projectile** on the phone and presses
  **Pucaj**. The phone keeps last turn's angle and power as the start, with big +/− buttons for fine steps, and shows
  "Prošli put: 45°, 70". No timer: the volley fires when every connected living player has pressed Pucaj; a disconnected
  player's tank does not fire.
- **No hints *(person)*:** until the volley fires, the TV shows only who is ready (a tick), never anyone's angle,
  power or projectile; barrels do not turn before firing. After Pucaj the phone hides the aim behind the hold-to-see
  card (main spec, "Hidden answers on phones").
- **The volley:** all shots leave together and fly in real time (a few seconds), with their trails; blasts land,
  damage counts at the same time for everyone, so two tanks can knock each other out. Faint trails of the last
  volley stay until the next one fires.
- **Projectiles:** Granata (normal, unlimited), Teška bomba (big blast, 1 per round), Kasetna (splits into small bombs
  at the top of its arc, 1 per round). The phone shows what is left. Exact blast sizes and damage left to the builder.
- **Maps *(person)*:** host setting Zemlja, Mjesec, Mars or Nasumično (random each round).
  - Zemlja: normal gravity; wind changes every turn.
  - Mjesec: low gravity, no wind, dark sky with the Earth on it; shots fly long and high.
  - Mars: medium gravity, red ground, strong dust-storm wind that changes every turn.
  - The wind is shown on the TV for the coming turn as an arrow and a number, and on every phone.
- **Rounds:** a round ends when one tank or none is left (all out at once is a draw, no points). Points as Curve
  (players outlived); host setting "Broj rundi", default 3; most points wins. Clear round winner, then every player's
  round points.
- **Drop-outs:** a disconnected player's tank stays on the board and doesn't fire; they can come back and play the
  next turn.
- Left out for now: bots, moving tanks, more projectile types.

## Both games

- Performance on the real TV: 8 wrestlers / 8 tanks with blasts and trails at 60 Hz, as Curve's gate measured.
- Phones at 360×640 to 390×844; controls big enough for a sofa.
- Sounds: hits, blasts, dash, falling off the ring, round win, from the existing set plus a few new ones.
