import 'package:flutter/material.dart';

import '../models/transfer_progress.dart';
import '../utils/app_haptics.dart';

class TransferProgressButton extends StatelessWidget {
  const TransferProgressButton({
    super.key,
    required this.progress,
    required this.activeLabel,
    this.idleLabel = 'Start',
    this.idleIcon = Icons.download_outlined,
    this.onPressed,
  });

  final TransferProgress? progress;
  final String activeLabel;
  final String idleLabel;
  final IconData idleIcon;
  final VoidCallback? onPressed;

  bool get isActive => progress != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = progress?.fraction ?? 0;
    final percent = progress?.percent ?? 0;
    final label = isActive ? '$activeLabel $percent%' : idleLabel;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FilledButton(
            onPressed: isActive ? null : AppHaptics.wrap(onPressed),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isActive)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fraction.clamp(0.04, 1),
                        child: ColoredBox(
                          color: theme.colorScheme.onPrimary.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: fraction > 0 ? fraction : null,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        else
                          Icon(idleIcon, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
