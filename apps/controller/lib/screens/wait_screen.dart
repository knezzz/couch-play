import 'package:flutter/material.dart';

class WaitScreen extends StatelessWidget {
  const WaitScreen(this.reason, {super.key});
  final String reason;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          reason,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    ),
  );
}
