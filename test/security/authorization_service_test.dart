/// Unit tests for AuthorizationService
///
/// These tests verify that the authorization service correctly enforces
/// access controls and prevents unauthorized data access.
///
/// Test coverage:
/// - Authenticated user validation
/// - Ownership verification
/// - Batch authorization
/// - Security audit logging
/// - Exception handling
library;

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/security/authorization_exception.dart';
import 'package:duru_notes/core/security/authorization_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
  MockSpec<User>(),
  MockSpec<AppLogger>(),
])
import 'authorization_service_test.mocks.dart';

void main() {
  group('AuthorizationService', () {
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late MockUser mockUser;
    late MockAppLogger mockLogger;
    late AuthorizationService authService;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockUser = MockUser();
      mockLogger = MockAppLogger();

      when(mockSupabase.auth).thenReturn(mockAuth);

      authService = AuthorizationService(
        supabase: mockSupabase,
        logger: mockLogger,
      );
    });

    group('currentUserId', () {
      test('returns user ID when user is authenticated', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        expect(authService.currentUserId, equals('user-123'));
      });

      test('returns null when no user is authenticated', () {
        when(mockAuth.currentUser).thenReturn(null);

        expect(authService.currentUserId, isNull);
      });
    });

    group('isAuthenticated', () {
      test('returns true when user is authenticated', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        expect(authService.isAuthenticated, isTrue);
      });

      test('returns false when no user is authenticated', () {
        when(mockAuth.currentUser).thenReturn(null);

        expect(authService.isAuthenticated, isFalse);
      });
    });

    group('requireAuthenticatedUser', () {
      test('returns user ID when user is authenticated', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        final userId = authService.requireAuthenticatedUser();

        expect(userId, equals('user-123'));
        verifyNever(mockLogger.warning(any));
      });

      test('throws AuthorizationException when no user is authenticated', () {
        when(mockAuth.currentUser).thenReturn(null);

        expect(
          () => authService.requireAuthenticatedUser(),
          throwsA(isA<AuthorizationException>().having(
            (e) => e.message,
            'message',
            'User must be authenticated to perform this operation',
          )),
        );
      });

      test('logs security warning when authentication fails', () {
        when(mockAuth.currentUser).thenReturn(null);

        expect(
          () => authService.requireAuthenticatedUser(context: 'deleteNote'),
          throwsA(isA<AuthorizationException>()),
        );

        verify(mockLogger.warning(
          'SECURITY: Authorization failed: No authenticated user (deleteNote)',
        )).called(1);
      });

      test('includes context in exception when provided', () {
        when(mockAuth.currentUser).thenReturn(null);

        expect(
          () => authService.requireAuthenticatedUser(context: 'updateTask'),
          throwsA(isA<AuthorizationException>().having(
            (e) => e.resourceType,
            'resourceType',
            'updateTask',
          )),
        );
      });
    });

    group('verifyOwnership', () {
      test('allows access when user owns the resource', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        // Should not throw
        authService.verifyOwnership(
          resourceUserId: 'user-123',
          resourceType: 'Note',
          resourceId: 'note-456',
        );

        verify(mockLogger.debug(argThat(contains('Authorization granted')))).called(1);
      });

      test('throws AuthorizationException when user does not own resource', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        expect(
          () => authService.verifyOwnership(
            resourceUserId: 'user-999',
            resourceType: 'Note',
            resourceId: 'note-456',
          ),
          throwsA(isA<AuthorizationException>().having(
            (e) => e.message,
            'message',
            contains('You do not have permission to access this Note'),
          )),
        );
      });

      test('throws AuthorizationException when no user is authenticated', () {
        when(mockAuth.currentUser).thenReturn(null);

        expect(
          () => authService.verifyOwnership(
            resourceUserId: 'user-123',
            resourceType: 'Note',
            resourceId: 'note-456',
          ),
          throwsA(isA<AuthorizationException>()),
        );
      });

      test('logs security audit trail for denied access', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        expect(
          () => authService.verifyOwnership(
            resourceUserId: 'user-999',
            resourceType: 'Note',
            resourceId: 'note-456',
          ),
          throwsA(isA<AuthorizationException>()),
        );

        verify(mockLogger.warning(
          argThat(contains('SECURITY: Authorization failed')),
        )).called(1);
      });

      test('includes resource type in exception', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        expect(
          () => authService.verifyOwnership(
            resourceUserId: 'user-999',
            resourceType: 'Task',
            resourceId: 'task-789',
            operation: 'delete',
          ),
          throwsA(isA<AuthorizationException>().having(
            (e) => e.resourceType,
            'resourceType',
            'Task',
          )),
        );
      });

      test('throws when resourceUserId is null', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        expect(
          () => authService.verifyOwnership(
            resourceUserId: null,
            resourceType: 'Note',
            resourceId: 'note-456',
          ),
          throwsA(isA<AuthorizationException>().having(
            (e) => e.message,
            'message',
            contains('Resource has no owner'),
          )),
        );
      });

      test('supports custom operation in error messages', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        expect(
          () => authService.verifyOwnership(
            resourceUserId: 'user-999',
            resourceType: 'Note',
            resourceId: 'note-456',
            operation: 'delete',
          ),
          throwsA(isA<AuthorizationException>().having(
            (e) => e.message,
            'message',
            contains('delete'),
          )),
        );
      });
    });

    group('isOwner', () {
      test('returns true when user owns the resource', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        final result = authService.isOwner('user-123');

        expect(result, isTrue);
      });

      test('returns false when user does not own resource', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        final result = authService.isOwner('user-999');

        expect(result, isFalse);
      });

      test('returns false when no user is authenticated', () {
        when(mockAuth.currentUser).thenReturn(null);

        final result = authService.isOwner('user-123');

        expect(result, isFalse);
      });

      test('returns false when resourceUserId is null', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        final result = authService.isOwner(null);

        expect(result, isFalse);
      });
    });

    group('verifyBatchOwnership', () {
      setUp(() {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');
      });

      test('allows access when user owns all resources', () {
        final resources = [
          ('user-123', 'note-1'),
          ('user-123', 'note-2'),
          ('user-123', 'note-3'),
        ];

        // Should not throw
        authService.verifyBatchOwnership(
          resources: resources,
          resourceType: 'Note',
        );

        verify(mockLogger.debug(argThat(contains('Batch authorization granted')))).called(1);
      });

      test('throws on first unauthorized resource', () {
        final resources = [
          ('user-123', 'note-1'), // authorized
          ('user-999', 'note-2'), // unauthorized - should fail here
          ('user-123', 'note-3'), // won't be checked
        ];

        expect(
          () => authService.verifyBatchOwnership(
            resources: resources,
            resourceType: 'Note',
          ),
          throwsA(isA<AuthorizationException>().having(
            (e) => e.resourceId,
            'resourceId',
            'note-2',
          )),
        );
      });

      test('throws when any resource has null userId', () {
        final resources = [
          ('user-123', 'note-1'),
          (null, 'note-2'), // null userId
        ];

        expect(
          () => authService.verifyBatchOwnership(
            resources: resources,
            resourceType: 'Note',
          ),
          throwsA(isA<AuthorizationException>()),
        );
      });

      test('handles empty resource list', () {
        // Should not throw for empty list
        authService.verifyBatchOwnership(
          resources: const [],
          resourceType: 'Note',
        );

        // Should log debug message
        verify(mockLogger.debug(argThat(contains('Batch authorization granted')))).called(1);
      });

      test('supports custom operation in error messages', () {
        final resources = [
          ('user-123', 'note-1'),
          ('user-999', 'note-2'),
        ];

        expect(
          () => authService.verifyBatchOwnership(
            resources: resources,
            resourceType: 'Note',
            operation: 'delete',
          ),
          throwsA(isA<AuthorizationException>().having(
            (e) => e.message,
            'message',
            contains('delete'),
          )),
        );
      });

      test('logs security warning for batch failures', () {
        final resources = [
          ('user-123', 'note-1'),
          ('user-999', 'note-2'),
        ];

        expect(
          () => authService.verifyBatchOwnership(
            resources: resources,
            resourceType: 'Note',
          ),
          throwsA(isA<AuthorizationException>()),
        );

        verify(mockLogger.warning(
          argThat(contains('Batch authorization failed')),
        )).called(1);
      });
    });

    group('Security Edge Cases', () {
      test('prevents timing attacks by consistent execution time', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        final stopwatch1 = Stopwatch()..start();
        final result1 = authService.isOwner('user-123');
        stopwatch1.stop();

        final stopwatch2 = Stopwatch()..start();
        final result2 = authService.isOwner('user-999');
        stopwatch2.stop();

        expect(result1, isTrue);
        expect(result2, isFalse);

        // Execution times should be roughly similar (within 10ms for safety)
        expect(
          (stopwatch1.elapsedMicroseconds - stopwatch2.elapsedMicroseconds).abs(),
          lessThan(10000),
        );
      });

      test('handles concurrent authorization checks safely', () async {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        // Run 100 concurrent authorization checks
        final futures = List.generate(100, (i) {
          return Future(() {
            try {
              authService.verifyOwnership(
                resourceUserId: i % 2 == 0 ? 'user-123' : 'user-999',
                resourceType: 'Note',
                resourceId: 'note-$i',
              );
              return true; // Success
            } catch (e) {
              return false; // Failure
            }
          });
        });

        final results = await Future.wait(futures);

        // Should have 50 successes and 50 failures
        final successes = results.where((r) => r == true).length;
        expect(successes, equals(50));
      });

      test('maintains security under rapid-fire authentication state changes', () {
        // Simulate user logging out mid-check
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.id).thenReturn('user-123');

        expect(authService.isAuthenticated, isTrue);

        // User logs out
        when(mockAuth.currentUser).thenReturn(null);

        expect(authService.isAuthenticated, isFalse);
        expect(
          () => authService.requireAuthenticatedUser(),
          throwsA(isA<AuthorizationException>()),
        );
      });
    });
  });
}
