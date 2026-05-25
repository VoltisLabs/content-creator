import 'package:flutter/material.dart';

import '../screens/calendar_screen.dart';
import '../state/appearance_controller.dart';
import '../theme/app_theme.dart';
import 'calendar_ambient_backdrop.dart';
import 'palette_gradient_backdrop.dart';
import 'settings_sheet.dart';

/// Calendar home with settings as an overlay (never replaces the home route).
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.appearance,
    required this.violetDarkMode,
    required this.onToggleVioletBrightness,
    required this.stayOnTop,
    required this.onStayOnTopChanged,
  });

  final AppearanceController appearance;
  final bool violetDarkMode;
  final VoidCallback onToggleVioletBrightness;
  final bool stayOnTop;
  final ValueChanged<bool> onStayOnTopChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _settingsVisible = false;
  var _settingsSession = 0;
  var _homeReloadKey = 0;

  void _openSettings() {
    widget.appearance.beginBatch();
    setState(() {
      _settingsSession++;
      _settingsVisible = true;
    });
  }

  /// Closes settings and rebuilds the entire home calendar tree.
  void _closeSettings({bool reloadHome = true}) {
    widget.appearance.endBatch();
    if (!mounted) return;
    setState(() {
      _settingsVisible = false;
      if (reloadHome) _homeReloadKey++;
    });
  }

  /// Theme picked — apply immediately and reload home (no back navigation).
  void _applyAppearanceAndClose() {
    _closeSettings(reloadHome: true);
  }

  @override
  Widget build(BuildContext context) {
    final appearance = widget.appearance;
    final preset = appearance.effectivePreset;
    final usesLive = appearance.usesLiveHomeTheme;
    final usesGradientPalette =
        appearance.usesPaletteTheme && preset.isGradient;
    final theme = AppTheme.resolve(
      preset: preset,
      violetDarkMode: widget.violetDarkMode,
    );

    final calendar = CalendarScreen(
      preset: preset,
      usesLiveHomeTheme: usesLive,
      violetDarkMode: widget.violetDarkMode,
      onToggleVioletBrightness: widget.onToggleVioletBrightness,
      onPresetChanged: appearance.selectPalettePreset,
      ambientMode: appearance.ambient,
      onAmbientChanged: appearance.selectLiveTheme,
      useCustomBackground: appearance.useCustomBackground,
      onUseCustomBackgroundChanged: appearance.setUseCustomBackground,
      onCustomBackgroundChanged: appearance.refreshCustomBackgroundPath,
      stayOnTop: widget.stayOnTop,
      onStayOnTopChanged: widget.onStayOnTopChanged,
      onOpenSettings: _openSettings,
    );

    final calendarTree = usesLive
        ? CalendarAmbientBackdrop(
            mode: appearance.ambient,
            customBackgroundPath: appearance.customBackgroundPath,
            useCustomPhoto: appearance.useCustomBackground &&
                appearance.customBackgroundPath != null,
            child: calendar,
          )
        : usesGradientPalette
            ? PaletteGradientBackdrop(preset: preset, child: calendar)
            : calendar;

    final chromeBackground = usesLive || usesGradientPalette
        ? Colors.transparent
        : theme.scaffoldBackgroundColor;

    final homeContent = KeyedSubtree(
      key: ValueKey('home-reload-$_homeReloadKey'),
      child: Material(
        color: chromeBackground,
        child: calendarTree,
      ),
    );

    return Theme(
      data: theme,
      child: ColoredBox(
        color: chromeBackground,
        child: Stack(
          fit: StackFit.expand,
          children: [
            homeContent,
            if (_settingsVisible)
              Positioned.fill(
                child: SettingsFlow(
                  key: ValueKey('settings-session-$_settingsSession'),
                  appearance: widget.appearance,
                  violetDarkMode: widget.violetDarkMode,
                  stayOnTop: widget.stayOnTop,
                  onStayOnTopChanged: widget.onStayOnTopChanged,
                  onClose: () => _closeSettings(),
                  onAppearanceApplied: _applyAppearanceAndClose,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
