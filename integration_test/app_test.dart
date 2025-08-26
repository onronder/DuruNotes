import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:duru_notes_app/app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('App loads and displays correctly', (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(
        const ProviderScope(
          child: App(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify app loaded successfully
      expect(find.byType(MaterialApp), findsOneWidget);
      
      // Should find some basic UI elements
      expect(find.text('Duru Notes'), findsOneWidget);
    });
  });
}
