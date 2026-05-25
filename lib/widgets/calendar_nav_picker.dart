import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/content_entry.dart';
import '../services/plan_service.dart';
import 'haptic_buttons.dart';
import 'paywall_sheet.dart';

Future<void> showCalendarNavPicker(
  BuildContext context, {
  required DateTime initialMonth,
  required Map<String, List<ContentEntry>> entriesByDate,
  required Future<bool> Function(DateTime month) monthAllowed,
  required Future<void> Function(DateTime month) onMonthSelected,
}) {
  final isMobile = MediaQuery.sizeOf(context).width < 720;

  if (isMobile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CalendarNavPickerBody(
        initialMonth: initialMonth,
        entriesByDate: entriesByDate,
        monthAllowed: monthAllowed,
        onMonthSelected: onMonthSelected,
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: _CalendarNavPickerBody(
          initialMonth: initialMonth,
          entriesByDate: entriesByDate,
          monthAllowed: monthAllowed,
          onMonthSelected: onMonthSelected,
        ),
      ),
    ),
  );
}

class _CalendarNavPickerBody extends StatefulWidget {
  const _CalendarNavPickerBody({
    required this.initialMonth,
    required this.entriesByDate,
    required this.monthAllowed,
    required this.onMonthSelected,
  });

  final DateTime initialMonth;
  final Map<String, List<ContentEntry>> entriesByDate;
  final Future<bool> Function(DateTime month) monthAllowed;
  final Future<void> Function(DateTime month) onMonthSelected;

  @override
  State<_CalendarNavPickerBody> createState() => _CalendarNavPickerBodyState();
}

class _CalendarNavPickerBodyState extends State<_CalendarNavPickerBody> {
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  late int _year;
  late int _month;
  var _isPro = true;

  @override
  void initState() {
    super.initState();
    _year = widget.initialMonth.year;
    _month = widget.initialMonth.month;
    PlanService.instance.isPro.then((pro) {
      if (mounted) setState(() => _isPro = pro);
    });
  }

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  bool _hasPosts(DateTime date) {
    final posts = widget.entriesByDate[_dateKey(date)];
    return posts != null && posts.isNotEmpty;
  }

  int _postsInMonth(int year, int month) {
    var count = 0;
    for (final entry in widget.entriesByDate.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      if (int.parse(parts[0]) == year && int.parse(parts[1]) == month) {
        count += entry.value.length;
      }
    }
    return count;
  }

  Future<void> _selectMonth(int month) async {
    final target = DateTime(_year, month);
    if (!await widget.monthAllowed(target)) {
      if (!mounted) return;
      await showPaywallSheet(
        context,
        feature: PlanLimits.freeMonthWindowMessage,
      );
      return;
    }
    setState(() => _month = month);
  }

  Future<void> _selectDay(DateTime date) async {
    final month = DateTime(date.year, date.month);
    if (!await widget.monthAllowed(month)) {
      if (!mounted) return;
      await showPaywallSheet(
        context,
        feature: PlanLimits.freeMonthWindowMessage,
      );
      return;
    }
    await widget.onMonthSelected(month);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _applyMonthOnly() async {
    final target = DateTime(_year, _month);
    if (!await widget.monthAllowed(target)) {
      if (!mounted) return;
      await showPaywallSheet(
        context,
        feature: PlanLimits.freeMonthWindowMessage,
      );
      return;
    }
    await widget.onMonthSelected(target);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(_year, _month));
    final daysInMonth = DateUtils.getDaysInMonth(_year, _month);
    final firstWeekday = DateTime(_year, _month, 1).weekday;
    final leadingEmpty = firstWeekday - 1;
    final today = DateTime.now();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Text(
            'Go to date',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoundOutlinedIconButton(
                onPressed: () => setState(() => _year--),
                icon: Icons.chevron_left,
              ),
              Text(
                '$_year',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              RoundOutlinedIconButton(
                onPressed: () => setState(() => _year++),
                icon: Icons.chevron_right,
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final selected = month == _month;
              final postCount = _postsInMonth(_year, month);
              final label = DateFormat('MMM').format(DateTime(_year, month));
              final allowed =
                  _isPro || PlanLimits.isMonthAllowedForFree(DateTime(_year, month));

              return Material(
                color: selected
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: allowed ? 0.5 : 0.25),
                borderRadius: BorderRadius.circular(12),
                child: HapticInkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _selectMonth(month),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                          color: selected
                              ? theme.colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                      if (postCount > 0)
                        Positioned(
                          top: 6,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            monthLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _weekdays
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: leadingEmpty + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingEmpty) return const SizedBox.shrink();

              final day = index - leadingEmpty + 1;
              final date = DateTime(_year, _month, day);
              final hasPosts = _hasPosts(date);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              return Material(
                color: isToday
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: HapticInkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _selectDay(date),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isToday ? theme.colorScheme.primary : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: hasPosts
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          HapticFilledButton(
            onPressed: _applyMonthOnly,
            child: Text('Go to ${DateFormat('MMMM yyyy').format(DateTime(_year, _month))}'),
          ),
        ],
        ),
      ),
    );
  }
}
