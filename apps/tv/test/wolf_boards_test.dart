import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/strings.dart';
import 'package:tv/ui/tv_theme.dart';
import 'package:tv/ui/wolf/end_screen.dart';
import 'package:tv/ui/wolf/village_screen.dart';
import 'package:tv/ui/wolf/vote_screen.dart';

List<VillagePlayer> _people(int n, {Set<int> out = const {}}) => [
      for (var i = 0; i < n; i++)
        VillagePlayer(id: i + 1, name: 'Ime${i + 1}', colorIndex: i, character: characterIds[i], out: out.contains(i + 1)),
    ];

void _big(WidgetTester t) {
  t.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget _vote(List<VillagePlayer> p, {int voted = 4, int expected = 5, int? outId, String? result, String? extra, String? role}) => MaterialApp(
      theme: tvTheme(),
      home: WolfVoteScreen(players: p, day: 3, voted: voted, expected: expected, outId: outId, result: result, extra: extra, role: role),
    );

Finder _face(String id) => find.byWidgetPredicate((w) => w is CharacterFace && w.id == id);

void main() {
  group('vote', () {
    testWidgets('the header, the question, and how many have voted: the only count', (t) async {
      _big(t);
      await t.pumpWidget(_vote(_people(5)));
      expect(find.text(Strings.wolfVoteHeader(3)), findsOneWidget);
      expect(find.text(Strings.wolfVoteQuestion), findsOneWidget);
      expect(find.textContaining(Strings.wolfVoted(4, 5)), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a card for every player, and no voter faces, arrows, tallies or "glasova" anywhere', (t) async {
      _big(t);
      await t.pumpWidget(_vote(_people(5), voted: 5));
      for (var i = 0; i < 5; i++) {
        expect(_face(characterIds[i]), findsOneWidget, reason: 'one face each: no voters shown under a card');
        expect(find.text('Ime${i + 1}'), findsOneWidget);
      }
      for (final w in t.widgetList<Text>(find.byType(Text))) {
        final d = w.data ?? w.textSpan?.toPlainText() ?? '';
        expect(RegExp(r'^\s*\d+\s*$').hasMatch(d), isFalse, reason: 'a bare number "$d" would be a tally');
        expect(d.toLowerCase(), isNot(contains('glasova')));
        expect(d, isNot(contains('→')));
      }
    });

    testWidgets('who is out: their card is marked and the line says so; otherwise no card is marked', (t) async {
      _big(t);
      await t.pumpWidget(_vote(_people(5, out: {3}), outId: 3, result: 'Selo je izbacilo Ime3.', extra: 'Ostao je još 1 vukodlak.'));
      expect(find.text('Selo je izbacilo Ime3.'), findsOneWidget);
      expect(find.text('Ostao je još 1 vukodlak.'), findsOneWidget);
      expect(find.byKey(const ValueKey('out-card')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('out-card')), matching: find.text('Ime3')), findsOneWidget);
      await t.pumpWidget(_vote(_people(5), result: 'Glasovi su podijeljeni. Nitko ne ispada.'));
      expect(find.byKey(const ValueKey('out-card')), findsNothing);
      expect(find.text('Glasovi su podijeljeni. Nitko ne ispada.'), findsOneWidget);
      await t.pumpWidget(_vote(_people(5)));
      expect(find.byKey(const ValueKey('result')), findsNothing, reason: 'no result while the vote runs');
    });

    testWidgets('the banner has three parts (V2WolfVote): who is out, their role in red, how many wolves are left', (t) async {
      _big(t);
      await t.pumpWidget(_vote(_people(5, out: {3}), outId: 3, result: 'Selo je izbacilo Ime3.', role: 'Vukodlak', extra: 'Ostao je još 1 vukodlak.'));
      final banner = find.byKey(const ValueKey('result'));
      expect(find.descendant(of: banner, matching: find.text('Selo je izbacilo Ime3.')), findsOneWidget);
      final role = find.descendant(of: banner, matching: find.byKey(const ValueKey('result-role')));
      expect(role, findsOneWidget);
      expect(t.widget<Text>(role).textSpan!.toPlainText(), 'Uloga: Vukodlak.');
      final span = t.widget<Text>(role).textSpan!;
      final red = <Color?>[];
      span.visitChildren((c) {
        if (c is TextSpan && c.text == 'Vukodlak') red.add(c.style?.color);
        return true;
      });
      expect(red, [const Color(0xFFFF4D6D)], reason: 'the role word is red');
      final left = find.descendant(of: banner, matching: find.text('Ostao je još 1 vukodlak.'));
      expect(left, findsOneWidget);
      expect(t.getRect(left).right, greaterThan(t.getRect(role).right), reason: 'the third part is at the right end');
    });

    testWidgets('no role part while roles are hidden', (t) async {
      _big(t);
      await t.pumpWidget(_vote(_people(5, out: {3}), outId: 3, result: 'Selo je izbacilo Ime3.'));
      expect(find.byKey(const ValueKey('result-role')), findsNothing);
    });

    testWidgets('the grid is only the players still in the vote', (t) async {
      _big(t);
      // 8 started, 3 are out of the game already: 5 cards, in the roomy layout.
      await t.pumpWidget(_vote(_people(5), expected: 5));
      expect(find.byWidgetPredicate((w) => w is CharacterFace && w.size == 160), findsNWidgets(5));
    });

    for (final n in [5, 8]) {
      testWidgets('$n players with the result banner: everything on screen, cards clear of the banner', (t) async {
        _big(t);
        await t.pumpWidget(_vote(_people(n), outId: 2, result: 'Selo je izbacilo Ime2. ' * 2, extra: 'Ostao je još 1 vukodlak.'));
        expect(t.takeException(), isNull);
        final banner = t.getRect(find.byKey(const ValueKey('result')));
        expect(banner.bottom, lessThanOrEqualTo(1080));
        for (var i = 0; i < n; i++) {
          final r = t.getRect(find.byKey(ValueKey('vote-card-${i + 1}')));
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(1920));
          expect(r.bottom, lessThanOrEqualTo(banner.top + 1), reason: 'card ${i + 1} above the banner');
        }
      });
    }
  });

  group('end', () {
    final roles = {
      1: WolfRole.wolf,
      2: WolfRole.seer,
      3: WolfRole.villager,
      4: WolfRole.tramp,
      5: WolfRole.alpha,
    };

    Widget end(int n, {Map<int, WolfRole>? r}) => MaterialApp(
          theme: tvTheme(),
          home: WolfEndScreen(
            players: _people(n),
            roles: r ?? {for (var i = 0; i < n; i++) i + 1: WolfRole.values[i % WolfRole.values.length]},
            headline: 'Selo je pobijedilo.',
          ),
        );

    testWidgets('every player with their role, the headline and the header', (t) async {
      _big(t);
      await t.pumpWidget(end(5, r: roles));
      expect(find.text(Strings.wolfEndHeader), findsOneWidget);
      expect(find.text('Selo je pobijedilo.'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        final card = find.byKey(ValueKey('end-card-${i + 1}'));
        expect(find.descendant(of: card, matching: find.text('Ime${i + 1}')), findsOneWidget);
        expect(find.descendant(of: card, matching: _face(characterIds[i])), findsOneWidget);
      }
      expect(find.descendant(of: find.byKey(const ValueKey('end-card-1')), matching: find.text('Vukodlak')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('end-card-2')), matching: find.text('Vidovnjakinja')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('end-card-4')), matching: find.text('Lutalica')), findsOneWidget);
    });

    testWidgets('wolves are marked red, the village green, the tramp amber', (t) async {
      _big(t);
      await t.pumpWidget(end(5, r: roles));
      Color tag(int id) => t.widget<Text>(find.descendant(of: find.byKey(ValueKey('end-card-$id')), matching: find.byKey(const ValueKey('role')))).style!.color!;
      expect(tag(1), const Color(0xFFFF4D6D));
      expect(tag(5), const Color(0xFFFF4D6D));
      expect(tag(2), const Color(0xFF2ECC71));
      expect(tag(3), const Color(0xFF2ECC71));
      expect(tag(4), const Color(0xFFFFB020));
    });

    testWidgets('8 players fit', (t) async {
      _big(t);
      await t.pumpWidget(end(8));
      expect(t.takeException(), isNull);
      for (var i = 0; i < 8; i++) {
        final r = t.getRect(find.byKey(ValueKey('end-card-${i + 1}')));
        expect(r.right, lessThanOrEqualTo(1920));
        expect(r.bottom, lessThanOrEqualTo(1080));
      }
    });
  });
}
