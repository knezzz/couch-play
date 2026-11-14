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

  static void start() => SchedulerBinding.instance.addTimingsCallback(_onTimings);

  static void _onTimings(List<FrameTiming> ts) {
    for (final t in ts) {
      _build.add(t.buildDuration.inMicroseconds);
      _raster.add(t.rasterDuration.inMicroseconds);
      _total.add(t.totalSpan.inMicroseconds);
    }
    if (_sw.elapsed.inSeconds < 60) return;
    // ignore: avoid_print
    print(line(_build, _raster, _total));
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
