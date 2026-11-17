import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Curve power-up legend, shared by the TV home and the host's phone.
void main() {
  test('every power-up has a name, one line and a time', () {
    for (final k in PowerUpKind.values) {
      final t = powerUpTexts[k];
      expect(t, isNotNull, reason: '$k');
      expect(t!.name.trim(), isNotEmpty);
      expect(t.what.trim(), isNotEmpty);
      expect(t.time.trim(), isNotEmpty);
      expect(t.what.length, lessThan(120), reason: 'one line, not a paragraph: $k');
    }
    expect(powerUpTexts.length, PowerUpKind.values.length);
  });

  test('who it acts on: green is you, red is everyone else, blue is everyone', () {
    for (final k in [PowerUpKind.speed, PowerUpKind.slow, PowerUpKind.ghost, PowerUpKind.cheese]) {
      expect(powerUpActsOn(k), PowerUpTarget.you, reason: '$k');
    }
    for (final k in [PowerUpKind.speedOthers, PowerUpKind.slowOthers, PowerUpKind.fatOthers, PowerUpKind.reverseOthers, PowerUpKind.squareOthers]) {
      expect(powerUpActsOn(k), PowerUpTarget.others, reason: '$k');
    }
    expect(powerUpActsOn(PowerUpKind.clear), PowerUpTarget.all);
    expect(powerUpActsOn(PowerUpKind.wrap), PowerUpTarget.all);
  });

  test('names are distinct, and no gendered past forms: the legend reads for anyone', () {
    final names = powerUpTexts.values.map((t) => t.name).toSet();
    expect(names.length, powerUpTexts.length);
    for (final t in powerUpTexts.values) {
      expect(t.what, isNot(matches(RegExp(r'\b\w+(ao|ila|ela)\b'))), reason: t.what);
    }
  });

  test('the fat line lasts longer, clear is instant', () {
    expect(powerUpTexts[PowerUpKind.clear]!.time, 'odmah');
    expect(powerUpTexts[PowerUpKind.fatOthers]!.time, '7,5 s');
    expect(powerUpTexts[PowerUpKind.speed]!.time, '5 s');
  });
}
