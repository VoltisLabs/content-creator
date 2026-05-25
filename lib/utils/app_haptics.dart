import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Light haptic feedback for tappable controls.
abstract final class AppHaptics {
  static void tap() {
    HapticFeedback.lightImpact();
  }

  static VoidCallback? wrap(VoidCallback? action) {
    if (action == null) return null;
    return () {
      tap();
      action();
    };
  }
}
