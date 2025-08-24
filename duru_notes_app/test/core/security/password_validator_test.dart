import 'package:flutter_test/flutter_test.dart';
import 'package:duru_notes_app/core/security/password_validator.dart';

void main() {
  group('PasswordValidator', () {
    late PasswordValidator validator;

    setUp(() {
      validator = PasswordValidator();
    });

    group('validatePassword', () {
      test('should reject passwords shorter than 12 characters', () {
        final result = validator.validatePassword('short');
        
        expect(result.isValid, false);
        expect(result.failedCriteria, contains('At least 12 characters'));
        expect(result.score, lessThan(70)); // Should not meet minimum score for validity
      });

      test('should reject passwords without uppercase letters', () {
        final result = validator.validatePassword('lowercase123!');
        
        expect(result.isValid, false);
        expect(result.failedCriteria, contains('At least one uppercase letter (A-Z)'));
      });

      test('should reject passwords without lowercase letters', () {
        final result = validator.validatePassword('UPPERCASE123!');
        
        expect(result.isValid, false);
        expect(result.failedCriteria, contains('At least one lowercase letter (a-z)'));
      });

      test('should reject passwords without numbers', () {
        final result = validator.validatePassword('NoNumbersHere!');
        
        expect(result.isValid, false);
        expect(result.failedCriteria, contains('At least one number (0-9)'));
      });

      test('should reject passwords without special characters', () {
        final result = validator.validatePassword('NoSpecialChars123');
        
        expect(result.isValid, false);
        expect(result.failedCriteria, contains('At least one special character (!@#\$%^&*)'));
      });

      test('should reject passwords with common patterns', () {
        final result1 = validator.validatePassword('Password123!');
        final result2 = validator.validatePassword('Qwerty123456!');
        final result3 = validator.validatePassword('Abc123456789!');
        
        expect(result1.failedCriteria, contains('No common patterns (123, abc, etc.)'));
        expect(result2.failedCriteria, contains('No common patterns (123, abc, etc.)'));
        expect(result3.failedCriteria, contains('No common patterns (123, abc, etc.)'));
      });

      test('should reject passwords with repeated characters', () {
        final result = validator.validatePassword('Aaa123456789!');
        
        expect(result.failedCriteria, contains('No common patterns (123, abc, etc.)'));
      });

      test('should accept strong passwords', () {
        final result = validator.validatePassword('MyStr0ng!P@ssw0rd');
        
        expect(result.isValid, true);
        expect(result.strength, isIn([PasswordStrength.strong, PasswordStrength.veryStrong]));
        expect(result.failedCriteria, isEmpty);
        expect(result.score, greaterThan(70));
      });

      test('should calculate correct strength levels', () {
        final weakPassword = 'weak';
        final mediumPassword = 'Medium123!';
        final strongPassword = 'Str0ng!P@ssw0rd2024';
        final veryStrongPassword = r'V3ry$tr0ng!P@ssw0rd#2024&Complex';

        final weakResult = validator.validatePassword(weakPassword);
        final mediumResult = validator.validatePassword(mediumPassword);
        final strongResult = validator.validatePassword(strongPassword);
        final veryStrongResult = validator.validatePassword(veryStrongPassword);

        expect(weakResult.strength, PasswordStrength.weak);
        expect(mediumResult.strength, isIn([PasswordStrength.medium, PasswordStrength.strong]));
        expect(strongResult.strength, isIn([PasswordStrength.strong, PasswordStrength.veryStrong]));
        expect(veryStrongResult.strength, PasswordStrength.veryStrong);
      });

      test('should provide helpful suggestions', () {
        final result = validator.validatePassword('weak');
        
        expect(result.suggestions, isNotEmpty);
        expect(result.suggestions.any((s) => s.contains('12 characters')), true);
        expect(result.suggestions.any((s) => s.contains('uppercase')), true);
        expect(result.suggestions.any((s) => s.contains('number')), true);
        expect(result.suggestions.any((s) => s.contains('special character')), true);
      });

      test('should give bonus points for extra length', () {
        final basePassword = 'Basic123!Pass';
        final longerPassword = 'Basic123!PassWithExtraLength';
        
        final baseResult = validator.validatePassword(basePassword);
        final longerResult = validator.validatePassword(longerPassword);
        
        expect(longerResult.score, greaterThan(baseResult.score));
      });

      test('should give bonus points for character diversity', () {
        final lessDiverse = 'aaaa123456!A';
        final moreDiverse = 'AbCd123!@#XyZ';
        
        final lessResult = validator.validatePassword(lessDiverse);
        final moreResult = validator.validatePassword(moreDiverse);
        
        expect(moreResult.score, greaterThan(lessResult.score));
      });
    });

    group('getCriteria', () {
      test('should return all password criteria', () {
        final criteria = PasswordValidator.getCriteria();
        
        expect(criteria, hasLength(6));
        expect(criteria.map((c) => c.id), contains('min_length'));
        expect(criteria.map((c) => c.id), contains('uppercase'));
        expect(criteria.map((c) => c.id), contains('lowercase'));
        expect(criteria.map((c) => c.id), contains('number'));
        expect(criteria.map((c) => c.id), contains('special_char'));
        expect(criteria.map((c) => c.id), contains('no_common_patterns'));
      });
    });

    group('hashPassword', () {
      test('should generate consistent hashes', () {
        const password = 'TestPassword123!';
        
        final hash1 = PasswordValidator.hashPassword(password);
        final hash2 = PasswordValidator.hashPassword(password);
        
        expect(hash1, equals(hash2));
        expect(hash1, isNotEmpty);
      });

      test('should generate different hashes for different passwords', () {
        const password1 = 'TestPassword123!';
        const password2 = 'DifferentPassword456!';
        
        final hash1 = PasswordValidator.hashPassword(password1);
        final hash2 = PasswordValidator.hashPassword(password2);
        
        expect(hash1, isNot(equals(hash2)));
      });
    });

    group('getStrengthDescription', () {
      test('should return correct descriptions', () {
        expect(PasswordValidator.getStrengthDescription(PasswordStrength.weak), 'Weak');
        expect(PasswordValidator.getStrengthDescription(PasswordStrength.medium), 'Medium');
        expect(PasswordValidator.getStrengthDescription(PasswordStrength.strong), 'Strong');
        expect(PasswordValidator.getStrengthDescription(PasswordStrength.veryStrong), 'Very Strong');
      });
    });

    group('getStrengthColor', () {
      test('should return appropriate colors', () {
        expect(PasswordValidator.getStrengthColor(PasswordStrength.weak), '#f44336');
        expect(PasswordValidator.getStrengthColor(PasswordStrength.medium), '#ff9800');
        expect(PasswordValidator.getStrengthColor(PasswordStrength.strong), '#4caf50');
        expect(PasswordValidator.getStrengthColor(PasswordStrength.veryStrong), '#2e7d32');
      });
    });
  });
}
