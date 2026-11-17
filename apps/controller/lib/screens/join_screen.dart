import 'dart:async';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../character_grid.dart';
import '../connection.dart';
import '../theme.dart';
import '../strings.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen(
    this.conn, {
    required this.onJoined,
    this.initialCharacter,
    super.key,
  });
  final Connection conn;
  final VoidCallback onJoined;

  /// Tests pin this; otherwise a random one is preselected.
  final String? initialCharacter;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _name = TextEditingController();
  StreamSubscription<Message>? _sub;
  String? _error;
  late String _character =
      widget.initialCharacter ??
      characterIds[Random().nextInt(characterIds.length)];

  @override
  void initState() {
    super.initState();
    _sub = widget.conn.messages.listen((m) {
      if (m is Welcome) widget.onJoined();
      if (m is ErrorMsg) setState(() => _error = m.message);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c, width: 2),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                MediaQuery.sizeOf(context).height -
                56 -
                MediaQuery.paddingOf(context).vertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                Strings.appTitle,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                Strings.joinHelper,
                style: TextStyle(fontSize: 20, color: muted, height: 1.4),
              ),
              const SizedBox(height: 48),
              const Text(
                Strings.nameLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                maxLength: 16,
                style: const TextStyle(fontSize: 24),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  enabledBorder: _border(accent),
                  focusedBorder: _border(accent),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                Strings.nameLimit,
                style: TextStyle(fontSize: 16, color: muted),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                Strings.pickCharacter,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
              const SizedBox(height: 8),
              // The TV says nothing before the join, so nothing can be greyed
              // here; a taken pick falls back to a free one (Welcome.character).
              CharacterGrid(
                selected: _character,
                taken: const {},
                color: accent,
                onPick: (id) => setState(() => _character = id),
              ),
              const SizedBox(height: 16),
              // What the others will see: the face and the name.
              Container(
                key: const ValueKey('character-preview'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    CharacterFace(_character, 56, accent),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _name,
                            builder: (_, v, _) => Text(
                              v.text.trim(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            Strings.animal(_character),
                            style: const TextStyle(fontSize: 18, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  final name = _name.text.trim();
                  if (name.isEmpty) {
                    setState(() => _error = Strings.emptyName);
                    return;
                  }
                  setState(() => _error = null);
                  widget.conn.send(
                    Join(name, widget.conn.token, character: _character),
                  );
                },
                child: const Text(Strings.join),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
