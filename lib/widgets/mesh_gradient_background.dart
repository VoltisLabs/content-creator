import 'dart:ui';

import 'package:flutter/material.dart';

/// Soft atmosphere behind auth screens (Pinnacle-style).
class MeshGradientBackground extends StatelessWidget {
  const MeshGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final baseGradient = isLight
        ? [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            theme.colorScheme.surface,
          ]
        : [
            const Color(0xFF0B1220),
            const Color(0xFF0F172A),
            const Color(0xFF0B1220),
          ];

    final orb1 = isLight
        ? theme.colorScheme.primary.withValues(alpha: 0.18)
        : theme.colorScheme.primary.withValues(alpha: 0.28);
    final orb2 = isLight
        ? theme.colorScheme.tertiary.withValues(alpha: 0.12)
        : const Color(0x331E40AF);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: baseGradient,
            ),
          ),
        ),
        Positioned(
          right: -80,
          top: -60,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(shape: BoxShape.circle, color: orb1),
            ),
          ),
        ),
        Positioned(
          left: -40,
          bottom: 120,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(shape: BoxShape.circle, color: orb2),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
