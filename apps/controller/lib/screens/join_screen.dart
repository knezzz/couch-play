import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import '../theme.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen(this.conn, {required this.onJoined, super.key});
  final Connection conn;
  final VoidCallback onJoined;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _name = TextEditingController();
  StreamSubscription<Message>? _sub;
  String? _error;

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
            minHeight: MediaQuery.sizeOf(context).height - 56 - MediaQuery.paddingOf(context).vertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'CouchPlay',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'Type your name to join the game on the TV.',
                style: TextStyle(fontSize: 20, color: muted, height: 1.4),
              ),
              const SizedBox(height: 48),
              const Text('Your name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: muted)),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                maxLength: 16,
                style: const TextStyle(fontSize: 24),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  enabledBorder: _border(accent),
                  focusedBorder: _border(accent),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Up to 16 characters.', style: TextStyle(fontSize: 16, color: muted)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: const TextStyle(fontSize: 18, color: Colors.redAccent)),
                ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () {
                  final name = _name.text.trim();
                  if (name.isEmpty) {
                    setState(() => _error = 'Type a name to join.');
                    return;
                  }
                  setState(() => _error = null);
                  widget.conn.send(Join(name, widget.conn.token));
                },
                child: const Text('Join'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
