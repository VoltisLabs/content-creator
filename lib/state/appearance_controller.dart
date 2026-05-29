import 'package:flutter/foundation.dart';

import '../services/appearance_preferences.dart';
import '../services/custom_background_service.dart';
import '../theme/app_theme_preset.dart';
import '../theme/calendar_ambient_mode.dart';
import '../theme/home_theme_kind.dart';

/// Owns live home appearance. While [batching] is true (settings open), changes
/// are queued and the home tree is not rebuilt until [endBatch].
class AppearanceController extends ChangeNotifier {
  AppearanceController({
    required HomeThemeKind kind,
    required AppThemePreset preset,
    required CalendarAmbientMode ambient,
    required bool useCustomBackground,
    String? customBackgroundPath,
  })  : kind = kind,
        preset = preset,
        ambient = ambient,
        useCustomBackground = useCustomBackground,
        customBackgroundPath = customBackgroundPath;

  /// UI chrome preset when [kind] is [HomeThemeKind.live].
  static const liveChromePreset = AppThemePreset.developer;

  HomeThemeKind kind;
  AppThemePreset preset;
  CalendarAmbientMode ambient;
  bool useCustomBackground;
  String? customBackgroundPath;

  var _batching = false;
  HomeThemeKind? _pendingKind;
  AppThemePreset? _pendingPreset;
  CalendarAmbientMode? _pendingAmbient;
  bool? _pendingUseCustomBackground;
  String? _pendingCustomBackgroundPath;
  var _pendingCustomPathRefresh = false;

  bool get usesLiveHomeTheme => effectiveKind == HomeThemeKind.live;
  bool get usesPaletteTheme => effectiveKind == HomeThemeKind.palette;

  HomeThemeKind get effectiveKind => _pendingKind ?? kind;

  AppThemePreset get effectivePreset =>
      usesPaletteTheme ? (_pendingPreset ?? preset) : liveChromePreset;

  AppThemePreset get settingsUiPreset {
    if (effectiveKind == HomeThemeKind.live) return liveChromePreset;
    return _pendingPreset ?? preset;
  }

  void beginBatch() => _batching = true;

  /// Clears unsaved theme picks when leaving Appearance without closing settings.
  void discardPendingAppearance() {
    _pendingKind = null;
    _pendingPreset = null;
    _pendingAmbient = null;
    notifyListeners();
  }

  void endBatch() {
    _batching = false;

    if (_pendingKind != null) {
      kind = _pendingKind!;
      _pendingKind = null;
    }
    if (_pendingPreset != null) {
      preset = _pendingPreset!;
      _pendingPreset = null;
    }
    if (_pendingAmbient != null) {
      ambient = _pendingAmbient!;
      _pendingAmbient = null;
    }
    if (_pendingUseCustomBackground != null) {
      useCustomBackground = _pendingUseCustomBackground!;
      _pendingUseCustomBackground = null;
    }
    if (_pendingCustomPathRefresh) {
      customBackgroundPath = _pendingCustomBackgroundPath;
      _pendingCustomPathRefresh = false;
      _pendingCustomBackgroundPath = null;
    }

    notifyListeners();
  }

  /// Colour or gradient palette — clears any live theme selection.
  Future<void> selectPalettePreset(AppThemePreset value) async {
    await AppearancePreferences.saveKind(HomeThemeKind.palette);
    await AppearancePreferences.savePreset(value);

    if (_batching) {
      _pendingKind = HomeThemeKind.palette;
      _pendingPreset = value;
      _pendingAmbient = null;
      return;
    }

    kind = HomeThemeKind.palette;
    preset = value;
    notifyListeners();
  }

  /// Live animated home theme — clears any palette selection.
  Future<void> selectLiveTheme(CalendarAmbientMode value) async {
    await AppearancePreferences.saveKind(HomeThemeKind.live);
    await AppearancePreferences.saveAmbient(value);
    await AppearancePreferences.savePreset(liveChromePreset);

    if (_batching) {
      _pendingKind = HomeThemeKind.live;
      _pendingAmbient = value;
      _pendingPreset = null;
      return;
    }

    kind = HomeThemeKind.live;
    ambient = value;
    preset = liveChromePreset;
    notifyListeners();
  }

  Future<void> setUseCustomBackground(bool value) async {
    await AppearancePreferences.saveUseCustomBackground(value);
    if (_batching) {
      _pendingUseCustomBackground = value;
      return;
    }
    if (useCustomBackground == value) return;
    useCustomBackground = value;
    notifyListeners();
  }

  Future<void> refreshCustomBackgroundPath() async {
    final file = await CustomBackgroundService.instance.loadBackgroundFile();
    if (_batching) {
      _pendingCustomPathRefresh = true;
      _pendingCustomBackgroundPath = file?.path;
      return;
    }
    customBackgroundPath = file?.path;
    notifyListeners();
  }

  HomeThemeKind get settingsKind => effectiveKind;
  AppThemePreset? get settingsPalettePreset =>
      effectiveKind == HomeThemeKind.palette ? (_pendingPreset ?? preset) : null;
  CalendarAmbientMode? get settingsLiveMode =>
      effectiveKind == HomeThemeKind.live ? (_pendingAmbient ?? ambient) : null;
  bool get settingsUseCustomBackground =>
      _pendingUseCustomBackground ?? useCustomBackground;
}
