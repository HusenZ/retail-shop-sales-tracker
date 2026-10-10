import 'package:flutter/material.dart';

/// Large, high-contrast controls for quick use at a shop counter.
ThemeData buildTheme() {
  final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF00796B));
  const buttonSize = Size.fromHeight(52);
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  return ThemeData(
    colorScheme: colors,
    useMaterial3: true,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: buttonSize, textStyle: buttonText),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: buttonSize, textStyle: buttonText),
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
  );
}

/// Profit and pending colours used across screens.
extension MoneyColors on ColorScheme {
  Color get gain => const Color(0xFF2E7D32);
  Color get warning => const Color(0xFFE65100);
}
