/// Every text the pack checker shows to a person, in Croatian. The TV and the
/// phone show these as received. Wording changes go here and nowhere else.
class PackStrings {
  const PackStrings._();

  static const tooBig = 'Paket je veći od 5 MB. Smanji ga ili izbaci neke slike pa pokušaj ponovno.';
  static const notJson =
      'Paket nije ispravan JSON. Provjeri da je datoteka tekst (UTF-8) i da počinje znakom {.';
  static const badFormat = 'Nepodržan format paketa. Upiši "format": 1.';
  static const badId =
      'Oznaka paketa smije imati samo mala slova, brojke i crtice (1 do 40 znakova).';
  static const needTitle = 'Paketu treba naslov. Upiši ga u "title".';
  static const titleTooLong = 'Naslov paketa smije imati najviše 60 znakova.';
  static const needQuestion = 'Paket mora imati barem jedno pitanje.';
  static const zipNeedsJson = 'Zip mora na vrhu sadržavati točno jednu .json datoteku paketa.';
  static const unzippedTooBig = 'Paket je prevelik kad se raspakira (najviše 20 MB). Smanji slike.';
  static const unreadable = 'Paket se ne može pročitati. Provjeri da datoteka nije oštećena.';

  static String notObject(int n) =>
      'Pitanje $n: mora biti objekt s poljima q, choices i answer.';
  static String emptyQuestion(int n) => 'Pitanje $n: tekst pitanja je prazan. Upiši ga u "q".';
  static String badChoices(int n) =>
      'Pitanje $n: treba točno 4 odgovora i nijedan ne smije biti prazan.';
  static String badAnswer(int n) => 'Pitanje $n: "answer" mora biti 0, 1, 2 ili 3.';
  static String badImage(int n, Object? image) =>
      'Pitanje $n: slika $image mora biti relativna putanja do .svg, .jpg, .png ili .webp datoteke.';
  static String missingImage(int n, String image) =>
      'Pitanje $n: slike $image nema u zipu. Dodaj je ili ukloni "image".';
}
