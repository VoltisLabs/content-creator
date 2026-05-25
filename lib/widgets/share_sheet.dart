import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/transfer_progress.dart';
import '../services/calendar_share_service.dart';
import '../services/plan_service.dart';
import '../services/platform_network.dart';
import 'adaptive_sheet.dart';
import 'done_animation_overlay.dart';
import 'paywall_sheet.dart';
import 'transfer_progress_button.dart';

/// Share a single day (used from day detail / post screens).
Future<void> showShareSheet(
  BuildContext context, {
  required DateTime date,
  String? postCaption,
}) async {
  final dateKey = DateFormat('yyyy-MM-dd').format(date);
  if (!context.mounted) return;

  await showAdaptiveSheet<void>(
    context,
    builder: (context) {
      return _DayShareSheetBody(
        dateKey: dateKey,
        postCaption: postCaption,
      );
    },
  );
}

/// Share an entire month (Pro — used from calendar month toolbar).
Future<void> showShareMonthSheet(
  BuildContext context, {
  required DateTime month,
}) async {
  var isPro = await PlanService.instance.isPro;
  if (!context.mounted) return;

  if (!isPro) {
    final upgraded = await showPaywallSheet(
      context,
      feature: 'Share whole months with another device on your Wi‑Fi.',
    );
    if (!upgraded || !context.mounted) return;
    isPro = await PlanService.instance.isPro;
    if (!isPro) return;
  }

  final monthKey = DateFormat('yyyy-MM').format(month);

  await showAdaptiveSheet<void>(
    context,
    builder: (context) {
      return _MonthShareSheetBody(
        monthKey: monthKey,
        month: month,
      );
    },
  );
}

class _DayShareSheetBody extends StatefulWidget {
  const _DayShareSheetBody({
    required this.dateKey,
    this.postCaption,
  });

  final String dateKey;
  final String? postCaption;

  @override
  State<_DayShareSheetBody> createState() => _DayShareSheetBodyState();
}

class _DayShareSheetBodyState extends State<_DayShareSheetBody> {
  TransferProgress? _progress;
  String? _url;
  var _preparing = false;

  @override
  void initState() {
    super.initState();
    _prepareLink();
  }

  Future<void> _prepareLink() async {
    setState(() {
      _preparing = true;
      _progress = null;
      _url = null;
    });

    try {
      await CalendarShareService.instance.prepareShare(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
        estimateBytes: () =>
            CalendarShareService.instance.estimateDayTransferBytes(widget.dateKey),
        label: 'This day',
      );

      final url = await CalendarShareService.instance.shareUrlForDay(widget.dateKey);
      if (!mounted) return;
      setState(() {
        _url = url;
        _preparing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _preparing = false);
    }
  }

  Future<void> _copyLink() async {
    if (_url == null) return;
    await Clipboard.setData(ClipboardData(text: _url!));
    if (!context.mounted) return;
    Navigator.pop(context);
    await showDoneAnimation(
      context,
      title: 'Link copied!',
      subtitle: 'Share this day with another device on your Wi‑Fi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ShareSheetLayout(
      title: 'Share this day',
      subtitle: prefersIpShareHost
          ? 'Copy this link to another phone or computer on the same Wi‑Fi.'
          : 'Anyone on the same Wi‑Fi can import using this link.',
      preparing: _preparing,
      progress: _progress,
      url: _url,
      onCopy: _copyLink,
    );
  }
}

class _MonthShareSheetBody extends StatefulWidget {
  const _MonthShareSheetBody({
    required this.monthKey,
    required this.month,
  });

  final String monthKey;
  final DateTime month;

  @override
  State<_MonthShareSheetBody> createState() => _MonthShareSheetBodyState();
}

class _MonthShareSheetBodyState extends State<_MonthShareSheetBody> {
  TransferProgress? _progress;
  String? _url;
  var _preparing = false;

  @override
  void initState() {
    super.initState();
    _prepareLink();
  }

  Future<void> _prepareLink() async {
    setState(() {
      _preparing = true;
      _progress = null;
      _url = null;
    });

    try {
      await CalendarShareService.instance.prepareShare(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
        estimateBytes: () => CalendarShareService.instance.estimateMonthTransferBytes(
          widget.month.year,
          widget.month.month,
        ),
        label: 'Whole month',
      );

      final url =
          await CalendarShareService.instance.shareUrlForMonth(widget.monthKey);
      if (!mounted) return;
      setState(() {
        _url = url;
        _preparing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _preparing = false);
    }
  }

  Future<void> _copyLink() async {
    if (_url == null) return;
    await Clipboard.setData(ClipboardData(text: _url!));
    if (!context.mounted) return;
    Navigator.pop(context);
    await showDoneAnimation(
      context,
      title: 'Link copied!',
      subtitle: 'Share ${DateFormat('MMMM yyyy').format(widget.month)} with another device on your Wi‑Fi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ShareSheetLayout(
      title: 'Share whole month',
      subtitle: prefersIpShareHost
          ? 'Copy this link to share all posts in ${DateFormat('MMMM yyyy').format(widget.month)}.'
          : 'Anyone on the same Wi‑Fi can import the full month using this link.',
      preparing: _preparing,
      progress: _progress,
      url: _url,
      onCopy: _copyLink,
    );
  }
}

class _ShareSheetLayout extends StatelessWidget {
  const _ShareSheetLayout({
    required this.title,
    required this.subtitle,
    required this.preparing,
    required this.progress,
    required this.url,
    required this.onCopy,
  });

  final String title;
  final String subtitle;
  final bool preparing;
  final TransferProgress? progress;
  final String? url;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          if (preparing)
            TransferProgressButton(
              progress: progress,
              activeLabel: progress?.label ?? 'Preparing',
              idleLabel: 'Preparing…',
            )
          else if (url != null) ...[
            SelectableText(
              url!,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TransferProgressButton(
              progress: null,
              activeLabel: 'Copy link',
              idleLabel: 'Copy link',
              idleIcon: Icons.copy_outlined,
              onPressed: onCopy,
            ),
          ] else
            Text(
              'Could not detect a local network address. Connect to Wi‑Fi and try again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}
