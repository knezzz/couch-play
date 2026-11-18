import 'package:controller/screens/settings_widgets.dart';
import 'package:controller/strings.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _packs = [
  PackInfo('a', 'Crtići', 40),
  PackInfo('b', 'Hrana', 30),
  PackInfo('c', 'Životinje', 21),
];

Future<void> _show(
  WidgetTester t,
  Set<String> ticked,
  void Function(String) onToggle, {
  List<PackInfo> packs = _packs,
  double width = 390,
}) async {
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PackChecklist(
            title: 'Paketi',
            packs: packs,
            ticked: ticked,
            onToggle: onToggle,
          ),
        ),
      ),
    ),
  );
}

void main() {
  IconData icon(WidgetTester t, String id) => t
      .widget<Icon>(
        find.descendant(
          of: find.byKey(ValueKey('pack-$id')),
          matching: find.byType(Icon),
        ),
      )
      .icon!;

  testWidgets('ticked packs show a ticked box, the others an empty one', (
    t,
  ) async {
    await _show(t, {'a', 'c'}, (_) {});
    expect(icon(t, 'a'), Icons.check_box);
    expect(icon(t, 'b'), Icons.check_box_outline_blank);
    expect(icon(t, 'c'), Icons.check_box);
  });

  testWidgets('a tap sends the pack; nothing changes until the TV says so', (
    t,
  ) async {
    final sent = <String>[];
    await _show(t, {'a', 'b', 'c'}, sent.add);
    await t.tap(find.byKey(const ValueKey('pack-b')));
    await t.pump();
    expect(sent, ['b']);
    expect(icon(t, 'b'), Icons.check_box);
  });

  testWidgets('the last ticked pack says it stays, and a tap shows why', (
    t,
  ) async {
    final sent = <String>[];
    await _show(t, {'b'}, sent.add);
    expect(find.text(Strings.packMustStay), findsOneWidget);
    expect(find.byKey(const ValueKey('pack-refused')), findsNothing);
    await t.tap(find.byKey(const ValueKey('pack-b')));
    await t.pump();
    expect(sent, isEmpty);
    expect(find.text(Strings.lastPackStays), findsOneWidget);
    // Another pack can still be ticked, and that clears the reason.
    await t.tap(find.byKey(const ValueKey('pack-a')));
    await t.pump();
    expect(sent, ['a']);
    expect(find.byKey(const ValueKey('pack-refused')), findsNothing);
  });

  testWidgets('with two ticked, either can be unticked', (t) async {
    final sent = <String>[];
    await _show(t, {'a', 'b'}, sent.add);
    expect(find.text(Strings.packMustStay), findsNothing);
    await t.tap(find.byKey(const ValueKey('pack-a')));
    expect(sent, ['a']);
  });

  testWidgets('a long list scrolls and fits at 360 px', (t) async {
    final many = [
      for (var i = 0; i < 40; i++)
        PackInfo('p$i', 'Paket s jako dugačkim imenom broj $i', 100 + i),
    ];
    await _show(
      t,
      {for (final p in many) p.id},
      (_) {},
      packs: many,
      width: 360,
    );
    expect(t.takeException(), isNull);
    await t.drag(find.byType(SingleChildScrollView), const Offset(0, -3000));
    await t.pump();
    expect(find.byKey(const ValueKey('pack-p39')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('the count words: all, or the number', () {
    expect(Strings.packCount(5, 5), 'Svi paketi');
    expect(Strings.packCount(1, 5), '1 paket');
    expect(Strings.packCount(3, 5), '3 paketa');
    expect(Strings.packCount(21, 30), '21 paket');
  });
}
