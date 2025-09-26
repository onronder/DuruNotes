# Providers Refactoring Plan

## Overview

This document outlines the comprehensive refactoring plan for the massive `lib/providers.dart` file (1661 lines, 107 providers) into organized feature modules. The goal is to improve maintainability, reduce coupling, and make the codebase more scalable.

## Current State

- **Original file**: `lib/providers.dart` (1661 lines, 107 providers)
- **Issues**:
  - Extremely large monolithic file
  - Difficult to maintain and navigate
  - High coupling between unrelated features
  - Poor separation of concerns

## New Structure

### Core Infrastructure Providers
**Location**: `lib/core/providers/`

- `database_providers.dart` - Database, crypto, and key management
- `infrastructure_providers.dart` - Logging, analytics, migration config

**Key providers**:
- `appDbProvider`
- `keyManagerProvider`
- `cryptoBoxProvider`
- `noteIndexerProvider`
- `loggerProvider`
- `analyticsProvider`
- `migrationConfigProvider`

### Authentication Providers
**Location**: `lib/features/auth/providers/`

- `auth_providers.dart` - Authentication state and user management

**Key providers**:
- `authStateChangesProvider`
- `supabaseClientProvider`
- `userIdProvider`

### Notes Providers
**Location**: `lib/features/notes/providers/`

- `notes_repository_providers.dart` - Repository and API providers
- `notes_domain_providers.dart` - Domain entity providers
- `notes_pagination_providers.dart` - Pagination and filtering
- `notes_conditional_providers.dart` - Migration conditional logic

**Key providers**:
- `notesRepositoryProvider`
- `notesCoreRepositoryProvider`
- `domainNotesStreamProvider`
- `notesPageProvider`
- `dualNotesPageProvider`
- `filteredNotesProvider`
- `currentNotesProvider`

### Folders Providers
**Location**: `lib/features/folders/providers/`

- `folders_repository_providers.dart` - Repository providers
- `folders_state_providers.dart` - State management
- `folders_integration_providers.dart` - Integration and derived providers

**Key providers**:
- `folderRepositoryProvider`
- `folderCoreRepositoryProvider`
- `folderHierarchyProvider`
- `currentFolderProvider`
- `rootFoldersProvider`
- `domainFoldersProvider`

### Tasks Providers
**Location**: `lib/features/tasks/providers/`

- `tasks_repository_providers.dart` - Task repositories
- `tasks_domain_providers.dart` - Domain task entities
- `tasks_services_providers.dart` - Task services and unified system

**Key providers**:
- `taskServiceProvider`
- `taskCoreRepositoryProvider`
- `unifiedTaskServiceProvider`
- `domainTasksStreamProvider`
- `taskAnalyticsServiceProvider`

### Templates Providers
**Location**: `lib/features/templates/providers/`

- `templates_providers.dart` - Template management and migration

**Key providers**:
- `templateRepositoryProvider`
- `templateCoreRepositoryProvider`
- `templateListProvider`
- `domainTemplatesProvider`

### Sync Providers
**Location**: `lib/features/sync/providers/`

- `sync_providers.dart` - Synchronization and realtime services

**Key providers**:
- `syncServiceProvider`
- `syncModeProvider`
- `unifiedRealtimeServiceProvider`
- `folderSyncCoordinatorProvider`

### Search Providers
**Location**: `lib/features/search/providers/`

- `search_providers.dart` - Search functionality and preferences

**Key providers**:
- `searchServiceProvider`
- `tagRepositoryInterfaceProvider`
- `filterStateProvider`
- `currentSortSpecProvider`

### Settings Providers
**Location**: `lib/features/settings/providers/`

- `settings_providers.dart` - User preferences and configuration

**Key providers**:
- `themeModeProvider`
- `localeProvider`
- `analyticsSettingsProvider`

### Services Providers
**Location**: `lib/services/providers/`

- `services_providers.dart` - Miscellaneous services

**Key providers**:
- `exportServiceProvider`
- `importServiceProvider`
- `attachmentServiceProvider`
- `notificationHandlerServiceProvider`

## Migration Strategy

### Phase 1: Create Module Structure ✅
- Create directory structure for all feature modules
- Create individual provider files with proper categorization
- Handle cross-module dependencies with placeholders

### Phase 2: Fix Dependencies (Next Step)
The current implementation has placeholder imports that need to be resolved:

```dart
// Current placeholder (needs fixing):
final repo = null; // ref.watch(notesRepositoryProvider);

// Should become:
final repo = ref.watch(notesRepositoryProvider);
```

### Phase 3: Update Imports
- Update all consumer files to use new module imports
- Replace imports from `lib/providers.dart` with specific module imports
- Test for any missing or broken dependencies

### Phase 4: Gradual Migration
- Initially, keep both old and new provider files
- Gradually migrate consumers to use new structure
- Remove old providers.dart once migration is complete

## Usage Guide

### Importing Providers

**Old way**:
```dart
import 'package:duru_notes/providers.dart';
```

**New way** (specific modules):
```dart
import 'package:duru_notes/core/providers/core_providers.dart';
import 'package:duru_notes/features/notes/providers/notes_providers.dart';
import 'package:duru_notes/features/folders/providers/folders_providers.dart';
```

**New way** (all providers):
```dart
import 'package:duru_notes/providers_refactored.dart';
```

### Adding New Providers

1. Identify the appropriate feature module
2. Add provider to the relevant file within that module
3. Export it in the module's barrel file
4. Update documentation

### Barrel Files

Each module has a barrel file that exports all providers:
- `lib/core/providers/core_providers.dart`
- `lib/features/notes/providers/notes_providers.dart`
- `lib/features/folders/providers/folders_providers.dart`
- etc.

## Dependencies to Fix

The following cross-module dependencies need to be resolved:

1. **Folders → Notes**: `notesRepositoryProvider`
2. **Sync → Notes**: `notesPageProvider`, `dualNotesPageProvider`
3. **Sync → Folders**: `folderHierarchyProvider`
4. **Services → Various**: Multiple cross-module dependencies
5. **Search → Folders**: `currentFolderProvider`

## Benefits

1. **Maintainability**: Smaller, focused files are easier to understand and modify
2. **Separation of Concerns**: Each module handles its specific domain
3. **Reduced Coupling**: Clear boundaries between features
4. **Scalability**: Easy to add new features without affecting existing code
5. **Testing**: Easier to unit test individual modules
6. **Code Navigation**: Developers can quickly find relevant providers
7. **Parallel Development**: Teams can work on different modules independently

## Next Steps

1. ✅ Create module structure and provider files
2. 🔄 Fix cross-module dependencies (in progress)
3. ⏳ Update all import statements throughout the codebase
4. ⏳ Test thoroughly to ensure no broken dependencies
5. ⏳ Remove original providers.dart file
6. ⏳ Update documentation and development guidelines

## Files Created

### Core Providers
- `/Users/onronder/duru-notes/lib/core/providers/database_providers.dart`
- `/Users/onronder/duru-notes/lib/core/providers/infrastructure_providers.dart`
- `/Users/onronder/duru-notes/lib/core/providers/core_providers.dart`

### Feature Modules
- `/Users/onronder/duru-notes/lib/features/auth/providers/auth_providers.dart`
- `/Users/onronder/duru-notes/lib/features/notes/providers/notes_repository_providers.dart`
- `/Users/onronder/duru-notes/lib/features/notes/providers/notes_domain_providers.dart`
- `/Users/onronder/duru-notes/lib/features/notes/providers/notes_pagination_providers.dart`
- `/Users/onronder/duru-notes/lib/features/notes/providers/notes_conditional_providers.dart`
- `/Users/onronder/duru-notes/lib/features/folders/providers/folders_repository_providers.dart`
- `/Users/onronder/duru-notes/lib/features/folders/providers/folders_state_providers.dart`
- `/Users/onronder/duru-notes/lib/features/folders/providers/folders_integration_providers.dart`
- `/Users/onronder/duru-notes/lib/features/tasks/providers/tasks_repository_providers.dart`
- `/Users/onronder/duru-notes/lib/features/tasks/providers/tasks_domain_providers.dart`
- `/Users/onronder/duru-notes/lib/features/tasks/providers/tasks_services_providers.dart`
- `/Users/onronder/duru-notes/lib/features/templates/providers/templates_providers.dart`
- `/Users/onronder/duru-notes/lib/features/sync/providers/sync_providers.dart`
- `/Users/onronder/duru-notes/lib/features/search/providers/search_providers.dart`
- `/Users/onronder/duru-notes/lib/features/settings/providers/settings_providers.dart`
- `/Users/onronder/duru-notes/lib/services/providers/services_providers.dart`

### Barrel Files
- All corresponding `*_barrel.dart` or main export files for each module

### Main Entry Point
- `/Users/onronder/duru-notes/lib/providers_refactored.dart`

## Impact Assessment

This refactoring affects:
- **Maintainability**: ⬆️ Significantly improved
- **Performance**: ➡️ No impact (same providers, just organized)
- **Development Speed**: ⬆️ Improved (easier to find and modify providers)
- **Code Quality**: ⬆️ Much improved organization and separation of concerns
- **Testing**: ⬆️ Easier to test individual modules
- **Onboarding**: ⬆️ New developers can understand the structure more easily

This refactoring provides a solid foundation for the application's continued growth and development.