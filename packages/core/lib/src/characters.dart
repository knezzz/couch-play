/// The player characters (animals). The id is what travels in the protocol and
/// names the drawing. The order is fixed: a phone's grid and the TV's agree.
const characterIds = [
  'fox',
  'owl',
  'frog',
  'bear',
  'cat',
  'dog',
  'rabbit',
  'penguin',
  'lion',
  'panda',
  'pig',
  'koala',
  'mouse',
  'tiger',
  'duck',
  'monkey',
];

bool isCharacter(String id) => characterIds.contains(id);
