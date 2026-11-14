import 'package:flutter/material.dart';

/// The one highlight colour on the TV: a focused button gets a 3 px ring of it.
const tvAccent = Color(0xFF4DD9FF);

/// Dark theme with couch-sized buttons whose focus ring is always visible.
ThemeData tvTheme() {
  final style = ButtonStyle(
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 40, vertical: 20),
    ),
    side: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.focused)
          ? const BorderSide(color: tvAccent, width: 3)
          : null,
    ),
  );
  return ThemeData.dark().copyWith(
    filledButtonTheme: FilledButtonThemeData(style: style),
  );
}
