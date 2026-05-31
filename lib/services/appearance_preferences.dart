import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme_preset.dart';
import '../theme/calendar_ambient_mode.dart';
import '../theme/home_theme_kind.dart';

class AppearancePreferences {
  AppearancePreferences._();

  static const _kindKey = 'home_theme_kind';
  static const _presetKey = 'app_theme_preset';
  static const _ambientKey = 'calendar_ambient_mode';

  static Future<HomeThemeKind> loadKind({required AppThemePreset preset}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kindKey);
    if (raw == HomeThemeKind.live.name) return HomeThemeKind.live;
    if (raw == HomeThemeKind.palette.name) return HomeThemeKind.palette;
    // Migrate installs that stored both palette + live at once.
    if (preset.isGradient) return HomeThemeKind.palette;
    return HomeThemeKind.live;
  }

  static Future<void> saveKind(HomeThemeKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kindKey, kind.name);
  }

  static Future<AppThemePreset> loadPreset() async {
    final prefs = await SharedPreferences.getInstance();
    return AppThemePreset.fromStorage(prefs.getString(_presetKey));
  }

  static Future<void> savePreset(AppThemePreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetKey, preset.storageName);
  }

  static Future<CalendarAmbientMode> loadAmbient() async {
    final prefs = await SharedPreferences.getInstance();
    return CalendarAmbientMode.fromStorage(prefs.getString(_ambientKey));
  }

  static Future<void> saveAmbient(CalendarAmbientMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ambientKey, mode.name);
  }
}
