import 'dart:io';

import 'package:image/image.dart';

/// Builds a multi-size Windows .ico for crisp taskbar/title-bar icons.
void main() {
  const pngPath = 'assets/icons/app_icon_windows.png';
  const icoPath = 'windows/runner/resources/app_icon.ico';
  const sizes = [16, 32, 48, 64, 128, 256];

  final pngBytes = File(pngPath).readAsBytesSync();
  final decoded = decodeImage(pngBytes);
  if (decoded == null) {
    stderr.writeln('Could not decode $pngPath');
    exit(1);
  }

  final images = [
    for (final size in sizes)
      copyResize(
        decoded,
        width: size,
        height: size,
        interpolation: Interpolation.average,
      ),
  ];

  final base = images.last;
  base.frames = images;

  File(icoPath).writeAsBytesSync(encodeIco(base));
  stdout.writeln('Wrote ${images.length} icon sizes to $icoPath');
}
