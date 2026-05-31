import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/auth_gate.dart';
import 'screens/voltis_splash_screen.dart';
import 'services/appearance_preferences.dart';
import 'services/calendar_share_service.dart';
import 'services/desktop_window.dart';
import 'services/storage_service.dart';
import 'services/subscription_service.dart';
import 'services/voltis_core_service.dart';
import 'state/appearance_controller.dart';
import 'state/app_settings.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_preset.dart';
import 'theme/calendar_ambient_mode.dart';
import 'theme/home_theme_kind.dart';
import 'widgets/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    }
  };

  await initDesktopWindow();
  await StorageService.instance.init();
  final settings = await AppSettings.load();
  await VoltisCoreService.instance.initialize();
  if (VoltisCoreService.instance.isSignedIn) {
    await VoltisCoreService.instance.syncFromSession();
    await applyVoltisSessionToApp(settings);
  } else if (settings.contentCalendarPro) {
    await SubscriptionService.instance
        .setCoreProEntitlement(settings.contentCalendarPro);
  }
  final storedPreset = await AppearancePreferences.loadPreset();
  final kind = await AppearancePreferences.loadKind(preset: storedPreset);
  final preset = kind == HomeThemeKind.live
      ? AppearanceController.liveChromePreset
      : storedPreset;
  final ambient = await AppearancePreferences.loadAmbient();

  runApp(
    AppSettingsScope(
      settings: settings,
      child: ContentCalendarApp(
        initialKind: kind,
        initialPreset: preset,
        initialAmbient: ambient,
      ),
    ),
  );

  unawaited(_bootstrapBackgroundServices());
}

Future<void> _bootstrapBackgroundServices() async {
  try {
    await CalendarShareService.instance.start();
  } catch (error, stack) {
    debugPrint('CalendarShareService.start failed: $error\n$stack');
  }

  try {
    await SubscriptionService.instance.init().timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        debugPrint('SubscriptionService.init timed out — continuing without store');
      },
    );
  } catch (error, stack) {
    debugPrint('SubscriptionService.init failed: $error\n$stack');
  }
}

class ContentCalendarApp extends StatefulWidget {
  const ContentCalendarApp({
    super.key,
    required this.initialKind,
    required this.initialPreset,
    required this.initialAmbient,
  });

  final HomeThemeKind initialKind;
  final AppThemePreset initialPreset;
  final CalendarAmbientMode initialAmbient;

  @override
  State<ContentCalendarApp> createState() => _ContentCalendarAppState();
}

class _ContentCalendarAppState extends State<ContentCalendarApp> {
  late final AppearanceController _appearance;
  bool _violetDarkMode = false;
  bool _stayOnTop = false;

  @override
  void initState() {
    super.initState();
    _appearance = AppearanceController(
      kind: widget.initialKind,
      preset: widget.initialPreset,
      ambient: widget.initialAmbient,
    );
  }

  @override
  void dispose() {
    _appearance.dispose();
    super.dispose();
  }

  void _toggleVioletBrightness() {
    if (!_appearance.usesPaletteTheme ||
        _appearance.preset != AppThemePreset.violet) {
      return;
    }
    setState(() {
      _violetDarkMode = !_violetDarkMode;
    });
  }

  Future<void> _setStayOnTop(bool value) async {
    setState(() => _stayOnTop = value);
    await setStayOnTop(value);
  }

  List<PlatformMenu> _desktopMenus() {
    final isMac = Platform.isMacOS;

    return [
      PlatformMenu(
        label: 'File',
        menus: [
          PlatformMenuItem(
            label: isMac ? 'Close Window' : 'Close',
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyW,
              meta: isMac,
              control: !isMac,
            ),
            onSelected: closeDesktopWindow,
          ),
          PlatformMenuItem(
            label: isMac ? 'Quit Content Calendar' : 'Exit',
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyQ,
              meta: isMac,
              control: !isMac,
            ),
            onSelected: closeDesktopWindow,
          ),
        ],
      ),
      PlatformMenu(
        label: 'View',
        menus: [
          if (_appearance.usesPaletteTheme &&
              _appearance.preset == AppThemePreset.violet)
            PlatformMenuItem(
              label: _violetDarkMode ? 'Violet light' : 'Violet dark',
              shortcut: SingleActivator(
                LogicalKeyboardKey.keyD,
                meta: isMac,
                control: !isMac,
                shift: true,
              ),
              onSelected: _toggleVioletBrightness,
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final home = VoltisSplashScreen(
      child: AuthGate(
        child: HomeShell(
          appearance: _appearance,
          violetDarkMode: _violetDarkMode,
          onToggleVioletBrightness: _toggleVioletBrightness,
          stayOnTop: _stayOnTop,
          onStayOnTopChanged: _setStayOnTop,
        ),
      ),
    );

    final themed = MaterialApp(
      title: 'Content Calendar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.shell,
      home: home,
    );

    if (!isDesktop) return themed;

    return PlatformMenuBar(
      menus: _desktopMenus(),
      child: themed,
    );
  }
}
