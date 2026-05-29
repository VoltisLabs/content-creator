import 'package:flutter/material.dart';

import 'app_theme_preset.dart';
import 'page_slide_transitions.dart';
import 'ui_fonts.dart';

/// Theme tokens copied from Voltis Labs products (NotepadPro, Pinnacle).
abstract final class AppTheme {
  static const _violetSeed = Color(0xFF6366F1);

  /// Stable MaterialApp theme so route transitions do not rebuild the whole navigator.
  static ThemeData get shell => developer;

  static ThemeData resolve({
    required AppThemePreset preset,
    required bool violetDarkMode,
  }) {
    if (preset == AppThemePreset.violet) {
      return violetDarkMode ? violetDark : violet;
    }
    return switch (preset) {
      AppThemePreset.developer => developer,
      AppThemePreset.cursor => cursor,
      AppThemePreset.pinnacleClassic => pinnacleClassic,
      AppThemePreset.violet => violet,
      AppThemePreset.gradientSunrise => gradientSunrise,
      AppThemePreset.gradientOcean => gradientOcean,
      AppThemePreset.gradientForest => gradientForest,
      AppThemePreset.gradientBerry => gradientBerry,
      AppThemePreset.gradientGold => gradientGold,
      AppThemePreset.gradientSlate => gradientSlate,
      AppThemePreset.gradientCoral => gradientCoral,
      AppThemePreset.gradientNeon => gradientNeon,
      AppThemePreset.gradientLagoon => gradientLagoon,
      AppThemePreset.gradientTwilight => gradientTwilight,
    };
  }

  static ThemeData get gradientSunrise => _gradient(
        seed: const Color(0xFFF97316),
        scaffold: const Color(0xFF1C1210),
        brightness: Brightness.dark,
      );

  static ThemeData get gradientOcean => _gradient(
        seed: const Color(0xFF06B6D4),
        scaffold: const Color(0xFF041E2E),
        brightness: Brightness.dark,
      );

  static ThemeData get gradientForest => _gradient(
        seed: const Color(0xFF22C55E),
        scaffold: const Color(0xFF0F1A14),
        brightness: Brightness.dark,
      );

  static ThemeData get gradientBerry => _gradient(
        seed: const Color(0xFFDB2777),
        scaffold: const Color(0xFF1A0A14),
        brightness: Brightness.dark,
      );

  static ThemeData get gradientGold => _gradient(
        seed: const Color(0xFFEAB308),
        scaffold: const Color(0xFF1A1608),
        brightness: Brightness.dark,
      );

  static ThemeData get gradientSlate => _gradient(
        seed: const Color(0xFF64748B),
        scaffold: const Color(0xFF0F172A),
        brightness: Brightness.dark,
      );

  static ThemeData get gradientCoral => _gradient(
        seed: const Color(0xFFFF6B6B),
        scaffold: const Color(0xFF1F1010),
        brightness: Brightness.dark,
      );

  static ThemeData get gradientNeon => _gradient(
        seed: const Color(0xFF22D3EE),
        scaffold: const Color(0xFF070B14),
        brightness: Brightness.dark,
      );

  static ThemeData get gradientLagoon => _gradient(
        seed: const Color(0xFF10B981),
        scaffold: const Color(0xFF042F2E),
        brightness: Brightness.dark,
      );

  static ThemeData get gradientTwilight => _gradient(
        seed: const Color(0xFF8B5CF6),
        scaffold: const Color(0xFF120B24),
        brightness: Brightness.dark,
      );

  static ThemeData _gradient({
    required Color seed,
    required Color scaffold,
    required Brightness brightness,
  }) =>
      _build(
        brightness: brightness,
        scheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          surface: scaffold.withValues(alpha: 0.98),
        ),
        scaffold: scaffold,
      );

  static ThemeData get violet => _build(
        brightness: Brightness.light,
        scheme: ColorScheme.fromSeed(
          seedColor: _violetSeed,
          brightness: Brightness.light,
          surface: const Color(0xFFF8F9FC),
        ),
        scaffold: const Color(0xFFF8F9FC),
      );

  static ThemeData get violetDark => _build(
        brightness: Brightness.dark,
        scheme: ColorScheme.fromSeed(
          seedColor: _violetSeed,
          brightness: Brightness.dark,
          surface: const Color(0xFF121218),
        ),
        scaffold: const Color(0xFF121218),
      ).copyWith(
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1C1C24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2E2E3A)),
          ),
        ),
      );

  /// Copied from NotepadPro `AppTheme.developer` (lib/theme/app_theme.dart).
  static ThemeData get developer => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          surfaceTint: Colors.transparent,
          primary: Color(0xFF4FC3F7),
          onPrimary: Color(0xFF0D1117),
          primaryContainer: Color(0xFF1F6FEB),
          onPrimaryContainer: Color(0xFFE3F2FD),
          secondary: Color(0xFFCE9178),
          onSecondary: Color(0xFF0D1117),
          secondaryContainer: Color(0xFF3D2E24),
          onSecondaryContainer: Color(0xFFFFE0CC),
          tertiary: Color(0xFFC586C0),
          onTertiary: Color(0xFF0D1117),
          tertiaryContainer: Color(0xFF3A2D3A),
          onTertiaryContainer: Color(0xFFF3E5F5),
          error: Color(0xFFF48771),
          onError: Color(0xFF2D0A0A),
          surface: Color(0xFF252526),
          onSurface: Color(0xFFCCCCCC),
          onSurfaceVariant: Color(0xFF858585),
          surfaceContainerHighest: Color(0xFF2D2D30),
          outline: Color(0xFF3E3E42),
          outlineVariant: Color(0xFF474747),
          shadow: Color(0x99000000),
          scrim: Color(0xCC000000),
          inverseSurface: Color(0xFFE8E8E8),
          onInverseSurface: Color(0xFF1E1E1E),
          inversePrimary: Color(0xFF007ACC),
        ),
        scaffold: const Color(0xFF1E1E1E),
      );

  /// Copied from NotepadPro `AppTheme.dark` — navy night palette (Cursor companion).
  static ThemeData get cursor => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          surfaceTint: Colors.transparent,
          primary: Color(0xFF60A5FA),
          onPrimary: Color(0xFF0B1220),
          primaryContainer: Color(0xFF1E3A8A),
          onPrimaryContainer: Color(0xFFBFDBFE),
          secondary: Color(0xFF38BDF8),
          onSecondary: Color(0xFF0B1220),
          secondaryContainer: Color(0xFF0C4A6E),
          onSecondaryContainer: Color(0xFFE0F2FE),
          tertiary: Color(0xFF818CF8),
          onTertiary: Color(0xFF0B1220),
          error: Color(0xFFF87171),
          onError: Color(0xFF450A0A),
          surface: Color(0xFF151F2E),
          onSurface: Color(0xFFF1F5F9),
          onSurfaceVariant: Color(0xFF94A3B8),
          surfaceContainerHighest: Color(0xFF1E293B),
          outline: Color(0xFF334155),
          outlineVariant: Color(0xFF1E293B),
          shadow: Color(0x66000000),
          scrim: Color(0x99000000),
          inverseSurface: Color(0xFFF1F5F9),
          onInverseSurface: Color(0xFF0F172A),
          inversePrimary: Color(0xFF1D4ED8),
        ),
        scaffold: const Color(0xFF0B1220),
      );

  /// Copied from Pinnacle `AppTheme.light` (yellow-brown parchment).
  static ThemeData get pinnacleClassic => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          surfaceTint: Colors.transparent,
          primary: Color(0xFF3A302B),
          onPrimary: Color(0xFFFDF9F4),
          primaryContainer: Color(0xFFE5D6CA),
          onPrimaryContainer: Color(0xFF261F1B),
          secondary: Color(0xFF4A5A4E),
          onSecondary: Color(0xFFFDF9F4),
          secondaryContainer: Color(0xFFD6E0D8),
          onSecondaryContainer: Color(0xFF1A221C),
          tertiary: Color(0xFF5C4A3D),
          onTertiary: Color(0xFFFDF9F4),
          tertiaryContainer: Color(0xFFE8DDD4),
          onTertiaryContainer: Color(0xFF2A221C),
          error: Color(0xFFB91C1C),
          onError: Color(0xFFFFFFFF),
          surface: Color(0xFFFBF7F1),
          onSurface: Color(0xFF1F1814),
          onSurfaceVariant: Color(0xFF5A524C),
          surfaceContainerHighest: Color(0xFFEDE5DD),
          outline: Color(0xFFBEB0A5),
          outlineVariant: Color(0xFFD9CFC4),
          shadow: Color(0x1A0F172A),
          scrim: Color(0x660F172A),
          inverseSurface: Color(0xFF2A2622),
          onInverseSurface: Color(0xFFF5F0EA),
          inversePrimary: Color(0xFFC9A86C),
        ),
        scaffold: const Color(0xFFF1E8DE),
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkSparkle.splashFactory,
    );

    TextTheme textTheme;
    try {
      textTheme = base.textTheme.apply(
        fontFamily: UiFonts.family,
        fontFamilyFallback: UiFonts.fallback,
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );
    } catch (_) {
      textTheme = base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      );
    }

    final isLight = brightness == Brightness.light;
    final border = scheme.outline.withValues(alpha: isLight ? 0.55 : 0.65);

    return base.copyWith(
      pageTransitionsTheme: slidePageTransitionsTheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: isLight ? 0.9 : 0.5),
      ),
    );
  }
}
