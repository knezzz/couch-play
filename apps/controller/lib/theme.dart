import 'package:flutter/material.dart';

/// Tokens from docs/design/couchplay-screens/canvas.json.
const bg = Color(0xFF14141E);
const surface = Color(0xFF1F1F2C);
const raised = Color(0xFF2A2A3A);
const textColor = Color(0xFFF4F4F8);
const muted = Color(0xFFA9A9BC);
const accent = Color(0xFF4DD9FF);
const ink = Color(0xFF14141E); // text on colored chips and buttons

final theme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: bg,
  colorScheme: const ColorScheme.dark(
    primary: accent,
    onPrimary: ink,
    surface: bg,
    onSurface: textColor,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(64),
      textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
);
