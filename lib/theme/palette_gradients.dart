import 'package:flutter/material.dart';

import 'app_theme_preset.dart';

/// Full-screen palette gradients and chip swatches for appearance settings.
abstract final class PaletteGradients {
  PaletteGradients._();

  static LinearGradient? homeBackground(AppThemePreset preset) {
    final spec = _specs[preset];
    if (spec == null) return null;
    return _ambientGradient(
      base: spec.base,
      hint: spec.hint,
      hintStrength: spec.homeStrength,
      begin: spec.begin,
      end: spec.end,
    );
  }

  static BoxDecoration chipSwatch(AppThemePreset preset) {
    const radius = BorderRadius.all(Radius.circular(8));
    final spec = _specs[preset];
    if (spec != null) {
      return BoxDecoration(
        borderRadius: radius,
        gradient: _ambientGradient(
          base: spec.base,
          hint: spec.hint,
          hintStrength: spec.chipStrength,
          begin: spec.begin,
          end: spec.end,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      );
    }
    return BoxDecoration(
      borderRadius: radius,
      color: _classicSwatchColor(preset),
      border: Border.all(
        color: _classicAccentColor(preset).withValues(alpha: 0.65),
        width: 1.5,
      ),
    );
  }

  static Color _classicSwatchColor(AppThemePreset preset) => switch (preset) {
        AppThemePreset.developer => const Color(0xFF1E1E1E),
        AppThemePreset.pinnacleClassic => const Color(0xFFF1E8DE),
        AppThemePreset.cursor => const Color(0xFF0B1220),
        AppThemePreset.violet => const Color(0xFFF8F9FC),
        _ => const Color(0xFF1E1E1E),
      };

  static Color _classicAccentColor(AppThemePreset preset) => switch (preset) {
        AppThemePreset.developer => const Color(0xFF4FC3F7),
        AppThemePreset.pinnacleClassic => const Color(0xFF3A302B),
        AppThemePreset.cursor => const Color(0xFF60A5FA),
        AppThemePreset.violet => const Color(0xFF6366F1),
        _ => Colors.white54,
      };

  /// Dark base with a gentle colour wash — readable, not blinding.
  static LinearGradient _ambientGradient({
    required Color base,
    required Color hint,
    required double hintStrength,
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    final mid = Color.lerp(base, hint, hintStrength)!;
    final whisper = Color.lerp(base, hint, hintStrength * 0.5)!;
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [base, whisper, mid, base],
      stops: const [0.0, 0.4, 0.65, 1.0],
    );
  }

  static const _topDown = (Alignment.topCenter, Alignment.bottomCenter);
  static const _diag = (Alignment.topLeft, Alignment.bottomRight);
  static const _diagFlip = (Alignment.topRight, Alignment.bottomLeft);

  static final _specs = {
    AppThemePreset.gradientSunrise: (
      base: const Color(0xFF1C1210),
      hint: const Color(0xFFF97316),
      begin: _diag.$1,
      end: _diag.$2,
      homeStrength: 0.13,
      chipStrength: 0.22,
    ),
    AppThemePreset.gradientOcean: (
      base: const Color(0xFF041E2E),
      hint: const Color(0xFF06B6D4),
      begin: _topDown.$1,
      end: _topDown.$2,
      homeStrength: 0.12,
      chipStrength: 0.20,
    ),
    AppThemePreset.gradientForest: (
      base: const Color(0xFF0F1A14),
      hint: const Color(0xFF22C55E),
      begin: _diag.$1,
      end: _diag.$2,
      homeStrength: 0.11,
      chipStrength: 0.19,
    ),
    AppThemePreset.gradientBerry: (
      base: const Color(0xFF1A0A14),
      hint: const Color(0xFFDB2777),
      begin: _diagFlip.$1,
      end: _diagFlip.$2,
      homeStrength: 0.12,
      chipStrength: 0.20,
    ),
    AppThemePreset.gradientGold: (
      base: const Color(0xFF1A1608),
      hint: const Color(0xFFEAB308),
      begin: _diag.$1,
      end: _diag.$2,
      homeStrength: 0.14,
      chipStrength: 0.23,
    ),
    AppThemePreset.gradientSlate: (
      base: const Color(0xFF0F172A),
      hint: const Color(0xFF64748B),
      begin: _topDown.$1,
      end: _topDown.$2,
      homeStrength: 0.10,
      chipStrength: 0.17,
    ),
    AppThemePreset.gradientCoral: (
      base: const Color(0xFF1F1010),
      hint: const Color(0xFFFF6B6B),
      begin: _diag.$1,
      end: _diag.$2,
      homeStrength: 0.12,
      chipStrength: 0.20,
    ),
    AppThemePreset.gradientNeon: (
      base: const Color(0xFF070B14),
      hint: const Color(0xFF22D3EE),
      begin: _diag.$1,
      end: _diag.$2,
      homeStrength: 0.11,
      chipStrength: 0.19,
    ),
    AppThemePreset.gradientLagoon: (
      base: const Color(0xFF042F2E),
      hint: const Color(0xFF10B981),
      begin: _topDown.$1,
      end: _topDown.$2,
      homeStrength: 0.12,
      chipStrength: 0.20,
    ),
    AppThemePreset.gradientTwilight: (
      base: const Color(0xFF120B24),
      hint: const Color(0xFF8B5CF6),
      begin: _diag.$1,
      end: _diag.$2,
      homeStrength: 0.13,
      chipStrength: 0.21,
    ),
  };
}
