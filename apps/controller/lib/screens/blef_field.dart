import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../strings.dart';
import '../theme.dart';

/// Blef's one-line answer field and the Pošalji button. At most [maxLength]
/// characters; Pošalji (or the keyboard's send key) hands the trimmed text to
/// [onSend]; an empty text is not sent.
class BlefField extends StatefulWidget {
  const BlefField({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.maxLength = 40,
    this.error,
  });
  final void Function(String text) onSend;
  final bool enabled;
  final int maxLength;

  /// A line under the field, red (the TV's "To je točan odgovor!").
  final String? error;

  @override
  State<BlefField> createState() => _BlefFieldState();
}

class _BlefFieldState extends State<BlefField> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final t = _text.text.trim();
    if (t.isEmpty || !widget.enabled) return;
    widget.onSend(t);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('blef-field'),
        controller: _text,
        enabled: widget.enabled,
        maxLength: widget.maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        textInputAction: TextInputAction.send,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _send(),
        style: const TextStyle(fontSize: 24),
        decoration: InputDecoration(
          hintText: Strings.blefHint,
          filled: true,
          fillColor: surface,
          counterStyle: const TextStyle(fontSize: 18, color: muted),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          enabledBorder: _border(accent),
          focusedBorder: _border(accent),
          disabledBorder: _border(raised),
        ),
      ),
      if (widget.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            widget.error!,
            key: const ValueKey('blef-error'),
            style: const TextStyle(fontSize: 18, color: Colors.redAccent),
          ),
        ),
      const SizedBox(height: 12),
      FilledButton(
        key: const ValueKey('blef-send'),
        onPressed: widget.enabled ? _send : null,
        child: const Text(Strings.send),
      ),
    ],
  );

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: 2),
  );
}

/// A page for trying the typing on real phones: /?spike=blef on the built
/// controller. It shows what the field handed over, character by character.
class BlefSpikeScreen extends StatefulWidget {
  const BlefSpikeScreen({super.key});

  @override
  State<BlefSpikeScreen> createState() => _BlefSpikeState();
}

class _BlefSpikeState extends State<BlefSpikeScreen> {
  final _sent = <String>[];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              Strings.blefSpikeTitle,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              Strings.blefSpikeTry,
              style: TextStyle(fontSize: 18, color: muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            BlefField(onSend: (t) => setState(() => _sent.insert(0, t))),
            const SizedBox(height: 16),
            for (final t in _sent)
              Container(
                key: const ValueKey('blef-spike-sent'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t, style: const TextStyle(fontSize: 22)),
                    Text(
                      '${t.characters.length} znakova · ${t.runes.map((r) => r.toRadixString(16)).join(' ')}',
                      style: const TextStyle(fontSize: 18, color: muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
