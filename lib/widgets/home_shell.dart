import 'package:flutter/material.dart';

import '../screens/calendar_screen.dart';
import '../state/appearance_controller.dart';
import '../theme/app_theme.dart';
import 'calendar_ambient_backdrop.dart';
import 'palette_gradient_backdrop.dart';
import 'settings_sheet.dart';

/// Calendar home with optional demo content mode and settings overlay.
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
  var _calendarReloadKey = 0;
  var _demoMode = false;

  @override
  void initState() {
    super.initState();
    widget.appearance.addListener(_onAppearanceChanged);
  }

  @override
  void dispose() {
    widget.appearance.removeListener(_onAppearanceChanged);
    super.dispose();
  }

  void _onAppearanceChanged() {
    if (!mounted || _settingsVisible) return;
    setState(() {});
  }

  void _openSettings() {
    widget.appearance.beginBatch();
    setState(() {
      _settingsSession++;
      _settingsVisible = true;
    });
  }

  void _closeSettings({bool reloadHome = true}) {
    if (!mounted) return;
    setState(() => _settingsVisible = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.appearance.endBatch();
      if (reloadHome) {
        setState(() => _calendarReloadKey++);
      }
    });
  }

  void _applyAppearanceInSettings() {}

  void _setDemoMode(bool value) {
    setState(() => _demoMode = value);
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
      key: ValueKey('calendar-$_calendarReloadKey'),
      screenTitle: _demoMode ? 'Demo Content' : 'Content Calendar',
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
      demoMode: _demoMode,
      onEnterDemoContent: () => _setDemoMode(true),
      onExitDemoContent: () => _setDemoMode(false),
    );

    final calendarTree = usesLive
        ? CalendarAmbientBackdrop(
            key: ValueKey(
              'live-${appearance.ambient.name}-'
              '${appearance.customBackgroundPath}-'
              '${appearance.useCustomBackground}',
            ),
            mode: appearance.ambient,
            customBackgroundPath: appearance.customBackgroundPath,
            useCustomPhoto: appearance.useCustomBackground &&
                appearance.customBackgroundPath != null,
            child: calendar,
          )
        : usesGradientPalette
            ? PaletteGradientBackdrop(
                key: ValueKey('gradient-$preset'),
                preset: preset,
                child: calendar,
              )
            : calendar;

    final chromeBackground = usesLive || usesGradientPalette
        ? Colors.transparent
        : theme.scaffoldBackgroundColor;

    final homeContent = Material(
      color: chromeBackground,
      child: TickerMode(
        enabled: !_settingsVisible,
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
                  onAppearanceApplied: _applyAppearanceInSettings,
                  onStorageChanged: () {
                    if (!mounted) return;
                    setState(() => _calendarReloadKey++);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
