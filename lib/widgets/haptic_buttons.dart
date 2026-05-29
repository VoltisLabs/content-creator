import 'package:flutter/material.dart';

import '../utils/app_haptics.dart';

/// Outlined circular icon button — matches month navigation controls.
class RoundOutlinedIconButton extends StatelessWidget {
  const RoundOutlinedIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: AppHaptics.wrap(onPressed),
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
        minimumSize: const Size(40, 40),
        backgroundColor: selected
            ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.28 : 0.14)
            : null,
        foregroundColor: selected ? theme.colorScheme.primary : null,
      ),
      icon: Icon(icon),
    );
  }
}

/// Standard icon button with haptic feedback.
class HapticIconButton extends StatelessWidget {
  const HapticIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.style,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: AppHaptics.wrap(onPressed),
      style: style,
      icon: Icon(icon),
    );
  }
}

/// Text button with haptic feedback.
class HapticTextButton extends StatelessWidget {
  const HapticTextButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: AppHaptics.wrap(onPressed),
      child: child,
    );
  }
}

/// Filled button with haptic feedback.
class HapticFilledButton extends StatelessWidget {
  const HapticFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return FilledButton.icon(
        onPressed: AppHaptics.wrap(onPressed),
        icon: icon!,
        label: child,
      );
    }
    return FilledButton(
      onPressed: AppHaptics.wrap(onPressed),
      child: child,
    );
  }
}

/// InkWell wrapper that fires haptic on tap.
class HapticInkWell extends StatelessWidget {
  const HapticInkWell({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius,
  });

  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap == null
          ? null
          : () {
              AppHaptics.tap();
              onTap!();
            },
      child: child,
    );
  }
}
