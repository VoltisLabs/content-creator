/// System SF Pro on Apple platforms; same family name + fallbacks elsewhere.
abstract final class UiFonts {
  static const String family = '.SF Pro Text';

  static const List<String> fallback = [
    'SF Pro Text',
    'SF Pro Display',
    '.SF Pro Text',
    '.SF Pro Display',
    'Segoe UI',
    'Helvetica Neue',
    'sans-serif',
  ];
}
