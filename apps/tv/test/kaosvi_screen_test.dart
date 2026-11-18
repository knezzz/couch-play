import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/kaosvi/kaosvi_screen.dart';
import 'package:tv/ui/tv_theme.dart';

final _eight = [for (var i = 0; i < 8; i++) PlayerInfo(i, 'Igrac$i-duže', i, true, 0, character: characterIds[i])];
const _q = 'Navedi voće koje se najčešće jede ljeti na plaži, u hladu ili kod kuće, uz sladoled ili samo tako.';

KaosviBoard _board(KaosviShow st, {Set<int> answered = const {}, int left = 20, List<KaosviStack> groups = const [], bool tie = false, List<PlayerInfo>? players}) => KaosviBoard(
    stage: st, number: 2, total: 12, question: _q, players: players ?? _eight, answered: answered, secondsLeft: left, seconds: 30, groups: groups, tie: tie);

Future<void> _show(WidgetTester t, KaosviBoard b, Size size) async {
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: KaosviScreen(b)));
}

void main() {
  testWidgets('asking: the question, who has answered (lit) and how many, never an answer', (t) async {
    await _show(t, _board(KaosviShow.ask, answered: const {0, 3}), const Size(1920, 1080));
    expect(find.text(_q), findsOneWidget);
    expect(find.text('Odgovoreno: 2 od 8'), findsOneWidget);
    expect(find.byKey(const ValueKey('who-0-yes')), findsOneWidget);
    expect(find.byKey(const ValueKey('who-1-no')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('seconds'))).data, '20');
    expect(find.byKey(const ValueKey('group-0')), findsNothing);
    expect(t.takeException(), isNull);
    await _show(t, _board(KaosviShow.ask, left: 5), const Size(1920, 1080));
    expect(t.widget<Text>(find.byKey(const ValueKey('seconds'))).style!.color, const Color(0xFFFF4D6D));
  });

  testWidgets('merging: says the host is merging; no answers, no groups', (t) async {
    await _show(t, _board(KaosviShow.merge, left: 12), const Size(1920, 1080));
    expect(find.byKey(const ValueKey('merging')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-0')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('reveal: groups largest first with their answer, faces and points; the largest is marked', (t) async {
    final groups = [
      KaosviStack('jabuka', [_eight[0], _eight[1], _eight[2]], points: 1),
      KaosviStack('kruška', [_eight[3], _eight[4]]),
      KaosviStack('dinja', [_eight[5]], points: -1),
    ];
    await _show(t, _board(KaosviShow.reveal, groups: groups, players: _eight.sublist(0, 6)), const Size(1920, 1080));
    expect(find.byKey(const ValueKey('group-0-top')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-2')), findsOneWidget);
    expect(t.getTopLeft(find.byKey(const ValueKey('group-0-top'))).dy, lessThan(t.getTopLeft(find.byKey(const ValueKey('group-1'))).dy));
    expect(find.text('jabuka'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('points-0'))).data, '+1');
    expect(t.widget<Text>(find.byKey(const ValueKey('points-2'))).data, '−1');
    expect(t.widget<Text>(find.byKey(const ValueKey('points-1'))).data, '');
    expect(find.byKey(const ValueKey('tie')), findsNothing);
    expect(find.byType(PlayerDot), findsNWidgets(6), reason: 'one face per player in the stacks');
  });

  testWidgets('a tie: nobody is marked or scores, and the screen says so', (t) async {
    final groups = [KaosviStack('a', [_eight[0], _eight[1]]), KaosviStack('b', [_eight[2], _eight[3]]), KaosviStack('c', [_eight[4]])];
    await _show(t, _board(KaosviShow.reveal, groups: groups, tie: true, players: _eight.sublist(0, 5)), const Size(1920, 1080));
    expect(find.byKey(const ValueKey('tie')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-0-top')), findsNothing);
    expect(find.textContaining('+'), findsNothing);
  });

  for (final size in [const Size(1280, 720), const Size(1920, 1080)]) {
    testWidgets('${size.width.toInt()}x${size.height.toInt()}: 8 players, a 4-line question, 8 different answers (and one group of 8) fit, text >= 40 px', (t) async {
      void fits(String what) {
        expect(t.takeException(), isNull, reason: what);
        for (final w in t.widgetList<Text>(find.byType(Text))) {
          final r = t.getRect(find.byWidget(w));
          expect(r.bottom, lessThanOrEqualTo(size.height * 1030 / 1080 + 1), reason: '$what: ${w.data} $r');
          expect(r.right, lessThanOrEqualTo(size.width + 1), reason: '$what: ${w.data}');
          expect(w.style?.fontSize ?? 40, greaterThanOrEqualTo(40), reason: '$what: ${w.data}');
        }
      }

      await _show(t, _board(KaosviShow.ask, answered: const {0, 1, 2, 3, 4}), size);
      fits('ask');
      await _show(t, _board(KaosviShow.merge), size);
      fits('merge');
      await _show(t, _board(KaosviShow.reveal, groups: [for (var i = 0; i < 8; i++) KaosviStack('odgovor broj $i, dosta dug', [_eight[i]], points: i == 7 ? -1 : 0)]), size);
      fits('8 groups');
      await _show(t, _board(KaosviShow.reveal, groups: [KaosviStack('svi isto', _eight, points: 1)]), size);
      fits('one group of 8');
      final r = t.getRect(find.byKey(const ValueKey('group-0-top')));
      expect(r.right, lessThanOrEqualTo(size.width + 1));
    });
  }
}
