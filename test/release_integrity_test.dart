import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mirrors [scripts/verify-release-readiness.py] so CI and `flutter test` catch regressions.
void main() {
  final root = Directory.current;

  String read(String rel) {
    final file = File('${root.path}/$rel');
    expect(file.existsSync(), isTrue, reason: 'Missing $rel');
    return file.readAsStringSync();
  }

  test('Voltis Core wiring is present in main.dart', () {
    final mainDart = read('lib/main.dart');
    expect(mainDart, contains('AuthGate'));
    expect(mainDart, contains('VoltisCoreService'));
    expect(mainDart, contains('AppSettingsScope'));
    expect(mainDart, isNot(contains('CustomBackgroundService')));
  });

  test('Settings uses Voltis Core plans, not removed features', () {
    final settings = read('lib/widgets/settings_sheet.dart');
    expect(settings, contains('SettingsPlansPage'));
    expect(settings, contains('SettingsAccountPage'));
    expect(settings, contains('onOpenAccount'));
    expect(settings, contains('Voltis Core Account'));
    expect(settings, isNot(contains('_SettingsBackgroundPage')));
    expect(settings, isNot(contains('CustomBackgroundService')));
    expect(settings, isNot(contains('PaywallSheetBody(embeddedInSettings')));
  });

  test('custom background service stays removed', () {
    expect(
      File('${root.path}/lib/services/custom_background_service.dart').existsSync(),
      isFalse,
    );
  });
}
