import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme_preset.dart';
import '../utils/app_haptics.dart';

class CalendarCell extends StatelessWidget {
  const CalendarCell({
    super.key,
    required this.preset,
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    required this.coverPath,
    required this.hasContent,
    required this.postCount,
    required this.tagCount,
    required this.onTap,
  });

  final AppThemePreset preset;
  final int? day;
  final bool isCurrentMonth;
  final bool isToday;
  final String? coverPath;
  final bool hasContent;
  final int postCount;
  final int tagCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (day == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final hasCover = coverPath != null;
    final glass = preset.isGradient;

    final borderColor = isToday
        ? accent
        : hasContent
            ? accent.withValues(alpha: glass ? 0.55 : 0.4)
            : theme.colorScheme.outline.withValues(alpha: glass ? 0.2 : 0.3);

    final fillColor = _cellFill(theme, hasCover: hasCover);
    final dayBadgeColor = isToday
        ? accent
        : hasCover
            ? Colors.black.withValues(alpha: 0.5)
            : accent.withValues(alpha: isDark ? 0.85 : 0.75);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                AppHaptics.tap();
                onTap!();
              },
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: isToday ? 2 : 1,
            ),
            color: fillColor,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasCover)
                  Image.file(
                    File(coverPath!),
                    key: ValueKey(coverPath),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    color: glass
                        ? accent.withValues(alpha: 0.12)
                        : null,
                    colorBlendMode: glass ? BlendMode.softLight : null,
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholder(theme, accent, secondary),
                  )
                else if (hasContent)
                  _placeholder(theme, accent, secondary)
                else if (!glass)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: isDark ? 0.06 : 0.04),
                          secondary.withValues(alpha: isDark ? 0.04 : 0.03),
                        ],
                      ),
                    ),
                  ),
                if (hasCover || hasContent)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          (glass ? accent : Colors.black)
                              .withValues(alpha: isDark ? 0.72 : 0.58),
                        ],
                      ),
                    ),
                  ),
                if (glass && (hasCover || hasContent))
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0.4, sigmaY: 0.4),
                    child: const SizedBox.expand(),
                  ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: dayBadgeColor,
                              borderRadius: BorderRadius.circular(6),
                              border: glass && !hasCover
                                  ? Border.all(
                                      color: accent.withValues(alpha: 0.35),
                                    )
                                  : null,
                            ),
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: isToday || hasCover
                                    ? Colors.white
                                    : theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (postCount > 1)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (hasCover ? Colors.black : accent)
                                      .withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$postCount',
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          if (hasContent && tagCount > 0)
                            Icon(
                              Icons.local_offer_outlined,
                              size: 14,
                              color: hasCover
                                  ? Colors.white70
                                  : accent.withValues(alpha: 0.85),
                            ),
                        ],
                      ),
                      const Spacer(),
                      if (hasContent && !hasCover)
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Icon(
                            Icons.edit_note,
                            size: 18,
                            color: secondary.withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color? _cellFill(ThemeData theme, {required bool hasCover}) {
    if (hasCover) return Colors.transparent;
    if (preset.isGradient) {
      return theme.colorScheme.primary.withValues(alpha: 0.07);
    }
    if (!isCurrentMonth) {
      return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    }
    return (theme.cardTheme.color ?? theme.colorScheme.surface)
        .withValues(alpha: 0.72);
  }

  Widget _placeholder(ThemeData theme, Color accent, Color secondary) {
    final stops = _placeholderStops(accent, secondary);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: stops,
        ),
      ),
    );
  }

  List<Color> _placeholderStops(Color accent, Color secondary) {
    final third = Color.lerp(accent, secondary, 0.45)!;
    final a = switch (preset) {
      AppThemePreset.developer => accent.withValues(alpha: 0.35),
      AppThemePreset.pinnacleClassic => accent.withValues(alpha: 0.4),
      AppThemePreset.cursor => secondary.withValues(alpha: 0.38),
      AppThemePreset.violet => accent.withValues(alpha: 0.42),
      AppThemePreset.gradientSunrise => const Color(0xFFF97316).withValues(alpha: 0.45),
      AppThemePreset.gradientOcean => const Color(0xFF06B6D4).withValues(alpha: 0.42),
      AppThemePreset.gradientForest => const Color(0xFF22C55E).withValues(alpha: 0.4),
      AppThemePreset.gradientBerry => const Color(0xFFDB2777).withValues(alpha: 0.44),
      AppThemePreset.gradientGold => const Color(0xFFEAB308).withValues(alpha: 0.4),
      AppThemePreset.gradientSlate => const Color(0xFF64748B).withValues(alpha: 0.38),
      AppThemePreset.gradientCoral => const Color(0xFFFF6B6B).withValues(alpha: 0.42),
      AppThemePreset.gradientNeon => const Color(0xFFA855F7).withValues(alpha: 0.45),
      AppThemePreset.gradientLagoon => const Color(0xFF14B8A6).withValues(alpha: 0.42),
      AppThemePreset.gradientTwilight => const Color(0xFF818CF8).withValues(alpha: 0.44),
    };
    final b = third.withValues(alpha: preset.isGradient ? 0.28 : 0.32);
    return [a, b];
  }
}
