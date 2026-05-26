import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/transfer_progress.dart';
import '../services/calendar_import_service.dart';
import 'adaptive_sheet.dart';
import 'done_animation_overlay.dart';
import 'haptic_buttons.dart';
import 'transfer_progress_button.dart';

Future<void> showImportLinkSheet(
  BuildContext context, {
  required ValueChanged<CalendarImportResult> onImported,
}) async {
  final clipboard = await Clipboard.getData('text/plain');
  final clip = clipboard?.text?.trim() ?? '';
  final initialText =
      CalendarImportService.instance.isShareUrl(clip) ? clip : '';

  if (!context.mounted) return;

  await showAdaptiveSheet<void>(
    context,
    builder: (sheetContext) {
      return _ImportLinkSheet(
        initialText: initialText,
        onImported: onImported,
      );
    },
  );
}

String? clipText(String? text) {
  final trimmed = text?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

class _ImportLinkSheet extends StatefulWidget {
  const _ImportLinkSheet({
    required this.initialText,
    required this.onImported,
  });

  final String initialText;
  final ValueChanged<CalendarImportResult> onImported;

  @override
  State<_ImportLinkSheet> createState() => _ImportLinkSheetState();
}

class _ImportLinkSheetState extends State<_ImportLinkSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);
  TransferProgress? _progress;
  var _importing = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = clipText(data?.text);
    if (text == null) {
      setState(() => _errorText = 'Nothing to paste from the clipboard.');
      return;
    }
    _controller.text = text;
    setState(() => _errorText = null);
  }

  Future<void> _importLink() async {
    final link = _controller.text.trim();
    if (!CalendarImportService.instance.isShareUrl(link)) {
      setState(
        () => _errorText = 'Paste a shared day or month link (…/day/… or …/month/…).',
      );
      return;
    }

    setState(() {
      _importing = true;
      _errorText = null;
      _progress = const TransferProgress(fraction: 0, label: 'Downloading…');
    });

    try {
      final result = await CalendarImportService.instance.importFromUrl(
        link,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onImported(result);
      await showDoneAnimation(
        context,
        title: 'Import complete!',
        subtitle: result.importedDays > 1
            ? '${result.importedCount} posts across ${result.importedDays} days.'
            : '${result.importedCount} post${result.importedCount == 1 ? '' : 's'} imported.',
      );
    } on CalendarImportException catch (error) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _progress = null;
        _errorText = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _progress = null;
        _errorText = 'Could not import from that link.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 28 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import shared link',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste a link from another device on the same Wi‑Fi. '
            'It should look like http://192.168.x.x:port/day/2026-05-24',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_importing,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'http://192.168.1.10:54321/day/2026-05-24',
              suffixIcon: HapticIconButton(
                tooltip: 'Paste',
                onPressed: _importing ? null : _pasteFromClipboard,
                icon: Icons.content_paste_outlined,
              ),
            ),
            onSubmitted: _importing ? null : (_) => _importLink(),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          TransferProgressButton(
            progress: _importing ? _progress : null,
            activeLabel: _progress?.label ?? 'Downloading…',
            idleLabel: 'Import posts',
            idleIcon: Icons.download_outlined,
            onPressed: _importing ? null : _importLink,
          ),
        ],
      ),
    );
  }
}
