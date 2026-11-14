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
  const CurveScreen(this.conn, {this.alive = true, super.key});
  final Connection conn;

  /// False after a crash: steering is inert until the next round.
  final bool alive;

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
    // 20 Hz, not 1 Hz: sparse traffic lets the TV's Wi-Fi sleep (p95 ~114 ms
    // at 1 Hz vs ~19 ms at 10 Hz on the Mac), and this keeps the radio warm for steering.
    _ping = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => widget.conn.send(Ping(DateTime.now().millisecondsSinceEpoch)),
    );
  }

  @override
  void didUpdateWidget(CurveScreen old) {
    super.didUpdateWidget(old);
    if (old.alive && !widget.alive) {
      // Ignored pointers never send their release, so release for them or the
      // TV keeps turning this player.
      final held = _left || _right;
      _held[0] = _held[1] = 0;
      if (held) _set(left: false, right: false);
    }
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
        IgnorePointer(
          ignoring: !widget.alive,
          child: Row(
            children: [
              _half(0, '◀', (v) => _set(left: v), const Color(0xFF1E3A5F)),
              _half(1, '▶', (v) => _set(right: v), const Color(0xFF5F1E3A)),
            ],
          ),
        ),
        if (!widget.alive)
          const Center(
            child: Text(
              'You crashed. Wait for the next round.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
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
