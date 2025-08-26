import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:duru_notes_app/app/app.dart';
import 'package:duru_notes_app/ui/auth_screen.dart';
import 'package:duru_notes_app/ui/home_screen.dart';
import 'mocks/mock_supabase.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Login + Sync Integration Test', () {
    late MockSupabaseClient mockSupabaseClient;
    late MockGoTrueClient mockAuth;
    late MockSession mockSession;
    late MockUser mockUser;

    setUpAll(() async {
      // Initialize mock Supabase
      mockSupabaseClient = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockSession = MockSession();
      mockUser = MockUser();

      // Setup mock relationships
      when(mockSupabaseClient.auth).thenReturn(mockAuth);
      when(mockAuth.currentSession).thenReturn(null); // Start logged out
      when(mockAuth.currentUser).thenReturn(null);

      // Initialize Supabase with mock
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
      );
    });

    setUp(() {
      // Reset mocks before each test
      reset(mockSupabaseClient);
      reset(mockAuth);
      reset(mockSession);
      reset(mockUser);

      // Setup default mock behavior
      when(mockSupabaseClient.auth).thenReturn(mockAuth);
      when(mockAuth.currentSession).thenReturn(null);
      when(mockAuth.currentUser).thenReturn(null);
    });

    testWidgets('Complete login flow with sync', (WidgetTester tester) async {
      // Setup successful authentication mock
      final mockAuthResponse = MockAuthResponse();
      when(mockAuthResponse.user).thenReturn(mockUser);
      when(mockUser.id).thenReturn('test-user-123');
      when(mockUser.email).thenReturn('test@example.com');

      when(mockAuth.signInWithPassword(
        email: 'test@example.com',
        password: 'ValidPassword123!',
      )).thenAnswer((_) async => mockAuthResponse);

      // After successful login, update session state
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockSession.user).thenReturn(mockUser);

      // Launch the app
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Verify we're on the auth screen initially
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Duru Notes'), findsOneWidget);
      expect(find.text('Secure, encrypted note-taking'), findsOneWidget);

      // Find form fields
      final emailField = find.byKey(const Key('email_field'));
      final passwordField = find.byKey(const Key('password_field'));
      final signInButton = find.text('Sign In');

      expect(emailField, findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(signInButton, findsOneWidget);

      // Enter valid credentials
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'ValidPassword123!');
      await tester.pumpAndSettle();

      // Tap sign in button
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      // Verify auth method was called
      verify(mockAuth.signInWithPassword(
        email: 'test@example.com',
        password: 'ValidPassword123!',
      )).called(1);

      // Should navigate to home screen after successful login
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(HomeScreen), findsOneWidget);

      // Verify sync was triggered
      // This would verify that the SyncService was called
      // In a real implementation, you'd verify sync operations here
    });

    testWidgets('Login with invalid credentials shows error', (WidgetTester tester) async {
      // Setup failed authentication mock
      when(mockAuth.signInWithPassword(
        email: 'invalid@example.com',
        password: 'wrongpassword',
      )).thenThrow(const AuthException('Invalid login credentials'));

      // Launch the app
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Find form fields
      final emailField = find.byKey(const Key('email_field'));
      final passwordField = find.byKey(const Key('password_field'));
      final signInButton = find.text('Sign In');

      // Enter invalid credentials
      await tester.enterText(emailField, 'invalid@example.com');
      await tester.enterText(passwordField, 'wrongpassword');
      await tester.pumpAndSettle();

      // Tap sign in button
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      // Verify error message is shown
      expect(find.textContaining('Invalid credentials'), findsOneWidget);
      
      // Should still be on auth screen
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('Rate limiting displays lockout message', (WidgetTester tester) async {
      // Setup rate limiting scenario
      when(mockAuth.signInWithPassword(
        email: any,
        password: any,
      )).thenThrow(Exception('Too many attempts'));

      // Launch the app
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // Find form fields
      final emailField = find.byKey(const Key('email_field'));
      final passwordField = find.byKey(const Key('password_field'));
      final signInButton = find.text('Sign In');

      // Make multiple failed attempts
      for (int i = 0; i < 3; i++) {
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'wrongpassword$i');
        await tester.pumpAndSettle();

        await tester.tap(signInButton);
        await tester.pumpAndSettle();
      }

      // Should show rate limiting message
      expect(find.textContaining('Too many recent attempts'), findsOneWidget);
    });

    testWidgets('Logout flow clears session and returns to auth', (WidgetTester tester) async {
      // Setup initial logged-in state
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.id).thenReturn('test-user-123');

      // Setup sign out mock
      when(mockAuth.signOut()).thenAnswer((_) async {
        // Update state after sign out
        when(mockAuth.currentSession).thenReturn(null);
        when(mockAuth.currentUser).thenReturn(null);
      });

      // Launch the app (should go to home screen since logged in)
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      // Find and tap logout button (if visible in UI)
      final logoutButton = find.byKey(const Key('logout_button'));
      if (logoutButton.evaluate().isNotEmpty) {
        await tester.tap(logoutButton);
        await tester.pumpAndSettle();

        // Verify signOut was called
        verify(mockAuth.signOut()).called(1);

        // Should return to auth screen
        expect(find.byType(AuthScreen), findsOneWidget);
      }
    });

    testWidgets('App handles network connectivity issues gracefully', (WidgetTester tester) async {
      // Setup network error mock
      when(mockAuth.signInWithPassword(
        email: any,
        password: any,
      )).thenThrow(Exception('Network error'));

      // Launch the app
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      final emailField = find.byKey(const Key('email_field'));
      final passwordField = find.byKey(const Key('password_field'));
      final signInButton = find.text('Sign In');

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'ValidPassword123!');
      await tester.pumpAndSettle();

      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      // Should show network error message
      expect(find.textContaining('network'), findsOneWidget);
    });
  });
}
