/// Croatian texts for the party games' start rules and the TV-to-phone lines.
class PartyText {
  /// The name of a union of packs (the same texts as the TV home's pack line).
  static const allPacks = 'Svi paketi';
  static String somePacks(int ticked, int total) => '$ticked od $total paketa';

  static const soon = 'Ova igra još nije spremna na ovom televizoru.';
  static const noBots = 'Ova igra se igra bez botova. Ukloni botove.';
  static const objasniNeedPlayers = 'Objasni traži 4 do 8 igrača na mobitelima.';
  static const kolikoNeedPlayers = 'Koliko? traži 2 do 8 igrača na mobitelima.';
  static const blefNeedPlayers = 'Blef traži 3 do 8 igrača na mobitelima.';
  static const tkobiNeedPlayers = 'Tko bi? traži 3 do 8 igrača na mobitelima.';
  static const tenkoviNeedPlayers = 'Tenkovi traži 2 do 8 igrača na mobitelima.';
  static const tenkoviName = 'Tenkovi';
  static const objasniName = 'Objasni';
  static const kolikoName = 'Koliko?';
  static const blefName = 'Blef';
  static const tkobiName = 'Tko bi?';
}
