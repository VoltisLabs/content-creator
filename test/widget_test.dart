import 'package:flutter_test/flutter_test.dart';
import 'package:content_calendar/main.dart';
import 'package:content_calendar/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App loads calendar screen', (tester) async {
    await StorageService.instance.init();
    await tester.pumpWidget(const ContentCalendarApp());
    await tester.pumpAndSettle();
    expect(find.text('Content Calendar'), findsOneWidget);
  });
}
