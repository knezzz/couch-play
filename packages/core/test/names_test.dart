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

  test('cleanName_rejects_names_with_nothing_visible', () {
    for (final invisible in [
      '\u200B',
      '\u2060',
      '\uFEFF',
      '\u200B \u2060\uFEFF',
      '\u0000\u0007\u007F',
      '\u202E',
      '\u2066\u2069',
      '\u200E\u200F',
    ]) {
      expect(cleanName(invisible), isNull,
          reason: invisible.codeUnits.map((c) => c.toRadixString(16)).join(' '));
    }
  });

  test('cleanName_drops_invisible_and_bidi_characters', () {
    expect(cleanName('\u202Eana\u202C'), 'ana'); // right-to-left override
    expect(cleanName('\u2066x\u2069'), 'x');
    expect(cleanName('A\u200Bn\u2060a\uFEFF'), 'Ana');
    expect(cleanName('An\u0000a'), 'Ana');
    expect(cleanName('\u202A\u202B\u202C\u202D\u202EBo'), 'Bo');
  });

  test('cleanName_turns_tabs_and_newlines_into_spaces_not_nothing', () {
    expect(cleanName('Ana\tMaria'), 'Ana Maria');
    expect(cleanName('Ana\r\nMaria'), 'Ana Maria');
  });

  test('cleanName_keeps_zwj_so_emoji_sequences_survive', () {
    const family = '👨\u200D👩\u200D👧\u200D👦';
    expect(cleanName(family), family);
    expect(cleanName(family)!.characters.length, 1);
    expect(cleanName('  $family  '), family);
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
