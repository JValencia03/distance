import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// "Pastel clay" visual identity: peach and lavender pastels, soft rounded
/// shapes and two typefaces — Fraunces (a soft serif) for headings and Nunito
/// (a rounded sans) for everything else.
///
/// Widgets read colors from [ColorScheme] roles, so both themes stay in sync.
ThemeData buildTheme(Brightness brightness) {
  final colors = _colorScheme(brightness);
  final text = _textTheme(colors);
  const pill = StadiumBorder();
  final rounded20 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  );
  return ThemeData(
    colorScheme: colors,
    fontFamily: _body,
    textTheme: text,
    scaffoldBackgroundColor: colors.surface,
    // Apple platforms keep their native slide; the rest use the soft
    // fade-and-slide "forwards" transition.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(color: colors.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: pill,
        textStyle: text.titleMedium,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: pill, textStyle: text.labelLarge),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: pill, textStyle: text.labelLarge),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.secondary,
      foregroundColor: colors.onSecondary,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      extendedTextStyle: text.titleSmall,
    ),
    chipTheme: ChipThemeData(
      shape: pill,
      side: BorderSide.none,
      backgroundColor: colors.surfaceContainerHigh,
      selectedColor: colors.primaryContainer,
      labelStyle: text.labelLarge,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: colors.primaryContainer,
        selectedForegroundColor: colors.onPrimaryContainer,
        side: BorderSide(color: colors.outlineVariant),
        textStyle: text.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colors.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: _inputBorder(Colors.transparent),
      enabledBorder: _inputBorder(Colors.transparent),
      focusedBorder: _inputBorder(colors.primary, width: 2),
      errorBorder: _inputBorder(colors.error),
      focusedErrorBorder: _inputBorder(colors.error, width: 2),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    listTileTheme: ListTileThemeData(shape: rounded20),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: rounded20,
      backgroundColor: colors.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: colors.onInverseSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.primaryContainer,
    ),
  );
}

/// Shared outline for text fields: no visible border until focused.
OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: color, width: width),
    );

const _body = 'Nunito';
const _display = 'Fraunces';

/// Fraunces at full softness gives the rounded, "clay" headings. Variable
/// fonts are tuned with [FontVariation] axes instead of [FontWeight].
List<FontVariation> _soft(double weight) => [
  const FontVariation('SOFT', 100),
  FontVariation('wght', weight),
];

TextTheme _textTheme(ColorScheme colors) {
  TextStyle display(double size, double weight, {double height = 1.15}) =>
      TextStyle(
        fontFamily: _display,
        fontSize: size,
        height: height,
        // Keeps the engine from synthesizing bold on top of the variation.
        fontWeight: FontWeight.w400,
        fontVariations: _soft(weight),
        letterSpacing: -0.4,
      );
  TextStyle body(double size, FontWeight weight, {double height = 1.4}) =>
      TextStyle(
        fontFamily: _body,
        fontSize: size,
        fontWeight: weight,
        height: height,
      );
  return TextTheme(
    displayLarge: display(52, 600),
    displayMedium: display(44, 600),
    displaySmall: display(36, 600),
    headlineLarge: display(32, 600),
    headlineMedium: display(28, 600),
    headlineSmall: display(24, 600, height: 1.2),
    titleLarge: display(22, 600, height: 1.2),
    titleMedium: body(16, FontWeight.w800, height: 1.3),
    titleSmall: body(14, FontWeight.w800, height: 1.3),
    bodyLarge: body(16, FontWeight.w400),
    bodyMedium: body(14, FontWeight.w400),
    bodySmall: body(12, FontWeight.w600),
    labelLarge: body(14, FontWeight.w700),
    labelMedium: body(12, FontWeight.w700),
    labelSmall: body(11, FontWeight.w700),
  ).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface);
}

/// Lavender as primary, peach as secondary and mint as tertiary, over a
/// warm cream (light) or deep plum (dark) background.
ColorScheme _colorScheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7158D6),
    brightness: brightness,
  );
  return switch (brightness) {
    Brightness.light => base.copyWith(
      primary: const Color(0xFF6A50D0),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE6DEFF),
      onPrimaryContainer: const Color(0xFF2A1A6B),
      secondary: const Color(0xFFD8634A),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFDCCF),
      onSecondaryContainer: const Color(0xFF4A1A0C),
      tertiary: const Color(0xFF2F8571),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFC9F0E4),
      onTertiaryContainer: const Color(0xFF0F3A31),
      surface: const Color(0xFFFFF8F3),
      onSurface: const Color(0xFF2D2433),
      onSurfaceVariant: const Color(0xFF6B5F72),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFFF1E9),
      surfaceContainer: const Color(0xFFFBECE4),
      surfaceContainerHigh: const Color(0xFFF6E6DE),
      surfaceContainerHighest: const Color(0xFFF0E0D9),
      outline: const Color(0xFFB9AAB4),
      outlineVariant: const Color(0xFFEADCDC),
      inverseSurface: const Color(0xFF2D2433),
      onInverseSurface: const Color(0xFFFFF1E9),
    ),
    Brightness.dark => base.copyWith(
      primary: const Color(0xFFC7B8FF),
      onPrimary: const Color(0xFF2A1A6B),
      primaryContainer: const Color(0xFF4A3A99),
      onPrimaryContainer: const Color(0xFFE6DEFF),
      secondary: const Color(0xFFFFB59E),
      onSecondary: const Color(0xFF4A1A0C),
      secondaryContainer: const Color(0xFF7A3A27),
      onSecondaryContainer: const Color(0xFFFFDCCF),
      tertiary: const Color(0xFF8FD8C3),
      onTertiary: const Color(0xFF0F3A31),
      tertiaryContainer: const Color(0xFF1F5246),
      onTertiaryContainer: const Color(0xFFC9F0E4),
      surface: const Color(0xFF1B1622),
      onSurface: const Color(0xFFF3EAF2),
      onSurfaceVariant: const Color(0xFFC2B5C6),
      surfaceContainerLowest: const Color(0xFF241D2C),
      surfaceContainerLow: const Color(0xFF221C2A),
      surfaceContainer: const Color(0xFF272030),
      surfaceContainerHigh: const Color(0xFF312939),
      surfaceContainerHighest: const Color(0xFF3B3244),
      outline: const Color(0xFF8A7D8F),
      outlineVariant: const Color(0xFF4A3F50),
      inverseSurface: const Color(0xFFF3EAF2),
      onInverseSurface: const Color(0xFF2D2433),
    ),
  };
}
