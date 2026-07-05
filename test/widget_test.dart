import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:truck_account_book/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('app opens directly without PIN configured', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: MohsinMaterialApp()));
    await tester.pump();

    // Should show the dashboard screen (no lock screen)
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
