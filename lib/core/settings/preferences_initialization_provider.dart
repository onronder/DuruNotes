import 'package:duru_notes/core/settings/preferences_initializer.dart';
import 'package:duru_notes/features/settings/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider that initializes user preferences on authentication
///
/// This provider:
/// 1. Watches auth state
/// 2. When user logs in, checks if preferences need initialization
/// 3. Syncs local preferences to database if needed
/// 4. Runs once per login session
final preferencesInitializationProvider = FutureProvider<bool>((ref) async {
  // Watch auth state - rebuilds when user logs in/out
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  // If no user, return false (not initialized, not needed)
  if (user == null) {
    return false;
  }

  // Get dependencies (imported from settings_providers.dart)
  final logger = ref.watch(loggerProvider);
  final preferencesService = ref.watch(userPreferencesServiceProvider);

  // Create initializer
  final initializer = PreferencesInitializer(
    preferencesService: preferencesService,
    logger: logger,
  );

  try {
    // Check if initialization is needed
    final needsInit = await initializer.needsInitialization();

    if (needsInit) {
      logger.info('[PreferencesInit] Initializing preferences for user ${user.id.substring(0, 8)}');
      await initializer.initialize();
      return true;
    } else {
      logger.info('[PreferencesInit] No initialization needed for user ${user.id.substring(0, 8)}');
      return false;
    }
  } catch (e) {
    // Don't throw - this is a non-critical operation
    logger.error(
      '[PreferencesInit] Error during preferences initialization',
      error: e,
    );
    return false;
  }
});
