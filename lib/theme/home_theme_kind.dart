/// How the calendar home screen is themed — palette and live are mutually exclusive.
enum HomeThemeKind {
  /// Classic or gradient [AppThemePreset] colours on the calendar (no animated backdrop).
  palette,

  /// Animated [CalendarAmbientMode] backdrop with neutral UI chrome.
  live,
}
