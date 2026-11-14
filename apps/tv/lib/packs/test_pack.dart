import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';

const _svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
    '<circle cx="50" cy="50" r="40" fill="#FF4D6D"/></svg>';

/// A small built-in pack so the quiz can be played before real packs exist.
final testPack = QuizPack('test', 'Test pack', const [
  PackQuestion('What is 2 + 2?', null, ['3', '4', '5', '22'], 1),
  PackQuestion('Which planet is known as the Red Planet?', null,
      ['Venus', 'Jupiter', 'Mars', 'Mercury'], 2),
  PackQuestion('What color is this circle?', 'circle.svg',
      ['Red', 'Blue', 'Green', 'Yellow'], 0),
  PackQuestion('How many legs does a spider have?', null, ['6', '8', '10', '12'], 1),
  PackQuestion('Which one is a fruit?', null,
      ['Carrot', 'Potato', 'Banana', 'Onion'], 2),
], {
  'circle.svg': Uint8List.fromList(utf8.encode(_svg)),
});
