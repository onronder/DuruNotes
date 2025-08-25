import 'package:flutter_test/flutter_test.dart';
import 'package:duru_notes_app/services/analytics/analytics_service.dart';
import 'package:duru_notes_app/services/analytics/analytics_sentry.dart';

void main() {
  group('AnalyticsService', () {
    group('AnalyticsHelper', () {
      test('should sample correctly based on rate', () {
        // Test edge cases
        expect(AnalyticsHelper.shouldSample(0.0), isFalse);
        expect(AnalyticsHelper.shouldSample(1.0), isTrue);
        
        // Test sampling behavior (statistical test with multiple runs)
        var sampledCount = 0;
        const testRuns = 1000;
        const samplingRate = 0.1;
        
        for (int i = 0; i < testRuns; i++) {
          if (AnalyticsHelper.shouldSample(samplingRate)) {
            sampledCount++;
          }
        }
        
        // Should be roughly 10% with some tolerance
        final actualRate = sampledCount / testRuns;
        expect(actualRate, greaterThan(0.05));
        expect(actualRate, lessThan(0.15));
      });

      test('should sanitize PII properties', () {
        final input = {
          'user_email': 'test@example.com',
          'user_name': 'John Doe',
          'note_content': 'My secret note',
          'search_query': 'sensitive search',
          'note_length': 'medium',
          'word_count': 150,
          'has_attachments': true,
        };

        final sanitized = AnalyticsHelper.sanitizeProperties(input);

        // PII should be removed
        expect(sanitized.containsKey('user_email'), isFalse);
        expect(sanitized.containsKey('user_name'), isFalse);
        
        // Content should be transformed
        expect(sanitized['note_content'], contains('characters'));
        expect(sanitized['search_query'], contains('characters'));
        
        // Safe properties should remain
        expect(sanitized['note_length'], equals('medium'));
        expect(sanitized['word_count'], equals(150));
        expect(sanitized['has_attachments'], equals(true));
      });

      test('should detect PII keys correctly', () {
        final piiKeys = [
          'user_email',
          'customer_name',
          'phone_number',
          'address_line',
          'ip_address',
          'password_hash',
          'auth_token',
          'api_secret',
          'encryption_key',
        ];

        for (final key in piiKeys) {
          final properties = {key: 'test_value'};
          final sanitized = AnalyticsHelper.sanitizeProperties(properties);
          expect(sanitized.containsKey(key), isFalse, 
            reason: 'Key "$key" should be filtered as PII');
        }
      });

      test('should truncate long strings', () {
        final longString = 'a' * 200;
        final properties = {'title': longString}; // Use a safe key
        final sanitized = AnalyticsHelper.sanitizeProperties(properties);
        
        expect(sanitized.containsKey('title'), isTrue);
        final result = sanitized['title'] as String;
        expect(result.length, lessThanOrEqualTo(100));
        expect(result, endsWith('...'));
      });

      test('should get standard properties', () {
        final standard = AnalyticsHelper.getStandardProperties();
        
        expect(standard, containsPair('timestamp', isA<String>()));
        expect(standard, containsPair('platform', 'flutter'));
        
        // Verify timestamp format
        final timestamp = standard['timestamp'] as String;
        expect(() => DateTime.parse(timestamp), returnsNormally);
      });

      test('should calculate note metadata correctly', () {
        const content = 'This is a test note with some words and content.';
        final metadata = AnalyticsHelper.getNoteMetadata(content);
        
        expect(metadata['character_count'], equals(content.length));
        expect(metadata['word_count'], equals(10)); // 10 words
        expect(metadata['note_length'], equals('short')); // < 100 chars
      });

      test('should categorize note lengths correctly', () {
        expect(AnalyticsHelper.getNoteMetadata('')['note_length'], equals('empty'));
        expect(AnalyticsHelper.getNoteMetadata('short')['note_length'], equals('short'));
        expect(AnalyticsHelper.getNoteMetadata('a' * 150)['note_length'], equals('medium'));
        expect(AnalyticsHelper.getNoteMetadata('a' * 1000)['note_length'], equals('long'));
        expect(AnalyticsHelper.getNoteMetadata('a' * 3000)['note_length'], equals('very_long'));
      });
    });

    group('NoOpAnalytics', () {
      late NoOpAnalytics analytics;

      setUp(() {
        analytics = NoOpAnalytics();
      });

      test('should implement AnalyticsService interface', () {
        expect(analytics, isA<AnalyticsService>());
      });

      test('should not throw on any method call', () {
        expect(() => analytics.event('test'), returnsNormally);
        expect(() => analytics.screen('test'), returnsNormally);
        expect(() => analytics.setUser('user123'), returnsNormally);
        expect(() => analytics.clearUser(), returnsNormally);
        expect(() => analytics.setUserProperty('key', 'value'), returnsNormally);
        expect(() => analytics.startTiming('test'), returnsNormally);
        expect(() => analytics.endTiming('test'), returnsNormally);
        expect(() => analytics.funnelStep('funnel', 'step'), returnsNormally);
        expect(() => analytics.featureUsed('feature'), returnsNormally);
        expect(() => analytics.engagement('action'), returnsNormally);
        expect(() => analytics.trackError('error'), returnsNormally);
      });

      test('should handle complex parameters gracefully', () {
        final complexProperties = {
          'string': 'value',
          'number': 42,
          'boolean': true,
          'list': [1, 2, 3],
          'map': {'nested': 'value'},
          'null': null,
        };

        expect(() => analytics.event('test', properties: complexProperties), 
          returnsNormally);
        expect(() => analytics.setUser('user123', properties: complexProperties), 
          returnsNormally);
      });
    });

    group('AnalyticsFactory', () {
      setUp(() {
        AnalyticsFactory.reset();
      });

      test('should create NoOpAnalytics by default', () {
        final instance = AnalyticsFactory.instance;
        expect(instance, isA<NoOpAnalytics>());
      });

      test('should return same instance on multiple calls', () {
        final instance1 = AnalyticsFactory.instance;
        final instance2 = AnalyticsFactory.instance;
        expect(identical(instance1, instance2), isTrue);
      });

      test('should reset instance correctly', () {
        final instance1 = AnalyticsFactory.instance;
        AnalyticsFactory.reset();
        final instance2 = AnalyticsFactory.instance;
        expect(identical(instance1, instance2), isFalse);
      });
    });

    group('AnalyticsEvents constants', () {
      test('should have authentication events', () {
        expect(AnalyticsEvents.authLoginAttempt, equals('auth.login.attempt'));
        expect(AnalyticsEvents.authLoginSuccess, equals('auth.login.success'));
        expect(AnalyticsEvents.authLoginFailure, equals('auth.login.failure'));
        expect(AnalyticsEvents.authLogout, equals('auth.logout'));
      });

      test('should have note events', () {
        expect(AnalyticsEvents.noteCreate, equals('note.create'));
        expect(AnalyticsEvents.noteEdit, equals('note.edit'));
        expect(AnalyticsEvents.noteDelete, equals('note.delete'));
        expect(AnalyticsEvents.noteView, equals('note.view'));
      });

      test('should have search events', () {
        expect(AnalyticsEvents.searchPerformed, equals('search.performed'));
        expect(AnalyticsEvents.searchResults, equals('search.results'));
        expect(AnalyticsEvents.searchResultClicked, equals('search.result.clicked'));
      });
    });

    group('AnalyticsProperties constants', () {
      test('should have user properties', () {
        expect(AnalyticsProperties.userId, equals('user_id'));
        expect(AnalyticsProperties.sessionId, equals('session_id'));
      });

      test('should have note properties', () {
        expect(AnalyticsProperties.noteId, equals('note_id'));
        expect(AnalyticsProperties.noteLength, equals('note_length'));
        expect(AnalyticsProperties.hasAttachments, equals('has_attachments'));
        expect(AnalyticsProperties.wordCount, equals('word_count'));
      });

      test('should have search properties', () {
        expect(AnalyticsProperties.searchQuery, equals('search_query'));
        expect(AnalyticsProperties.searchQueryLength, equals('search_query_length'));
        expect(AnalyticsProperties.searchResultCount, equals('search_result_count'));
      });
    });

    group('AnalyticsFunnels constants', () {
      test('should have funnel names', () {
        expect(AnalyticsFunnels.userOnboarding, equals('user_onboarding'));
        expect(AnalyticsFunnels.noteCreation, equals('note_creation'));
        expect(AnalyticsFunnels.searchFlow, equals('search_flow'));
        expect(AnalyticsFunnels.syncSetup, equals('sync_setup'));
      });
    });

    group('Global analytics instance', () {
      test('should be accessible via global getter', () {
        expect(analytics, isA<AnalyticsService>());
      });

      test('should reflect factory changes', () {
        AnalyticsFactory.reset();
        final instance1 = analytics;
        
        AnalyticsFactory.reset();
        final instance2 = analytics;
        
        expect(identical(instance1, instance2), isFalse);
      });
    });
  });
}
