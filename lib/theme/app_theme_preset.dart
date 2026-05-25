/// Saved appearance preset for Content Calendar (classic + gradient palettes).
enum AppThemePreset {
  developer,
  pinnacleClassic,
  cursor,
  violet,
  gradientSunrise,
  gradientOcean,
  gradientForest,
  gradientBerry,
  gradientGold,
  gradientSlate,
  gradientCoral,
  gradientNeon,
  gradientLagoon,
  gradientTwilight;

  static const classicPresets = [
    AppThemePreset.developer,
    AppThemePreset.pinnacleClassic,
    AppThemePreset.cursor,
    AppThemePreset.violet,
  ];

  static const gradientPresets = [
    AppThemePreset.gradientSunrise,
    AppThemePreset.gradientOcean,
    AppThemePreset.gradientForest,
    AppThemePreset.gradientBerry,
    AppThemePreset.gradientGold,
    AppThemePreset.gradientSlate,
    AppThemePreset.gradientCoral,
    AppThemePreset.gradientNeon,
    AppThemePreset.gradientLagoon,
    AppThemePreset.gradientTwilight,
  ];

  static AppThemePreset fromStorage(String? raw) {
    for (final preset in AppThemePreset.values) {
      if (preset.storageName == raw) return preset;
    }
    return AppThemePreset.developer;
  }

  String get storageName => name;

  bool get isGradient => gradientPresets.contains(this);

  String get label => switch (this) {
        AppThemePreset.developer => 'Developer',
        AppThemePreset.pinnacleClassic => 'Voltis Core',
        AppThemePreset.cursor => 'Cursor',
        AppThemePreset.violet => 'Violet',
        AppThemePreset.gradientSunrise => 'Sunrise',
        AppThemePreset.gradientOcean => 'Ocean gradient',
        AppThemePreset.gradientForest => 'Forest gradient',
        AppThemePreset.gradientBerry => 'Berry gradient',
        AppThemePreset.gradientGold => 'Gold gradient',
        AppThemePreset.gradientSlate => 'Slate gradient',
        AppThemePreset.gradientCoral => 'Coral gradient',
        AppThemePreset.gradientNeon => 'Neon gradient',
        AppThemePreset.gradientLagoon => 'Lagoon gradient',
        AppThemePreset.gradientTwilight => 'Twilight gradient',
      };
}
