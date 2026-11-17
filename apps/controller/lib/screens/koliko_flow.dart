import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import 'koliko_screens.dart';

/// What the TV last told this phone during a Koliko? game.
class KolikoInbox {
  KolikoAsk? ask;
  KolikoResult? result;

  void on(Message m) {
    switch (m) {
      case KolikoAsk():
        ask = m;
        result = null;
      case KolikoResult():
        result = m;
      default:
    }
  }
}

/// The phone's Koliko? screens: the pad while a question is open, the result
/// after the reveal.
class KolikoFlow extends StatelessWidget {
  const KolikoFlow(this.conn, this.inbox, {super.key});
  final Connection conn;
  final KolikoInbox inbox;

  @override
  Widget build(BuildContext context) {
    final r = inbox.result, a = inbox.ask;
    if (r != null) {
      return KolikoResultScreen(
        key: ValueKey('koliko-result-${a?.number}'),
        answer: r.answer,
        value: r.value,
        rank: r.rank,
        points: r.points,
        total: r.total,
        // The result carries its own unit (also after a reload); an older TV
        // sends none, then the question's will do.
        unit: r.unit.isNotEmpty ? r.unit : (a?.unit ?? ''),
      );
    }
    if (a == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return KolikoAskScreen(
      // A new question is a fresh pad.
      key: ValueKey('koliko-${a.number}'),
      number: a.number,
      total: a.total,
      seconds: a.seconds,
      question: a.q,
      unit: a.unit,
      sent: a.sent,
      onSend: (v) => conn.send(NumberAnswer(v)),
    );
  }
}
