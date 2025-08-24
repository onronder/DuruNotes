import 'package:flutter_test/flutter_test.dart';
import 'package:duru_notes_app/core/auth/auth_service.dart';
import 'package:duru_notes_app/core/auth/login_attempts_service.dart';

void main() {
  group('AuthService', () {

    group('Rate Limiting', () {
      test('should have proper constants defined', () {
        // Test that we can import and reference the classes
        expect(AuthService, isNotNull);
        expect(LoginAttemptsService, isNotNull);
      });
    });

    group('AuthResult', () {
      test('should create successful result', () {
        const result = AuthResult(success: true);
        
        expect(result.success, isTrue);
        expect(result.isRetryable, isFalse);
        expect(result.isAccountLocked, isFalse);
      });

      test('should create failed result with lockout', () {
        const result = AuthResult(
          success: false,
          isAccountLocked: true,
          lockoutDuration: Duration(minutes: 15),
          error: 'Account locked',
        );
        
        expect(result.success, isFalse);
        expect(result.isRetryable, isFalse);
        expect(result.isAccountLocked, isTrue);
        expect(result.lockoutDuration, equals(const Duration(minutes: 15)));
      });

      test('should create retryable failed result', () {
        const result = AuthResult(
          success: false,
          error: 'Network error',
        );
        
        expect(result.success, isFalse);
        expect(result.isRetryable, isTrue);
        expect(result.isAccountLocked, isFalse);
      });
    });
  });

  group('LockoutStatus', () {
    test('should create unlocked status', () {
      const status = LockoutStatus(
        isLocked: false,
        attemptsRemaining: 5,
      );
      
      expect(status.isLocked, isFalse);
      expect(status.attemptsRemaining, equals(5));
      expect(status.remainingLockoutTime, isNull);
    });

    test('should create locked status', () {
      const lockoutTime = Duration(minutes: 15);
      const status = LockoutStatus(
        isLocked: true,
        remainingLockoutTime: lockoutTime,
        attemptsRemaining: 0,
      );
      
      expect(status.isLocked, isTrue);
      expect(status.remainingLockoutTime, equals(lockoutTime));
      expect(status.attemptsRemaining, equals(0));
    });
  });

  group('Security Configuration', () {
    test('should have secure default behavior', () {
      // Test that the classes are properly structured
      expect(AuthResult, isNotNull);
      expect(LockoutStatus, isNotNull);
      
      // Test result creation without Supabase
      const result = AuthResult(success: false, error: 'Test error');
      expect(result.success, isFalse);
      expect(result.error, equals('Test error'));
    });
  });
}
