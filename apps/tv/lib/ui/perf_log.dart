import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
    _starts.clear();
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
    // ignore: avoid_print
    if (_starts.isNotEmpty) print('PERF-STARTS ${starts()}');
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

  // Where animations/tickers were started in the last minute: the app frames of the stack that called
  // scheduleFrameCallback (not a reschedule), counted. A ticker that runs for ever shows up here once, with
  // the widget code that started it. (The ticker owners can't be read in a release build.)
  static final _starts = <String, int>{};

  static void noteStart(StackTrace st) {
    final frames = [
      for (final l in st.toString().split('\n'))
        if (l.contains('package:') && !l.contains('/scheduler/') && !l.contains('/animation/') && !l.contains('perf_log')) l.trim().replaceFirst(RegExp(r'^#\d+\s+'), ''),
    ].take(4).join(' < ');
    final key = frames.isEmpty ? 'unknown' : frames;
    if (_starts.length < 200 || _starts.containsKey(key)) _starts[key] = (_starts[key] ?? 0) + 1;
  }

  /// The six most frequent starts: 'n x frames | n x frames'.
  static String starts() {
    final by = _starts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return by.take(6).map((e) => '${e.value}x ${e.key}').join(' | ');
  }
}

/// PERF=true only: a binding that tells [PerfLog] who starts each animation.
mixin PerfStarts on SchedulerBinding {
  @override
  int scheduleFrameCallback(FrameCallback callback, {bool rescheduling = false, bool scheduleNewFrame = true}) {
    if (!rescheduling) PerfLog.noteStart(StackTrace.current);
    return super.scheduleFrameCallback(callback, rescheduling: rescheduling, scheduleNewFrame: scheduleNewFrame);
  }
}

class PerfBinding extends BindingBase with GestureBinding, SchedulerBinding, ServicesBinding, PaintingBinding, SemanticsBinding, RendererBinding, WidgetsBinding, PerfStarts {
  static WidgetsBinding ensureInitialized() {
    // ignore: prefer_conditional_assignment
    if (WidgetsBinding.instance is! PerfBinding) PerfBinding();
    return WidgetsBinding.instance;
  }
}
