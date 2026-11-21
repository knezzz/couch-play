import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/uljez/uljez_screen.dart';

/// The BRAVIA drew 60 frames a second all through Uljez (tickers_active 60/60): the speaker's
/// ring pulsed for ever. It pulses a few times when the turn moves, then holds still.
Widget _screen(int turn) => MaterialApp(
      home: UljezScreen(
        seats: [for (var i = 0; i < 4; i++) UljezSeat(id: i, name: 'P$i', colorIndex: i, turn: i == turn)],
        kicker: 'KRUG 1',
        headline: 'Tko je uljez?',
        clockLabel: '',
        clock: '',
      ),
    );

void main() {
  testWidgets('the speaker ring pulses, then the screen settles: no ticker between changes', (t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_screen(0));
    await t.pump(const Duration(milliseconds: 200));
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0), reason: 'it pulses when the turn starts');
    await t.pump(const Duration(seconds: 10));
    expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'still pulsing: the TV draws 60 fps');
    // The turn moves on: it pulses again, then settles again.
    await t.pumpWidget(_screen(1));
    await t.pump(const Duration(milliseconds: 200));
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));
    await t.pump(const Duration(seconds: 10));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });
}
