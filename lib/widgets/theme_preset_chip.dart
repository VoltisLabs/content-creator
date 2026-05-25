import 'package:flutter/material.dart';

import '../theme/app_theme_preset.dart';
import '../utils/app_haptics.dart';

/// Swatch accent for theme chips (not full [AppTheme.resolve] — preview only).
Color themePresetSwatch(AppThemePreset preset) => switch (preset) {
      AppThemePreset.developer => const Color(0xFF4FC3F7),
      AppThemePreset.pinnacleClassic => const Color(0xFF3A302B),
      AppThemePreset.cursor => const Color(0xFF60A5FA),
      AppThemePreset.violet => const Color(0xFF6366F1),
      AppThemePreset.gradientSunrise => const Color(0xFFF97316),
      AppThemePreset.gradientOcean => const Color(0xFF06B6D4),
      AppThemePreset.gradientForest => const Color(0xFF22C55E),
      AppThemePreset.gradientBerry => const Color(0xFFDB2777),
      AppThemePreset.gradientGold => const Color(0xFFEAB308),
      AppThemePreset.gradientSlate => const Color(0xFF64748B),
      AppThemePreset.gradientCoral => const Color(0xFFFF6B6B),
      AppThemePreset.gradientNeon => const Color(0xFF22D3EE),
      AppThemePreset.gradientLagoon => const Color(0xFF10B981),
      AppThemePreset.gradientTwilight => const Color(0xFF8B5CF6),
    };

/// One selectable theme in a horizontal row.
class ThemePresetChip extends StatelessWidget {
  const ThemePresetChip({
    super.key,
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AppThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = themePresetSwatch(preset);
    final isGradient = preset.isGradient;

    return SizedBox(
      width: 108,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            AppHaptics.tap();
            onTap();
          },
          child: Ink(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.35),
                width: selected ? 2 : 1,
              ),
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
            ),
            child: Column(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: isGradient
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent,
                                Color.lerp(accent, Colors.white, 0.25)!,
                              ],
                            )
                          : null,
                      color: isGradient ? null : accent.withValues(alpha: 0.85),
                    ),
                    child: selected
                        ? const Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  preset.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrollable row of palette / gradient presets.
class HorizontalThemePresetRow extends StatelessWidget {
  const HorizontalThemePresetRow({
    super.key,
    required this.presets,
    required this.selected,
    required this.onSelected,
  });

  final List<AppThemePreset> presets;
  final AppThemePreset? selected;
  final ValueChanged<AppThemePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final preset = presets[index];
          return ThemePresetChip(
            preset: preset,
            selected: selected == preset,
            onTap: () => onSelected(preset),
          );
        },
      ),
    );
  }
}
