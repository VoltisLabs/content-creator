import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme_preset.dart';

typedef GradientPaletteSpec = ({
  Color base,
  Color hint,
  Color hint2,
  Alignment begin,
  Alignment end,
  double homeStrength,
  double chipStrength,
});

/// Full-screen palette gradients and chip swatches for appearance settings.
abstract final class PaletteGradients {
  PaletteGradients._();

  static GradientPaletteSpec? specFor(AppThemePreset preset) => _specs[preset];

  static LinearGradient? homeBackground(AppThemePreset preset) {
    final spec = _specs[preset];
    if (spec == null) return null;
    return _ambientGradient(
      base: spec.base,
      hint: spec.hint,
      hint2: spec.hint2,
      hintStrength: spec.homeStrength,
      begin: spec.begin,
      end: spec.end,
      phase: 0,
    );
  }

  static LinearGradient animatedHomeBackground({
    required GradientPaletteSpec spec,
    required double phase,
  }) {
    final begin = Alignment(
      spec.begin.x + math.sin(phase) * 0.15,
      spec.begin.y + math.cos(phase * 0.7) * 0.12,
    );
    final end = Alignment(
      spec.end.x + math.cos(phase * 0.9) * 0.12,
      spec.end.y + math.sin(phase * 0.8) * 0.15,
    );
    return _ambientGradient(
      base: spec.base,
      hint: spec.hint,
      hint2: spec.hint2,
      hintStrength: spec.homeStrength,
      begin: begin,
      end: end,
      phase: phase,
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
          hint2: spec.hint2,
          hintStrength: spec.chipStrength,
          begin: spec.begin,
          end: spec.end,
          phase: 0,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: spec.hint.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
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

  static LinearGradient _ambientGradient({
    required Color base,
    required Color hint,
    required Color hint2,
    required double hintStrength,
    required Alignment begin,
    required Alignment end,
    required double phase,
  }) {
    final pulse = 0.85 + 0.15 * math.sin(phase);
    final strength = hintStrength * pulse;
    final mid = Color.lerp(base, hint, strength)!;
    final peak = Color.lerp(mid, hint2, strength * 0.85)!;
    final whisper = Color.lerp(base, hint, strength * 0.45)!;
    final rim = Color.lerp(base, hint2, strength * 0.25)!;
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [base, rim, whisper, mid, peak, mid, base],
      stops: const [0.0, 0.18, 0.35, 0.52, 0.68, 0.82, 1.0],
    );
  }

  static const _topDown = (Alignment.topCenter, Alignment.bottomCenter);
  static const _diag = (Alignment.topLeft, Alignment.bottomRight);
  static const _diagFlip = (Alignment.topRight, Alignment.bottomLeft);

  static final _specs = {
    AppThemePreset.gradientSunrise: (
      base: const Color(0xFF140C08),
      hint: const Color(0xFFF97316),
      hint2: const Color(0xFFFBBF24),
      begin: _diag.$1,
      end: _diag.$2,
      homeStrength: 0.22,
      chipStrength: 0.34,
    ),
    AppThemePreset.gradientOcean: (
      base: const Color(0xFF021018),
      hint: const Color(0xFF06B6D4),
      hint2: const Color(0xFF3B82F6),
      begin: _topDown.$1,
      end: _topDown.$2,
      homeStrength: 0.20,
      chipStrength: 0.32,
    ),
    AppThemePreset.gradientForest: (
      base: const Color(0xFF081410),
      hint: const Color(0xFF22C55E),
      hint2: const Color(0xFF84CC16),
      begin: _diag.$1,
      end: _diag.$2,
      homeStrength: 0.19,
      chipStrength: 0.30,
    ),
    AppThemePreset.gradientBerry: (
      base: const Color(0xFF140610),
      hint: const Color(0xFFDB2777),
      hint2: const Color(0xFFA855F7),
      begin: _diagFlip.$1,
      end: _diagFlip.$2,
      homeStrength: 0.21,
      chipStrength: 0.33,
    ),
    AppThemePreset.gradientGold: (
      base: const Color(0xFF121008),
      hint: const Color(0xFFEAB308),
      hint2: const Color(0xFFF59E0B),
      begin: _diag.$1,
      end: _diag.$2,
      homeStrength: 0.23,
      chipStrength: 0.35,
    ),
    AppThemePreset.gradientSlate: (
      base: const Color(0xFF0A1018),
      hint: const Color(0xFF64748B),
      hint2: const Color(0xFF94A3B8),
      begin: _topDown.$1,
      end: _topDown.$2,
      homeStrength: 0.17,
      chipStrength: 0.28,
    ),
    AppThemePreset.gradientCoral: (
      base: const Color(0xFF180A0A),
      hint: const Color(0xFFFF6B6B),
      hint2: const Color(0xFFF472B6),
      begin: _diag.$1,
      end: _diag.$2,
      homeStrength: 0.21,
      chipStrength: 0.32,
    ),
    AppThemePreset.gradientNeon: (
      base: const Color(0xFF04060E),
      hint: const Color(0xFF22D3EE),
      hint2: const Color(0xFF52FFA8),
      begin: _diag.$1,
      end: _diag.$2,
      homeStrength: 0.20,
      chipStrength: 0.31,
    ),
    AppThemePreset.gradientLagoon: (
      base: const Color(0xFF031E1C),
      hint: const Color(0xFF10B981),
      hint2: const Color(0xFF2DD4BF),
      begin: _topDown.$1,
      end: _topDown.$2,
      homeStrength: 0.20,
      chipStrength: 0.31,
    ),
    AppThemePreset.gradientTwilight: (
      base: const Color(0xFF0E0820),
      hint: const Color(0xFF8B5CF6),
      hint2: const Color(0xFFEC4899),
      begin: _diag.$1,
      end: _diag.$2,
      homeStrength: 0.22,
      chipStrength: 0.34,
    ),
  };
}
