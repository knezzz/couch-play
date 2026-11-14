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
}
