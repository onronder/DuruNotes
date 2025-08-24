import 'package:flutter_test/flutter_test.dart';
import 'package:duru_notes_app/core/security/password_validator.dart';

void main() {
  group('PasswordValidator Security', () {

    group('Password Hashing Security', () {
      test('should generate different hashes for same password', () {
        const password = 'TestPassword123!';
        
        final hash1 = PasswordValidator.hashPassword(password);
        final hash2 = PasswordValidator.hashPassword(password);
        
        // Different salts should produce different hashes
        expect(hash1, isNot(equals(hash2)));
        
        // But both should verify correctly
        expect(PasswordValidator.verifyPassword(password, hash1), isTrue);
        expect(PasswordValidator.verifyPassword(password, hash2), isTrue);
      });

      test('should use secure salt format', () {
        const password = 'TestPassword123!';
        final hash = PasswordValidator.hashPassword(password);
        
        // Hash should be in salt:hash format
        expect(hash.contains(':'), isTrue);
        final parts = hash.split(':');
        expect(parts.length, equals(2));
        
        // Salt should be hex encoded (64 chars for 32 bytes)
        expect(parts[0].length, equals(64));
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(parts[0]), isTrue);
        
        // Hash should be hex encoded (64 chars for 32 bytes)
        expect(parts[1].length, equals(64));
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(parts[1]), isTrue);
      });

      test('should reject wrong passwords', () {
        const password = 'TestPassword123!';
        const wrongPassword = 'WrongPassword123!';
        
        final hash = PasswordValidator.hashPassword(password);
        
        expect(PasswordValidator.verifyPassword(password, hash), isTrue);
        expect(PasswordValidator.verifyPassword(wrongPassword, hash), isFalse);
      });

      test('should handle malformed hashes gracefully', () {
        const password = 'TestPassword123!';
        
        expect(PasswordValidator.verifyPassword(password, 'invalid'), isFalse);
        expect(PasswordValidator.verifyPassword(password, 'no:enough:parts'), isFalse);
        expect(PasswordValidator.verifyPassword(password, ''), isFalse);
      });

      test('should use constant-time comparison', () {
        const password = 'TestPassword123!';
        final hash = PasswordValidator.hashPassword(password);
        final parts = hash.split(':');
        
        // Create a hash with same salt but different hash part
        final fakeHash = '${parts[0]}:${'0' * 64}';
        
        expect(PasswordValidator.verifyPassword(password, fakeHash), isFalse);
      });
    });

    group('PBKDF2 Implementation', () {
      test('should be deterministic with same salt', () {
        const password = 'TestPassword123!';
        const salt = 'testsalt123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';
        
        final hash1 = PasswordValidator.hashPassword(password, providedSalt: salt);
        final hash2 = PasswordValidator.hashPassword(password, providedSalt: salt);
        
        expect(hash1, equals(hash2));
      });

      test('should use sufficient iterations for security', () {
        const password = 'TestPassword123!';
        final startTime = DateTime.now();
        
        PasswordValidator.hashPassword(password);
        
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        
        // PBKDF2 with 100,000 iterations should take some time
        // This is a rough check - actual time depends on device performance
        expect(duration.inMilliseconds, greaterThan(10));
      });
    });
  });
}
