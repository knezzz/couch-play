# Croatian quiz sources: what exists and what we may use

Research for Task 21, 2026-11-15. Read-only web search and fetch; nothing signed up for or submitted.

**Result:** no Croatian pub-quiz or Potjera question set with an open licence was found. Every source below is
"topics, style and difficulty only". All question text in our packs is our own wording of a fact verified elsewhere
(the source per question is in each pack's `.sources.md`). Nothing is copied from the sites below.

| Source | What it has | Licence as stated | Use |
|---|---|---|---|
| [Hrvatski kviz savez, repozitorij](https://hrkviz.hr/repozitorij) | 63 PDFs, 2017–2026. Championship question-and-answer sets (PHP, EDP, Trofej Rukavine) and themed "100" sets (sport, music, STEM, history, 128 Croatian towns). Open answer, about 84 questions per set in 7 categories. Long, clue-led, hard. | Footer: "Copyright © 2026 Hrvatski kviz savez". In the PDF: "© HRVATSKI KVIZ SAVEZ. Zabranjeno korištenje pitanja u komercijalne svrhe." | Style and difficulty only. Do not copy. |
| [AhaSlides, Croatian blog](https://ahaslides.com/hr/blog/general-knowledge-quiz-questions-and-answers/) | About 100 general-knowledge questions per page, machine-translated from English, UK/US topics. | "© 2026 AhaSlides Pte Ltd", no open licence | Not used. |
| [Index.hr on Milijunaš](https://www.index.hr/magazin/clanak/na-ova-pitanja-publika-u-ovoj-sezoni-milijunasa-nije-znala-odgovor/2470061.aspx) | A few HRT Milijunaš questions with their four choices. | "© 2026 Index" | Style only. |
| [tportal on Potjera](https://www.tportal.hr/showtime/clanak/kakva-drama-u-potjeri-lovac-vukorepa-pokazao-zasto-je-jedan-od-najiskusnijih-kvizasa-u-hrvatskoj-odgovorio-na-nevjerojatnih-19-pitanja-i-ulovio-ekipu-20191227) | The show's format, no question text. | "© Hrvatski Telekom 2026. Sva prava pridržana." | Format only. |
| [StudyPal/LLM1 (Hugging Face)](https://huggingface.co/datasets/StudyPal/LLM1) | A generated Croatian quiz file with placeholder answers ("Odgovor A za pitanje 11"). | Apache-2.0 | Useless content. |
| [classla/copa_hr](https://huggingface.co/datasets/classla/copa_hr), [procesaur/znanje](https://huggingface.co/datasets/procesaur/znanje) | A reasoning benchmark and a scientific corpus, not trivia. | CC BY-SA 4.0 | Not trivia. |
| OpenTriviaQA / Open Trivia DB | English multiple-choice trivia, US-centric. | Said to be Creative Commons; not verified | Not used. |

Not found: any Potjera question list, transcription, app or board game; any Croatian TriviaQA or Open Trivia DB set.
Not checked: public Kahoot, Quizlet or Wordwall sets (user-made, terms restrict reuse), Kviskoteka, Najslabija karika,
school competitions. The HKS notice was read in one PDF (PHP 2024) and is assumed for the others.

## Style we take from them

- **Milijunaš / Superpotjera:** one short sentence, four options of the same kind, broad adult knowledge. Examples of
  the kind (topics only): the first word of the Croatian constitution; which Croatian great was of Polish descent;
  whose moustache Dalí copied.
- **HKS:** a fact as a lead-in, then the question ("Iako je rođen u Šibeniku…, gdje…?"). We keep the lead-in idea but
  cut each to one sentence that fits on the TV.
- **Mix:** world knowledge with a Croatian hook where it fits naturally (a Croatian inventor, place or word), so it
  feels like a Croatian quiz rather than a translated one.
