import 'package:flutter/material.dart';

bool useDialogSheet(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 720;

Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context) builder,
  bool isScrollControlled = true,
  double dialogMaxWidth = 440,
  double? dialogMaxHeight,
}) {
  if (useDialogSheet(context)) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogMaxWidth,
            maxHeight: dialogMaxHeight ?? 620,
          ),
          child: builder(context),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: true,
    builder: builder,
  );
}
