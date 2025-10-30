import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/security/authorization_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Production-grade authorization service for enforcing data access controls
///
/// This service implements the principle of least privilege and ensures users
/// can only access resources they own. All repository methods should use this
/// service to verify authorization before performing operations.
///
/// **Security Model:**
/// - Every resource (note, task, folder, template) has an owner (userId)
/// - Users can only access resources where resource.userId == currentUser.id
/// - Authorization is fail-safe: if userId is missing/null, access is DENIED
/// - All authorization failures are logged for security audit trails
///
/// **Performance:**
/// - Lightweight checks (simple string comparison)
/// - No database queries (userId is already loaded)
/// - Fails fast on authorization violations
class AuthorizationService {
  final SupabaseClient _supabase;
  final AppLogger _logger;

  AuthorizationService({required SupabaseClient supabase, AppLogger? logger})
    : _supabase = supabase,
      _logger = logger ?? LoggerFactory.instance;

  /// Get the currently authenticated user's ID
  ///
  /// Returns null if no user is authenticated.
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Require the current user to be authenticated
  ///
  /// Throws [AuthorizationException] if no user is authenticated.
  String requireAuthenticatedUser({String? context}) {
    final userId = currentUserId;
    if (userId == null) {
      _logger.warning(
        'SECURITY: Authorization failed: No authenticated user${context != null ? ' ($context)' : ''}',
      );
      throw AuthorizationException(
        message: 'User must be authenticated to perform this operation',
        resourceType: context,
      );
    }
    return userId;
  }

  /// Verify that a resource belongs to the current user
  ///
  /// This is the primary authorization check for resource access.
  ///
  /// **Parameters:**
  /// - [resourceUserId]: The userId of the resource being accessed
  /// - [resourceType]: Type of resource (e.g., 'note', 'task', 'folder')
  /// - [resourceId]: ID of the resource being accessed
  /// - [operation]: Operation being performed (e.g., 'read', 'update', 'delete')
  ///
  /// **Throws:**
  /// - [AuthorizationException] if the resource doesn't belong to the current user
  /// - [AuthorizationException] if no user is authenticated
  ///
  /// **Example:**
  /// ```dart
  /// authService.verifyOwnership(
  ///   resourceUserId: note.userId,
  ///   resourceType: 'note',
  ///   resourceId: note.id,
  ///   operation: 'update',
  /// );
  /// ```
  void verifyOwnership({
    required String? resourceUserId,
    required String resourceType,
    required String resourceId,
    String operation = 'access',
  }) {
    final currentUser = requireAuthenticatedUser(
      context: '$operation $resourceType',
    );

    // Fail-safe: if resource has no userId, deny access
    if (resourceUserId == null) {
      _logger.warning(
        'SECURITY: Authorization failed: $resourceType $resourceId has no userId (attempted by $currentUser)',
      );
      throw AuthorizationException(
        message: 'Resource has no owner - access denied',
        resourceType: resourceType,
        resourceId: resourceId,
        userId: currentUser,
      );
    }

    // Check if current user owns the resource
    if (resourceUserId != currentUser) {
      _logger.warning(
        'SECURITY: Authorization failed: User $currentUser attempted to $operation $resourceType $resourceId owned by $resourceUserId',
      );
      throw AuthorizationException(
        message: 'You do not have permission to $operation this $resourceType',
        resourceType: resourceType,
        resourceId: resourceId,
        userId: currentUser,
      );
    }

    // Authorization successful - log for audit trail
    _logger.debug(
      'Authorization granted: User $currentUser can $operation $resourceType $resourceId',
    );
  }

  /// Verify ownership of multiple resources in batch
  ///
  /// This is more efficient than calling verifyOwnership multiple times
  /// when you have multiple resources to check.
  ///
  /// **Throws:**
  /// - [AuthorizationException] if ANY resource fails authorization
  ///
  /// **Example:**
  /// ```dart
  /// authService.verifyBatchOwnership(
  ///   resources: notes.map((n) =&gt; (n.userId, n.id)).toList(),
  ///   resourceType: 'note',
  ///   operation: 'delete',
  /// );
  /// ```
  void verifyBatchOwnership({
    required List<(String? userId, String id)> resources,
    required String resourceType,
    String operation = 'access',
  }) {
    final currentUser = requireAuthenticatedUser(
      context: '$operation $resourceType',
    );

    for (final (userId, id) in resources) {
      if (userId == null || userId != currentUser) {
        _logger.warning(
          'SECURITY: Batch authorization failed: User $currentUser attempted to $operation $resourceType $id',
        );
        throw AuthorizationException(
          message:
              'You do not have permission to $operation these ${resourceType}s',
          resourceType: resourceType,
          resourceId: id,
          userId: currentUser,
        );
      }
    }

    _logger.debug(
      'Batch authorization granted: User $currentUser can $operation ${resources.length} ${resourceType}s',
    );
  }

  /// Check if the current user owns a resource (non-throwing version)
  ///
  /// Returns true if authorized, false otherwise. Use this when you want to
  /// conditionally show UI elements based on authorization without throwing.
  ///
  /// **Example:**
  /// ```dart
  /// if (authService.isOwner(note.userId)) {
  ///   // Show edit button
  /// }
  /// ```
  bool isOwner(String? resourceUserId) {
    final currentUser = currentUserId;
    if (currentUser == null || resourceUserId == null) {
      return false;
    }
    return resourceUserId == currentUser;
  }

  /// Check if user is authenticated (non-throwing version)
  bool get isAuthenticated => currentUserId != null;
}
