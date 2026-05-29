import 'package:flutter/material.dart';

/// Multiline field with a bottom drag handle to grow or shrink height.
class ResizableTextField extends StatefulWidget {
  const ResizableTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.minLines = 2,
    this.maxLines = 16,
  });

  final TextEditingController controller;
  final String? hintText;
  final int minLines;
  final int maxLines;

  @override
  State<ResizableTextField> createState() => _ResizableTextFieldState();
}

class _ResizableTextFieldState extends State<ResizableTextField> {
  late int _lines;

  @override
  void initState() {
    super.initState();
    _lines = widget.minLines;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final deltaLines = (details.delta.dy / 22).round();
    if (deltaLines == 0) return;
    final next = (_lines + deltaLines).clamp(widget.minLines, widget.maxLines);
    if (next != _lines) {
      setState(() => _lines = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          maxLines: _lines,
          minLines: _lines,
          decoration: InputDecoration(
            hintText: widget.hintText,
            isDense: true,
          ),
        ),
        GestureDetector(
          onVerticalDragUpdate: _onVerticalDragUpdate,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.drag_handle_rounded, size: 20, color: muted),
                const SizedBox(width: 6),
                Text(
                  'Drag to resize',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
