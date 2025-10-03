import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/security/authorization_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the authorization service
///
/// This service should be injected into all repositories that need to
/// enforce authorization checks.
final authorizationServiceProvider = Provider<AuthorizationService>((ref) {
  return AuthorizationService(
    supabase: Supabase.instance.client,
    logger: LoggerFactory.instance,
  );
});
