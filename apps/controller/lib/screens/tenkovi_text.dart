import 'package:core/core.dart';

/// Croatian texts on the Tenkovi phone screens.
class TenkoviStrings {
  static String round(int n, int of) => 'Runda $n od $of';
  static const wind = 'Vjetar';
  static const noWind = 'Bez vjetra';
  static String windValue(int w) => w == 0 ? noWind : '${w < 0 ? '←' : '→'} ${w.abs()}';
  static String life(int hp) => 'Život $hp';

  static const angle = 'Kut';
  static const power = 'Snaga';
  static const shell = 'Projektil';
  static String degrees(int a) => '$a°';
  static String shellName(TenkoviShell s) => switch (s) {
        TenkoviShell.grenade => 'Granata',
        TenkoviShell.heavy => 'Teška bomba',
        TenkoviShell.cluster => 'Kasetna',
        TenkoviShell.bomblet => 'Kasetna',
      };
  static const none = '0';
  static const unlimited = '∞';
  static const one = '1';

  static String lastValues(int a, int p) => '$a°, $p';
  static const lastTimeButton = 'Prošli put';
  static const fire = 'Pucaj';

  static const sentCaps = 'TVOJ HITAC';
  static String angleAndPower(int a, int p) => 'Kut $a° · Snaga $p';
  static const holdHint = 'Tvoj hitac se vidi samo dok držiš.\nPusti i nestaje.';
  static String turn(int n) => 'Okret $n';
  static String roundTurn(int n, int of, int turn) => 'Runda $n od $of · okret $turn';
  static const sentTitle = 'Pucaj je poslan';
  static const waitOthers = 'Čekamo ostale';
  static const volleyTitle = 'Pucaju svi';
  static const watchTv = 'Gledaj TV';
  static String stillAiming(int n) => 'Još ciljaju · $n';
  static const privacyNote = 'Tvoj hitac se ne vidi na TV-u dok svi ne pucaju.';
  static String ready(int n, int of) => 'Spremno $n od $of';
  static const volley = 'Pucaju svi. Gledaj TV.';
  static const out = 'Ispao si u ovoj rundi. Gledaj TV.';

  static const roundOver = 'Runda je gotova';
  static const youWon = 'Pobijedio si rundu!';
  static const draw = 'Neriješeno';
  static String roundPoints(int p, int total) => 'Bodovi u rundi: +$p · Ukupno: $total';
  static const nextRound = 'Sljedeća runda uskoro.';

  // Phone home (host settings and the game card).
  static const mapLabel = 'Mapa';
  static const roundsLabel = 'Broj rundi';
  static String mapName(TenkoviMapPick m) => switch (m) {
        TenkoviMapPick.earth => 'Zemlja',
        TenkoviMapPick.moon => 'Mjesec',
        TenkoviMapPick.mars => 'Mars',
        TenkoviMapPick.random => 'Nasumično',
      };
  static const name = 'Tenkovi';
  static const blurb = 'Svi ciljaju, svi pucaju odjednom.';
}
