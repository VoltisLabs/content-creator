import 'package:flutter/material.dart';

import '../theme/app_theme_preset.dart';
import '../theme/palette_gradients.dart';

/// Static multi-stop gradient behind the calendar for palette gradient themes.
class PaletteGradientBackdrop extends StatelessWidget {
  const PaletteGradientBackdrop({
    super.key,
    required this.preset,
    required this.child,
  });

  final AppThemePreset preset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final gradient = PaletteGradients.homeBackground(preset);
    if (gradient == null) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
        ),
        // Extra veil keeps calendar text readable on every display.
        ColoredBox(color: Colors.black.withValues(alpha: 0.08)),
        child,
      ],
    );
  }
}
