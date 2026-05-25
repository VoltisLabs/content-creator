import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Copied from Bars `voltis_splash_screen.dart` — same timing and motion.
enum _SplashPhase { hidden, mainVisible, allVisible, exiting }

class VoltisSplashScreen extends StatefulWidget {
  const VoltisSplashScreen({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<VoltisSplashScreen> createState() => _VoltisSplashScreenState();
}

class _VoltisSplashScreenState extends State<VoltisSplashScreen> {
  /// Survives parent [setState] (e.g. theme changes) so the home screen never re-splashes to blank.
  static bool _splashCompletedGlobally = false;

  _SplashPhase _phase = _SplashPhase.hidden;
  bool _footerVisible = false;
  bool _finished = false;
  final List<Timer> _timers = [];

  static const _mainInMs = 600;
  static const _holdMs = 1200;
  static const _outMs = 500;

  /// Square app mark (Bars uses ~2.5:1 Voltis wordmark).
  static const double _logoAspect = 1;

  @override
  void initState() {
    super.initState();
    if (_splashCompletedGlobally) {
      _finished = true;
      return;
    }
    _startAnimation();
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _schedule(Duration delay, VoidCallback cb) {
    _timers.add(Timer(delay, () {
      if (!mounted) return;
      cb();
    }));
  }

  void _startAnimation() {
    setState(() => _phase = _SplashPhase.mainVisible);

    _schedule(
      const Duration(milliseconds: _mainInMs),
      () => setState(() => _phase = _SplashPhase.allVisible),
    );

    const allInDone = _mainInMs;
    _schedule(
      const Duration(milliseconds: allInDone),
      () => setState(() => _footerVisible = true),
    );

    final totalBeforeExit = allInDone + _holdMs;
    _schedule(
      Duration(milliseconds: totalBeforeExit),
      () => setState(() {
        _phase = _SplashPhase.exiting;
        _footerVisible = false;
      }),
    );
    _schedule(
      Duration(milliseconds: totalBeforeExit + _outMs),
      () {
        _splashCompletedGlobally = true;
        setState(() => _finished = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return SizedBox.expand(child: widget.child);
    }

    final media = MediaQuery.of(context);
    final isDark = media.platformBrightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final logoAsset = isDark
        ? 'assets/branding/content_calendar_logo.svg'
        : 'assets/branding/content_calendar_logo.svg';
    final footerColor = isDark ? Colors.white70 : Colors.black54;

    final mainOpacity = switch (_phase) {
      _SplashPhase.hidden => 0.0,
      _SplashPhase.mainVisible || _SplashPhase.allVisible => 1.0,
      _SplashPhase.exiting => 0.0,
    };
    final scale = _phase == _SplashPhase.exiting ? 1.04 : 1.0;

    final maxLogoW = math
        .min(media.size.width - 48, 220)
        .clamp(120.0, media.size.width)
        .toDouble();
    final logoH = maxLogoW / _logoAspect;

    return Scaffold(
      backgroundColor: bg,
      body: SizedBox.expand(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              AnimatedScale(
                duration: const Duration(milliseconds: _mainInMs),
                curve: Curves.easeInOut,
                scale: _phase == _SplashPhase.hidden ? 0.92 : scale,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: _mainInMs),
                  opacity: mainOpacity,
                  child: Center(
                    child: SvgPicture.asset(
                      logoAsset,
                      width: maxLogoW,
                      height: logoH,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                duration: const Duration(milliseconds: _mainInMs),
                opacity: _footerVisible ? 1 : 0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: _mainInMs),
                  scale: _footerVisible ? 1 : 0.92,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 26),
                    child: Text(
                      'Created by Voltis Labs',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: footerColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
