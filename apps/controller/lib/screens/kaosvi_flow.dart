import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../connection.dart';
import 'blef_screens.dart';
import 'kaosvi_screens.dart';
import '../strings.dart';

/// What the TV last told this phone during a Kao svi game.
class KaosviInbox {
  KaosviAsk? ask;
  KaosviMerging? merging;
  KaosviResult? result;

  void on(Message m) {
    switch (m) {
      case KaosviAsk():
        ask = m;
        merging = null;
        result = null;
      case KaosviMerging():
        merging = m;
        result = null;
      case KaosviResult():
        result = m;
        merging = null;
      default:
    }
  }
}

/// The phone's Kao svi screens: answer, merge (host) or wait, result. [error]
/// is the TV's refusal of the last answer, shown under the field.
class KaosviFlow extends StatelessWidget {
  const KaosviFlow(this.conn, this.inbox, {this.error, this.onSend, super.key});
  final Connection conn;
  final KaosviInbox inbox;
  final String? error;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final r = inbox.result, m = inbox.merging, a = inbox.ask;
    if (r != null) {
      return KaosviResultScreen(
        key: ValueKey('kaosvi-result-${a?.number}'),
        answer: r.answer,
        size: r.size,
        points: r.points,
        total: r.total,
        largest: r.largest,
        lone: r.lone,
      );
    }
    if (m != null) {
      if (!m.host) {
        return const KaosviWaitScreen();
      }
      return KaosviMergeScreen(
        key: ValueKey('kaosvi-merge-${a?.number}'),
        seconds: m.seconds,
        groups: [for (final g in m.groups) MergeGroup(g.id, g.text)],
        onMerge: (x, y) => conn.send(KaosviMerge(x, y)),
        onDone: () => conn.send(const KaosviDone()),
      );
    }
    if (a == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return BlefWriteScreen(
      key: ValueKey('kaosvi-write-${a.number}'),
      number: a.number,
      total: a.total,
      seconds: a.seconds,
      question: a.q,
      sent: a.sent,
      error: error,
      title: Strings.kaosviTitle,
      sentLabel: Strings.kaosviSentLabel,
      maxLength: 30,
      onSend: (t) {
        onSend?.call();
        conn.send(KaosviAnswer(t));
      },
    );
  }
}
