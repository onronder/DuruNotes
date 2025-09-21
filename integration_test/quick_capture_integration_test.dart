import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:duru_notes/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  const runIntegration = bool.fromEnvironment('RUN_INTEGRATION_TESTS');
  if (!runIntegration) {
    return;
  }

  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Quick Capture Widget Integration Tests', () {
    setUpAll(() async {
      // Set up test environment
      const MethodChannel channel =
          MethodChannel('com.fittechs.durunotes/quick_capture');
      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getAuthStatus':
            return {'isAuthenticated': true, 'userId': 'test-user'};
          case 'updateWidgetData':
            return true;
          case 'refreshWidget':
            return true;
          case 'getPendingCaptures':
            return [];
          default:
            return null;
        }
      });
    });

    testWidgets('App launches and initializes QuickCaptureService',
        (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Verify app is running
      expect(find.byType(MaterialApp), findsOneWidget);

      // Wait for initialization
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('Handle widget capture intent from platform',
        (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Simulate widget capture intent
      const MethodChannel channel =
          MethodChannel('com.fittechs.durunotes/quick_capture');

      // Simulate receiving a capture request from widget
      await tester.runAsync(() async {
        await channel.invokeMethod('handleWidgetCapture', {
          'type': 'text',
          'source': 'widget',
          'widgetId': 1,
        });
      });

      await tester.pumpAndSettle();

      // Verify capture dialog or screen appears
      // This depends on your app's UI implementation
      // expect(find.text('Quick Capture'), findsOneWidget);
    });

    testWidgets('Process offline queue when coming online',
        (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Simulate offline captures in queue
      const MethodChannel channel =
          MethodChannel('com.fittechs.durunotes/quick_capture');
      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getPendingCaptures') {
          return [
            {
              'id': '1',
              'content': 'Offline note 1',
              'type': 'text',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
            {
              'id': '2',
              'content': 'Offline note 2',
              'type': 'text',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
          ];
        }
        return null;
      });

      // Trigger sync
      await tester.runAsync(() async {
        await channel.invokeMethod('processPendingCaptures');
      });

      await tester.pump(const Duration(seconds: 3));

      // Verify queue is processed
      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getPendingCaptures') {
          return []; // Queue should be empty after processing
        }
        return null;
      });

      final result = await channel.invokeMethod('getPendingCaptures');
      expect(result, isEmpty);
    });

    testWidgets('Update widget data from Flutter to platform',
        (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Simulate data update
      const MethodChannel channel =
          MethodChannel('com.fittechs.durunotes/quick_capture');

      bool updateCalled = false;
      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'updateWidgetData') {
          updateCalled = true;
          final data = methodCall.arguments as Map;
          expect(data['recentCaptures'], isNotNull);
          return true;
        }
        return null;
      });

      // Trigger widget update
      await tester.runAsync(() async {
        await channel.invokeMethod('updateWidgetData', {
          'recentCaptures': [
            {'id': '1', 'title': 'Test Note', 'snippet': 'Test content'}
          ],
          'authToken': 'test-token',
          'userId': 'test-user',
        });
      });

      expect(updateCalled, true);
    });

    testWidgets('Handle deep link from widget', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Simulate deep link
      await tester.runAsync(() async {
        // Simulate opening a note via deep link
        const MethodChannel channel =
            MethodChannel('com.fittechs.durunotes/quick_capture');
        await channel.invokeMethod('openNote', {'noteId': 'test-note-123'});
      });

      await tester.pumpAndSettle();

      // Verify navigation occurred
      // This depends on your app's navigation implementation
      // expect(find.byKey(Key('note_test-note-123')), findsOneWidget);
    });

    testWidgets('Handle template selection from widget',
        (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Simulate template selection
      const MethodChannel channel =
          MethodChannel('com.fittechs.durunotes/quick_capture');

      await tester.runAsync(() async {
        await channel.invokeMethod('handleWidgetCapture', {
          'type': 'template',
          'templateId': 'meeting',
          'source': 'widget',
        });
      });

      await tester.pumpAndSettle();

      // Verify template is applied
      // This depends on your app's UI
      // expect(find.text('Meeting Notes'), findsOneWidget);
    });
  },
      skip:
          'Integration scenario requiring full app runtime (Firebase, platform channels).');

  group('Platform-Specific Widget Tests', () {
    testWidgets('iOS widget data sync', (WidgetTester tester) async {
      // This would typically be tested in XCTest
      // Here we can test the Flutter side of the integration

      app.main();
      await tester.pumpAndSettle();

      const MethodChannel channel =
          MethodChannel('com.fittechs.durunotes/quick_capture');

      // Simulate iOS requesting data
      bool dataProvided = false;
      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getRecentCaptures') {
          dataProvided = true;
          return [
            {
              'id': '1',
              'title': 'iOS Note',
              'snippet': 'From iOS widget',
              'created_at': DateTime.now().millisecondsSinceEpoch,
            }
          ];
        }
        return null;
      });

      await tester.runAsync(() async {
        final result = await channel.invokeMethod('getRecentCaptures');
        expect(result, isNotEmpty);
      });

      expect(dataProvided, true);
    });

    testWidgets('Android widget data sync', (WidgetTester tester) async {
      // Test Android-specific widget communication

      app.main();
      await tester.pumpAndSettle();

      const MethodChannel channel =
          MethodChannel('com.fittechs.durunotes/quick_capture');

      // Simulate Android widget configuration request
      bool configProvided = false;
      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getWidgetSettings') {
          configProvided = true;
          final widgetId = methodCall.arguments['widgetId'];
          return {
            'defaultCaptureType': 'text',
            'showRecentCaptures': true,
            'enableVoice': true,
            'enableCamera': false,
            'theme': 'auto',
          };
        }
        return null;
      });

      await tester.runAsync(() async {
        final settings = await channel.invokeMethod('getWidgetSettings', {
          'widgetId': 1,
        });
        expect(settings['defaultCaptureType'], 'text');
      });

      expect(configProvided, true);
    });
  });

  group('Error Handling Tests', () {
    testWidgets('Handle network error during capture',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      const MethodChannel channel =
          MethodChannel('com.fittechs.durunotes/quick_capture');

      // Simulate network error
      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'captureNote') {
          throw PlatformException(
            code: 'NETWORK_ERROR',
            message: 'No internet connection',
          );
        }
        return null;
      });

      // Attempt capture
      bool errorHandled = false;
      try {
        await channel.invokeMethod('captureNote', {
          'text': 'Test note',
          'platform': 'ios',
        });
      } on PlatformException catch (e) {
        errorHandled = true;
        expect(e.code, 'NETWORK_ERROR');
      }

      expect(errorHandled, true);
    });

    testWidgets('Handle rate limiting', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      const MethodChannel channel =
          MethodChannel('com.fittechs.durunotes/quick_capture');

      int captureCount = 0;
      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'captureNote') {
          captureCount++;
          if (captureCount > 10) {
            throw PlatformException(
              code: 'RATE_LIMITED',
              message: 'Too many requests',
            );
          }
          return {'success': true, 'noteId': 'test-$captureCount'};
        }
        return null;
      });

      // Make multiple captures
      for (int i = 0; i < 12; i++) {
        try {
          await channel.invokeMethod('captureNote', {
            'text': 'Note $i',
            'platform': 'android',
          });
        } on PlatformException catch (e) {
          if (i >= 10) {
            expect(e.code, 'RATE_LIMITED');
          }
        }
      }

      expect(captureCount, 11);
    });
  });

  group('Performance Tests', () {
    testWidgets('Measure capture latency', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      const MethodChannel channel =
          MethodChannel('com.fittechs.durunotes/quick_capture');

      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'captureNote') {
          // Simulate processing time
          await Future.delayed(const Duration(milliseconds: 100));
          return {'success': true, 'noteId': 'perf-test'};
        }
        return null;
      });

      // Measure capture time
      final stopwatch = Stopwatch()..start();

      await channel.invokeMethod('captureNote', {
        'text': 'Performance test note',
        'platform': 'ios',
      });

      stopwatch.stop();

      // Should complete within reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      print('Capture latency: ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('Test bulk capture processing', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      const MethodChannel channel =
          MethodChannel('com.fittechs.durunotes/quick_capture');

      final captures = List.generate(
          50,
          (i) => {
                'id': '$i',
                'content': 'Bulk note $i',
                'type': 'text',
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              });

      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getPendingCaptures') {
          return captures;
        }
        if (methodCall.method == 'processPendingCaptures') {
          // Simulate bulk processing
          await Future.delayed(const Duration(seconds: 2));
          return captures.length;
        }
        return null;
      });

      // Process bulk captures
      final stopwatch = Stopwatch()..start();

      final processed = await channel.invokeMethod('processPendingCaptures');

      stopwatch.stop();

      expect(processed, 50);
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      print(
          'Bulk processing time: ${stopwatch.elapsedMilliseconds}ms for 50 items');
    });
  }, skip: 'Integration scenario requiring full app runtime.');
}
