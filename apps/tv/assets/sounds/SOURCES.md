# Sound effects

All files are made in this repo by `tool/make_sounds.py` (sine waves, a
square wave for `wrong`, seeded noise for `crash`; Python standard library
only). No recordings, no samples: nothing to license. Licence: the same as the
rest of the project. 22.05 kHz (nightAmbience and howl 11.025 kHz), 16-bit, mono,
peak at most 35 % of full scale (frequent or long ones lower; tickUrgent and heartbeat 50 %). Run the
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
| menuMove.wav | TV home: focus moves | 40 ms soft click |
| menuConfirm.wav | TV home: a choice is confirmed | two quick rising notes |
| quizTick.wav | quiz: every second of a question | 50 ms soft low tock |
| nightAmbience.wav | Vukodlak: night falls | 8 s low drone and wind that swells in and fades out (one-shot, no loop) |
| howl.wav | Vukodlak: the wolves choose | 1.6 s rising and falling howl |
| rooster.wav | Vukodlak: morning | three-part crow, 0.9 s |
| voteBell.wav | Vukodlak: the vote starts | 1.2 s hand bell |
| drum.wav | Vukodlak: someone is out | 0.6 s low drum |
| tickUrgent.wav | quiz: the fast ticking at the end of a question | 30 ms high click, 50 % |
| heartbeat.wav | quiz: once a second in the last 5 s | low double thump (lub-dub), 50 % |
| timeUp.wav | quiz: time runs out before everyone answered | three falling notes |
