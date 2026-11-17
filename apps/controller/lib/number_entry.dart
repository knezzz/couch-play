/// The number being typed on Koliko?'s pad: digits, one decimal comma, no
/// minus. The state is the plain text ("1234567,5"); [groupDigits] is what the
/// player sees ("1.234.567,5").
class NumberEntry {
  const NumberEntry([this.text = '']);
  final String text;

  /// Most integer and decimal digits: a double keeps ~15 significant digits.
  static const maxInt = 12, maxDecimals = 4;

  bool get isEmpty => text.isEmpty;

  NumberEntry digit(int d) {
    assert(d >= 0 && d <= 9);
    final c = text.indexOf(',');
    if (c >= 0) {
      return text.length - c - 1 >= maxDecimals ? this : NumberEntry('$text$d');
    }
    if (text == '0') return NumberEntry('$d'); // no leading zero
    return text.length >= maxInt ? this : NumberEntry('$text$d');
  }

  NumberEntry comma() {
    if (text.contains(',')) return this;
    return NumberEntry(text.isEmpty ? '0,' : '$text,');
  }

  NumberEntry delete() =>
      text.isEmpty ? this : NumberEntry(text.substring(0, text.length - 1));

  /// "1.234.567,5": groups of three in the integer part, the comma kept as typed.
  String get shown => groupDigits(text);

  /// The number, or null while nothing is typed.
  double? get value => text.isEmpty
      ? null
      : double.parse(
          text.replaceAll(',', '.').replaceFirst(RegExp(r'\.$'), ''),
        );

  static String groupDigits(String raw) {
    final c = raw.indexOf(',');
    final i = c < 0 ? raw : raw.substring(0, c);
    final rest = c < 0 ? '' : raw.substring(c);
    final b = StringBuffer();
    for (var k = 0; k < i.length; k++) {
      if (k > 0 && (i.length - k) % 3 == 0) b.write('.');
      b.write(i[k]);
    }
    return '$b$rest';
  }

  /// A number from the TV, as a player reads it: 1.234.567 or 3,14 (at most
  /// [maxDecimals] decimals, trailing zeros dropped).
  static String format(double v) {
    var s = v.toStringAsFixed(maxDecimals);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return groupDigits(s.replaceAll('.', ','));
  }
}
