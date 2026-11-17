import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import 'blef_screens.dart';

/// What the TV last told this phone during a Blef game.
class BlefInbox {
  BlefWrite? write;
  BlefList? list;
  BlefResult? result;

  void on(Message m) {
    switch (m) {
      case BlefWrite():
        write = m;
        list = null;
        result = null;
      case BlefList():
        list = m;
        result = null;
      case BlefResult():
        result = m;
      default:
    }
  }
}

/// The phone's Blef screens: write, pick, result. [error] is the TV's refusal
/// of the last fake ("To je točan odgovor! Smisli laž.").
class BlefFlow extends StatelessWidget {
  const BlefFlow(this.conn, this.inbox, {this.error, this.onSend, super.key});
  final Connection conn;
  final BlefInbox inbox;
  final String? error;

  /// Called when a fake goes out, so the app can clear the old refusal.
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final r = inbox.result, l = inbox.list, w = inbox.write;
    if (r != null) {
      return BlefResultScreen(
        key: ValueKey('blef-result-${w?.number}'),
        points: r.points,
        total: r.total,
        foundTruth: r.foundTruth,
        fooled: r.fooled,
      );
    }
    if (l != null) {
      return BlefListScreen(
        key: ValueKey('blef-list-${w?.number}'),
        seconds: l.seconds,
        options: l.options,
        ids: l.ids,
        picked: l.picked,
        onPick: (id) => conn.send(BlefPick(id)),
      );
    }
    if (w == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return BlefWriteScreen(
      key: ValueKey('blef-write-${w.number}'),
      number: w.number,
      total: w.total,
      seconds: w.seconds,
      question: w.q,
      sent: w.sent,
      error: error,
      onSend: (t) {
        onSend?.call();
        conn.send(BlefFake(t));
      },
    );
  }
}
