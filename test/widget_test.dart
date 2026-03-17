import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:atl_project_2/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the campus feed and opens access settings', (
    WidgetTester tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});

    await tester.pumpWidget(const DecentralizedCampusApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Campus Events'), findsOneWidget);
    expect(find.text('Upcoming events'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Access settings'), findsOneWidget);
  });
}
