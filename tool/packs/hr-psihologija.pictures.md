# hr-psihologija: picture sourcing

Sourced 2026-11-20 for the content lead (queue task qitem-20261120143701-7140f031657b5db2, pack 11 of 12). No pack file was touched.

**This pack suits pictures only partly.** Most questions are about experiments, dates and theories. Portraits and optical illusions work; the rest don't. I did not pad it to 50 %.

**Numbering:** question numbers are the position in `tool/packs/hr-psihologija.json` (1 to 112, a flat file) as of 2026-11-20.

**Count:** Part A: 22 pictures for existing questions (Q1, 5, 7, 9, 12, 24, 27, 30, 33, 46, 61, 64, 68, 74, 75, 76, 78, 88, 89, 98, 99, 109) = 22 of 112 = 20 %. Part B: 6 proposed NEW picture questions (Penrose triangle, Hermann grid, Ishihara plates, duck-rabbit, Ebbinghaus illusion, Zener cards), each with four choices and a source. With all of B: 28 of 118.

## How it was checked

- Each file's licence, author, size and mime came from the Commons API. Only PD, CC0, CC BY and CC BY-SA were kept. SVGs in Part B were fetched as text and have no `<style>` and no `class=`.
- I re-checked 8 of the 22 Part A files against the live API: licence and width matched in all 8. Part B was not spot-checked.
- **Nobody opened the images.** Look at each when wiring it in.
- **13 questions are marked for rewording.** 10 are "Tko je na slici?" portraits (Q5, 27, 33, 61, 64, 68, 74, 88, 89, 98; under my cap of 12). 3 make the picture the question: Q75 Necker, Q76 Rubin, Q78 Kanizsa.
- Check by eye: B4 duck-rabbit (the SVG may carry the German caption "Kaninchen und Ente"). B3 Ishihara and B4 are 650 to 760 KB SVGs, heavy for flutter_svg on the TV: render-check or use a PNG instead.
- Place photos for Q1 (Yale), Q12 (Johns Hopkins), Q99 (Monte Carlo) are marked "ne", but anyone who recognises the place gets the answer.
- Many portraits are under 640 px, so no picture: Jung, Adler, Piaget, Milgram, Erikson, Vygotsky, Watson, and no usable Marulić portrait (Q112).
- Skipped on purpose: Rorschach blot (Q56 asks "Mrlje od tinte", so any blot gives it away), animal photos for Q10, 11, 94, Maslow pyramid, Bobo doll, Stroop (the Stroop SVG has a `<style>` element), Q101 (the "Ames room" file is a house in Rio with forced perspective), Q91 (baboons fail the mirror test).
- Credit is required for CC BY and CC BY-SA files.

# Slike za paket: psihologija

Slike nisu otvarane ni preuzimane; provjereni su samo podaci s Commonsa (licenca, veličina, tip) i tekst SVG-ova (grep na `<style` i `class=`: 0 pogodaka za sve navedene SVG-ove).

## A. Slike za postojeća pitanja

### 1. Na kojem je sveučilištu Stanley Milgram 1961. započeo pokuse o poslušnosti autoritetu?
- Odgovor: Yale
- Slika: https://commons.wikimedia.org/wiki/File:Sterling_Memorial_Library_seen_from_the_front,_Yale_University,_New_Haven,_Connecticut.jpg
- Autor: Christian David
- Licenca: CC BY-SA 4.0
- Veličina: 5714x4285 px, image/jpeg
- Preoblikovati?: ne (zgrada knjižnice Yalea bez natpisa; odaje odgovor samo onome tko je prepozna)

### 5. Koji je psiholog vodio Stanfordski zatvorski eksperiment 1971.?
- Odgovor: Philip Zimbardo
- Slika: https://commons.wikimedia.org/wiki/File:Philip_Zimbardo.jpg
- Autor: Elekes Andor
- Licenca: CC BY-SA 4.0
- Veličina: 4000x3000 px, image/jpeg
- Preoblikovati?: da — „Tko je na slici, psiholog koji je 1971. vodio Stanfordski zatvorski eksperiment?” (odgovor: Philip Zimbardo)

### 7. Za istraživanje čega je Ivan Pavlov dobio Nobelovu nagradu 1904.?
- Odgovor: Fiziologije probave
- Slika: https://commons.wikimedia.org/wiki/File:Ivan_Pavlov_NLM2.jpg
- Autor: Deschiens
- Licenca: Public domain
- Veličina: 1142x1410 px, image/jpeg
- Preoblikovati?: ne

### 9. Koji je psiholog dao ime kutiji za proučavanje operantnog uvjetovanja životinja?
- Odgovor: B. F. Skinner
- Slika: https://commons.wikimedia.org/wiki/File:Skinner_boxes_01.jpg
- Autor: Luis Dantas
- Licenca: Public domain
- Veličina: 640x480 px, image/jpeg
- Preoblikovati?: ne (slika kutije ne odaje ime)

### 12. Na kojem su sveučilištu Watson i Rayner izveli pokus 'mali Albert'?
- Odgovor: Johns Hopkins
- Slika: https://commons.wikimedia.org/wiki/File:Gilman_Hall,_Johns_Hopkins_University,_Baltimore,_MD.jpg
- Autor: Daderot
- Licenca: Public domain
- Veličina: 3264x2448 px, image/jpeg
- Preoblikovati?: ne (Gilman Hall; odaje odgovor samo onome tko ga prepozna)

### 24. Koje je godine Franz Müller-Lyer osmislio svoju poznatu iluziju?
- Odgovor: 1889.
- Slika: https://commons.wikimedia.org/wiki/File:M%C3%BCller-Lyer_illusion_-_simple.svg
- Autor: Phlsph7
- Licenca: CC0
- Veličina: 512x341 px, image/svg+xml
- Preoblikovati?: ne (pitanje 23 „od čega se sastoji” ovom slikom ne smije imati sliku, jer bi ona odavala odgovor)

### 27. Koga često nazivaju 'ocem američke psihologije'?
- Odgovor: Williama Jamesa
- Slika: https://commons.wikimedia.org/wiki/File:William_James_by_Alice_M._Boughton,_c._1907,_platinum_print,_from_the_National_Portrait_Gallery_-_NPG-NPG_87_37James-000001_(cropped).jpg
- Autor: Alice Boughton
- Licenca: Public domain
- Veličina: 4711x6245 px, image/jpeg
- Preoblikovati?: da — „Tko je na slici, često nazivan 'ocem američke psihologije'?” (odgovor: William James). Pitanje 28 (isti odgovor) ostaje bez slike.

### 30. U kojoj je današnjoj državi rođen Sigmund Freud?
- Odgovor: Češkoj
- Slika: https://commons.wikimedia.org/wiki/File:Sigmund_Freud,_by_Max_Halberstadt_(cropped).jpg
- Autor: Max Halberstadt
- Licenca: Public domain
- Veličina: 1647x2240 px, image/jpeg
- Preoblikovati?: ne

### 33. Koji je psiholog skovao naziv 'halo efekt'?
- Odgovor: Edward Thorndike
- Slika: https://commons.wikimedia.org/wiki/File:PSM_V80_D211_Edward_Lee_Thorndike.png
- Autor: nepoznat
- Licenca: Public domain
- Veličina: 788x1039 px, image/png
- Preoblikovati?: da — „Tko je na slici, psiholog koji je skovao naziv 'halo efekt'?” (odgovor: Edward Thorndike). Pitanje 8 (isti odgovor) ostaje bez slike.

### 46. U kojem je gradu Wilhelm Wundt osnovao prvi psihološki laboratorij?
- Odgovor: U Leipzigu
- Slika: https://commons.wikimedia.org/wiki/File:Wilhelm_Wundt.jpg
- Autor: nepoznat
- Licenca: Public domain
- Veličina: 710x956 px, image/jpeg
- Preoblikovati?: ne

### 61. Što je Phineasu Gageu probilo glavu i promijenilo mu osobnost?
- Odgovor: Željezna šipka
- Slika: https://commons.wikimedia.org/wiki/File:Phineas_Gage_Cased_Daguerreotype_WilgusPhoto2008-12-19_EnhancedRetouched_Color.jpg
- Autor: Jack i Beverly Wilgus (fotografija daguerreotipije)
- Licenca: CC BY-SA 3.0
- Veličina: 811x952 px, image/jpeg
- Preoblikovati?: da — na slici Gage drži šipku, pa slika odaje odgovor. Predlažem: „Tko je čovjek na slici, kojemu je 1848. željezna šipka probila glavu i promijenila mu osobnost?” (odgovor: Phineas Gage)

### 64. Koji efekt kaže da bolje pamtimo prekinute nego dovršene zadatke?
- Odgovor: Efekt Zeigarnik
- Slika: https://commons.wikimedia.org/wiki/File:Bluma_Zeigarnik,_1970-1980s.jpg
- Autor: Andrey Zeigarnik
- Licenca: Public domain
- Veličina: 3422x5000 px, image/jpeg
- Preoblikovati?: da — „Tko je na slici, psihologinja po kojoj je nazvan efekt pamćenja prekinutih zadataka?” (odgovor: Bluma Zeigarnik). Pitanje 65 ostaje bez slike.

### 68. Koja je psihijatrica 1969. opisala pet faza suočavanja sa smrću i gubitkom?
- Odgovor: Elisabeth Kübler-Ross
- Slika: https://commons.wikimedia.org/wiki/File:Elisabeth_Kubler-Ross_%C2%A9Lynn_Gilbert.jpg
- Autor: Lynn Gilbert
- Licenca: CC BY-SA 4.0
- Veličina: 2120x1440 px, image/jpeg
- Preoblikovati?: da — „Tko je na slici, psihijatrica koja je 1969. opisala pet faza suočavanja sa smrću i gubitkom?” (odgovor: Elisabeth Kübler-Ross)

### 74. Koji je psiholog utemeljio terapiju usmjerenu na klijenta?
- Odgovor: Carl Rogers
- Slika: https://commons.wikimedia.org/wiki/File:Carl_Rogers.jpg
- Autor: vvvvv
- Licenca: CC BY-SA 4.0
- Veličina: 1600x1094 px, image/jpeg
- Preoblikovati?: da — „Tko je na slici, utemeljitelj terapije usmjerene na klijenta?” (odgovor: Carl Rogers)

### 75. Koji se lik prividno 'prevrće' u Neckerovoj iluziji iz 1832.?
- Odgovor: Kocka
- Slika: https://commons.wikimedia.org/wiki/File:Necker_cube.svg
- Autor: BenFrantzDale
- Licenca: CC BY-SA 3.0
- Veličina: 400x360 px, image/svg+xml
- Preoblikovati?: da — slika sama je odgovor. „Koji se lik prividno 'prevrće' kad dulje gledaš ovu sliku (Neckerova iluzija, 1832.)?” ili bolje: „Kako se zove ova optička iluzija iz 1832.?” (odgovor: Neckerova kocka; potrebna tri netočna izbora)

### 76. Što se osim vaze može vidjeti na poznatom Rubinovu crtežu?
- Odgovor: Dva lica
- Slika: https://commons.wikimedia.org/wiki/File:Face_or_vase_ata_01.svg
- Autor: Nevit Dilmen
- Licenca: CC BY-SA 3.0
- Veličina: 377x494 px, image/svg+xml
- Preoblikovati?: da — „Što se, osim vaze, može vidjeti na ovoj slici?” (odgovor: Dva lica). Slika odaje odgovor kome pogleda, ali upravo je to pitanje.

### 78. Koji se lik 'vidi' iako nije nacrtan u Kanizsinoj iluziji?
- Odgovor: Trokut
- Slika: https://commons.wikimedia.org/wiki/File:Kanizsa_triangle.svg
- Autor: Fibonacci
- Licenca: CC BY-SA 3.0
- Veličina: 600x600 px, image/svg+xml
- Preoblikovati?: da — „Koji se lik vidi na ovoj slici iako nije nacrtan?” (odgovor: Trokut; slika je pitanje)

### 88. Koja je psihologinja poznata po istraživanjima lažnih sjećanja?
- Odgovor: Elizabeth Loftus
- Slika: https://commons.wikimedia.org/wiki/File:Elizabeth_Loftus-TAM_9-July_2011.JPG
- Autor: BDEngler
- Licenca: CC BY-SA 3.0
- Veličina: 1318x1977 px, image/jpeg
- Preoblikovati?: da — „Tko je na slici, psihologinja poznata po istraživanjima lažnih sjećanja?” (odgovor: Elizabeth Loftus)

### 89. Koji je psiholog 1975. opisao stanje potpune zaokupljenosti zvano 'flow'?
- Odgovor: Mihaly Csikszentmihalyi
- Slika: https://commons.wikimedia.org/wiki/File:Mihaly_Csikszentmihalyi.jpg
- Autor: Ehirsh
- Licenca: Public domain
- Veličina: 673x774 px, image/jpeg
- Preoblikovati?: da — „Tko je na slici, psiholog koji je 1975. opisao stanje 'flowa'?” (odgovor: Mihaly Csikszentmihalyi)

### 98. Koji je psiholog 1998. kao predsjednik APA-e pokrenuo pozitivnu psihologiju?
- Odgovor: Martin Seligman
- Slika: https://commons.wikimedia.org/wiki/File:Martin_Seligman.png
- Autor: The U.S. Army
- Licenca: Public domain
- Veličina: 824x886 px, image/png
- Preoblikovati?: da — „Tko je na slici, psiholog koji je 1998. kao predsjednik APA-e pokrenuo pozitivnu psihologiju?” (odgovor: Martin Seligman). Pitanje 82 (isti odgovor) ostaje bez slike.

### 99. Po kojem mjestu kockarska zabluda nosi i drugo ime, zbog 26 crnih zaredom 1913.?
- Odgovor: Monte Carlo
- Slika: https://commons.wikimedia.org/wiki/File:Casino_de_Montecarlo,_M%C3%B3naco,_2016-06-23,_DD_06.jpg
- Autor: Diego Delso
- Licenca: CC BY-SA 4.0
- Veličina: 3786x2520 px, image/jpeg
- Preoblikovati?: ne (kasino bez natpisa koji bih znao; odaje odgovor onome tko ga prepozna)

### 109. Koji je njemački psihijatar 1924. izumio elektroencefalografiju (EEG)?
- Odgovor: Hans Berger
- Slika: https://commons.wikimedia.org/wiki/File:1st-eeg.png
- Autor: Hans Berger
- Licenca: Public domain
- Veličina: 916x123 px, image/png
- Preoblikovati?: ne (prvi objavljeni EEG čovjeka; vrlo široka i niska slika, na TV-u će biti mala)

## B. Prijedlozi novih pitanja sa slikom

### B1. Kako se zove ova nemoguća figura?
- Izbori: Penroseov trokut (točno) / Kanizsin trokut / Sierpińskijev trokut / Reuleauxov trokut
- Slika: https://commons.wikimedia.org/wiki/File:Penrose-dreieck.svg
- Autor: Tobias R. – Metoc
- Licenca: Public domain
- Veličina: 526x477 px, image/svg+xml

### B2. Kako se zove ova optička iluzija u kojoj se u raskrižjima bijelih pruga pojavljuju sivi mrljasti kvadratići?
- Izbori: Hermannova rešetka (točno) / Müller-Lyerova iluzija / Ponzova iluzija / Neckerova kocka
- Slika: https://commons.wikimedia.org/wiki/File:HermannGrid.svg
- Autor: Mrmw
- Licenca: CC0
- Veličina: 500x500 px, image/svg+xml

### B3. Koji se poremećaj vida otkriva testom s ovakvim pločama?
- Izbori: Sljepoća za boje (daltonizam) (točno) / Kratkovidnost / Dalekovidnost / Astigmatizam
- Slika: https://commons.wikimedia.org/wiki/File:Ishihara_tests_12_74.svg
- Autor: RWhitwam (prema Shinobu Ishihara)
- Licenca: CC BY-SA 4.0
- Veličina: 1632x864 px, image/svg+xml (SVG ima oko 757 KB; velik za flutter_svg, treba isprobati na TV-u)

### B4. Koje se dvije životinje mogu vidjeti na ovoj dvoznačnoj slici?
- Izbori: Patka i zec (točno) / Patka i lisica / Labud i zec / Guska i miš
- Slika: https://commons.wikimedia.org/wiki/File:Kaninchen_und_Ente.svg
- Autor: nepoznat (crtež iz 1892.)
- Licenca: Public domain
- Veličina: 1298x1139 px, image/svg+xml (SVG ima oko 656 KB; nisam otvorio sliku pa ne znam ima li njemački natpis „Kaninchen und Ente” koji bi odao odgovor)

### B5. Kako se zove ova iluzija veličine, u kojoj se isti središnji krug čini različit zbog krugova oko njega?
- Izbori: Ebbinghausova iluzija (točno) / Müller-Lyerova iluzija / Ponzova iluzija / Zöllnerova iluzija
- Slika: https://commons.wikimedia.org/wiki/File:Ebbinghaus_Illusion.svg
- Autor: AlexWorth91
- Licenca: CC0
- Veličina: 155x225 px, image/svg+xml (vektor, ali izvorna veličina je mala)

### B6. Za ispitivanje čega su se koristile Zenerove kartice sa slike?
- Izbori: Izvansenzorne percepcije (ESP, telepatije) (točno) / Inteligencije / Kratkoročnog pamćenja / Sljepoće za boje
- Slika: https://commons.wikimedia.org/wiki/File:Zener_cards_(color).svg
- Autor: Mikhail Ryazanov
- Licenca: CC BY-SA 3.0
- Veličina: 732x252 px, image/svg+xml

## Preskočeno / sumnje

- Rorschach: slike mrlja (Rorschach_blot_08.jpg, PD, 773x673) nisam stavio ni uz 58 ni u B, jer pitanje 56 („Što ispitanik tumači?” — „Mrlje od tinte”) odaje odgovor ako bilo koje drugo pitanje u paketu pokazuje mrlju.
- 23 (Müller-Lyer, „od čega se sastoji”): slika bi odala odgovor; preskočeno. 25 (Stroop, riječi „pogrešnom” bojom): slika odaje odgovor, a Stroop_comparison.svg ima `<style>`; 26 preskočeno.
- 10 (golubovi), 11 (bijeli štakor), 14 (makaki), 15 (majka presvučena tkaninom), 94 (guske), 104 (morski konjić): fotografija životinje ili pokusa odaje odgovor; preskočeno. Hippocampus_(brain).jpg je stilizirani dijagram, nije uz 104 jer ne znam kako izgleda.
- 39 (Bobo): slika lutke odaje odgovor. 40, 41 (Maslow): dijagram piramide odaje odgovor. 75/76/78: slika je sama pitanje, zato je preoblikovanje „da”.
- 101 (Amesova soba): Casaperspectiva.jpg nije Amesova soba nego kuća u Rio de Janeiru sa zavaravajućom perspektivom; Ames_room-uk.png je samo 545x540. Preskočeno.
- 106 (Edip): Ingresov „Edip i Sfinga” je samo 616x800 px (ispod 640), preskočeno.
- 112 (Marulić): nisam našao portret u javnoj domeni veći od 640 px. Judita-str1.gif (naslovnica, 522x812) je premala; kip u Splitu je Meštrovićevo djelo (autor umro 1962.), nije slobodan za upotrebu.
- Premale slike (širina < 640 px) za portrete koji bi inače došli u obzir: Jung (366/271 px), Adler (572/244), Piaget (408/193), Milgram (523), Erikson (233), Vygotsky (225), Watson (237/304/600), Skinner (269–546), Rorschach_inkblots.jpg (410), Bowlby/Harlow/Festinger/Ainsworth/Bujas: ništa nije nađeno.
- Mirror_test_with_a_Baboon.JPG (CC BY-SA 3.0, 742x1024) nije uz 91 jer pavijani ne prolaze test, pa slika zavarava.
- Yerkes_dodson_gesetz.svg (PD) ima njemačke natpise, preskočeno za 83. Ponzo (jedino 654x818 mađarski dijagram) preskočeno jer ne znam što slika sadrži.
- Aaron_T._Beck,_1939.jpg (PD) je školska slika tinejdžera, neprepoznatljiva pa preskočena za 96. Hans_Berger_1938.jpg (CC BY 3.0, 886x1174) ima čudan opis autora; zato je uz 109 uzet snimak prvog EEG-a.
- Mnogo pitanja (godine, nazivi, brojevi) nema smislene slike pa su preskočena.
- Pitanja koja dijele odgovor s pitanjem koje ima portret (8, 28, 65, 82) namjerno nemaju sliku, da se isti portret ne ponavlja.
