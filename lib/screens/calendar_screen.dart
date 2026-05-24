import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/content_entry.dart';
import '../services/storage_service.dart';
import '../widgets/calendar_cell.dart';
import 'content_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.onToggleTheme,
  });

  final VoidCallback onToggleTheme;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _storage = StorageService.instance;
  late DateTime _focusedMonth;
  Map<String, ContentEntry> _entries = {};
  double _gridScale = 0.5;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _loadEntries();
  }

  void _loadEntries() {
    setState(() => _entries = Map.from(_storage.entries));
  }

  void _applyEntry(String dateKey, ContentEntry? entry) {
    setState(() {
      if (entry != null) {
        _entries[dateKey] = entry;
      } else {
        _entries.remove(dateKey);
      }
    });
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() => _focusedMonth = DateTime(now.year, now.month));
  }

  List<DateTime?> _buildMonthGrid() {
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final leadingEmpty = firstOfMonth.weekday - 1;

    final cells = <DateTime?>[];
    for (var i = 0; i < leadingEmpty; i++) {
      cells.add(null);
    }
    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(DateTime(_focusedMonth.year, _focusedMonth.month, day));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  Future<void> _openDay(DateTime date) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final result = await Navigator.push<ContentEntry?>(
      context,
      MaterialPageRoute(
        builder: (_) => ContentDetailScreen(
          date: date,
          initialEntry: _entries[dateKey] ?? _storage.getEntry(dateKey),
          onEntryChanged: (entry) => _applyEntry(dateKey, entry),
        ),
      ),
    );
    if (!mounted) return;
    _loadEntries();
    if (result != null) {
      _applyEntry(dateKey, result);
    } else if (_storage.getEntry(dateKey) == null) {
      _applyEntry(dateKey, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_focusedMonth);
    final today = DateTime.now();
    final cells = _buildMonthGrid();
    final filledCount =
        _entries.values.where((e) => _isSameMonth(e.dateKey)).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridSpacing = 4 + (_gridScale * 10);
    final gridAspectRatio = 1.15 - (_gridScale * 0.55);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Content Calendar'),
            Text(
              '$filledCount posts this month',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          ),
          TextButton(
            onPressed: _goToToday,
            child: const Text('Today'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_size_select_small,
                  size: 18,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
                Expanded(
                  child: Slider(
                    value: _gridScale,
                    onChanged: (value) => setState(() => _gridScale = value),
                  ),
                ),
                Icon(
                  Icons.photo_size_select_large,
                  size: 22,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.outlined(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  monthLabel,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                IconButton.outlined(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: _weekdays
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.55),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: gridSpacing,
                  crossAxisSpacing: gridSpacing,
                  childAspectRatio: gridAspectRatio,
                ),
                itemCount: cells.length,
                itemBuilder: (context, index) {
                  final date = cells[index];
                  if (date == null) {
                    return const SizedBox.shrink();
                  }

                  final dateKey = DateFormat('yyyy-MM-dd').format(date);
                  final entry = _entries[dateKey];
                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;

                  return CalendarCell(
                    key: ValueKey('$dateKey-${entry?.coverImagePath ?? ''}'),
                    day: date.day,
                    isCurrentMonth: true,
                    isToday: isToday,
                    coverPath: entry?.coverImagePath,
                    hasContent: entry?.hasContent ?? false,
                    tagCount: entry?.tags.length ?? 0,
                    onTap: () => _openDay(date),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameMonth(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return false;
    return int.parse(parts[0]) == _focusedMonth.year &&
        int.parse(parts[1]) == _focusedMonth.month;
  }
}
