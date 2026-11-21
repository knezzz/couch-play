
import 'dart:async';

import 'package:flutter/material.dart';

import '../number_entry.dart';
import '../strings.dart';
import '../theme.dart';
import 'sent_hold.dart';

/// A Koliko? question: the question, a number pad and Pošalji. After sending
/// (or when the TV says [sent]) the number stays on screen and the pad is shut.
class KolikoAskScreen extends StatefulWidget {
  const KolikoAskScreen({
    super.key,
    required this.number,
    required this.total,
    required this.seconds,
    required this.question,
    required this.unit,
    required this.onSend,
    this.sent,
  });
  final int number, total, seconds;
  final String question, unit;
  final double? sent;
  final void Function(double value) onSend;

  @override
  State<KolikoAskScreen> createState() => _AskState();
}

class _AskState extends State<KolikoAskScreen> {
  NumberEntry _entry = const NumberEntry();
  late int _left = widget.seconds;
  late bool _sent = widget.sent != null;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.sent != null) {
      _entry = NumberEntry(
        NumberEntry.format(widget.sent!).replaceAll('.', ''),
      );
    }
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left > 0) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool get _open => !_sent && _left > 0;

  void _key(NumberEntry Function(NumberEntry) f) {
    if (_open) setState(() => _entry = f(_entry));
  }

  void _send() {
    final v = _entry.value;
    if (!_open || v == null) return;
    setState(() => _sent = true);
    widget.onSend(v);
  }

  @override
  Widget build(BuildContext context) => _sent
      ? SentHoldScreen(
          key: const ValueKey('koliko-sent'),
          title: Strings.questionOf(widget.number, widget.total),
          label: Strings.yourNumberCaps,
          answer:
              _entry.shown + (widget.unit.isEmpty ? '' : ' ${widget.unit}'),
        )
      : _form();

  Widget _form() => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (_, c) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Strings.questionOf(widget.number, widget.total),
                        style: const TextStyle(fontSize: 18, color: muted),
                      ),
                    ),
                    Text(
                      Strings.minutes(_left),
                      key: const ValueKey('koliko-clock'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.question,
                  key: const ValueKey('koliko-question'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                _display(),
                const SizedBox(height: 12),
                _pad(),
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: FilledButton(
                    key: const ValueKey('koliko-send'),
                    onPressed: _open && !_entry.isEmpty ? _send : null,
                    child: const Text(Strings.send),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _display() => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _sent ? raised : accent, width: 2),
    ),
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _entry.isEmpty ? '0' : _entry.shown,
                key: const ValueKey('koliko-display'),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: _entry.isEmpty ? raised : textColor,
                ),
              ),
            ),
          ),
        ),
        if (widget.unit.isNotEmpty) ...[
          const SizedBox(width: 10),
          Text(widget.unit, style: const TextStyle(fontSize: 22, color: muted)),
        ],
      ],
    ),
  );

  Widget _pad() {
    Widget key(String id, String label, VoidCallback onTap, {String? tip}) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Tooltip(
              message: tip ?? label,
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  key: ValueKey('key-$id'),
                  style: FilledButton.styleFrom(
                    backgroundColor: raised,
                    foregroundColor: textColor,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(56, 56),
                    textStyle: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _open ? onTap : null,
                  child: Text(label),
                ),
              ),
            ),
          ),
        );
    Widget row(List<Widget> k) => Row(children: k);
    Widget d(int n) => key('$n', '$n', () => _key((e) => e.digit(n)));
    return Column(
      children: [
        row([d(1), d(2), d(3)]),
        row([d(4), d(5), d(6)]),
        row([d(7), d(8), d(9)]),
        row([
          key(',', ',', () => _key((e) => e.comma())),
          d(0),
          key('del', '⌫', () => _key((e) => e.delete()), tip: Strings.del),
        ]),
      ],
    );
  }
}

/// After the reveal: the true answer, your number, your rank and points.
class KolikoResultScreen extends StatelessWidget {
  const KolikoResultScreen({
    super.key,
    required this.answer,
    required this.value,
    required this.rank,
    required this.points,
    required this.total,
    required this.unit,
  });
  final double answer;
  final double? value;
  final int? rank;
  final int points, total;
  final String unit;

  String _n(double v) => NumberEntry.format(v) + (unit.isEmpty ? '' : ' $unit');

  @override
  Widget build(BuildContext context) {
    final exact = value != null && value == answer;
    final headline = value == null
        ? Strings.noNumber
        : exact
        ? Strings.exactHit
        : rank == 1
        ? Strings.closest
        : rank != null && points > 0
        ? Strings.place(rank!)
        : '';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _card(
                Strings.correctAnswer,
                _n(answer),
                accent,
                const ValueKey('answer'),
              ),
              const SizedBox(height: 12),
              _card(
                Strings.yourNumber,
                value == null ? '–' : _n(value!),
                textColor,
                const ValueKey('your-number'),
              ),
              const SizedBox(height: 24),
              if (headline.isNotEmpty)
                Text(
                  headline,
                  key: const ValueKey('headline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                Strings.plusPoints(points),
                key: const ValueKey('points'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                Strings.totalScore(total),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String label, String text, Color color, Key key) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 18, color: muted)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            key: key,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

