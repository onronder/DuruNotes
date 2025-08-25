import 'package:flutter_test/flutter_test.dart';
import 'package:duru_notes_app/core/monitoring/app_logger.dart';

void main() {
  group('AppLogger', () {
    group('LoggerFactory', () {
      setUp(() {
        LoggerFactory.reset();
      });

      test('should create SentryLogger when useSentry is true', () {
        LoggerFactory.initialize(useSentry: true);
        expect(LoggerFactory.instance, isA<SentryLogger>());
      });

      test('should create ConsoleLogger when useSentry is false', () {
        LoggerFactory.initialize(useSentry: false);
        expect(LoggerFactory.instance, isA<ConsoleLogger>());
      });

      test('should create ConsoleLogger by default', () {
        final instance = LoggerFactory.instance;
        expect(instance, isA<ConsoleLogger>());
      });

      test('should return same instance on multiple calls', () {
        final instance1 = LoggerFactory.instance;
        final instance2 = LoggerFactory.instance;
        expect(identical(instance1, instance2), isTrue);
      });

      test('should reset instance correctly', () {
        final instance1 = LoggerFactory.instance;
        LoggerFactory.reset();
        final instance2 = LoggerFactory.instance;
        expect(identical(instance1, instance2), isFalse);
      });
    });

    group('ConsoleLogger', () {
      late ConsoleLogger logger;

      setUp(() {
        logger = ConsoleLogger();
      });

      test('should implement AppLogger interface', () {
        expect(logger, isA<AppLogger>());
      });

      test('should not throw on any method call', () {
        expect(() => logger.info('test'), returnsNormally);
        expect(() => logger.warn('test'), returnsNormally);
        expect(() => logger.error('test'), returnsNormally);
        expect(() => logger.debug('test'), returnsNormally);
        expect(() => logger.breadcrumb('test'), returnsNormally);
        expect(() => logger.setUser('user123'), returnsNormally);
        expect(() => logger.clearUser(), returnsNormally);
        expect(() => logger.setContext('key', {'value': 'test'}), returnsNormally);
        expect(() => logger.removeContext('key'), returnsNormally);
      });

      test('should handle null parameters gracefully', () {
        expect(() => logger.warn('test', error: null), returnsNormally);
        expect(() => logger.error('test', error: null, stackTrace: null), returnsNormally);
        expect(() => logger.setUser(null), returnsNormally);
      });

      test('should handle empty and null data maps', () {
        expect(() => logger.info('test', data: {}), returnsNormally);
        expect(() => logger.info('test', data: null), returnsNormally);
      });
    });

    group('SentryLogger', () {
      late SentryLogger logger;

      setUp(() {
        logger = SentryLogger();
      });

      test('should implement AppLogger interface', () {
        expect(logger, isA<AppLogger>());
      });

      test('should not throw on any method call', () {
        expect(() => logger.info('test'), returnsNormally);
        expect(() => logger.warn('test'), returnsNormally);
        expect(() => logger.error('test'), returnsNormally);
        expect(() => logger.debug('test'), returnsNormally);
        expect(() => logger.breadcrumb('test'), returnsNormally);
        expect(() => logger.setUser('user123'), returnsNormally);
        expect(() => logger.clearUser(), returnsNormally);
        expect(() => logger.setContext('key', {'value': 'test'}), returnsNormally);
        expect(() => logger.removeContext('key'), returnsNormally);
      });

      test('should handle complex data structures', () {
        final complexData = {
          'string': 'value',
          'number': 42,
          'boolean': true,
          'list': [1, 2, 3],
          'map': {'nested': 'value'},
          'null': null,
        };
        
        expect(() => logger.info('test', data: complexData), returnsNormally);
        expect(() => logger.error('test', data: complexData), returnsNormally);
      });

      test('should handle exception objects', () {
        final exception = Exception('Test exception');
        final stackTrace = StackTrace.current;
        
        expect(() => logger.error('test', 
          error: exception, 
          stackTrace: stackTrace
        ), returnsNormally);
      });

      test('should handle user context with extra properties', () {
        expect(() => logger.setUser('user123', 
          email: 'test@example.com',
          extra: {'role': 'admin', 'tier': 'premium'}
        ), returnsNormally);
      });
    });

    group('Global logger instance', () {
      test('should be accessible via global getter', () {
        expect(logger, isA<AppLogger>());
      });

      test('should reflect factory changes', () {
        LoggerFactory.reset();
        LoggerFactory.initialize(useSentry: false);
        expect(logger, isA<ConsoleLogger>());
        
        LoggerFactory.reset();
        LoggerFactory.initialize(useSentry: true);
        expect(logger, isA<SentryLogger>());
      });
    });
  });
}
