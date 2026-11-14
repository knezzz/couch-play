/// Every user-facing text on the phone, in Croatian (informal "ti").
/// Texts the TV sends (ErrorMsg, Waiting) are shown as received.
abstract final class Strings {
  // Join
  static const appTitle = 'CouchPlay';
  static const joinHelper = 'Upiši svoje ime da se pridružiš igri na TV-u.';
  static const nameLabel = 'Tvoje ime';
  static const nameLimit = 'Najviše 16 znakova.';
  static const join = 'Pridruži se';
  static const joinAgain = 'Pridruži se ponovno';
  static const emptyName = 'Upiši ime da se pridružiš.';
  static const removed = 'Uklonjen si iz igre.';
  static const ok = 'U redu';

  // Lobby
  static String waitingForHost(String? host) =>
      'Čekaš da ${host ?? 'domaćin'} pokrene igru.';
  static const hostBadge = '★ DOMAĆIN';
  static const pickGame = 'Odaberi igru';
  static const quiz = 'Kviz';
  static const curve = 'Curve';
  static const quizPack = 'Paket pitanja';
  static const addPack = 'Dodaj paket pitanja…';
  static const bots = 'Roboti';
  static const fewerBots = 'Manje robota';
  static const moreBots = 'Više robota';
  static String others(int n) => 'Ostali · $n';
  static const away = ' (nije tu)';
  static const botTag = 'ROBOT';
  static const remove = 'Ukloni';
  static const keep = 'Zadrži';
  static String removeTitle(String name) => 'Ukloniti igrača $name?';
  static String removeBody(String name) =>
      '$name izlazi iz igre i može se ponovno pridružiti sa svog mobitela.';

  // Pack upload
  static const tvProblem = 'TV ima problem. Pokušaj ponovno.';
  static const tvUnreachable =
      'Ne mogu doći do TV-a. Provjeri Wi-Fi i pokušaj ponovno.';

  // Quiz
  static String questionHeader(int n, int total) =>
      'Pitanje $n od $total · gledaj TV';
  static const locked = 'Odgovor je zaključan. Gledaj TV.';
  static const correct = 'Točno';
  static const notThisTime = 'Ovaj put ne';
  static const yourTotal = 'Tvoj ukupni rezultat';

  // Curve
  static const crashed = 'Zabio si se. Pričekaj sljedeću rundu.';

  /// Debug readout of the phone-to-TV round trip, not meant for players.
  static String rtt(int now, int p95, int n) =>
      'rtt ${now}ms · p95 ${p95}ms · n=$n';

  // Results
  static const gameOver = 'Igra je gotova.';
  static String placed(int place) => 'Završio si na $place. mjestu';
  static String sessionPoints(int n) => '+$n ${points(n)} za ovu večer';

  /// bod, boda, bodova
  static String points(int n) {
    final t = n % 100, o = n % 10;
    if (o == 1 && t != 11) return 'bod';
    if (o >= 2 && o <= 4 && (t < 12 || t > 14)) return 'boda';
    return 'bodova';
  }
}
