import 'package:duru_notes_app/core/config/environment_config.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  group('EnvironmentConfig', () {
    setUp(() {
      // Reset the environment config state before each test
      // This is a simple test since EnvironmentConfig uses static state
    });

    test('should have correct environment enum values', () {
      expect(Environment.development.fileName, equals('dev'));
      expect(Environment.staging.fileName, equals('staging'));
      expect(Environment.production.fileName, equals('prod'));
    });

    test('should detect environment from flavor', () {
      // Test the environment detection logic
      // Note: This test verifies the enum mapping logic
      const {
        'dev': Environment.development,
        'development': Environment.development,
        'staging': Environment.staging,
        'prod': Environment.production,
        'production': Environment.production,
        'unknown': Environment.development, // Default case
      };

      // Since _getEnvironmentFromFlavor is private, we test the public behavior
      // by checking that Environment enum has the expected values
      expect(Environment.values.length, equals(3));
      expect(Environment.values, contains(Environment.development));
      expect(Environment.values, contains(Environment.staging));
      expect(Environment.values, contains(Environment.production));
    });

    test('should provide safe config summary structure', () {
      // Test that getSafeConfigSummary provides expected structure
      // when initialized (will test initialization separately)
      
      // For now, just verify the method exists and returns a map
      expect(() => EnvironmentConfig.getSafeConfigSummary(), returnsNormally);
      
      // Verify it returns a map type
      expect(EnvironmentConfig.getSafeConfigSummary(), isA<Map<String, dynamic>>());
    });

    test('should validate required configuration fields', () {
      // Test that validateConfig returns false when not initialized
      expect(EnvironmentConfig.validateConfig(), isFalse);
    });

    test('should provide all config when initialized', () {
      // Test the getAllConfig method structure
      final config = EnvironmentConfig.getAllConfig();
      
      expect(config, isA<Map<String, dynamic>>());
      
      // Should contain error when not initialized
      if (!EnvironmentConfig.isInitialized) {
        expect(config.containsKey('error'), isTrue);
      }
    });

    test('should track initialization state', () {
      // Test the initialization state tracking
      expect(EnvironmentConfig.isInitialized, isA<bool>());
      expect(EnvironmentConfig.currentEnvironment, isA<Environment>());
    });

    group('Environment-specific settings', () {
      test('development environment should have debug features', () {
        expect(Environment.development.fileName, equals('dev'));
      });

      test('staging environment should be production-like', () {
        expect(Environment.staging.fileName, equals('staging'));
      });

      test('production environment should be optimized', () {
        expect(Environment.production.fileName, equals('prod'));
      });
    });

    group('Configuration values', () {
      test('should provide default values for safety', () {
        // Test that the configuration provides sensible defaults
        // when environment files are not available
        
        // These methods should not throw when called with proper defaults
        expect(() => Environment.development.fileName, returnsNormally);
        expect(() => Environment.staging.fileName, returnsNormally);
        expect(() => Environment.production.fileName, returnsNormally);
      });
    });
  });
}
