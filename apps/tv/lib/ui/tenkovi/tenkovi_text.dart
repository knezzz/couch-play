import 'package:core/core.dart';

/// Croatian texts on the Tenkovi TV screens.
class TenkoviText {
  static String map(TenkoviMap m) => switch (m) {
        TenkoviMap.earth => 'Zemlja',
        TenkoviMap.moon => 'Mjesec',
        TenkoviMap.mars => 'Mars',
      };
  static String round(int n, int of) => 'Runda $n od $of';
  static const aimKicker = 'Nišanite';
  static String ready(int n, int of) => 'Spremno $n / $of';
  static String turn(int n) => 'okret $n';
  static const volley = 'Pucaju svi!';
  static const wind = 'Vjetar';
  static const noWind = 'Bez vjetra';
  static const draw = 'Neriješeno';
}
