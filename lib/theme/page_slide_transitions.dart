import 'package:flutter/material.dart';

/// No animation between routes (no fade or slide).
class InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

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
    TargetPlatform.android: InstantPageTransitionsBuilder(),
    TargetPlatform.iOS: InstantPageTransitionsBuilder(),
    TargetPlatform.macOS: InstantPageTransitionsBuilder(),
    TargetPlatform.linux: InstantPageTransitionsBuilder(),
    TargetPlatform.windows: InstantPageTransitionsBuilder(),
    TargetPlatform.fuchsia: InstantPageTransitionsBuilder(),
  },
);
