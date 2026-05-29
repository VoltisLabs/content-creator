import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/app_haptics.dart';

class MobileCalendarDock extends StatelessWidget {
  const MobileCalendarDock({
    super.key,
    required this.showSlider,
    required this.onToggleSlider,
    required this.gridScale,
    required this.onGridScaleChanged,
    required this.onImportLink,
    required this.onShareMonth,
    required this.onOpenSettings,
    this.demoMode = false,
    this.onToggleDemo,
    this.showProBadgeOnShare = false,
    this.onToggleTheme,
    this.showThemeToggle = false,
    this.isDarkTheme = false,
  });

  final bool showSlider;
  final VoidCallback onToggleSlider;
  final double gridScale;
  final ValueChanged<double> onGridScaleChanged;
  final VoidCallback onImportLink;
  final VoidCallback onShareMonth;
  final VoidCallback onOpenSettings;
  final bool demoMode;
  final VoidCallback? onToggleDemo;
  final bool showProBadgeOnShare;
  final VoidCallback? onToggleTheme;
  final bool showThemeToggle;
  final bool isDarkTheme;

  static const double dockHeight = 72;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final glassFill = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.55);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: glassFill,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSlider) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                    child: Row(
                      children: [
                        Icon(Icons.view_compact_rounded, size: 20, color: muted),
                        Expanded(
                          child: Slider(
                            value: gridScale,
                            onChanged: onGridScaleChanged,
                          ),
                        ),
                        Icon(Icons.view_module_rounded, size: 22, color: muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (onToggleDemo != null)
                      _DockButton(
                        tooltip: demoMode ? 'Content Calendar' : 'Demo content',
                        icon: demoMode
                            ? Icons.calendar_month_rounded
                            : Icons.collections_rounded,
                        selected: demoMode,
                        badgeLabel: demoMode ? null : 'DEMO',
                        onPressed: onToggleDemo!,
                      ),
                    _DockButton(
                      tooltip: 'Import shared link',
                      icon: Icons.add_link_rounded,
                      onPressed: onImportLink,
                    ),
                    _DockButton(
                      tooltip: showSlider ? 'Hide thumbnail size' : 'Thumbnail size',
                      icon: Icons.dashboard_customize_rounded,
                      selected: showSlider,
                      onPressed: onToggleSlider,
                    ),
                    _DockButton(
                      tooltip: 'Share this month',
                      icon: Icons.share_rounded,
                      onPressed: onShareMonth,
                      showProBadge: showProBadgeOnShare,
                    ),
                    _DockButton(
                      tooltip: 'Settings',
                      icon: Icons.settings_rounded,
                      onPressed: onOpenSettings,
                    ),
                    if (showThemeToggle && onToggleTheme != null)
                      _DockButton(
                        tooltip: isDarkTheme ? 'Light mode' : 'Dark mode',
                        icon: isDarkTheme
                            ? Icons.wb_sunny_rounded
                            : Icons.nights_stay_rounded,
                        onPressed: onToggleTheme!,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.badgeLabel,
    this.showProBadge = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;
  final String? badgeLabel;
  final bool showProBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = selected
        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.28 : 0.16)
        : Colors.transparent;
    final fg = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.88);

    return IconButton(
      tooltip: tooltip,
      onPressed: AppHaptics.wrap(onPressed),
      iconSize: 26,
      style: IconButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(44, 44),
        shape: const CircleBorder(),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, weight: 500),
          if (badgeLabel != null || showProBadge)
            Positioned(
              top: -5,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeLabel ?? 'PRO',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 8,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
