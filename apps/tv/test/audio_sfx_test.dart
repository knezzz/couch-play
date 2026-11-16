import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv/sound/audio_sfx.dart';
import 'package:tv/sound/sfx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every_sound_has_a_small_wav_file_and_a_source_line', () {
    final sources = File('assets/sounds/SOURCES.md').readAsStringSync();
    for (final s in Sound.values) {
      final f = File('assets/sounds/${s.name}.wav');
      expect(f.existsSync(), isTrue, reason: '${s.name}.wav');
      expect(f.lengthSync(), lessThan(60 * 1024), reason: '${s.name}.wav is a short effect');
      expect(sources, contains('${s.name}.wav'));
    }
  });

  test('without_a_working_audio_plugin_loading_gives_silence_and_playing_does_not_throw', () async {
    final sfx = await AudioSfx.load(); // no plugin in unit tests
    for (final s in Sound.values) {
      sfx.play(s);
    }
    expect(sfx, isA<Sfx>());
  });
}
