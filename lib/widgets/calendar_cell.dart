import 'dart:io';

import 'package:flutter/material.dart';

class CalendarCell extends StatelessWidget {
  const CalendarCell({
    super.key,
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
    required this.coverPath,
    required this.hasContent,
    required this.tagCount,
    required this.onTap,
  });

  final int? day;
  final bool isCurrentMonth;
  final bool isToday;
  final String? coverPath;
  final bool hasContent;
  final int tagCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (day == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isToday
        ? theme.colorScheme.primary
        : hasContent
            ? theme.colorScheme.primary.withValues(alpha: 0.35)
            : theme.colorScheme.outline.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: isToday ? 2 : 1,
            ),
            color: isCurrentMonth
                ? theme.cardTheme.color ?? theme.colorScheme.surface
                : theme.colorScheme.surfaceContainerHighest,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverPath != null)
                  Image.file(
                    File(coverPath!),
                    key: ValueKey(coverPath),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholder(theme),
                  )
                else if (hasContent)
                  _placeholder(theme)
                else
                  const SizedBox.shrink(),
                if (coverPath != null || hasContent)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: isDark ? 0.65 : 0.55),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$day',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (hasContent && tagCount > 0)
                            Icon(
                              Icons.local_offer_outlined,
                              size: 14,
                              color: coverPath != null
                                  ? Colors.white70
                                  : theme.colorScheme.primary,
                            ),
                        ],
                      ),
                      const Spacer(),
                      if (hasContent && coverPath == null)
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Icon(
                            Icons.edit_note,
                            size: 18,
                            color: theme.colorScheme.primary.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
          ],
        ),
      ),
    );
  }
}
