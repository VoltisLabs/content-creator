import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/content_entry.dart';
import '../services/storage_service.dart';
import '../utils/app_haptics.dart';
import '../screens/content_detail_screen.dart';

class CaptionSearchMatch {
  const CaptionSearchMatch({
    required this.date,
    required this.dateKey,
    required this.entry,
  });

  final DateTime date;
  final String dateKey;
  final ContentEntry entry;
}

List<CaptionSearchMatch> searchCaptions(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final storage = StorageService.instance;
  final results = <CaptionSearchMatch>[];

  for (final bucket in storage.entriesByDate.entries) {
    final dateKey = bucket.key;
    final parts = dateKey.split('-');
    if (parts.length != 3) continue;
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );

    for (final entry in bucket.value) {
      if (entry.caption.toLowerCase().contains(q)) {
        results.add(CaptionSearchMatch(date: date, dateKey: dateKey, entry: entry));
      }
    }
  }

  results.sort((a, b) {
    final aT = a.entry.createdAtMillis ?? 0;
    final bT = b.entry.createdAtMillis ?? 0;
    return bT.compareTo(aT);
  });

  return results;
}

Future<void> showCaptionSearch(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _CaptionSearchSheet(),
  );
}

class _CaptionSearchSheet extends StatefulWidget {
  const _CaptionSearchSheet();

  @override
  State<_CaptionSearchSheet> createState() => _CaptionSearchSheetState();
}

class _CaptionSearchSheetState extends State<_CaptionSearchSheet> {
  final _queryController = TextEditingController();
  List<CaptionSearchMatch> _results = [];

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() => _results = searchCaptions(_queryController.text));
  }

  Future<void> _openMatch(CaptionSearchMatch match) async {
    AppHaptics.tap();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push<void>(
      MaterialPageRoute(
        builder: (_) => ContentDetailScreen(
          date: match.date,
          initialEntry: match.entry,
          onEntryChanged: (_) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Material(
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () {
                          AppHaptics.tap();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                      Expanded(
                        child: Text(
                          'Search captions',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _queryController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search any post caption…',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _queryController.text.trim().isEmpty
                                  ? 'Type to search across all days'
                                  : 'No captions match your search',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final match = _results[index];
                            final caption = match.entry.caption.trim();
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                caption.isEmpty ? 'Untitled post' : caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                DateFormat('EEE, MMM d, yyyy')
                                    .format(match.date),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openMatch(match),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
