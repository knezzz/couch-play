import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';

/// Two full-height halves; holding one steers. Each half tracks its own
/// pointers so two thumbs work.
/// Value at fraction [q] (0..1) of [sorted] ascending; 0 when empty.
int percentile(List<int> sorted, double q) =>
    sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * q).round()];

class CurveScreen extends StatefulWidget {
  const CurveScreen(this.conn, {super.key});
  final Connection conn;

  @override
  State<CurveScreen> createState() => _CurveScreenState();
}

class _CurveScreenState extends State<CurveScreen> {
  bool _left = false, _right = false;
  // Pointer counts live here, not in build(): the 1 s Pong rebuild must not reset them.
  final _held = [0, 0];
  int? _rtt;
  final _samples = <int>[]; // last 300 round trips, ms
  Timer? _ping;
  StreamSubscription<Message>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.conn.messages.listen((m) {
      if (m is Pong) {
        setState(() {
          _rtt = DateTime.now().millisecondsSinceEpoch - m.t;
          _samples.add(_rtt!);
          if (_samples.length > 300) _samples.removeAt(0);
        });
      }
    });
    _ping = Timer.periodic(
      const Duration(seconds: 1),
      (_) => widget.conn.send(Ping(DateTime.now().millisecondsSinceEpoch)),
    );
  }

  @override
  void dispose() {
    _ping?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _set({bool? left, bool? right}) {
    _left = left ?? _left;
    _right = right ?? _right;
    widget.conn.send(Steer(left: _left, right: _right));
  }

  Widget _half(int side, String label, void Function(bool) set, Color color) {
    return Expanded(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (_held[side]++ == 0) set(true);
        },
        onPointerUp: (_) {
          if (--_held[side] == 0) set(false);
        },
        onPointerCancel: (_) {
          if (--_held[side] == 0) set(false);
        },
        child: Container(
          color: color,
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(fontSize: 96, color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Row(
          children: [
            _half(0, '◀', (v) => _set(left: v), const Color(0xFF1E3A5F)),
            _half(1, '▶', (v) => _set(right: v), const Color(0xFF5F1E3A)),
          ],
        ),
        Positioned(
          top: 4,
          right: 8,
          child: Text(
            _rtt == null
                ? ''
                : 'rtt ${_rtt}ms · p95 ${percentile([..._samples]..sort(), .95)}ms · n=${_samples.length}',
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ),
      ],
    ),
  );
}
