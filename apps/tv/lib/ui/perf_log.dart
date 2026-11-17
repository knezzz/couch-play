import 'package:flutter/scheduler.dart';

/// Value at fraction [q] (0..1) of [sorted] ascending; 0 when empty.
int percentile(List<int> sorted, double q) =>
    sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * q).round()];

/// PERF=true only: one log line per 60 s with frame-time stats in ms.
/// Lists are cleared (not reallocated) after each line, so memory is flat.
class PerfLog {
  PerfLog._();

  static final _build = <int>[], _raster = <int>[], _total = <int>[];
  static final _sw = Stopwatch()..start();

  /// The name of the screen on show (home, quiz, curve, ...), set by the app so each PERF
  /// line says where its frames were drawn.
  static String Function()? screen;

  static final _screens = <String, int>{};
  static var _tickSamples = 0, _tickActive = 0, _tickMax = 0;

  static void start() => SchedulerBinding.instance.addTimingsCallback(_onTimings);

  /// Records [frames] drawn on [screen] while [tickers] tickers/animations were running.
  static void note({required int frames, required String screen, required int tickers}) {
    _screens[screen] = (_screens[screen] ?? 0) + frames;
    _tickSamples++;
    if (tickers > 0) _tickActive++;
    if (tickers > _tickMax) _tickMax = tickers;
  }

  static void reset() {
    _screens.clear();
    _tickSamples = _tickActive = _tickMax = 0;
  }

  /// 'screens=home:3500,curve:130 tickers_active=1/4 tickers_max=2': frames per screen, and
  /// in how many samples a Ticker (an AnimationController, a Flame loop) was running: a ticker
  /// is what asks for a frame every vsync.
  static String context() {
    final by = _screens.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final screens = by.isEmpty ? '-' : by.map((e) => '${e.key}:${e.value}').join(',');
    return 'screens=$screens tickers_active=$_tickActive/$_tickSamples tickers_max=$_tickMax';
  }

  static void _onTimings(List<FrameTiming> ts) {
    for (final t in ts) {
      _build.add(t.buildDuration.inMicroseconds);
      _raster.add(t.rasterDuration.inMicroseconds);
      _total.add(t.totalSpan.inMicroseconds);
    }
    note(
      frames: ts.length,
      screen: screen?.call() ?? '?',
      tickers: SchedulerBinding.instance.transientCallbackCount,
    );
    if (_sw.elapsed.inSeconds < 60) return;
    // ignore: avoid_print
    print('${line(_build, _raster, _total)} ${context()}');
    reset();
    _build.clear();
    _raster.clear();
    _total.clear();
    _sw.reset();
  }

  static String line(List<int> build, List<int> raster, List<int> total) {
    String ms(int us) => (us / 1000).toStringAsFixed(1);
    String stats(String n, List<int> v) {
      final s = [...v]..sort();
      return '${n}_p50=${ms(percentile(s, .5))} ${n}_p95=${ms(percentile(s, .95))} '
          '${n}_max=${ms(percentile(s, 1))}';
    }

    final over = total.where((us) => us > 16000).length;
    return 'PERF frames=${total.length} ${stats('build', build)} '
        '${stats('raster', raster)} ${stats('total', total)} total_over16ms=$over';
  }
}
