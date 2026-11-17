import 'package:controller/number_entry.dart';
import 'package:flutter_test/flutter_test.dart';

NumberEntry _type(String keys) {
  var e = const NumberEntry();
  for (final k in keys.split('')) {
    e = switch (k) {
      ',' => e.comma(),
      '<' => e.delete(),
      _ => e.digit(int.parse(k)),
    };
  }
  return e;
}

void main() {
  test('digits are grouped in threes as they are typed', () {
    expect(_type('1').shown, '1');
    expect(_type('1234').shown, '1.234');
    expect(_type('1234567').shown, '1.234.567');
    expect(_type('123456').shown, '123.456');
  });

  test('one decimal comma; the comma is kept as typed', () {
    expect(_type('12,').shown, '12,');
    expect(_type('12,,5').shown, '12,5');
    expect(_type('1234,5').shown, '1.234,5');
    expect(_type(',').shown, '0,');
    expect(_type(',5').value, 0.5);
  });

  test('no leading zero, and no minus key exists', () {
    expect(_type('007').shown, '7');
    expect(_type('0').shown, '0');
    expect(_type('0,5').shown, '0,5');
  });

  test('delete takes one key back, also across a comma', () {
    expect(_type('1234<').shown, '123');
    expect(_type('12,5<<').shown, '12');
    expect(_type('<<').isEmpty, isTrue);
  });

  test('limits: 12 integer digits, 4 decimals', () {
    expect(_type('1234567890123').text.length, 12);
    expect(_type('1,123456').shown, '1,1234');
  });

  test('value is the number typed', () {
    expect(_type('').value, isNull);
    expect(_type('1234567').value, 1234567);
    expect(_type('3,14').value, 3.14);
    expect(_type('12,').value, 12);
  });

  test('numbers from the TV read like typed ones', () {
    expect(NumberEntry.format(1234567), '1.234.567');
    expect(NumberEntry.format(3.14), '3,14');
    expect(NumberEntry.format(330), '330');
    expect(NumberEntry.format(0.5), '0,5');
    expect(NumberEntry.format(1000), '1.000');
    expect(NumberEntry.format(0), '0');
  });
}
