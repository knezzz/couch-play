import 'package:core/core.dart';

/// Croatian texts the TV sends to a phone during Vukodlak (hints, results).
/// Every text is padded to [wolfTextWidth] so its length says nothing.
class WolfText {
  static const roleNames = {
    WolfRole.wolf: 'Vukodlak',
    WolfRole.alpha: 'Vođa čopora',
    WolfRole.lone: 'Vuk samotnjak',
    WolfRole.villager: 'Seljanin',
    WolfRole.seer: 'Vidovnjakinja',
    WolfRole.doc: 'Ljekarnik',
    WolfRole.guard: 'Tjelohranitelj',
    WolfRole.herb: 'Travarica',
    WolfRole.hunter: 'Lovac',
    WolfRole.elder: 'Starješina',
    WolfRole.mayor: 'Načelnik',
    WolfRole.cupid: 'Provodadžija',
    WolfRole.fool: 'Seoska budala',
    WolfRole.tramp: 'Lutalica',
  };

  static const hintWolves = 'Koga posjećujete?';
  static const hintAlpha = ' Prekidač: žrtva postaje vukodlak.';
  static const hintSeer = 'Čiju ulogu želiš vidjeti?';
  static const hintDoc = 'Koga štitiš noćas?';
  static const hintGuard = 'Koga čuvaš noćas?';
  static const hintHerb = 'Koga liječiš? Uključi prekidač za otrov.';
  static const hintCupid = 'Odaberi dvoje zaljubljenih.';
  static String sum(int a, int b) => 'Koliko je $a × $b?';
  static String sum2(int a, int b, int c, int d) => 'Koliko je $a × $b? A koliko $c × $d?';

  static const quiet = 'Noć je prošla mirno.';
  static const converted = 'Sada si u čoporu vukodlaka.';
  static String saw(String name, WolfRole r) => 'Rezultat: $name je ${roleNames[r]}.';
  static String lover(String name) => 'Tvoj par je $name. Ispadate zajedno.';
  static const needPlayers = 'Vukodlak traži 5 do 8 igrača na mobitelima.';
  static const noBots = 'Vukodlak se igra bez botova. Ukloni botove.';
  static const out = 'Više nisi u igri. Gledaj dalje.';
  static const spectating = 'Gledaš selo.';

  static String pad(String s) {
    final t = s.length > wolfTextWidth ? s.substring(0, wolfTextWidth) : s;
    return t.padRight(wolfTextWidth);
  }
}
