import 'package:flutter/material.dart';

const Color kBackground = Color(0xFF1B1B1B);
const Color kSheet = Color(0xFF262626);

/// Dark, neutral and flat so the photos carry all the colour.
ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF8C8C8C),
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ).copyWith(
        surface: kBackground,
        surfaceContainer: kSheet,
        surfaceContainerHigh: const Color(0xFF2F2F2F),
        surfaceContainerHighest: const Color(0xFF383838),
      );
  const smallRadius = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: kBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: const FilledButtonThemeData(
      style: ButtonStyle(shape: WidgetStatePropertyAll(smallRadius)),
    ),
    outlinedButtonTheme: const OutlinedButtonThemeData(
      style: ButtonStyle(shape: WidgetStatePropertyAll(smallRadius)),
    ),
    segmentedButtonTheme: const SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(smallRadius),
        visualDensity: VisualDensity.compact,
      ),
    ),
    chipTheme: const ChipThemeData(shape: smallRadius),
    dialogTheme: const DialogThemeData(
      backgroundColor: kSheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    sliderTheme: const SliderThemeData(
      showValueIndicator: ShowValueIndicator.never,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(),
    ),
  );
}
