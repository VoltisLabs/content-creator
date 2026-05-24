import 'dart:io';

import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

bool get isDesktop {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// Square minimum — resize freely above this; window cannot shrink below 800×800.
const Size desktopMinSize = Size(800, 800);
const Size desktopDefaultSize = Size(960, 960);

Future<void> initDesktopWindow() async {
  if (!isDesktop) return;
  await windowManager.ensureInitialized();
  final options = WindowOptions(
    size: desktopDefaultSize,
    minimumSize: desktopMinSize,
    center: true,
    title: 'Content Calendar',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setMinimumSize(desktopMinSize);
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> setStayOnTop(bool value) async {
  if (!isDesktop) return;
  await windowManager.setAlwaysOnTop(value);
}

Future<void> closeDesktopWindow() async {
  if (!isDesktop) return;
  await windowManager.close();
}
