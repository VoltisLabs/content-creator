import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../theme/calendar_ambient_mode.dart';

/// Small tile preview for settings theme picker (static frame — avoids 26 tickers).
class AmbientThemePreview extends StatelessWidget {
  const AmbientThemePreview({
    super.key,
    required this.mode,
    this.time,
  });

  final CalendarAmbientMode mode;

  /// Optional animation phase; defaults to a stable offset per mode.
  final double? time;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AmbientPainter(
        mode: mode,
        time: time ?? mode.index * 0.65,
        tiltX: 0,
        tiltY: 0,
        palette: mode.palette,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Full-screen animated home backdrop (Bars-style ambient layers).
class CalendarAmbientBackdrop extends StatefulWidget {
  const CalendarAmbientBackdrop({
    super.key,
    required this.mode,
    this.customBackgroundPath,
    this.useCustomPhoto = false,
    required this.child,
  });

  final CalendarAmbientMode mode;
  final String? customBackgroundPath;
  final bool useCustomPhoto;
  final Widget child;

  @override
  State<CalendarAmbientBackdrop> createState() => _CalendarAmbientBackdropState();
}

class _CalendarAmbientBackdropState extends State<CalendarAmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  double _tiltX = 0;
  double _tiltY = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _bindAccelerometer();
  }

  void _bindAccelerometer() {
    _accelerometerSub?.cancel();
    _accelerometerSub = null;
    if (!widget.mode.usesGyro) return;
    _accelerometerSub = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      setState(() {
        _tiltX = (event.x / 12).clamp(-1.0, 1.0);
        _tiltY = (event.y / 12).clamp(-1.0, 1.0);
      });
    });
  }

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CalendarAmbientBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _tiltX = 0;
      _tiltY = 0;
      _bindAccelerometer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.useCustomPhoto && widget.customBackgroundPath != null) ...[
          _CustomPhotoLayer(path: widget.customBackgroundPath!),
        ] else
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _AmbientPainter(
                  mode: widget.mode,
                  time: _controller.value * 18,
                  tiltX: _tiltX,
                  tiltY: _tiltY,
                  palette: widget.mode.palette,
                ),
              );
            },
          ),
        widget.child,
      ],
    );
  }
}

class _CustomPhotoLayer extends StatelessWidget {
  const _CustomPhotoLayer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        Container(color: Colors.black.withValues(alpha: 0.42)),
      ],
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.mode,
    required this.time,
    required this.tiltX,
    required this.tiltY,
    required this.palette,
  });

  final CalendarAmbientMode mode;
  final double time;
  final double tiltX;
  final double tiltY;
  final AmbientPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = palette.base);

    switch (mode) {
      case CalendarAmbientMode.aquatic:
        _paintAquatic(canvas, size);
      case CalendarAmbientMode.auroraDrift:
        _paintAurora(canvas, size, 0.6);
      case CalendarAmbientMode.rainVeil:
        _paintRain(canvas, size, 1.0, 0.55);
      case CalendarAmbientMode.snowfall:
        _paintSnow(canvas, size);
      case CalendarAmbientMode.starfield:
        _paintStarfield(canvas, size);
      case CalendarAmbientMode.emberBloom:
        _paintEmber(canvas, size);
      case CalendarAmbientMode.bokehMist:
        _paintBokeh(canvas, size);
      case CalendarAmbientMode.scanBands:
        _paintScanBands(canvas, size);
      case CalendarAmbientMode.prismShards:
        _paintPrism(canvas, size);
      case CalendarAmbientMode.pixelDrift:
        _paintPixels(canvas, size);
      case CalendarAmbientMode.sunsetGlow:
        _paintSunset(canvas, size);
      case CalendarAmbientMode.neonPulse:
        _paintNeon(canvas, size);
      case CalendarAmbientMode.deepLagoon:
        _paintLagoon(canvas, size);
      case CalendarAmbientMode.forestMist:
        _paintForest(canvas, size);
      case CalendarAmbientMode.cosmicDust:
        _paintCosmic(canvas, size);
      case CalendarAmbientMode.lavaFlow:
        _paintLava(canvas, size);
      case CalendarAmbientMode.northernLights:
        _paintNorthern(canvas, size);
      case CalendarAmbientMode.silkWaves:
        _paintSilk(canvas, size);
      case CalendarAmbientMode.gyroBlocks:
        _paintGyroBlocks(canvas, size);
      case CalendarAmbientMode.meshAurora:
        _paintMesh(canvas, size);
      case CalendarAmbientMode.cherryBlossom:
        _paintCherryBlossom(canvas, size);
      case CalendarAmbientMode.crystalHaze:
        _paintCrystalHaze(canvas, size);
      case CalendarAmbientMode.sandstorm:
        _paintSandstorm(canvas, size);
      case CalendarAmbientMode.electricVeil:
        _paintElectricVeil(canvas, size);
      case CalendarAmbientMode.midnightBloom:
        _paintMidnightBloom(canvas, size);
    }

    canvas.drawRect(
      rect,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
  }

  void _paintAquatic(Canvas canvas, Size size) {
    final wave = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          palette.accent.withValues(alpha: 0.15),
          palette.accent2.withValues(alpha: 0.35),
          palette.glow.withValues(alpha: 0.12),
        ],
      ).createShader(Offset.zero & size);
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.35 + i * 0.18);
      path.moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 12) {
        final dy = math.sin((x / size.width * 4 * math.pi) + time + i) * 14;
        path.lineTo(x, y + dy);
      }
    }
    canvas.drawPath(path, wave..style = PaintingStyle.stroke..strokeWidth = 2.2);

    final bubbleCount = 28;
    for (var i = 0; i < bubbleCount; i++) {
      final bx = _pseudo(i, 3) * size.width;
      final br = 2 + _pseudo(i, 7) * 6;
      final by = size.height - ((time * 40 + _pseudo(i, 11) * size.height) % (size.height + 40));
      canvas.drawCircle(
        Offset(bx, by),
        br,
        Paint()..color = palette.glow.withValues(alpha: 0.2 + _pseudo(i, 13) * 0.25),
      );
    }
  }

  void _paintAurora(Canvas canvas, Size size, double intensity) {
    for (var band = 0; band < 5; band++) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + math.sin(time * 0.3 + band), -1),
          end: Alignment(1, 1),
          colors: [
            palette.accent.withValues(alpha: 0),
            palette.accent2.withValues(alpha: 0.22 * intensity),
            palette.glow.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size);
      final path = Path()
        ..moveTo(0, size.height * (0.2 + band * 0.12))
        ..quadraticBezierTo(
          size.width * 0.5,
          size.height * (0.15 + band * 0.1 + math.sin(time + band) * 0.05),
          size.width,
          size.height * (0.35 + band * 0.08),
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _paintRain(Canvas canvas, Size size, double density, double thin) {
    final count = (70 * density).round();
    final paint = Paint()
      ..color = palette.accent.withValues(alpha: 0.25)
      ..strokeWidth = thin
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final x = _pseudo(i, 2) * size.width;
      final len = 10 + _pseudo(i, 5) * 22;
      final speed = 200 + _pseudo(i, 8) * 300;
      final y = ((time * speed + _pseudo(i, 9) * size.height) % (size.height + len)) - len;
      canvas.drawLine(Offset(x, y), Offset(x + 1.2, y + len), paint);
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    for (var i = 0; i < 80; i++) {
      final x = _pseudo(i, 4) * size.width + math.sin(time + i) * 6;
      final r = 0.8 + _pseudo(i, 6) * 2;
      final y = ((time * 35 + _pseudo(i, 10) * size.height) % (size.height + 12)) - 8;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = palette.glow.withValues(alpha: 0.15 + _pseudo(i, 12) * 0.4),
      );
    }
  }

  void _paintStarfield(Canvas canvas, Size size) {
    for (var i = 0; i < 120; i++) {
      final x = _pseudo(i, 1) * size.width;
      final y = _pseudo(i, 2) * size.height;
      final twinkle = 0.3 + 0.7 * ((math.sin(time * 2 + i) + 1) / 2);
      canvas.drawCircle(
        Offset(x, y),
        0.6 + _pseudo(i, 3),
        Paint()..color = palette.glow.withValues(alpha: twinkle * 0.7),
      );
    }
  }

  void _paintEmber(Canvas canvas, Size size) {
    for (var i = 0; i < 45; i++) {
      final x = _pseudo(i, 14) * size.width;
      final y = size.height - ((time * 25 + _pseudo(i, 15) * size.height) % (size.height + 30));
      canvas.drawCircle(
        Offset(x + math.sin(time + i) * 8, y),
        2 + _pseudo(i, 16) * 4,
        Paint()..color = palette.accent.withValues(alpha: 0.35),
      );
    }
    _paintAurora(canvas, size, 0.35);
  }

  void _paintBokeh(Canvas canvas, Size size) {
    for (var i = 0; i < 18; i++) {
      final drift = math.sin(time * 0.7 + i * 1.3) * 12;
      final x = _pseudo(i, 20) * size.width + drift;
      final y = _pseudo(i, 21) * size.height + math.cos(time * 0.5 + i) * 10;
      final r = 20 + _pseudo(i, 22) * 50 + math.sin(time + i) * 6;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = palette.accent.withValues(alpha: 0.06 + _pseudo(i, 23) * 0.1),
      );
    }
  }

  void _paintScanBands(Canvas canvas, Size size) {
    for (var i = 0; i < 8; i++) {
      final y = ((time * 60 + i * 40) % (size.height + 60)) - 30;
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 18),
        Paint()..color = palette.accent.withValues(alpha: 0.08),
      );
    }
  }

  void _paintPrism(Canvas canvas, Size size) {
    for (var i = 0; i < 24; i++) {
      final cx = _pseudo(i, 30) * size.width;
      final cy = _pseudo(i, 31) * size.height;
      final angle = time * 0.4 + i * 0.5;
      final path = Path()
        ..moveTo(cx + math.sin(angle) * 20, cy - math.cos(angle) * 20)
        ..lineTo(cx + math.cos(angle) * 16, cy + math.sin(angle) * 14)
        ..lineTo(cx - math.cos(angle) * 16, cy + math.sin(angle) * 14)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(palette.accent, palette.accent2, _pseudo(i, 32))!
              .withValues(alpha: 0.1 + math.sin(time * 2 + i) * 0.06),
      );
    }
  }

  void _paintPixels(Canvas canvas, Size size) {
    final cols = (size.width / 16).ceil();
    final rows = (size.height / 16).ceil();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (((c + r + (time * 8).floor()) % 5) != 0) continue;
        canvas.drawRect(
          Rect.fromLTWH(c * 16.0, r * 16.0, 8, 8),
          Paint()
            ..color = Color.lerp(palette.accent, palette.accent2, _pseudo(c + r, 40))!
                .withValues(alpha: 0.2),
        );
      }
    }
  }

  void _paintSunset(Canvas canvas, Size size) => _paintAurora(canvas, size, 0.85);

  void _paintNeon(Canvas canvas, Size size) {
    _paintMesh(canvas, size);
    _paintScanBands(canvas, size);
  }

  void _paintLagoon(Canvas canvas, Size size) => _paintAquatic(canvas, size);

  void _paintForest(Canvas canvas, Size size) {
    _paintBokeh(canvas, size);
    for (var i = 0; i < 12; i++) {
      final sway = math.sin(time * 1.2 + i) * 6;
      final x = size.width * (i / 12) + sway;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height * 0.55, 8, size.height * 0.45),
        Paint()..color = palette.accent.withValues(alpha: 0.12 + math.sin(time + i) * 0.05),
      );
    }
  }

  void _paintCosmic(Canvas canvas, Size size) {
    _paintStarfield(canvas, size);
    _paintBokeh(canvas, size);
  }

  void _paintLava(Canvas canvas, Size size) {
    _paintEmber(canvas, size);
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(0, 0.6 + math.sin(time) * 0.1),
        radius: 1.2,
        colors: [
          palette.accent.withValues(alpha: 0.35),
          palette.base,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintNorthern(Canvas canvas, Size size) {
    _paintAurora(canvas, size, 1.0);
    _paintSnow(canvas, size);
  }

  void _paintSilk(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      path.moveTo(0, size.height * (0.2 + i * 0.12));
      for (var x = 0.0; x <= size.width; x += 8) {
        path.lineTo(
          x,
          size.height * (0.25 + i * 0.1) +
              math.sin((x / size.width * 3 * math.pi) + time * 0.8 + i) * 18,
        );
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = palette.glow.withValues(alpha: 0.2),
    );
  }

  void _paintGyroBlocks(Canvas canvas, Size size) {
    const cols = 6;
    const rows = 8;
    final blockW = size.width / cols;
    final blockH = size.height / rows;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final offset = Offset(
          c * blockW + tiltX * 18,
          r * blockH + tiltY * 22 + math.sin(time + c + r) * 4,
        );
        final color = Color.lerp(
          palette.accent,
          palette.accent2,
          _pseudo(c + r, 50),
        )!;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            offset & Size(blockW - 6, blockH - 6),
            const Radius.circular(6),
          ),
          Paint()..color = color.withValues(alpha: 0.35),
        );
      }
    }
  }

  void _paintMesh(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(math.cos(time * 1.2), -1),
        end: Alignment(math.sin(time * 1.2), 1),
        colors: [
          palette.accent.withValues(alpha: 0.3),
          palette.accent2.withValues(alpha: 0.25),
          palette.glow.withValues(alpha: 0.2),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    _paintAurora(canvas, size, 0.55);
  }

  void _paintCherryBlossom(Canvas canvas, Size size) {
    for (var i = 0; i < 55; i++) {
      final x = _pseudo(i, 60) * size.width + math.sin(time * 0.8 + i) * 20;
      final y = ((time * 28 + _pseudo(i, 61) * size.height) % (size.height + 20)) - 10;
      canvas.drawCircle(
        Offset(x, y),
        2.5 + _pseudo(i, 62) * 3,
        Paint()..color = palette.accent.withValues(alpha: 0.35 + _pseudo(i, 63) * 0.25),
      );
    }
    _paintSilk(canvas, size);
  }

  void _paintCrystalHaze(Canvas canvas, Size size) {
    for (var i = 0; i < 40; i++) {
      final x = _pseudo(i, 70) * size.width;
      final y = _pseudo(i, 71) * size.height;
      final pulse = 0.5 + 0.5 * math.sin(time * 2.5 + i);
      canvas.drawCircle(
        Offset(x + math.sin(time + i) * 8, y),
        3 + pulse * 5,
        Paint()..color = palette.glow.withValues(alpha: 0.08 + pulse * 0.15),
      );
    }
    _paintAurora(canvas, size, 0.5);
  }

  void _paintSandstorm(Canvas canvas, Size size) {
    for (var i = 0; i < 90; i++) {
      final x = _pseudo(i, 80) * size.width;
      final len = 6 + _pseudo(i, 81) * 14;
      final y = ((time * 120 + _pseudo(i, 82) * size.height) % (size.height + len)) - len;
      canvas.drawLine(
        Offset(x + math.sin(time + i) * 12, y),
        Offset(x + len, y + 2),
        Paint()
          ..color = palette.accent.withValues(alpha: 0.2)
          ..strokeWidth = 1.2,
      );
    }
    final haze = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.2 + math.sin(time * 0.3) * 0.2, 0.3),
        radius: 1.1,
        colors: [
          palette.glow.withValues(alpha: 0.18),
          palette.base,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, haze);
  }

  void _paintElectricVeil(Canvas canvas, Size size) {
    _paintNeon(canvas, size);
    for (var i = 0; i < 6; i++) {
      final path = Path();
      final baseY = size.height * (0.15 + i * 0.14);
      path.moveTo(0, baseY);
      for (var x = 0.0; x <= size.width; x += 14) {
        path.lineTo(
          x,
          baseY + math.sin((x / size.width * 8 * math.pi) + time * 3 + i) * 10,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = palette.glow.withValues(alpha: 0.25),
      );
    }
  }

  void _paintMidnightBloom(Canvas canvas, Size size) {
    _paintStarfield(canvas, size);
    _paintBokeh(canvas, size);
    _paintAurora(canvas, size, 0.75);
    for (var i = 0; i < 20; i++) {
      final x = size.width * 0.5 + math.sin(time * 0.6 + i) * size.width * 0.35;
      final y = size.height * 0.4 + math.cos(time * 0.5 + i * 0.7) * size.height * 0.2;
      canvas.drawCircle(
        Offset(x, y),
        30 + math.sin(time + i) * 12,
        Paint()..color = palette.accent.withValues(alpha: 0.06),
      );
    }
  }

  double _pseudo(int seed, int salt) {
    final v = math.sin(seed * 12.9898 + salt * 78.233 + 1.0) * 43758.5453;
    return v - v.floor();
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.mode != mode ||
      oldDelegate.time != time ||
      oldDelegate.tiltX != tiltX ||
      oldDelegate.tiltY != tiltY;
}
