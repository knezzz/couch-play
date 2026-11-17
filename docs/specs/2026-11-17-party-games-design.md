# CouchPlay: four new party games, design

Date: 2026-11-17. Status: **approved by the person 2026-11-17: build all four, with new packs for each** (answers below). These games are not part of v1 yet, because
`2026-11-13-couchplay-design.md` lists "other mini-games" as a non-goal. Once the person approves a game, the PM
moves its section into the main design spec and adds a plan task, as was done for Vukodlak and Uljez.

The four games, cheapest first in what they add: **Objasni** (explain the word in teams), **Blef** (bluff trivia),
**Tko bi?** (vote on who in the room fits a prompt) and **Koliko?** (guess the number). All names, words and prompts
are our own.

## What every game here shares

- Each game is one more card in the console carousel (Task 30), with its own background art, a one-line description
  and its settings. The host's phone and the remote pick it the same way as the other games. "Igraj" starts it.
- Croatian interface and content. Text sizes and colours follow the reference screens (TV text at least 40 px,
  phone buttons at least 56–64 px).
- Players are shown with their character and colour wherever they appear.
- When a game ends, its own points become session placement points (`placementPoints`), as in every other game.
- TV sounds come from the existing sound set: menu clicks, the quiz ticker for timers, the reveal and winner
  sounds. Phones stay silent.
- **Dropping out (Claude's call, same as Quiz):** a player who drops out misses what happens while they are gone
  and scores 0 for it, keeps their points, and comes back in at the next step. Votes and answers they miss count as
  "no answer". Anyone who joins late waits for the next game.
- **No bots** in these games: each one depends on real people talking, writing or voting.
- Content lives in pack files that the TV loads like the Uljez word packs (`apps/tv/assets/<game>/`). Each pack
  format is a small JSON file with a parser in `packages/core` that throws `FormatException`, like
  `UljezPack.fromJson`. Uploading packs from the phone, as Quiz allows, is left out for now.

---

## 1. Objasni (explain the word, in teams)

A team word game. One player explains a word without saying it, their team shouts guesses, and the clock runs.

- **Players:** 4–8, split into two teams.
- **Teams (Claude's call):** the game splits the players into two random teams of as near equal size as possible.
  On the start screen the host can tap "Promiješaj" to draw again, then starts the game. Each team has a colour
  (the TV draws the two halves in those colours) and a name, "Tim 1" and "Tim 2".
- **A turn:**
  - The teams take turns, and the explainer rotates through each team so that everyone explains.
  - The explainer's phone shows one word in big type, with two large buttons: **Točno** (+1) and
    **Preskoči** (−1).
  - The next word appears at once after either button.
  - The explainer keeps the phone to themselves. The word stays on screen (no hold to reveal), because they need
    both hands free for the buttons.
- **Rules said out loud, not enforced by the app:** don't say the word or part of it, don't translate it, don't
  spell it, no gestures pointing at things in the room.
- **The other team's phones** show the same word, so they can catch a broken rule (Claude's call). They also get
  a **Prekršaj** button. It ends the current word as −1 and the next word comes up, so the explainer can't keep
  using a broken word. Phones on the explainer's team show only "Pogađaj naglas!" and the time left.
- **TV:**
  - the time left as the quiz's 20-segment ticker, with ticking and the speed-up in the last 5 seconds;
  - the explainer's character and name, big;
  - both team scores;
  - this turn's words, appearing as they are done: green if guessed, grey if skipped, red if called out as
    Prekršaj.
  - The word being explained never shows on the TV.
- **End of a turn:** when time runs out, the word on screen is lost with no points either way. The TV shows the
  turn's words and the score for 5 seconds, then the next explainer's name and "Spreman?". The next turn starts
  when that explainer taps **Kreni** on their phone.
- **End of the game:** when a team reaches the target score at the end of a full round (both teams have had the same
  number of turns). If both teams pass the target in the same round, the higher score wins. If the scores are
  equal, each team plays one more turn, and this repeats until one team leads.
- **Session points:** each player on the winning team scores 1 and each player on the other team scores 0. Those
  results go into `placementPoints`, as in Uljez.
- **Host settings:** time per turn (45 / 60 / 90 s, default 60), target score (20 / 30 / 50, default 30), the word
  pack.
- **Words:** packs of single words or short phrases by theme (Općenito, Hrana, Životinje, Poznate osobe, Mjesta,
  Filmovi i serije, Međimurje…). A word does not come up twice in one game. Format:
  `{"id","title","words":[...]}`, with at least 100 words, none empty, no duplicates. The first pack can start from
  the words in the Uljez packs (both words of each pair).
- **Dropping out:** if the explainer drops out, their turn ends at once with the score it had, and the next turn
  starts. If a team has no connected players left, the game pauses, as Curve does: "Čekamo da se igrači vrate"
  for 30 s, then the game ends with the scores as they are.

## 2. Blef (bluff trivia)

The TV asks a strange question. Everyone writes a believable fake answer, then everyone tries to find the true
answer among the fakes.

- **Players:** 3–8.
- **A question:**
  1. **Writing (60 s):**
     - The TV shows the question, for example "Koliko dugo je trajao najkraći rat u povijesti?".
     - Each phone has a text field of at most 40 characters and a **Pošalji** button.
     - A player who sends the true answer, compared without case, spaces or Croatian diacritics, gets "To je točan
       odgovor! Smisli laž." and must write something else.
     - The TV shows which players have sent their answer (characters light up) but never the answers themselves.
     - Writing ends early when everyone has sent an answer.
  2. **Picking (20 s):**
     - The TV lists every fake plus the true answer, shuffled, in big type.
     - Each phone shows the same list without the player's own fake, and the player taps the one they believe.
     - Identical fakes appear as one entry and count for each of their writers.
  3. **Reveal:**
     - The TV goes through the entries one at a time: the answer, then who picked it.
     - For a fake, it also shows whose fake it was ("Ana je prevarila Marka i Ivu!").
     - The true answer comes last.
- **Points:** finding the true answer +1000; each player your fake fooled +500. Not sending a fake, or picking
  nothing, scores 0 for that part.
- **Game:** 7 questions (host setting 5 / 7 / 10). Results by points, then placement points.
- **Text entry:** the controller already has a text field on the join screen (the name). Blef uses the same kind of
  field. **Risk to check first:** typing in Flutter Web on iOS Safari (keyboard showing, č/ć/š/ž/đ, autocorrect)
  must work on real phones before the screens are built.
- **Content:** packs of strange but **true** facts, each with a short true answer and a source:
  `{"id","title","questions":[{"q","answer","source"}]}`. Answers are short (a number, a name, a few words), so that
  fakes can look like them. All facts are verified, as for the quiz packs. Rude fakes are not filtered: the game is
  played among friends.

## 3. Tko bi? (who in the room)

A warm-up voting game about the people in the room. There are no right answers, only laughs.

- **Players:** 3–8.
- **A prompt:**
  - The TV shows a prompt, for example "Tko bi najvjerojatnije zaspao na vlastitom rođendanu?".
  - Each phone shows every player's character and name, the player's own included. The player taps one: 15 s, one
    tap, no changing the vote (Claude's call: no lock-in screen is needed).
  - The TV shows only how many have voted.
- **Reveal:**
  - The TV shows the characters with the number of votes each got, in a bar chart that grows.
  - The player with the most votes gets a crown and the confetti effect on the TV and on their phone. A tie crowns
    everyone tied.
  - Nobody sees who voted for whom, as in Vukodlak.
- **Points (Claude's call, so that the game can count on the session board):** you score 1 point if your vote went
  to a crowned player, so you read the room right. Being crowned scores nothing. After the last prompt, players are
  placed by their points.
- **Game:** 10 prompts (host setting 5 / 10 / 15), drawn from the chosen pack without repeats.
- **Content:** prompts in Croatian, cheeky but kind. No prompts about looks, weight, health, money troubles,
  relationships or anything that would hurt someone in a mixed group. Packs: "Blago" (default) and "Ljuto"
  (spicier, still within those limits). Format: `{"id","title","prompts":[...]}`, at least 30 prompts.

## 4. Koliko? (guess the number)

Questions whose answer is a number. The closest guess wins. Like the number round of a pub quiz.

- **Players:** 2–8.
- **A question:**
  - The TV shows the question, with its unit, and an optional picture as in Quiz. For example "Koliko je visok
    Eiffelov toranj? (m)".
  - Each phone shows a number pad: digits, a decimal comma, delete and **Pošalji**. The phone groups digits as
    they are typed (1.234.567) so that large numbers can be read. There are no negative numbers. Years work, as
    long as no question asks for a year BC.
  - 30 s (host setting 20 / 30 / 45). The TV shows which players have answered, but not their numbers.
- **Reveal:**
  - The TV draws a number line wide enough to fit every guess and the answer.
  - Each guess slides in as a character marker, then the true answer drops in as a line.
  - The closest guess gets a highlight and confetti.
- **Points per question:** ranked by distance from the answer. Closest 1000, then 750, 500, 250; everyone else 0.
  Equal distances share the higher rank. An exact hit gets +500 on top. No answer scores 0.
- **Game:** 10 questions (host setting 5 / 10 / 15), then placement points.
- **Content:** Croatian packs of number questions with verified answers and a source per question:
  `{"id","title","questions":[{"q","answer","unit","image"?,"source"}]}`. `answer` is a number; `unit` can be
  empty. The pictures follow the quiz pack rules (Commons, credited). Many existing quiz questions are number
  questions with four choices. Those can be converted: the content seat checks each one against its source again.
  Nobody has counted yet how many such questions there are.

## 5. Kao svi (match the herd) (added 2026-11-17, person approved)

Everyone answers the same open question; the goal is to give the SAME answer as most of the room. Our own name and
questions (no cow, no names or tokens from any existing game).

- **Players:** 3–8, no bots.
- **A question:** the TV shows an open question ("Navedi voće.", "Najbolji film svih vremena?", "Koliko jaja u
  omletu?"). Each phone has the Blef text field (≤ 30 characters) and **Pošalji**, 30 s. The TV shows who has
  answered, never the answers.
- **Grouping:** answers are grouped when they match after lower-casing, trimming and removing Croatian diacritics
  ("Jabuka" = "jabuka" = "JABUKA "). The host's phone then shows the groups for 15 s and may merge obvious synonyms
  or plurals by tapping two groups ("jabuka" + "jabuke"); everyone sees the merged result on the TV.
- **Reveal:** the TV shows the groups as stacks of player characters, largest first, with the answer text.
- **Points:** every player in the single largest group scores 1. If two or more groups tie for largest, nobody
  scores. If exactly one player is alone with a unique answer while everyone else is in groups of two or more, that
  player loses 1 point (not below 0).
- **Game:** first to 8 points, or 12 questions (host setting 8 / 12 / 16 questions; target 5 / 8 / 10); then
  placement points.
- **Content:** packs of open questions in Croatian with many plausible answers (`{"id","title","questions":[...]}`,
  ≥ 60 each): Općenito, Hrana, Hrvatska, Međimurje, Pop kultura.

---

## Questions for the person (answered 2026-11-17)

Answers: build all four (order: Objasni, Koliko?, Blef, Tko bi?; PM); skip costs −1; the other team sees the word
with Prekršaj; Tko bi? counts on the session board as written.


1. Which of the four do you want built, and in what order? (Claude's recommendation: Objasni, then Koliko? or
   Blef.)
2. Objasni: should a skipped word cost a point (−1), as written above, or should skipping cost nothing?
3. Objasni: may the other team's phones show the word, with the Prekršaj button?
4. Tko bi?: are points for voting with the majority all right, or should this game stay out of the session
   scoreboard?

## Left out on purpose

Pack upload for these games, custom team names, typing guesses on phones in Objasni, a profanity filter in Blef,
and negative numbers in Koliko?.
