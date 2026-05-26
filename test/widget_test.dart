import 'package:flutter_test/flutter_test.dart';
import 'package:content_calendar/main.dart';
import 'package:content_calendar/services/storage_service.dart';
import 'package:content_calendar/theme/app_theme_preset.dart';
import 'package:content_calendar/theme/calendar_ambient_mode.dart';
import 'package:content_calendar/theme/home_theme_kind.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App loads calendar screen', (tester) async {
    await StorageService.instance.init();
    await tester.pumpWidget(
      ContentCalendarApp(
        initialKind: HomeThemeKind.palette,
        initialPreset: AppThemePreset.violet,
        initialAmbient: CalendarAmbientMode.aquatic,
        initialUseCustomBackground: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Content Calendar'), findsOneWidget);
  });
}
