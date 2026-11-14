import 'package:characters/characters.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleanName_trims_and_collapses', () {
    expect(cleanName('  Ana  '), 'Ana');
    expect(cleanName('Ana \t\n  Maria'), 'Ana Maria');
  });

  test('cleanName_rejects_empty_and_whitespace', () {
    expect(cleanName(''), isNull);
    expect(cleanName('   '), isNull);
    expect(cleanName(' \n\t '), isNull);
  });

  test('cleanName_cuts_to_16_graphemes', () {
    expect(cleanName('😀' * 20)!.characters.length, 16);
    expect(cleanName('x' * 40), 'x' * 16);
    // A family emoji is several code points but one character.
    final family = '👨‍👩‍👧‍👦';
    expect(cleanName(family * 20)!.characters.length, 16);
    expect(cleanName('Ana'), 'Ana');
  });

  test('dedupe_adds_a_counter', () {
    expect(dedupeName('Ana', ['Bo']), 'Ana');
    expect(dedupeName('Ana', ['Ana']), 'Ana 2');
    expect(dedupeName('Ana', ['Ana', 'Ana 2']), 'Ana 3');
    expect(dedupeName('ana', ['Ana']), 'ana 2'); // case does not make it different
  });

  test('palette_has_the_eight_colors_in_order', () {
    expect(playerColors.length, 8);
    expect(playerColors.first.toARGB32(), 0xFFFF4D6D);
    expect(playerColors.last.toARGB32(), 0xFFFF7A2F);
    expect(playerColors.toSet().length, 8);
  });
}
