import 'package:flutter/material.dart';

/// Horizontal slide for all [MaterialPageRoute] pushes (no fade-through).
class SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      ),
    );
    return SlideTransition(position: slide, child: child);
  }
}

const slidePageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: SlidePageTransitionsBuilder(),
    TargetPlatform.iOS: SlidePageTransitionsBuilder(),
    TargetPlatform.macOS: SlidePageTransitionsBuilder(),
    TargetPlatform.linux: SlidePageTransitionsBuilder(),
    TargetPlatform.windows: SlidePageTransitionsBuilder(),
    TargetPlatform.fuchsia: SlidePageTransitionsBuilder(),
  },
);
