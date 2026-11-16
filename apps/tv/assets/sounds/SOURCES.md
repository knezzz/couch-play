# Sound effects

All twelve files are made in this repo by `tool/make_sounds.py` (sine waves, a
square wave for `wrong`, seeded noise for `crash`; Python standard library
only). No recordings, no samples: nothing to license. Licence: the same as the
rest of the project. 22.05 kHz, 16-bit, mono, peak 35 % of full scale. Run the
script to regenerate them; the names match `Sound` in `lib/sound/sfx.dart`.

| File | Used for | What it is |
|---|---|---|
| join.wav | a player joins the lobby | two short rising notes |
| countdownBeep.wav | Curve countdown, each second | 440 Hz beep |
| countdownGo.wav | Curve round starts | 880 Hz, longer |
| pickup.wav | a power-up is picked up | rising chirp |
| crash.wav | a head dies | noise burst and a falling tone |
| roundWin.wav | Curve round over | three rising notes |
| matchWin.wav | Curve match over | four rising notes |
| quizStart.wav | a quiz question appears | two notes |
| tick.wav | the last 5 s of a question | 40 ms click |
| right.wav | reveal, someone scored | two rising notes |
| wrong.wav | reveal, nobody scored | low falling buzz |
| fanfare.wav | the quiz ends | short fanfare |
