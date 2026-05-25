import 'package:flutter/material.dart';

import '../theme/app_theme_preset.dart';
import '../theme/palette_gradients.dart';
import '../utils/app_haptics.dart';

/// One selectable theme in a horizontal row.
class ThemePresetChip extends StatelessWidget {
  const ThemePresetChip({
    super.key,
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  static const chipWidth = 108.0;
  static const chipHeight = 104.0;
  static const swatchHeight = 56.0;

  final AppThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: chipWidth,
      height: chipHeight,
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
                SizedBox(
                  height: swatchHeight,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: PaletteGradients.chipSwatch(preset),
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
      height: ThemePresetChip.chipHeight,
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
