import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme_preset.dart';
import '../theme/palette_gradients.dart';

/// Animated multi-stop gradient behind the calendar for palette gradient themes.
class PaletteGradientBackdrop extends StatefulWidget {
  const PaletteGradientBackdrop({
    super.key,
    required this.preset,
    required this.child,
  });

  final AppThemePreset preset;
  final Widget child;

  @override
  State<PaletteGradientBackdrop> createState() => _PaletteGradientBackdropState();
}

class _PaletteGradientBackdropState extends State<PaletteGradientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = PaletteGradients.specFor(widget.preset);
    if (spec == null) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;
        final gradient = PaletteGradients.animatedHomeBackground(
          spec: spec,
          phase: t,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
            ColoredBox(color: Colors.black.withValues(alpha: 0.06)),
            widget.child,
          ],
        );
      },
    );
  }
}
