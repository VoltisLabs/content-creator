import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences._();

  static const _sliderSilentKey = 'slider_silent_mode';
  static const _gridScaleKey = 'calendar_grid_scale';

  /// Default matches mobile dock (mid-scale thumbnails).
  static const defaultGridScale = 0.5;

  static Future<double> gridScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_gridScaleKey) ?? defaultGridScale;
  }

  static Future<void> setGridScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_gridScaleKey, value);
  }

  static Future<bool> isSliderSilent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sliderSilentKey) ?? false;
  }

  static Future<void> setSliderSilent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sliderSilentKey, value);
  }
}
