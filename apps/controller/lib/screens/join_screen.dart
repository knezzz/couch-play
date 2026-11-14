import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _name,
            maxLength: 16,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 18, color: Colors.redAccent),
              ),
            ),
          FilledButton(
            onPressed: () {
              final name = _name.text.trim();
              if (name.isEmpty) return;
              setState(() => _error = null);
              widget.conn.send(Join(name, widget.conn.token));
            },
            child: const Text('Join'),
          ),
        ],
      ),
    ),
  );
}
