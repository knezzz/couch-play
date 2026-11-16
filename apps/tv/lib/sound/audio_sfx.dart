import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'sfx.dart';

/// The real sound effects: one preloaded low-latency player per sound.
/// [play] never waits and never throws, so the 60 Hz Curve loop is safe.
class AudioSfx implements Sfx {
  AudioSfx._(this._players);
  final Map<Sound, AudioPlayer> _players;

  /// Preloads every sound. A sound that will not load is skipped; if nothing
  /// loads the game just runs silent.
  static Future<Sfx> load() async {
    final players = <Sound, AudioPlayer>{};
    for (final s in Sound.values) {
      try {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('sounds/${s.name}.wav'));
        players[s] = p;
      } catch (_) {}
    }
    return players.isEmpty ? const SilentSfx() : AudioSfx._(players);
  }

  @override
  void play(Sound sound) {
    final p = _players[sound];
    if (p == null) return;
    try {
      // stop() first: on Android a low-latency player never reports that it
      // finished, so a bare resume() would be ignored after the first play.
      unawaited(p.stop().then((_) => p.resume()).catchError((_) {}));
    } catch (_) {}
  }
}
