import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/content_entry.dart';
import '../services/calendar_import_service.dart';
import '../services/app_preferences.dart';
import '../services/plan_service.dart';
import '../services/slider_sound.dart';
import '../utils/app_haptics.dart';
import '../services/storage_service.dart';
import '../theme/app_theme_preset.dart';
import '../theme/calendar_ambient_mode.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/calendar_nav_picker.dart';
import '../widgets/calendar_cell.dart';
import '../widgets/haptic_buttons.dart';
import '../widgets/caption_search_sheet.dart';
import '../widgets/import_link_sheet.dart';
import '../widgets/mobile_calendar_dock.dart';
import '../widgets/share_sheet.dart';
import '../data/demo_content_data.dart';
import 'day_posts_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    this.screenTitle = 'Content Calendar',
    required this.preset,
    required this.usesLiveHomeTheme,
    required this.violetDarkMode,
    required this.onToggleVioletBrightness,
    required this.onPresetChanged,
    required this.ambientMode,
    required this.onAmbientChanged,
    required this.stayOnTop,
    required this.onStayOnTopChanged,
    required this.onOpenSettings,
    this.demoMode = false,
    this.onEnterDemoContent,
    this.onExitDemoContent,
  });

  final String screenTitle;
  final AppThemePreset preset;
  final bool usesLiveHomeTheme;
  final bool violetDarkMode;
  final VoidCallback onToggleVioletBrightness;
  final ValueChanged<AppThemePreset> onPresetChanged;
  final CalendarAmbientMode ambientMode;
  final ValueChanged<CalendarAmbientMode> onAmbientChanged;
  final bool stayOnTop;
  final ValueChanged<bool> onStayOnTopChanged;
  final VoidCallback onOpenSettings;
  final bool demoMode;
  final VoidCallback? onEnterDemoContent;
  final VoidCallback? onExitDemoContent;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with WidgetsBindingObserver {
  final _storage = StorageService.instance;
  late DateTime _focusedMonth;
  Map<String, List<ContentEntry>> _entriesByDate = {};
  double _gridScale = AppPreferences.defaultGridScale;
  bool _showMobileSlider = false;
  bool _isPro = false;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _loadEntries();
    _loadGridScale();
    _refreshPlanState();
  }

  Future<void> _refreshPlanState() async {
    final isPro = await PlanService.instance.isPro;
    if (!mounted) return;
    setState(() => _isPro = isPro);
  }

  Future<void> _loadGridScale() async {
    final scale = await AppPreferences.gridScale();
    if (!mounted) return;
    setState(() => _gridScale = scale);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.demoMode != widget.demoMode) {
      _loadEntries();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.demoMode) {
        _loadEntries();
      } else {
        _reloadEntries();
      }
      unawaited(_refreshPlanState());
    }
  }

  Future<void> _reloadEntries() async {
    await _storage.reloadFromDisk();
    if (!mounted) return;
    _loadEntries();
  }

  void _loadEntries() {
    if (widget.demoMode) {
      final month = DemoContentData.currentMonth;
      setState(() {
        _focusedMonth = month;
        _entriesByDate = DemoContentData.entriesForMonth(month);
      });
      return;
    }
    setState(() => _entriesByDate = Map.from(_storage.entriesByDate));
  }

  Future<bool> _ensureMonthAllowed(DateTime month) async {
    if (await PlanService.instance.isPro) return true;
    if (PlanLimits.isMonthAllowedForFree(month)) return true;
    if (!mounted) return false;
    await showPaywallSheet(
      context,
      feature: PlanLimits.freeMonthWindowMessage,
    );
    return false;
  }

  Future<void> _previousMonth() async {
    if (widget.demoMode) return;
    final target = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    if (!await _ensureMonthAllowed(target)) return;
    setState(() => _focusedMonth = target);
  }

  Future<void> _nextMonth() async {
    if (widget.demoMode) return;
    final target = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    if (!await _ensureMonthAllowed(target)) return;
    setState(() => _focusedMonth = target);
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() => _focusedMonth = DateTime(now.year, now.month));
  }

  Future<void> _openMonthPicker() {
    return showCalendarNavPicker(
      context,
      initialMonth: _focusedMonth,
      entriesByDate: _entriesByDate,
      monthAllowed: (month) async {
        if (await PlanService.instance.isPro) return true;
        return PlanLimits.isMonthAllowedForFree(month);
      },
      onMonthSelected: (month) async {
        if (!await _ensureMonthAllowed(month)) return;
        setState(() => _focusedMonth = month);
      },
    );
  }

  void _openSettings() => widget.onOpenSettings();

  void _shareMonth() {
    showShareMonthSheet(
      context,
      month: _focusedMonth,
    );
  }

  Widget _settingsButton() {
    return HapticIconButton(
      tooltip: 'Settings',
      onPressed: _openSettings,
      icon: Icons.settings_rounded,
    );
  }

  bool get _isDesktopLayout => MediaQuery.sizeOf(context).width >= 720;

  void _onGridScaleChanged(double value) {
    final desktop = _isDesktopLayout;
    final previousColumns = columnCountForScale(_gridScale, desktop: desktop);
    final nextColumns = columnCountForScale(value, desktop: desktop);
    setState(() => _gridScale = value);
    unawaited(AppPreferences.setGridScale(value));
    if (previousColumns != nextColumns) {
      SliderSound.playColumnStep();
    }
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
    final demoPosts = widget.demoMode
        ? List<ContentEntry>.from(_entriesByDate[dateKey] ?? const [])
        : null;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DayPostsScreen(
          date: date,
          onChanged: _loadEntries,
          postsOverride: demoPosts,
          readOnly: widget.demoMode,
        ),
      ),
    );
    if (!mounted || widget.demoMode) return;
    _loadEntries();
  }

  int _postCountThisMonth() {
    var count = 0;
    for (final entry in _entriesByDate.entries) {
      if (_isSameMonth(entry.key)) {
        count += entry.value.length;
      }
    }
    return count;
  }

  ContentEntry? _primaryPost(List<ContentEntry> posts) {
    if (posts.isEmpty) return null;
    for (final post in posts) {
      if (post.coverImagePath != null) return post;
    }
    return posts.first;
  }

  void _handleImportedResult(CalendarImportResult result) {
    _loadEntries();
    final dateKey = result.dateKey;
    final parts = dateKey.split('-');
    if (parts.length == 3) {
      setState(() {
        _focusedMonth = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      });
    } else if (parts.length == 2) {
      setState(() {
        _focusedMonth = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      });
    }

    if (!mounted) return;

    if (result.importedDays == 1 && parts.length == 3) {
      final day = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.importedCount} post${result.importedCount == 1 ? '' : 's'} for ${DateFormat('MMM d, yyyy').format(day)}',
          ),
        ),
      );
      unawaited(_openDay(day));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.importedDays > 1
              ? 'Imported ${result.importedCount} posts across ${result.importedDays} days.'
              : 'Imported posts for ${DateFormat('MMM d, yyyy').format(DateTime.parse(dateKey))}',
        ),
      ),
    );
  }

  bool get _isMobile => MediaQuery.sizeOf(context).width < 720;

  double _gridSpacing() => 4 + (_gridScale * 10);

  int _columnCount(double availableWidth) =>
      columnCountForScale(_gridScale, desktop: _isDesktopLayout);

  double _cellWidth(double availableWidth, int columns) {
    final spacing = _gridSpacing();
    return (availableWidth - spacing * (columns - 1)) / columns;
  }

  double _cellHeight(double cellWidth) =>
      cellWidth * (1.1 - (_gridScale * 0.25));

  int get _layoutColumnCount =>
      columnCountForScale(_gridScale, desktop: _isDesktopLayout);

  /// Mon–Sun row only when cells are smallest (7 columns); hidden when day shows in-cell.
  bool get _showWeekdayHeader => _layoutColumnCount >= 7;

  List<DateTime?> _cellsForLayout(int columns) {
    if (columns >= 7) return _buildMonthGrid();

    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    return [
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(_focusedMonth.year, _focusedMonth.month, day),
    ];
  }

  Widget _buildCalendarCell(DateTime date, DateTime today) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final posts = _entriesByDate[dateKey] ?? const [];
    final primary = _primaryPost(posts);
    final tagCount = posts.fold<int>(
      0,
      (sum, post) => sum + post.tags.length,
    );
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    final showWeekdayInCell = _layoutColumnCount < 7;

    return CalendarCell(
      key: ValueKey('$dateKey-${primary?.coverImagePath ?? ''}-${posts.length}'),
      preset: widget.preset,
      day: date.day,
      isCurrentMonth: true,
      isToday: isToday,
      coverPath: primary?.coverImagePath,
      hasContent: posts.isNotEmpty,
      postCount: posts.length,
      tagCount: tagCount,
      weekdayLabel: DateFormat('EEE').format(date),
      showWeekdayLabel: showWeekdayInCell,
      onTap: () => _openDay(date),
    );
  }

  Widget _buildThumbnailSizeSlider(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Row(
      children: [
        Icon(Icons.photo_size_select_small, size: 18, color: muted),
        Expanded(
          child: Slider(
            value: _gridScale,
            onChanged: _onGridScaleChanged,
          ),
        ),
        Icon(Icons.photo_size_select_large, size: 22, color: muted),
      ],
    );
  }

  Widget _buildFluidGrid(List<DateTime?> cells, DateTime today) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columns = _columnCount(availableWidth);
        final gridSpacing = _gridSpacing();
        final cellWidth = _cellWidth(availableWidth, columns);
        final cellHeight = _cellHeight(cellWidth);
        final layoutCells = _cellsForLayout(columns);

        final dockInset = _isMobile ? MobileCalendarDock.dockHeight + 32 : 0.0;

        return GridView.builder(
          padding: EdgeInsets.only(bottom: dockInset),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gridSpacing,
            crossAxisSpacing: gridSpacing,
            mainAxisExtent: cellHeight,
          ),
          itemCount: layoutCells.length,
          itemBuilder: (context, index) {
            final date = layoutCells[index];
            if (date == null) {
              return const SizedBox.shrink();
            }
            return _buildCalendarCell(date, today);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_focusedMonth);
    final today = DateTime.now();
    final cells = _buildMonthGrid();
    final postCount = _postCountThisMonth();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyPadding = 40.0;
    final showWeekdays = _showWeekdayHeader;
    final isMobile = _isMobile;

    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: isMobile ? 22 : null,
          height: 1.15,
        );

    final useOpaqueBackground =
        !widget.usesLiveHomeTheme && !widget.preset.isGradient;

    return Scaffold(
      backgroundColor: useOpaqueBackground
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.transparent,
      extendBody: isMobile && !useOpaqueBackground,
      appBar: AppBar(
        titleSpacing: isMobile ? 20 : null,
        title: Text(
          widget.screenTitle,
          style: titleStyle,
        ),
        actions: [
          if (!isMobile) ...[
            SizedBox(
              width: 168,
              child: _buildThumbnailSizeSlider(context),
            ),
            HapticIconButton(
              tooltip: 'Import shared link',
              onPressed: () => showImportLinkSheet(
                context,
                onImported: _handleImportedResult,
              ),
              icon: Icons.add_link_rounded,
            ),
            if (widget.preset == AppThemePreset.violet)
              HapticIconButton(
                tooltip: isDark ? 'Violet light' : 'Violet dark',
                onPressed: widget.onToggleVioletBrightness,
                icon: isDark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
              ),
          ],
          if (!isMobile) _settingsButton(),
          if (!widget.demoMode && !isMobile)
            HapticIconButton(
              tooltip: 'Search captions',
              onPressed: () => showCaptionSearch(context),
              icon: Icons.search_rounded,
            ),
          if (!isMobile) ...[
            if (!widget.demoMode && widget.onEnterDemoContent != null)
              HapticTextButton(
                onPressed: widget.onEnterDemoContent,
                child: const Text('Demo Content'),
              ),
            if (widget.demoMode && widget.onExitDemoContent != null)
              HapticTextButton(
                onPressed: widget.onExitDemoContent,
                child: const Text('Calendar'),
              ),
          ],
          HapticTextButton(
            onPressed: _goToToday,
            child: const Text('Today'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RoundOutlinedIconButton(
                      onPressed: widget.demoMode ? null : _previousMonth,
                      icon: Icons.chevron_left,
                    ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: HapticInkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: widget.demoMode ? null : _openMonthPicker,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: [
                                Text(
                                  monthLabel,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$postCount posts this month',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.55),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isMobile) ...[
                          RoundOutlinedIconButton(
                            tooltip: 'Share this month',
                            onPressed: _shareMonth,
                            icon: Icons.share_rounded,
                          ),
                          const SizedBox(width: 8),
                        ],
                        RoundOutlinedIconButton(
                          onPressed: widget.demoMode ? null : _nextMonth,
                          icon: Icons.chevron_right,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (showWeekdays) ...[
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
                ],
                Expanded(
                  child: _buildFluidGrid(cells, today),
                ),
              ],
            ),
          ),
          if (isMobile)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: MobileCalendarDock(
                  showSlider: _showMobileSlider,
                  onToggleSlider: () {
                    AppHaptics.tap();
                    setState(() => _showMobileSlider = !_showMobileSlider);
                  },
                  gridScale: _gridScale,
                  onGridScaleChanged: _onGridScaleChanged,
                  demoMode: widget.demoMode,
                  onToggleDemo: widget.demoMode
                      ? widget.onExitDemoContent
                      : widget.onEnterDemoContent,
                  onShareMonth: _shareMonth,
                  onOpenSettings: _openSettings,
                  showProBadgeOnShare: !widget.demoMode && !_isPro,
                  onImportLink: () {
                    AppHaptics.tap();
                    showImportLinkSheet(
                      context,
                      onImported: _handleImportedResult,
                    );
                  },
                  showThemeToggle:
                      !widget.demoMode && widget.preset == AppThemePreset.violet,
                  isDarkTheme: isDark,
                  onToggleTheme: widget.onToggleVioletBrightness,
                ),
              ),
            ),
        ],
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
