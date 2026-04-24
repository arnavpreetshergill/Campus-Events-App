import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:atl_project_2/crypto_utils.dart';
import 'package:atl_project_2/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'guest mode hides private events and shows a single admin prompt',
    (WidgetTester tester) async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});

      await tester.pumpWidget(const DecentralizedCampusApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Campus Events'), findsOneWidget);
      expect(find.text('Upcoming events'), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();

      expect(find.text('Cryptography 101 Lecture'), findsOneWidget);
      expect(find.text('Ops Night Volunteer Grid'), findsNothing);

      await tester.tap(find.byTooltip('Access settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Access settings'), findsOneWidget);
      expect(find.text('Admin passphrase'), findsOneWidget);
      expect(find.text('Private key'), findsNothing);
    },
  );

  testWidgets(
    'admin mode shows private events when the AES passphrase is stored',
    (WidgetTester tester) async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'custodian_aes_secret': DemoCustodianKeys.adminAesPassphrase,
      });

      await tester.pumpWidget(const DecentralizedCampusApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Ops Night Volunteer Grid'), findsOneWidget);
    },
  );
}
