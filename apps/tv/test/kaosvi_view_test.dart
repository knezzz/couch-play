import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/session/kaosvi_match.dart';
import 'package:tv/session/session.dart';
import 'package:tv/ui/kaosvi/kaosvi_view.dart';

import 'session_kaosvi_test.dart' show pack;
import 'session_test.dart' show FakePeer, join;

/// The TV's Kao svi view over a live match: no answer anywhere before the reveal, the real points after it.
void main() {
  late Session s;
  late List<FakePeer> ps;
  var at = Duration.zero;

  void setUp3() {
    at = Duration.zero;
    s = Session(random: Random(1), clock: () => at)
      ..kaosviTvReady = true
      ..kaosviPacks = [pack('one')];
    ps = [for (var i = 0; i < 4; i++) join(s, 'P$i', token: 't$i')];
    ps[0].say(const StartGame(GameKind.kaosvi, null));
  }

  Future<void> show(WidgetTester t) async {
    t.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: EffectLayer(child: KaosviView(match: s.kaosvi!, players: s.playerInfos))));
    await t.pump();
  }

  testWidgets('answering and merging: faces and counts only, the answers are nowhere on screen', (t) async {
    setUp3();
    await show(t);
    expect(find.text('Odgovoreno: 0 od 4'), findsOneWidget);
    ps[0].say(const KaosviAnswer('jabuka'));
    ps[1].say(const KaosviAnswer('Kruška'));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Odgovoreno: 2 od 4'), findsOneWidget);
    expect(find.textContaining('jabuka'), findsNothing);
    expect(find.textContaining('Kruška'), findsNothing);
    ps[2].say(const KaosviAnswer('jabuka'));
    ps[3].say(const KaosviAnswer('dinja'));
    expect(s.kaosvi!.stage, KaosviStageTv.merge);
    await t.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('merging')), findsOneWidget);
    for (final w in ['jabuka', 'Kruška', 'dinja']) {
      expect(find.textContaining(w), findsNothing, reason: 'no answer on the TV while the host merges');
    }
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('the reveal: groups largest first with the real points; the lone one -1; confetti once', (t) async {
    setUp3();
    await show(t);
    ps[0].say(const KaosviAnswer('jabuka'));
    ps[1].say(const KaosviAnswer('Jabuka'));
    ps[2].say(const KaosviAnswer('jabuka '));
    ps[3].say(const KaosviAnswer('dinja'));
    ps[0].say(const KaosviDone());
    expect(s.kaosvi!.stage, KaosviStageTv.reveal);
    await t.pump(const Duration(seconds: 1)); // the view redraws on the session's change or its 1 s clock
    expect(find.byKey(const ValueKey('group-0-top')), findsOneWidget);
    expect(find.text('jabuka'), findsOneWidget, reason: 'one group, answers merged by case and spaces');
    expect(find.text('dinja'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('points-0'))).data, '+1');
    final lonePoints = t.widget<Text>(find.byKey(const ValueKey('points-1'))).data;
    final real = s.kaosvi!.reveal!.points[s.kaosvi!.reveal!.groups[1].members.first] ?? 0;
    expect(lonePoints, real == 0 ? '' : '−${real.abs()}', reason: 'what core really applied (the lone -1 is 0 at a total of 0)');
    await t.pump(const Duration(milliseconds: 100));
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0), reason: 'the confetti runs');
    await t.pump(const Duration(seconds: 6)); // (the match's own 8 s reveal hold is still running: the view stays)
    expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'and stops');
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('a tie: the screen says nobody scores and no confetti', (t) async {
    setUp3();
    await show(t);
    ps[0].say(const KaosviAnswer('a'));
    ps[1].say(const KaosviAnswer('a'));
    ps[2].say(const KaosviAnswer('b'));
    ps[3].say(const KaosviAnswer('b'));
    ps[0].say(const KaosviDone());
    await t.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('tie')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-0-top')), findsNothing);
    await t.pump(const Duration(milliseconds: 200));
    expect(SchedulerBinding.instance.transientCallbackCount, 0, reason: 'no confetti for a tie');
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });

  testWidgets('a merged group shows every spelling it carries, joined with a dot', (t) async {
    setUp3();
    await show(t);
    ps[0].say(const KaosviAnswer('jabuka'));
    ps[1].say(const KaosviAnswer('Banana'));
    ps[2].say(const KaosviAnswer('jabuka'));
    ps[3].say(const KaosviAnswer('dinja'));
    final groups = ps[0].sent.whereType<KaosviMerging>().last.groups;
    final jabuka = groups.firstWhere((g) => g.text == 'jabuka'), banana = groups.firstWhere((g) => g.text == 'Banana');
    ps[0].say(KaosviMerge(jabuka.id, banana.id));
    ps[0].say(const KaosviDone());
    await t.pump(const Duration(seconds: 1));
    expect(find.text('jabuka \u00b7 Banana'), findsOneWidget, reason: 'the host merge is not invisible on the TV');
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
