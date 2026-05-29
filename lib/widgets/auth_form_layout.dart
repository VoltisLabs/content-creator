import 'package:flutter/material.dart';

/// Pinnacle-style centered auth column (avoids full-width fields on desktop).
class AuthFormLayout extends StatelessWidget {
  const AuthFormLayout({
    super.key,
    required this.child,
    this.maxWidth = 400,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
