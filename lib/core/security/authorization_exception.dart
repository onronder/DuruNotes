/// Exception thrown when a user attempts to access a resource they don't own
class AuthorizationException implements Exception {
  final String message;
  final String? resourceType;
  final String? resourceId;
  final String? userId;

  const AuthorizationException({
    required this.message,
    this.resourceType,
    this.resourceId,
    this.userId,
  });

  @override
  String toString() {
    final details = [
      if (resourceType != null) 'Resource: $resourceType',
      if (resourceId != null) 'ID: $resourceId',
      if (userId != null) 'User: $userId',
    ].join(', ');

    return 'AuthorizationException: $message${details.isNotEmpty ? ' ($details)' : ''}';
  }
}
