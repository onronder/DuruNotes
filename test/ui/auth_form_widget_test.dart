import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:duru_notes_app/ui/auth_screen.dart';
import 'package:duru_notes_app/ui/widgets/password_strength_meter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  group('Auth Form Widget Tests', () {
    late MockSupabaseClient mockSupabaseClient;
    late MockGoTrueClient mockAuth;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      
      when(mockSupabaseClient.auth).thenReturn(mockAuth);
      when(mockAuth.currentSession).thenReturn(null);
      when(mockAuth.currentUser).thenReturn(null);
      
      // Mock Supabase instance
      Supabase.instance.client = mockSupabaseClient;
    });

    Widget createAuthScreen() {
      return ProviderScope(
        child: MaterialApp(
          home: const AuthScreen(),
        ),
      );
    }

    group('Email Validation', () {
      testWidgets('should show error for empty email', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        // Find the email field
        final emailField = find.byKey(const Key('email_field'));
        expect(emailField, findsOneWidget);
        
        // Find the form and try to submit without entering email
        final signInButton = find.text('Sign In');
        await tester.tap(signInButton);
        await tester.pumpAndSettle();
        
        // Should show email required error
        expect(find.text('Email is required'), findsOneWidget);
      });

      testWidgets('should show error for invalid email format', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        final emailField = find.byKey(const Key('email_field'));
        
        // Test various invalid email formats
        final invalidEmails = [
          'notanemail',
          'missing@domain',
          '@missinguser.com',
          'spaces in@email.com',
          'double@@domain.com',
          'trailing.dot.@domain.com',
        ];
        
        for (final email in invalidEmails) {
          await tester.enterText(emailField, email);
          await tester.pumpAndSettle();
          
          final signInButton = find.text('Sign In');
          await tester.tap(signInButton);
          await tester.pumpAndSettle();
          
          expect(
            find.text('Please enter a valid email'),
            findsOneWidget,
            reason: 'Should reject invalid email: $email',
          );
          
          // Clear the field for next test
          await tester.enterText(emailField, '');
        }
      });

      testWidgets('should accept valid email formats', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        final emailField = find.byKey(const Key('email_field'));
        final passwordField = find.byKey(const Key('password_field'));
        
        // Test valid email formats
        final validEmails = [
          'user@example.com',
          'test.email@domain.co.uk',
          'user+tag@example.org',
          'firstname.lastname@company.com',
        ];
        
        for (final email in validEmails) {
          await tester.enterText(emailField, email);
          await tester.enterText(passwordField, 'ValidPassword123!');
          await tester.pumpAndSettle();
          
          final signInButton = find.text('Sign In');
          await tester.tap(signInButton);
          await tester.pumpAndSettle();
          
          // Should not show email validation error
          expect(
            find.text('Please enter a valid email'),
            findsNothing,
            reason: 'Should accept valid email: $email',
          );
        }
      });

      testWidgets('should trim whitespace from email', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        final emailField = find.byKey(const Key('email_field'));
        final passwordField = find.byKey(const Key('password_field'));
        
        // Enter email with leading/trailing spaces
        await tester.enterText(emailField, '  test@example.com  ');
        await tester.enterText(passwordField, 'ValidPassword123!');
        await tester.pumpAndSettle();
        
        final signInButton = find.text('Sign In');
        await tester.tap(signInButton);
        await tester.pumpAndSettle();
        
        // Should not show validation error (whitespace should be trimmed)
        expect(find.text('Please enter a valid email'), findsNothing);
      });
    });

    group('Password Validation - Sign In', () {
      testWidgets('should show error for empty password', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        final emailField = find.byKey(const Key('email_field'));
        final passwordField = find.byKey(const Key('password_field'));
        
        await tester.enterText(emailField, 'test@example.com');
        // Leave password field empty
        
        final signInButton = find.text('Sign In');
        await tester.tap(signInButton);
        await tester.pumpAndSettle();
        
        expect(find.text('Password is required'), findsOneWidget);
      });

      testWidgets('should require minimum 6 characters for sign in', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        final emailField = find.byKey(const Key('email_field'));
        final passwordField = find.byKey(const Key('password_field'));
        
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, '12345'); // Only 5 characters
        
        final signInButton = find.text('Sign In');
        await tester.tap(signInButton);
        await tester.pumpAndSettle();
        
        expect(find.text('Password must be at least 6 characters'), findsOneWidget);
      });

      testWidgets('should accept valid password for sign in', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        final emailField = find.byKey(const Key('email_field'));
        final passwordField = find.byKey(const Key('password_field'));
        
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'validpass');
        
        final signInButton = find.text('Sign In');
        await tester.tap(signInButton);
        await tester.pumpAndSettle();
        
        // Should not show password validation error
        expect(find.text('Password must be at least 6 characters'), findsNothing);
      });
    });

    group('Password Validation - Sign Up', () {
      testWidgets('should enforce strong password requirements for sign up', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        // Switch to sign up mode
        final toggleButton = find.text('Don\'t have an account? Sign Up');
        await tester.tap(toggleButton);
        await tester.pumpAndSettle();
        
        expect(find.text('Create Account'), findsOneWidget);
        
        final emailField = find.byKey(const Key('email_field'));
        final passwordField = find.byKey(const Key('password_field'));
        
        await tester.enterText(emailField, 'test@example.com');
        
        // Test weak passwords
        final weakPasswords = [
          'short',           // Too short
          'nouppercase123!', // No uppercase
          'NOLOWERCASE123!', // No lowercase
          'NoNumbers!',      // No numbers
          'NoSpecialChars123', // No special characters
          'password123!',    // Common pattern
        ];
        
        for (final password in weakPasswords) {
          await tester.enterText(passwordField, password);
          await tester.pumpAndSettle();
          
          final signUpButton = find.text('Create Account');
          await tester.tap(signUpButton);
          await tester.pumpAndSettle();
          
          expect(
            find.text('Password must meet security requirements'),
            findsOneWidget,
            reason: 'Should reject weak password: $password',
          );
        }
      });

      testWidgets('should accept strong password for sign up', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        // Switch to sign up mode
        final toggleButton = find.text('Don\'t have an account? Sign Up');
        await tester.tap(toggleButton);
        await tester.pumpAndSettle();
        
        final emailField = find.byKey(const Key('email_field'));
        final passwordField = find.byKey(const Key('password_field'));
        
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'StrongPassword123!');
        await tester.pumpAndSettle();
        
        final signUpButton = find.text('Create Account');
        await tester.tap(signUpButton);
        await tester.pumpAndSettle();
        
        // Should not show password validation error
        expect(find.text('Password must meet security requirements'), findsNothing);
      });

      testWidgets('should show password strength meter during sign up', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        // Switch to sign up mode
        final toggleButton = find.text('Don\'t have an account? Sign Up');
        await tester.tap(toggleButton);
        await tester.pumpAndSettle();
        
        final passwordField = find.byKey(const Key('password_field'));
        
        // Enter a password to trigger strength meter
        await tester.enterText(passwordField, 'TestPass123!');
        await tester.pumpAndSettle();
        
        // Should show password strength meter
        expect(find.byType(PasswordStrengthMeter), findsOneWidget);
        
        // Should show strength indicator
        expect(find.textContaining('Strong'), findsOneWidget);
      });

      testWidgets('should update password strength in real-time', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        // Switch to sign up mode
        final toggleButton = find.text('Don\'t have an account? Sign Up');
        await tester.tap(toggleButton);
        await tester.pumpAndSettle();
        
        final passwordField = find.byKey(const Key('password_field'));
        
        // Start with weak password
        await tester.enterText(passwordField, 'weak');
        await tester.pumpAndSettle();
        
        expect(find.byType(PasswordStrengthMeter), findsOneWidget);
        expect(find.text('Weak'), findsOneWidget);
        
        // Improve to medium
        await tester.enterText(passwordField, 'Better123');
        await tester.pumpAndSettle();
        
        expect(find.text('Medium'), findsOneWidget);
        
        // Improve to strong
        await tester.enterText(passwordField, 'StrongPassword123!');
        await tester.pumpAndSettle();
        
        expect(find.text('Strong'), findsOneWidget);
      });
    });

    group('Password Visibility Toggle', () {
      testWidgets('should toggle password visibility', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        final passwordField = find.byKey(const Key('password_field'));
        final visibilityToggle = find.byIcon(Icons.visibility);
        
        expect(passwordField, findsOneWidget);
        expect(visibilityToggle, findsOneWidget);
        
        // Password should be obscured initially
        final passwordWidget = tester.widget<TextFormField>(passwordField);
        expect(passwordWidget.obscureText, isTrue);
        
        // Tap visibility toggle
        await tester.tap(visibilityToggle);
        await tester.pumpAndSettle();
        
        // Password should now be visible
        final updatedPasswordWidget = tester.widget<TextFormField>(passwordField);
        expect(updatedPasswordWidget.obscureText, isFalse);
        
        // Icon should change to visibility_off
        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsNothing);
      });
    });

    group('Form Mode Switching', () {
      testWidgets('should switch between sign in and sign up modes', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        // Should start in sign in mode
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Don\'t have an account? Sign Up'), findsOneWidget);
        
        // Switch to sign up
        final signUpToggle = find.text('Don\'t have an account? Sign Up');
        await tester.tap(signUpToggle);
        await tester.pumpAndSettle();
        
        expect(find.text('Create Account'), findsOneWidget);
        expect(find.text('Already have an account? Sign In'), findsOneWidget);
        
        // Switch back to sign in
        final signInToggle = find.text('Already have an account? Sign In');
        await tester.tap(signInToggle);
        await tester.pumpAndSettle();
        
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Don\'t have an account? Sign Up'), findsOneWidget);
      });

      testWidgets('should clear error messages when switching modes', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        final emailField = find.byKey(const Key('email_field'));
        final signInButton = find.text('Sign In');
        
        // Trigger validation error
        await tester.tap(signInButton);
        await tester.pumpAndSettle();
        
        expect(find.text('Email is required'), findsOneWidget);
        
        // Switch to sign up mode
        final signUpToggle = find.text('Don\'t have an account? Sign Up');
        await tester.tap(signUpToggle);
        await tester.pumpAndSettle();
        
        // Error should be cleared
        expect(find.text('Email is required'), findsNothing);
      });

      testWidgets('should show password strength when switching to sign up with existing password', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        final passwordField = find.byKey(const Key('password_field'));
        
        // Enter password in sign in mode
        await tester.enterText(passwordField, 'TestPassword123!');
        await tester.pumpAndSettle();
        
        // Should not show strength meter in sign in mode
        expect(find.byType(PasswordStrengthMeter), findsNothing);
        
        // Switch to sign up mode
        final signUpToggle = find.text('Don\'t have an account? Sign Up');
        await tester.tap(signUpToggle);
        await tester.pumpAndSettle();
        
        // Should now show strength meter
        expect(find.byType(PasswordStrengthMeter), findsOneWidget);
      });
    });

    group('Loading States', () {
      testWidgets('should show loading indicator during authentication', (WidgetTester tester) async {
        // Setup auth mock to delay response
        when(mockAuth.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) => Future.delayed(const Duration(seconds: 1), () => throw Exception()));
        
        await tester.pumpWidget(createAuthScreen());
        
        final emailField = find.byKey(const Key('email_field'));
        final passwordField = find.byKey(const Key('password_field'));
        final signInButton = find.text('Sign In');
        
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'validpass');
        
        // Tap sign in button
        await tester.tap(signInButton);
        await tester.pump(); // Start the async operation
        
        // Should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // Button should be disabled
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);
        
        // Wait for operation to complete
        await tester.pumpAndSettle();
      });

      testWidgets('should disable form fields during loading', (WidgetTester tester) async {
        when(mockAuth.signInWithPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) => Future.delayed(const Duration(seconds: 1), () => throw Exception()));
        
        await tester.pumpWidget(createAuthScreen());
        
        final emailField = find.byKey(const Key('email_field'));
        final passwordField = find.byKey(const Key('password_field'));
        final signInButton = find.text('Sign In');
        final toggleButton = find.text('Don\'t have an account? Sign Up');
        
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'validpass');
        
        await tester.tap(signInButton);
        await tester.pump();
        
        // Toggle button should be disabled during loading
        final toggle = tester.widget<TextButton>(find.byType(TextButton));
        expect(toggle.onPressed, isNull);
        
        await tester.pumpAndSettle();
      });
    });

    group('Accessibility', () {
      testWidgets('should have proper semantic labels', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        // Check for semantic information
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.byIcon(Icons.email_outlined), findsOneWidget);
        expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
      });

      testWidgets('should support keyboard navigation', (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        
        final emailField = find.byKey(const Key('email_field'));
        final passwordField = find.byKey(const Key('password_field'));
        
        // Focus should move between fields
        await tester.tap(emailField);
        await tester.pumpAndSettle();
        
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
        
        // Should be focusable
        expect(tester.binding.focusManager.primaryFocus, isNotNull);
      });
    });
  });
}
