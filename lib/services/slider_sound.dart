import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_preferences.dart';
import '../utils/app_haptics.dart';

class SliderSound {
  SliderSound._();

  /// Play tick + haptic when the grid column count changes (not every slider frame).
  static Future<void> playColumnStep() async {
    AppHaptics.tap();
    if (kIsWeb) return;
    if (await AppPreferences.isSliderSilent()) return;
    await SystemSound.play(SystemSoundType.click);
  }
}

/// Column count from slider value (matches calendar grid layout).
int columnCountForScale(double gridScale, {bool desktop = false}) {
  if (desktop) {
    // Desktop: widen cells (fewer columns), capped at 3 across — never full-width single column.
    return (7 - (gridScale * 4)).round().clamp(3, 7);
  }
  return (7 - (gridScale * 6)).round().clamp(1, 7);
}
