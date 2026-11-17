import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/perf_log.dart';

void main() {
  test('percentile and line', () {
    final v = List.generate(100, (i) => (i + 1) * 1000); // 1..100 ms
    expect(percentile(v, .5), 51000);
    expect(percentile(v, .95), 95000);
    expect(percentile(v, 1), 100000);
    expect(percentile([], .95), 0);
    final l = PerfLog.line(v, v, v);
    expect(l, contains('frames=100'));
    expect(l, contains('total_max=100.0'));
    expect(l, contains('total_over16ms=84'));
  });

  test('each PERF line says which screens the frames were drawn on and whether a ticker was running', () {
    PerfLog.reset();
    PerfLog.note(frames: 1800, screen: 'home', tickers: 0);
    PerfLog.note(frames: 1700, screen: 'home', tickers: 0);
    PerfLog.note(frames: 130, screen: 'curve', tickers: 2);
    PerfLog.note(frames: 5, screen: 'quiz', tickers: 0);
    final c = PerfLog.context();
    expect(c, contains('screens=home:3500,curve:130,quiz:5'), reason: 'most frames first');
    expect(c, contains('tickers_active=1/4'), reason: 'one of four samples had a ticker running');
    expect(c, contains('tickers_max=2'));
    PerfLog.reset();
    expect(PerfLog.context(), contains('screens=-'));
  });

  test('an idle home with no ticker reads as such', () {
    PerfLog.reset();
    PerfLog.note(frames: 3, screen: 'home', tickers: 0);
    expect(PerfLog.context(), 'screens=home:3 tickers_active=0/1 tickers_max=0');
  });

  test('start sites: only app frames, counted, the most frequent first', () {
    PerfLog.reset();
    final st = StackTrace.fromString('''
#0      Ticker.scheduleTick (package:flutter/src/scheduler/ticker.dart:100:5)
#1      AnimationController.forward (package:flutter/src/animation/animation_controller.dart:200:5)
#2      _HomeState.initState (package:tv/ui/home_screen.dart:90:7)
#3      StatefulElement._firstBuild (package:flutter/src/widgets/framework.dart:5000:10)
#4      _rootRun (dart:async/zone.dart:1:1)
''');
    PerfLog.noteStart(st);
    PerfLog.noteStart(st);
    PerfLog.noteStart(StackTrace.fromString('#0 X.y (package:tv/ui/other.dart:1:1)'));
    final out = PerfLog.starts();
    expect(out, startsWith('2x _HomeState.initState (package:tv/ui/home_screen.dart:90:7) < StatefulElement._firstBuild'));
    expect(out, contains('1x X.y (package:tv/ui/other.dart:1:1)'));
    expect(out, isNot(contains('ticker.dart')));
    PerfLog.reset();
    expect(PerfLog.starts(), '');
  });
}
