import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/sound/audio_sfx.dart';

/// The BRAVIA home drew 60 fps forever: a low-latency player on Android never completes,
/// so audioplayers' FramePositionUpdater kept scheduling a frame callback per frame.
void main() {
  testWidgets('audioplayers\' default updater keeps asking for frames (why we replace it)', (t) async {
    final u = FramePositionUpdater(getPosition: () async => null)..start();
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));
    u.stop();
  });

  testWidgets('the Sfx updater never schedules a frame, even after start', (t) async {
    final u = NoFramePositionUpdater()..start();
    await t.pump(const Duration(milliseconds: 100));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    u.stop();
    await u.dispose();
  });
}
