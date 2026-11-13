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

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextField(
              controller: _name,
              maxLength: 16,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final name = _name.text.trim();
                if (name.isEmpty) return;
                widget.conn.send(Join(name, widget.conn.token));
                widget.onJoined();
              },
              child: const Text('Join'),
            ),
          ]),
        ),
      );
}
