import 'package:controller/screens/wolf_screens.dart';
import 'package:controller/strings.dart';
import 'package:controller/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Task 54: 8 players with long names fit a 360x640 phone with no scroll, in
// one column, rows >= 48 px; list, sum and switch phones share row positions.

const _names = [
  'Aleksandrija',
  'Bartolomeja',
  'Konstantin',
  'Dragutinović',
  'Margarita',
  'Maksimilijan',
  'Hrvoslavica',
  'Krunoslav',
];

Future<void> _phone(WidgetTester t, Widget w, {Size? size}) async {
  t.view.physicalSize = size ?? const Size(360, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(MaterialApp(theme: theme, home: w));
}

Widget _night({
  List<String>? labels,
  bool power = false,
  bool kicked = false,
  String hint =
      'Koga želiš pogledati? Uključi prekidač za otrov ili ne. ......',
}) => NightScreen(
  night: 2,
  hint: hint,
  showSpecial: power,
  targets: [
    for (var i = 0; i < 8; i++)
      NightItem(i + 1, (labels ?? _names)[i], enabled: !(kicked && i == 3)),
  ],
  onConfirm: (_, _) {},
);

Widget _vote({int n = 8}) => VoteScreen(
  day: 2,
  selfId: 1,
  targets: [
    for (var i = 0; i < n; i++) WolfTarget(i + 1, _names[i % 8], 'owl', i),
  ],
  onVote: (_) {},
  onSkip: () {},
);

/// Top and height of each row, plus whether the list scrolls.
List<Rect> _rows(WidgetTester t, String prefix, int n) => [
  for (var i = 1; i <= n; i++) t.getRect(find.byKey(ValueKey('$prefix-$i'))),
];

void _fits(WidgetTester t, List<Rect> rows, double bottomLimit) {
  for (final r in rows) {
    expect(r.height, greaterThanOrEqualTo(48));
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(bottomLimit));
    // One column, the full width.
    expect(r.width, greaterThan(300));
  }
  for (var i = 1; i < rows.length; i++) {
    expect(rows[i].top, greaterThanOrEqualTo(rows[i - 1].bottom));
  }
  // The scroll view has nothing to scroll.
  final s = t.state<ScrollableState>(find.byType(Scrollable).first);
  expect(s.position.maxScrollExtent, 0);
}

void main() {
  group('night list at 360x640 with 8 long names', () {
    testWidgets('list phone: all 8 rows fit above Potvrdi', (t) async {
      await _phone(t, _night());
      _fits(
        t,
        _rows(t, 'night', 8),
        t.getTopLeft(find.byKey(const ValueKey('night-confirm'))).dy,
      );
      for (final n in _names) {
        expect(find.text(n), findsOneWidget);
      }
      expect(tester(t), isNull); // no render overflow reported
    });

    testWidgets('sum phone and switch phone: same row positions', (t) async {
      await _phone(t, _night());
      final list = _rows(t, 'night', 8);
      final confirm = t.getRect(find.byKey(const ValueKey('night-confirm')));

      await _phone(
        t,
        _night(labels: ['54', '56', '58', '63', '49', '51', '60', '45']),
      );
      expect(_rows(t, 'night', 8), list);

      await _phone(t, _night(power: true));
      expect(_rows(t, 'night', 8), list);
      _fits(
        t,
        _rows(t, 'night', 8),
        t.getTopLeft(find.byKey(const ValueKey('night-confirm'))).dy,
      );
      final withSwitch = t.getRect(find.byKey(const ValueKey('night-confirm')));
      expect(withSwitch.top, confirm.top);
      expect(withSwitch.height, confirm.height);
      expect(find.byKey(const ValueKey('night-special')), findsOneWidget);
      expect(tester(t), isNull);
    });

    testWidgets('a kicked, greyed row keeps its place', (t) async {
      await _phone(t, _night());
      final list = _rows(t, 'night', 8);
      await _phone(t, _night(kicked: true));
      expect(_rows(t, 'night', 8), list);
    });

    testWidgets('390x844 keeps full-size rows', (t) async {
      await _phone(t, _night(), size: const Size(390, 844));
      for (final r in _rows(t, 'night', 8)) {
        expect(r.height, greaterThanOrEqualTo(48));
      }
      final s = t.state<ScrollableState>(find.byType(Scrollable).first);
      expect(s.position.maxScrollExtent, 0);
      expect(tester(t), isNull);
    });
  });

  group('day vote at 360x640 with 8 long names', () {
    testWidgets('8 rows fit above Preskoči and Glasaj', (t) async {
      await _phone(t, _vote());
      _fits(
        t,
        _rows(t, 'vote', 8),
        t.getTopLeft(find.byKey(const ValueKey('vote-skip'))).dy,
      );
      for (final n in _names) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text(Strings.skipVote), findsOneWidget);
      expect(find.text(Strings.vote), findsOneWidget);
      final go = t.getRect(find.byKey(const ValueKey('vote-go')));
      expect(go.bottom, lessThanOrEqualTo(640));
      expect(tester(t), isNull);
    });

    testWidgets('390x844 keeps full-size rows', (t) async {
      await _phone(t, _vote(), size: const Size(390, 844));
      for (final r in _rows(t, 'vote', 8)) {
        expect(r.height, greaterThanOrEqualTo(48));
      }
      expect(tester(t), isNull);
    });
  });
}

/// The pending render exception, if any (an overflow stripe would be one).
Object? tester(WidgetTester t) => t.takeException();
