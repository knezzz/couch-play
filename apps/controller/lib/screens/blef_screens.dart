
import 'dart:async';

import 'package:flutter/material.dart';

import '../strings.dart';
import '../theme.dart';
import 'blef_field.dart';

/// Writing a fake answer: the question, a clock, the text field. When the TV
/// has accepted the fake ([sent] is set) the field is gone and only your own
/// text shows.
class BlefWriteScreen extends StatefulWidget {
  const BlefWriteScreen({
    super.key,
    required this.number,
    required this.total,
    required this.seconds,
    required this.question,
    required this.onSend,
    this.sent,
    this.error,
  });
  final int number, total, seconds;
  final String question;

  final String? sent, error;
  final void Function(String text) onSend;

  @override
  State<BlefWriteScreen> createState() => _WriteState();
}

class _WriteState extends State<BlefWriteScreen> {
  late int _left = widget.seconds;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left > 0) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                  key: const ValueKey('blef-clock'),
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
              key: const ValueKey('blef-question'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.sent != null) ...[
              Text(
                Strings.blefSentFake,
                style: const TextStyle(fontSize: 18, color: muted),
              ),
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('blef-sent'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(widget.sent!, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(height: 16),
              const Text(
                Strings.waitTv,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, color: muted),
              ),
            ] else ...[
              Text(
                Strings.blefWriteTitle,
                style: const TextStyle(fontSize: 18, color: muted),
              ),
              const SizedBox(height: 8),
              BlefField(
                maxLength: 40,
                enabled: _left > 0,
                error: widget.error,
                onSend: widget.onSend,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Picking the true answer from the list (without your own fake). One tap, final.
class BlefListScreen extends StatefulWidget {
  const BlefListScreen({
    super.key,
    required this.seconds,
    required this.options,
    required this.ids,
    required this.onPick,
    this.picked,
  });
  final int seconds;
  final List<String> options;
  final List<int> ids;
  final int? picked;
  final void Function(int id) onPick;

  @override
  State<BlefListScreen> createState() => _ListState();
}

class _ListState extends State<BlefListScreen> {
  late int _left = widget.seconds;
  late int? _picked = widget.picked;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left > 0) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool get _open => _picked == null && _left > 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    Strings.blefPickTitle,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  Strings.minutes(_left),
                  key: const ValueKey('blef-clock'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (var i = 0; i < widget.options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: _picked == widget.ids[i] ? accent : surface,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          key: ValueKey('option-${widget.ids[i]}'),
                          borderRadius: BorderRadius.circular(16),
                          // Checked when tapped, not when built: two quick taps
                          // must not send two picks.
                          onTap: () {
                            if (!_open) return;
                            setState(() => _picked = widget.ids[i]);
                            widget.onPick(widget.ids[i]);
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 64),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Text(
                              widget.options[i],
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: _picked == widget.ids[i]
                                    ? ink
                                    : textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_picked != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  Strings.blefPicked,
                  key: ValueKey('blef-picked'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: muted),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// This phone's points for the question.
class BlefResultScreen extends StatelessWidget {
  const BlefResultScreen({
    super.key,
    required this.points,
    required this.total,
    required this.foundTruth,
    required this.fooled,
  });
  final int points, total, fooled;
  final bool foundTruth;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Strings.plusPoints(points),
              key: const ValueKey('blef-points'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Text(
              foundTruth ? Strings.truthFound : Strings.truthMissed,
              key: const ValueKey('truth'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                color: foundTruth ? const Color(0xFF2ECC71) : muted,
              ),
            ),
            Text(
              Strings.fooledN(fooled),
              key: const ValueKey('fooled'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, color: muted),
            ),
            const SizedBox(height: 16),
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

