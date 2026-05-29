import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Subtle, random ambient backdrop for auth screens (new layout each visit).
class AuthAmbientBackground extends StatefulWidget {
  const AuthAmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuthAmbientBackground> createState() => _AuthAmbientBackgroundState();
}

class _Orb {
  const _Orb({
    required this.alignment,
    required this.radiusFactor,
    required this.colorIndex,
    required this.blur,
  });

  final Alignment alignment;
  final double radiusFactor;
  final int colorIndex;
  final double blur;
}

class _AuthAmbientBackgroundState extends State<AuthAmbientBackground> {
  late final math.Random _random;
  late final List<_Orb> _orbs;
  late final double _wireRotation;
  late final int _wireSides;

  @override
  void initState() {
    super.initState();
    _random = math.Random(DateTime.now().microsecondsSinceEpoch);
    _wireRotation = _random.nextDouble() * math.pi * 2;
    _wireSides = 3 + _random.nextInt(3);
    _orbs = List.generate(3 + _random.nextInt(3), (_) => _randomOrb());
  }

  _Orb _randomOrb() {
    return _Orb(
      alignment: Alignment(
        _random.nextDouble() * 1.6 - 0.8,
        _random.nextDouble() * 1.4 - 0.7,
      ),
      radiusFactor: 0.14 + _random.nextDouble() * 0.22,
      colorIndex: _random.nextInt(4),
      blur: 56 + _random.nextDouble() * 48,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final base = isLight
        ? [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            theme.colorScheme.surface,
          ]
        : const [
            Color(0xFF0B1220),
            Color(0xFF0F172A),
            Color(0xFF0B1220),
          ];

    final palette = isLight
        ? [
            theme.colorScheme.primary.withValues(alpha: 0.14),
            theme.colorScheme.tertiary.withValues(alpha: 0.1),
            const Color(0x1A22C55E),
            const Color(0x1A8B5CF6),
          ]
        : [
            theme.colorScheme.primary.withValues(alpha: 0.22),
            const Color(0x331E40AF),
            const Color(0x2822C55E),
            const Color(0x28A855F7),
          ];

    final wireColor = isLight
        ? theme.colorScheme.primary.withValues(alpha: 0.07)
        : theme.colorScheme.primary.withValues(alpha: 0.11);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: base,
            ),
          ),
        ),
        CustomPaint(
          painter: _SubtleWirePainter(
            rotation: _wireRotation,
            sides: _wireSides,
            color: wireColor,
            phase: _random.nextDouble(),
          ),
        ),
        ..._orbs.map((orb) {
          final color = palette[orb.colorIndex % palette.length];
          return LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest.shortestSide;
              final size = side * orb.radiusFactor;
              return Align(
                alignment: orb.alignment,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: orb.blur,
                    sigmaY: orb.blur,
                  ),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                ),
              );
            },
          );
        }),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, 0.05),
              radius: 1.05,
              colors: [
                (isLight ? Colors.white : const Color(0xFF0B1220))
                    .withValues(alpha: 0.35),
                (isLight ? Colors.white : const Color(0xFF0B1220))
                    .withValues(alpha: 0.82),
              ],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _SubtleWirePainter extends CustomPainter {
  _SubtleWirePainter({
    required this.rotation,
    required this.sides,
    required this.color,
    required this.phase,
  });

  final double rotation;
  final int sides;
  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    final cx = size.width * (0.72 + 0.06 * math.sin(phase * math.pi * 2));
    final cy = size.height * (0.28 + 0.05 * math.cos(phase * math.pi * 2));
    final r = size.shortestSide * (0.28 + 0.04 * phase);

    final outer = _polygon(Offset(cx, cy), r, sides, rotation);
    canvas.drawPath(outer, stroke);

    final inner = _polygon(
      Offset(cx - 18, cy + 12),
      r * 0.52,
      sides + 1,
      -rotation * 0.7,
    );
    canvas.drawPath(
      inner,
      stroke..color = color.withValues(alpha: color.a * 0.55),
    );

    final grid = Paint()
      ..color = color.withValues(alpha: color.a * 0.35)
      ..strokeWidth = 0.8;
    const step = 56.0;
    final offset = (phase * step) % step;
    for (var x = -step; x < size.width + step; x += step) {
      canvas.drawLine(
        Offset(x + offset, 0),
        Offset(x + offset, size.height),
        grid,
      );
    }
  }

  Path _polygon(Offset center, double radius, int sides, double rot) {
    final path = Path();
    for (var i = 0; i <= sides; i++) {
      final a = rot + (i / sides) * math.pi * 2;
      final p = Offset(
        center.dx + math.cos(a) * radius,
        center.dy + math.sin(a) * radius,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SubtleWirePainter oldDelegate) => false;
}
