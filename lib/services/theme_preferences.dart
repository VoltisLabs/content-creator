import '../theme/app_theme_preset.dart';
import 'appearance_preferences.dart';

class ThemePreferences {
  ThemePreferences._();

  static Future<AppThemePreset> load() => AppearancePreferences.loadPreset();

  static Future<void> save(AppThemePreset preset) =>
      AppearancePreferences.savePreset(preset);
}
