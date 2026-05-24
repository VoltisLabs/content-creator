import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/calendar_screen.dart';
import 'services/desktop_window.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDesktopWindow();
  await StorageService.instance.init();
  runApp(const ContentCalendarApp());
}

class ContentCalendarApp extends StatefulWidget {
  const ContentCalendarApp({super.key});

  @override
  State<ContentCalendarApp> createState() => _ContentCalendarAppState();
}

class _ContentCalendarAppState extends State<ContentCalendarApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _stayOnTop = false;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  Future<void> _toggleStayOnTop() async {
    setState(() => _stayOnTop = !_stayOnTop);
    await setStayOnTop(_stayOnTop);
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
          PlatformMenuItem(
            label: _stayOnTop ? 'Stay on Top  ✓' : 'Stay on Top',
            onSelected: _toggleStayOnTop,
          ),
          PlatformMenuItem(
            label: 'Toggle Dark Mode',
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyD,
              meta: isMac,
              control: !isMac,
              shift: true,
            ),
            onSelected: _toggleTheme,
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Content Calendar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: CalendarScreen(onToggleTheme: _toggleTheme),
    );

    if (!isDesktop) return app;

    return PlatformMenuBar(
      menus: _desktopMenus(),
      child: app,
    );
  }
}
