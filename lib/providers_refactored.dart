// Main providers file - imports all feature modules
// This file maintains backward compatibility while organizing providers into feature modules

// Export important types for easier importing
export 'data/local/app_db.dart' show AppDb, LocalNote;
export 'features/notes/pagination_notifier.dart' show NotesPage;

// Core infrastructure providers
export 'core/providers/core_providers.dart';

// Feature module providers
export 'features/auth/providers/auth_providers_barrel.dart';
export 'features/notes/providers/notes_providers.dart';
export 'features/folders/providers/folders_providers.dart';
export 'features/tasks/providers/tasks_providers.dart';
export 'features/templates/providers/templates_providers_barrel.dart';
export 'features/sync/providers/sync_providers_barrel.dart';
export 'features/search/providers/search_providers_barrel.dart';
export 'features/settings/providers/settings_providers_barrel.dart';

// Services providers
export 'services/providers/services_providers_barrel.dart';

// Providers that haven't been migrated yet (placeholder for incremental migration)
// These will be migrated and removed as dependencies are resolved