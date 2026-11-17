import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv/ui/curve/round_break_card.dart';
import 'package:tv/ui/pause_card.dart';

/// The pause and round-break cards are drawn over the game; with no Material above them Flutter
/// falls back to yellow underlined text. They bring their own Material, so it never shows.
void main() {
  final cards = <String, Widget>{
    'pause card': PauseCard(who: const PlayerInfo(1, 'Ana', 1, true, 0), remaining: () => const Duration(seconds: 20)),
    'round-break card': RoundBreakCard(
        round: 2, target: 30, remaining: () => const Duration(seconds: 3), players: const [BreakPlayer(name: 'Ana', colorIndex: 0, score: 5)]),
  };
  cards.forEach((name, card) {
    testWidgets('$name: text has no underline even with nothing above it', (t) async {
      await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: card));
      expect(DefaultTextStyle.of(t.element(find.byType(Text).first)).style.decoration, isNot(TextDecoration.underline));
      expect(find.descendant(of: find.byType(Material), matching: find.byType(Text)), findsWidgets);
    });
  });
}
