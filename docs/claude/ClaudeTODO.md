# 🚀 Duru Notes - Production Roadmap & TODO List

> **Document Version**: 2.0.0
> **Last Updated**: September 21, 2025
> **Author**: Claude AI Assistant
> **Purpose**: Comprehensive production roadmap with detailed micro-tasks for progress tracking

## 📊 Executive Summary

### Current State Assessment
- **Analyzer Issues**: 1,529 (critical: ~200, warnings: ~1,300)
- **Technical Debt Score**: 8/10 (High)
- **Feature Completeness**: 45%
- **Production Readiness**: 3/10

### Key Problems Identified
1. **Legacy Code**: 7 legacy widget files, duplicate service implementations
2. **Code Quality**: 102 print statements, 73 withOpacity deprecations, 44 TODO/FIXME comments
3. **Architecture Issues**: 6 parallel task services, duplicate reminder services, global singletons
4. **Missing Features**: Folders CRUD, share extension, templates, import/export, tasks/reminders UI

### Timeline Overview
- **Total Duration**: 37 working days (~7-8 weeks)
- **MVP Possible**: Day 25 (after Phase 4)
- **Production Ready**: Day 37
- **Daily Effort**: 6-8 hours focused development

---

## 📈 Progress Tracking Dashboard

### Overall Progress
- **Total Main Tasks**: 37
- **Total Micro-Tasks**: ~500
- **Completed**: 0
- **In Progress**: 0
- **Remaining**: 500
- **Completion**: 0%

### Phase Progress
- [ ] Phase 0: Emergency Stabilization (0/3 days)
- [ ] Phase 1: Service Consolidation (0/4 days)
- [ ] Phase 2: Core Infrastructure (0/5 days)
- [ ] Phase 3: Data Layer Cleanup (0/3 days)
- [ ] Phase 4: Complete Core Features (0/10 days)
- [ ] Phase 5: UI/UX Polish (0/3 days)
- [ ] Phase 6: Testing & Quality (0/4 days)
- [ ] Phase 7: Production Hardening (0/3 days)
- [ ] Phase 8: Release Preparation (0/2 days)

---

## 🎯 Phase 0: Emergency Stabilization
**Duration**: Days 1-3
**Goal**: Stop the bleeding - remove obvious problems blocking production
**Status**: ⏳ Not Started

### Day 1: Legacy Code Removal
**Main Task**: Remove all legacy and deprecated code

#### Delete Legacy Widget Files
- [ ] Navigate to lib/ui/widgets directory
- [ ] Delete legacy files:
  - [ ] `lib/ui/widgets/blocks/hierarchical_todo_block_widget_legacy.dart`
  - [ ] `lib/ui/widgets/blocks/todo_block_widget_legacy.dart`
  - [ ] `lib/ui/widgets/hierarchical_task_list_view_legacy.dart`
  - [ ] `lib/ui/widgets/shared/task_item_legacy.dart`
  - [ ] `lib/ui/widgets/task_item_widget_legacy.dart`
  - [ ] `lib/ui/widgets/task_item_with_actions_legacy.dart`
  - [ ] `lib/ui/widgets/task_tree_widget_legacy.dart`
- [ ] Search for any imports of deleted files:
  ```bash
  grep -r "import.*_legacy" lib --include="*.dart"
  ```
- [ ] Remove found import statements
- [ ] Run analyzer to verify no broken imports:
  ```bash
  flutter analyze | grep "legacy"
  ```

#### Delete Backup and Temporary Files
- [ ] Find all backup files:
  ```bash
  find lib -name "*.backup" -o -name "*.bak" -o -name "*.tmp"
  ```
- [ ] Delete identified files:
  - [ ] `lib/ui/widgets/tasks/task_list_item.dart.backup`
  - [ ] Any `.bak` files found
  - [ ] Any `.tmp` files found
- [ ] Verify deletion:
  ```bash
  find lib -name "*.backup" -o -name "*.bak" -o -name "*.tmp" | wc -l  # Should be 0
  ```

#### Remove Duplicate Imports in Crypto Modules
- [ ] Open `lib/core/crypto/crypto_box.dart`
- [ ] Identify duplicate imports (lines 3-8):
  - [ ] Remove duplicate `dart:typed_data` import (line 3)
  - [ ] Remove duplicate import on line 4
  - [ ] Remove duplicate import on line 6
  - [ ] Remove duplicate import on line 8
- [ ] Check other crypto files:
  - [ ] `lib/core/crypto/key_manager.dart`
  - [ ] Any other files in crypto directory
- [ ] Run analyzer on crypto module:
  ```bash
  flutter analyze lib/core/crypto/
  ```

#### Documentation and Commit
- [ ] Document removed files in CHANGELOG
- [ ] Update any documentation referencing legacy files
- [ ] Stage all deletions:
  ```bash
  git add -u
  ```
- [ ] Create commit:
  ```bash
  git commit -m "chore: remove legacy widget files and backups

  - Removed 7 legacy widget files
  - Deleted backup and temporary files
  - Fixed duplicate imports in crypto modules

  Part of Phase 0 production cleanup"
  ```

### Day 2: Print Statement Cleanup
**Main Task**: Replace all print statements with proper logging

#### Identify All Print Statements
- [ ] Generate list of files with print statements:
  ```bash
  grep -r "print(" lib --include="*.dart" > print_statements.txt
  ```
- [ ] Count by file:
  ```bash
  grep -r "print(" lib --include="*.dart" | cut -d: -f1 | sort | uniq -c
  ```
- [ ] Priority files to fix (highest count first):
  - [ ] `lib/services/folder_realtime_service.dart` (26 occurrences)
  - [ ] `lib/services/inbound_email_service.dart` (8 occurrences)
  - [ ] `lib/services/enhanced_task_service.dart` (17 occurrences)
  - [ ] `lib/app/app.dart` (22 occurrences)
  - [ ] `lib/providers.dart` (12 occurrences)
  - [ ] `lib/core/performance/performance_optimizations.dart` (2 occurrences)
  - [ ] `lib/data/local/app_db.dart` (10 occurrences)
  - [ ] `lib/features/folders/smart_folders/smart_folder_engine.dart` (1 occurrence)
  - [ ] `lib/providers/unified_reminder_provider.dart` (2 occurrences)
  - [ ] `lib/services/notification_handler_service.dart` (2 occurrences)

#### Replace Print Statements in Each File
- [ ] **lib/services/folder_realtime_service.dart** (26 prints):
  - [ ] Import logger at top of file
  - [ ] Replace informational prints with `logger.d()`
  - [ ] Replace error prints with `logger.e()`
  - [ ] Replace warning prints with `logger.w()`
  - [ ] Test service still works

- [ ] **lib/services/enhanced_task_service.dart** (17 prints):
  - [ ] Import logger
  - [ ] Replace sync status prints with `logger.i()`
  - [ ] Replace error prints with `logger.e()`
  - [ ] Replace debug prints with `logger.d()`
  - [ ] Verify task sync still functions

- [ ] **lib/app/app.dart** (22 prints):
  - [ ] Import logger
  - [ ] Replace navigation prints with `logger.d()`
  - [ ] Replace initialization prints with `logger.i()`
  - [ ] Test app startup

- [ ] **Other files** (remaining ~37 prints):
  - [ ] Process each file systematically
  - [ ] Ensure consistent logging levels
  - [ ] Remove commented-out print statements

#### Verify Complete Removal
- [ ] Run final check:
  ```bash
  grep -r "print(" lib --include="*.dart" | wc -l  # Should be 0
  ```
- [ ] Check for debugPrint as well:
  ```bash
  grep -r "debugPrint(" lib --include="*.dart"
  ```
- [ ] Replace any debugPrint with logger

#### Testing and Commit
- [ ] Run app and verify logging works
- [ ] Check log output format
- [ ] Ensure no console spam
- [ ] Commit changes:
  ```bash
  git commit -m "refactor: replace all print statements with logger

  - Replaced 102 print statements across 10 files
  - Using appropriate log levels (debug, info, warning, error)
  - Consistent logging format throughout app

  Part of Phase 0 production cleanup"
  ```

### Day 3: Automated Fixes and Deprecations
**Main Task**: Fix all deprecation warnings and apply automated fixes

#### Fix withOpacity Deprecations
- [ ] Find all withOpacity usages:
  ```bash
  grep -r "\.withOpacity(" lib --include="*.dart" > withopacity_list.txt
  ```
- [ ] Files to fix (73 occurrences):
  - [ ] **lib/theme/material3_theme.dart** (42 occurrences):
    - [ ] Replace each `color.withOpacity(0.x)` with `color.withAlpha((0.x * 255).round())`
    - [ ] Test theme still renders correctly
  - [ ] **lib/ui/auth_screen.dart** (2 occurrences):
    - [ ] Fix opacity calls
    - [ ] Verify auth screen appearance
  - [ ] **lib/ui/productivity_analytics_screen.dart** (3 occurrences):
    - [ ] Update opacity usage
    - [ ] Check charts render correctly
  - [ ] **lib/ui/screens/task_management_screen.dart** (3 occurrences):
    - [ ] Fix deprecations
    - [ ] Test task screen
  - [ ] **Other files** (remaining 23 occurrences):
    - [ ] Fix each file systematically
    - [ ] Test affected screens

#### Fix withValues Deprecations
- [ ] Find all withValues usages:
  ```bash
  grep -r "\.withValues(" lib --include="*.dart"
  ```
- [ ] Replace with appropriate Color methods
- [ ] Test color rendering

#### Apply Dart Fix
- [ ] Run dart fix in dry-run mode:
  ```bash
  dart fix --dry-run
  ```
- [ ] Review proposed fixes
- [ ] Apply fixes:
  ```bash
  dart fix --apply
  ```
- [ ] Review changes made by dart fix
- [ ] Test app still compiles

#### Fix Remaining Analyzer Issues
- [ ] Generate detailed analyzer report:
  ```bash
  flutter analyze --no-fatal-warnings > analyzer_report.txt
  ```
- [ ] Fix critical issues:
  - [ ] Type inference failures
  - [ ] Unused imports
  - [ ] Dead code warnings
  - [ ] Null safety issues
- [ ] Document unfixable issues for later phases

#### Final Verification
- [ ] Run analyzer again:
  ```bash
  flutter analyze | wc -l  # Target: < 500 issues
  ```
- [ ] Ensure app builds:
  ```bash
  flutter build ios --debug
  flutter build apk --debug
  ```
- [ ] Run basic smoke tests

#### Commit Phase 0 Completion
- [ ] Create comprehensive commit:
  ```bash
  git commit -m "fix: resolve deprecations and critical analyzer issues

  - Fixed 73 withOpacity deprecations
  - Applied automated dart fixes
  - Reduced analyzer issues from 1529 to <500
  - App builds successfully on iOS and Android

  Phase 0 Emergency Stabilization complete"
  ```

**Phase 0 Success Metrics**:
- [ ] ✅ No legacy files in codebase
- [ ] ✅ Zero print statements
- [ ] ✅ Analyzer issues < 500
- [ ] ✅ App builds without errors
- [ ] ✅ Basic functionality intact

---

## 🔧 Phase 1: Service Layer Consolidation
**Duration**: Days 4-7
**Goal**: Single source of truth for each service
**Status**: ⏳ Not Started

### Day 4-5: Task Service Unification
**Main Task**: Consolidate 6 task services into UnifiedTaskService

#### Audit Task Services
- [ ] Document current task services:
  - [ ] **lib/services/task_service.dart**:
    - [ ] List all public methods
    - [ ] Note dependencies
    - [ ] Identify unique functionality
  - [ ] **lib/services/unified_task_service.dart** ✅ (KEEP):
    - [ ] Review current implementation
    - [ ] List missing features from other services
  - [ ] **lib/services/enhanced_task_service.dart**:
    - [ ] Document enhanced features
    - [ ] Note what to migrate
  - [ ] **lib/services/bidirectional_task_sync_service.dart**:
    - [ ] Document sync logic
    - [ ] Identify merge points
  - [ ] **lib/services/hierarchical_task_sync_service.dart**:
    - [ ] Note hierarchy handling
    - [ ] Plan integration
  - [ ] **lib/services/enhanced_bidirectional_sync.dart**:
    - [ ] Review bidirectional logic
    - [ ] Document conflict resolution

#### Migrate Functionality to UnifiedTaskService
- [ ] **From TaskService**:
  - [ ] Copy basic CRUD methods:
    - [ ] `createTask()`
    - [ ] `updateTask()`
    - [ ] `deleteTask()`
    - [ ] `getTask()`
    - [ ] `getAllTasks()`
  - [ ] Migrate task status management
  - [ ] Transfer priority handling
  - [ ] Add tests for migrated methods

- [ ] **From EnhancedTaskService**:
  - [ ] Migrate enhanced features:
    - [ ] Batch operations
    - [ ] Advanced filtering
    - [ ] Task templates
  - [ ] Transfer performance optimizations
  - [ ] Copy caching logic
  - [ ] Update tests

- [ ] **From BidirectionalTaskSyncService**:
  - [ ] Integrate sync methods:
    - [ ] `syncTasksToRemote()`
    - [ ] `syncTasksFromRemote()`
    - [ ] `resolveConflicts()`
  - [ ] Merge conflict resolution
  - [ ] Add sync status tracking
  - [ ] Test sync functionality

- [ ] **From HierarchicalTaskSyncService**:
  - [ ] Add hierarchy support:
    - [ ] Parent-child relationships
    - [ ] Subtask management
    - [ ] Tree operations
  - [ ] Implement recursive operations
  - [ ] Test hierarchy features

#### Update All References
- [ ] Find all imports of old services:
  ```bash
  grep -r "import.*task_service" lib --include="*.dart"
  grep -r "import.*enhanced_task" lib --include="*.dart"
  ```
- [ ] Update imports in:
  - [ ] Providers
  - [ ] UI components
  - [ ] Other services
  - [ ] Tests
- [ ] Update provider definitions:
  - [ ] `lib/providers.dart`
  - [ ] `lib/providers/feature_flagged_providers.dart`

#### Delete Redundant Services
- [ ] Verify no references remain:
  ```bash
  grep -r "TaskService\|EnhancedTaskService\|BidirectionalTaskSyncService" lib
  ```
- [ ] Delete service files:
  - [ ] `lib/services/task_service.dart`
  - [ ] `lib/services/enhanced_task_service.dart`
  - [ ] `lib/services/bidirectional_task_sync_service.dart`
  - [ ] `lib/services/hierarchical_task_sync_service.dart`
  - [ ] `lib/services/enhanced_bidirectional_sync.dart`
- [ ] Remove related test files

#### Test Unified Implementation
- [ ] Unit tests:
  - [ ] CRUD operations
  - [ ] Sync functionality
  - [ ] Hierarchy management
  - [ ] Conflict resolution
- [ ] Integration tests:
  - [ ] Full task lifecycle
  - [ ] Sync scenarios
  - [ ] Performance benchmarks
- [ ] Manual testing:
  - [ ] Create tasks
  - [ ] Edit tasks
  - [ ] Delete tasks
  - [ ] Sync tasks

#### Commit Task Service Consolidation
- [ ] Stage all changes
- [ ] Create commit:
  ```bash
  git commit -m "refactor: consolidate task services into UnifiedTaskService

  - Merged 6 task services into single implementation
  - Preserved all functionality
  - Updated all references
  - All tests passing

  Part of Phase 1 service consolidation"
  ```

### Day 6: Reminder Service Cleanup
**Main Task**: Finalize reminder service migration

#### Rename Refactored Services
- [ ] **reminder_coordinator_refactored.dart**:
  - [ ] Rename file to `reminder_coordinator.dart`
  - [ ] Update class name if needed
  - [ ] Fix imports throughout codebase

- [ ] **snooze_reminder_service_refactored.dart**:
  - [ ] Rename to `snooze_reminder_service.dart`
  - [ ] Update references
  - [ ] Test snooze functionality

- [ ] **geofence_reminder_service_refactored.dart**:
  - [ ] Rename to `geofence_reminder_service.dart`
  - [ ] Verify geofence triggers
  - [ ] Update location permissions if needed

- [ ] **recurring_reminder_service_refactored.dart**:
  - [ ] Rename to `recurring_reminder_service.dart`
  - [ ] Test recurrence patterns
  - [ ] Verify timezone handling

#### Delete Original Versions
- [ ] Verify refactored versions have all functionality
- [ ] Delete original files:
  - [ ] Original reminder_coordinator.dart
  - [ ] Original service files
- [ ] Update imports project-wide
- [ ] Run tests to ensure nothing broke

#### Update Provider References
- [ ] Update `unified_reminder_provider.dart`
- [ ] Fix feature flag checks
- [ ] Remove conditional service loading
- [ ] Test provider functionality

#### Commit Reminder Cleanup
- [ ] Create commit:
  ```bash
  git commit -m "refactor: finalize reminder service migration

  - Renamed refactored services
  - Deleted original implementations
  - Updated all references
  - Simplified provider logic

  Part of Phase 1 service consolidation"
  ```

### Day 7: Feature Flag Cleanup
**Main Task**: Remove obsolete feature flags

#### Audit Current Feature Flags
- [ ] Review `lib/core/feature_flags.dart`:
  - [ ] List all flags:
    - [ ] `use_unified_reminders`
    - [ ] `use_new_block_editor`
    - [ ] `use_refactored_components`
    - [ ] `use_unified_permission_manager`
  - [ ] Determine which are obsolete
  - [ ] Check usage of each flag

#### Remove Obsolete Flags
- [ ] Find flag usage:
  ```bash
  grep -r "FeatureFlags\|isEnabled" lib --include="*.dart"
  ```
- [ ] Remove flags for completed migrations:
  - [ ] Remove flag definitions
  - [ ] Remove conditional logic
  - [ ] Simplify affected code
- [ ] Keep only flags for incomplete features

#### Update Feature-Flagged Components
- [ ] Review `feature_flagged_block_factory.dart`:
  - [ ] Remove if all migrations complete
  - [ ] Simplify if partially needed
- [ ] Update `feature_flagged_providers.dart`:
  - [ ] Remove conditional provider logic
  - [ ] Use direct implementations

#### Test Flag Removal
- [ ] Ensure app still builds
- [ ] Verify features work without flags
- [ ] Check no regression in functionality

#### Document Remaining Flags
- [ ] Create documentation for remaining flags
- [ ] Note purpose and removal timeline
- [ ] Update README if needed

#### Commit Feature Flag Cleanup
- [ ] Create commit:
  ```bash
  git commit -m "cleanup: remove obsolete feature flags

  - Removed completed migration flags
  - Simplified conditional logic
  - Updated providers and factories
  - Documented remaining flags

  Phase 1 Service Consolidation complete"
  ```

**Phase 1 Success Metrics**:
- [ ] ✅ Single task service implementation
- [ ] ✅ Cleaned reminder services
- [ ] ✅ Minimal feature flags
- [ ] ✅ All tests passing
- [ ] ✅ No duplicate service code

---

## 🏗️ Phase 2: Core Infrastructure
**Duration**: Days 8-12
**Goal**: Production-grade bootstrap and dependency injection
**Status**: ⏳ Not Started

### Day 8-9: Bootstrap Refactor
**Main Task**: Ensure robust application initialization

#### Review Current Bootstrap
- [ ] Analyze `lib/core/bootstrap/app_bootstrap.dart`:
  - [ ] Document current initialization order
  - [ ] Identify potential race conditions
  - [ ] Note error handling gaps
  - [ ] Check for missing services

#### Implement Initialization Sequence
- [ ] **Step 1: Environment Configuration**:
  - [ ] Load environment variables
  - [ ] Validate required configs
  - [ ] Set up fallbacks
  - [ ] Log configuration (sanitized)

- [ ] **Step 2: Core Services**:
  - [ ] Initialize logger first
  - [ ] Set up error boundaries
  - [ ] Configure crash reporting
  - [ ] Initialize monitoring

- [ ] **Step 3: External Services**:
  - [ ] Firebase initialization:
    - [ ] Add try-catch
    - [ ] Handle offline mode
    - [ ] Verify configuration
  - [ ] Supabase initialization:
    - [ ] Validate credentials
    - [ ] Test connection
    - [ ] Set up auth listeners
  - [ ] Analytics setup:
    - [ ] Initialize provider
    - [ ] Set user properties
    - [ ] Log app open event

- [ ] **Step 4: Feature Services**:
  - [ ] Load feature flags
  - [ ] Initialize notification service
  - [ ] Set up deep linking
  - [ ] Configure share extension

#### Add Comprehensive Error Handling
- [ ] Wrap each initialization in try-catch
- [ ] Create specific error types:
  ```dart
  class BootstrapError {
    final String service;
    final String message;
    final bool isCritical;
  }
  ```
- [ ] Implement retry logic for network services
- [ ] Add timeout handling
- [ ] Create fallback strategies

#### Create Bootstrap UI States
- [ ] Design loading screen:
  - [ ] App logo
  - [ ] Progress indicator
  - [ ] Loading message
- [ ] Create error screen:
  - [ ] Error message
  - [ ] Retry button
  - [ ] Offline mode option
- [ ] Implement success transition

#### Test Bootstrap Scenarios
- [ ] Test normal startup
- [ ] Test with no network
- [ ] Test with invalid credentials
- [ ] Test with missing environment vars
- [ ] Test retry functionality

#### Commit Bootstrap Improvements
- [ ] Create commit:
  ```bash
  git commit -m "refactor: production-grade bootstrap implementation

  - Robust initialization sequence
  - Comprehensive error handling
  - Retry logic for services
  - Bootstrap UI states

  Part of Phase 2 infrastructure"
  ```

### Day 10: Provider Migration
**Main Task**: Replace global singletons with dependency injection

#### Identify Global Singletons
- [ ] Find all global variables:
  ```bash
  grep -r "^late\|^final.*=.*\.instance" lib --include="*.dart"
  ```
- [ ] List to replace:
  - [ ] `logger` global
  - [ ] `analytics` global
  - [ ] `navigatorKey` global
  - [ ] Any other singletons

#### Create Riverpod Providers
- [ ] **Logger Provider**:
  ```dart
  final loggerProvider = Provider<AppLogger>((ref) {
    return LoggerFactory.instance;
  });
  ```
  - [ ] Create provider file
  - [ ] Add disposal if needed
  - [ ] Test provider access

- [ ] **Analytics Provider**:
  ```dart
  final analyticsProvider = Provider<AnalyticsService>((ref) {
    return AnalyticsFactory.instance;
  });
  ```
  - [ ] Implement provider
  - [ ] Handle initialization
  - [ ] Add event methods

- [ ] **Navigator Key Provider**:
  ```dart
  final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
    return GlobalKey<NavigatorState>();
  });
  ```
  - [ ] Create provider
  - [ ] Ensure single instance
  - [ ] Update navigation logic

#### Update All References
- [ ] Find and replace logger usage:
  - [ ] Change `logger.d()` to `ref.read(loggerProvider).d()`
  - [ ] Update in services
  - [ ] Update in UI components
  - [ ] Update in utilities

- [ ] Update analytics calls:
  - [ ] Replace direct calls with provider
  - [ ] Update event tracking
  - [ ] Fix user property setting

- [ ] Fix navigation references:
  - [ ] Update navigator key usage
  - [ ] Fix deep link handling
  - [ ] Update route management

#### Remove Global Variables
- [ ] Delete global declarations
- [ ] Remove initialization from main
- [ ] Clean up imports
- [ ] Verify no references remain

#### Test Provider Implementation
- [ ] Test logger works everywhere
- [ ] Verify analytics events fire
- [ ] Check navigation functions
- [ ] Ensure proper disposal

#### Commit Provider Migration
- [ ] Create commit:
  ```bash
  git commit -m "refactor: migrate from global singletons to providers

  - Replaced global logger with provider
  - Migrated analytics to provider
  - Fixed navigator key handling
  - Proper dependency injection throughout

  Part of Phase 2 infrastructure"
  ```

### Day 11: Environment Configuration
**Main Task**: Secure and flexible configuration management

#### Remove Hardcoded Secrets
- [ ] Search for hardcoded values:
  ```bash
  grep -r "supabase\.co\|AIza\|sk-\|pk_" lib --include="*.dart"
  ```
- [ ] Identify hardcoded:
  - [ ] Supabase URL
  - [ ] API keys
  - [ ] Secret keys
  - [ ] Service endpoints

#### Implement Secure Configuration
- [ ] Create configuration structure:
  ```dart
  class EnvironmentConfig {
    final String supabaseUrl;
    final String supabaseAnonKey;
    final String sentryDsn;
    // etc
  }
  ```
- [ ] Load from environment:
  - [ ] Use `--dart-define` for production
  - [ ] Use `.env` for development
  - [ ] Validate all required fields

#### Add Configuration Validation
- [ ] Check required fields present
- [ ] Validate URL formats
- [ ] Verify key formats
- [ ] Log configuration (sanitized)

#### Create Environment Templates
- [ ] Update `.env.example`:
  - [ ] All required variables
  - [ ] Clear descriptions
  - [ ] Example values
- [ ] Document in README:
  - [ ] Setup instructions
  - [ ] Variable explanations
  - [ ] Security notes

#### Test Configuration System
- [ ] Test with missing vars
- [ ] Test with invalid values
- [ ] Test production build
- [ ] Verify no secrets in binary

#### Commit Configuration Security
- [ ] Create commit:
  ```bash
  git commit -m "security: remove hardcoded secrets and improve config

  - Removed all hardcoded credentials
  - Implemented secure configuration loading
  - Added validation and documentation
  - Environment-based configuration

  Part of Phase 2 infrastructure"
  ```

### Day 12: Repository Pattern Implementation
**Main Task**: Abstract data access layer

#### Design Repository Interface
- [ ] Create base repository:
  ```dart
  abstract class Repository<T> {
    Future<T?> get(String id);
    Future<List<T>> getAll();
    Future<T> create(T item);
    Future<T> update(T item);
    Future<void> delete(String id);
  }
  ```
- [ ] Define specific interfaces:
  - [ ] NoteRepository
  - [ ] TaskRepository
  - [ ] FolderRepository
  - [ ] UserRepository

#### Implement Supabase Repository
- [ ] Create `SupabaseRepository`:
  - [ ] Connection management
  - [ ] Error handling
  - [ ] Retry logic
  - [ ] Response mapping

- [ ] Move Supabase calls:
  - [ ] Find all direct Supabase usage
  - [ ] Extract to repository methods
  - [ ] Update calling code
  - [ ] Remove direct imports

#### Add Caching Layer
- [ ] Implement cache strategy:
  - [ ] Memory cache for frequently accessed
  - [ ] Disk cache for offline support
  - [ ] Cache invalidation logic
  - [ ] TTL management

- [ ] Cache implementation:
  - [ ] Note caching
  - [ ] Task caching
  - [ ] Folder structure caching
  - [ ] User preferences caching

#### Test Repository Pattern
- [ ] Unit tests for repositories
- [ ] Mock Supabase responses
- [ ] Test error scenarios
- [ ] Verify caching works
- [ ] Test offline mode

#### Commit Repository Pattern
- [ ] Create commit:
  ```bash
  git commit -m "refactor: implement repository pattern for data access

  - Created repository abstractions
  - Moved Supabase calls to repositories
  - Added caching layer
  - Improved error handling

  Phase 2 Core Infrastructure complete"
  ```

**Phase 2 Success Metrics**:
- [ ] ✅ Robust bootstrap process
- [ ] ✅ No global singletons
- [ ] ✅ Secure configuration
- [ ] ✅ Repository pattern implemented
- [ ] ✅ Proper dependency injection

---

## 💾 Phase 3: Data Layer Cleanup
**Duration**: Days 13-15
**Goal**: Clean and optimized database layer
**Status**: ⏳ Not Started

### Day 13: Database Schema Cleanup
**Main Task**: Optimize database structure

#### Audit Current Schema
- [ ] Review `lib/data/local/app_db.dart`:
  - [ ] List all tables
  - [ ] Document relationships
  - [ ] Identify unused columns
  - [ ] Find missing indices

- [ ] Tables to review:
  - [ ] **notes** table:
    - [ ] Check column usage
    - [ ] Verify indices
    - [ ] Note redundant fields
  - [ ] **tasks** table:
    - [ ] Review structure
    - [ ] Check relationships
    - [ ] Plan optimizations
  - [ ] **folders** table:
    - [ ] Verify hierarchy support
    - [ ] Check constraints
    - [ ] Review indices
  - [ ] **tags** table:
    - [ ] Check normalization
    - [ ] Review relationships
  - [ ] **reminders** table:
    - [ ] Verify fields
    - [ ] Check scheduling data

#### Remove Unused Schema Elements
- [ ] Delete unused columns:
  - [ ] Identify via code search
  - [ ] Create migration to drop
  - [ ] Update model classes
- [ ] Remove unused tables:
  - [ ] Verify no references
  - [ ] Create drop migration
  - [ ] Clean up related code

#### Add Performance Indices
- [ ] Add missing indices:
  ```sql
  CREATE INDEX idx_notes_folder ON notes(folder_id);
  CREATE INDEX idx_notes_created ON notes(created_at);
  CREATE INDEX idx_tasks_due ON tasks(due_date);
  CREATE INDEX idx_tasks_status ON tasks(status);
  ```
- [ ] Composite indices for common queries
- [ ] Full-text search indices if needed

#### Create Schema Migration
- [ ] Write migration script
- [ ] Test on sample database
- [ ] Add rollback procedure
- [ ] Document changes

#### Regenerate Drift Files
- [ ] Clean generated files:
  ```bash
  find lib -name "*.g.dart" -delete
  ```
- [ ] Regenerate:
  ```bash
  flutter pub run build_runner build --delete-conflicting-outputs
  ```
- [ ] Verify generation successful
- [ ] Test database operations

#### Commit Schema Optimization
- [ ] Create commit:
  ```bash
  git commit -m "refactor: optimize database schema

  - Removed unused columns and tables
  - Added performance indices
  - Created migration scripts
  - Regenerated Drift files

  Part of Phase 3 data layer cleanup"
  ```

### Day 14: Repository Consolidation
**Main Task**: Merge duplicate repository implementations

#### Identify Duplicate Repositories
- [ ] List all repository files:
  ```bash
  ls -la lib/repository/
  ```
- [ ] Find duplicates:
  - [ ] Multiple note repositories
  - [ ] Template repository variants
  - [ ] Folder repository copies
  - [ ] Task repository versions

#### Merge Repository Functionality
- [ ] **Note Repositories**:
  - [ ] Compare implementations
  - [ ] Merge unique features
  - [ ] Create single NoteRepository
  - [ ] Delete duplicates

- [ ] **Template Repositories**:
  - [ ] Consolidate template logic
  - [ ] Merge with note repository if appropriate
  - [ ] Remove redundant code

- [ ] **Folder Repositories**:
  - [ ] Unify folder operations
  - [ ] Ensure hierarchy support
  - [ ] Delete extra implementations

#### Standardize Repository Interfaces
- [ ] Create consistent method names
- [ ] Standardize return types
- [ ] Unify error handling
- [ ] Add consistent logging

#### Update Repository References
- [ ] Find all repository usage
- [ ] Update imports
- [ ] Fix method calls
- [ ] Test each change

#### Add Repository Tests
- [ ] Unit tests for each repository
- [ ] Integration tests for complex operations
- [ ] Mock database for testing
- [ ] Test error scenarios

#### Commit Repository Consolidation
- [ ] Create commit:
  ```bash
  git commit -m "refactor: consolidate duplicate repositories

  - Merged duplicate repository implementations
  - Standardized interfaces
  - Added comprehensive tests
  - Improved code organization

  Part of Phase 3 data layer cleanup"
  ```

### Day 15: Migration System
**Main Task**: Robust database migration system

#### Review Existing Migrations
- [ ] List all migration scripts
- [ ] Check migration history table
- [ ] Verify applied migrations
- [ ] Identify pending migrations

#### Create Migration Framework
- [ ] Design migration system:
  ```dart
  abstract class Migration {
    int get version;
    String get description;
    Future<void> up();
    Future<void> down();
  }
  ```
- [ ] Implement migration runner
- [ ] Add version tracking
- [ ] Create rollback support

#### Write Pending Migrations
- [ ] Schema cleanup migration
- [ ] Index addition migration
- [ ] Data transformation migration
- [ ] Legacy cleanup migration

#### Test Migration System
- [ ] Test on empty database
- [ ] Test on existing database
- [ ] Test rollback functionality
- [ ] Test migration ordering
- [ ] Verify data integrity

#### Document Migration Process
- [ ] Write migration guide
- [ ] Document rollback procedures
- [ ] Create troubleshooting guide
- [ ] Add to README

#### Commit Migration System
- [ ] Create commit:
  ```bash
  git commit -m "feat: implement robust database migration system

  - Created migration framework
  - Added rollback support
  - Wrote pending migrations
  - Comprehensive testing and documentation

  Phase 3 Data Layer Cleanup complete"
  ```

**Phase 3 Success Metrics**:
- [ ] ✅ Optimized database schema
- [ ] ✅ Single repository per domain
- [ ] ✅ Migration system in place
- [ ] ✅ All migrations tested
- [ ] ✅ Database performance improved

---

## ✨ Phase 4: Complete Core Features
**Duration**: Days 16-25
**Goal**: Implement all missing core functionality
**Status**: ⏳ Not Started

### Days 16-18: Folders System
**Main Task**: Complete folder functionality

#### Day 16: Folder CRUD Operations

##### Implement Create Folder
- [ ] Design folder model:
  ```dart
  class Folder {
    String id;
    String name;
    String? parentId;
    int sortOrder;
    DateTime createdAt;
    DateTime updatedAt;
  }
  ```
- [ ] Implement `createFolder()`:
  - [ ] Validate folder name
  - [ ] Check for duplicates
  - [ ] Set parent relationship
  - [ ] Save to database
  - [ ] Update UI state
  - [ ] Sync to remote

- [ ] Create folder dialog:
  - [ ] Design UI layout
  - [ ] Add name input field
  - [ ] Parent folder selector
  - [ ] Validation messages
  - [ ] Create button handler
  - [ ] Cancel functionality

##### Implement Update Folder
- [ ] Add `renameFolder()` method
- [ ] Create rename dialog
- [ ] Validate new name
- [ ] Update database
- [ ] Refresh UI
- [ ] Sync changes

##### Implement Delete Folder
- [ ] Add `deleteFolder()` method:
  - [ ] Check for child folders
  - [ ] Check for notes in folder
  - [ ] Show confirmation dialog
  - [ ] Handle cascade delete
  - [ ] Update parent references
  - [ ] Sync deletion

- [ ] Delete confirmation UI:
  - [ ] Warning message
  - [ ] Note count display
  - [ ] Subfolder count
  - [ ] Move notes option
  - [ ] Confirm/Cancel buttons

#### Day 17: Folder Navigation

##### Build Folder Tree Widget
- [ ] Create folder tree structure:
  - [ ] Hierarchical display
  - [ ] Expand/collapse nodes
  - [ ] Current folder indicator
  - [ ] Note count badges
  - [ ] Drag-drop support

- [ ] Implement tree operations:
  - [ ] Load folder hierarchy
  - [ ] Cache tree structure
  - [ ] Handle expansions
  - [ ] Update on changes
  - [ ] Optimize rendering

##### Implement Folder Picker
- [ ] Create picker dialog:
  - [ ] Folder list display
  - [ ] Search functionality
  - [ ] Recent folders
  - [ ] Create new option
  - [ ] Selection handler

- [ ] Add move note functionality:
  - [ ] Select notes
  - [ ] Choose target folder
  - [ ] Update relationships
  - [ ] Refresh views
  - [ ] Sync moves

##### Add Folder Breadcrumbs
- [ ] Design breadcrumb widget
- [ ] Show folder path
- [ ] Make segments clickable
- [ ] Handle long paths
- [ ] Update on navigation

#### Day 18: Folder Sync and Polish

##### Implement Folder Sync
- [ ] Real-time folder updates:
  - [ ] Subscribe to folder changes
  - [ ] Handle remote creates
  - [ ] Process remote deletes
  - [ ] Merge remote updates
  - [ ] Resolve conflicts

- [ ] Sync error handling:
  - [ ] Network failures
  - [ ] Conflict resolution
  - [ ] Retry logic
  - [ ] User notifications

##### Add Drag and Drop (Desktop)
- [ ] Implement drag source
- [ ] Create drop targets
- [ ] Visual feedback
- [ ] Validate drops
- [ ] Execute moves
- [ ] Undo support

##### Test Folder System
- [ ] Unit tests:
  - [ ] CRUD operations
  - [ ] Hierarchy management
  - [ ] Sync functionality
- [ ] Integration tests:
  - [ ] Full folder workflow
  - [ ] Multi-device sync
- [ ] Manual testing:
  - [ ] Create nested folders
  - [ ] Move notes between folders
  - [ ] Delete folders with content
  - [ ] Sync across devices

##### Commit Folder Implementation
- [ ] Create commit:
  ```bash
  git commit -m "feat: complete folder system implementation

  - Full CRUD operations for folders
  - Hierarchical folder navigation
  - Folder picker and breadcrumbs
  - Real-time sync support
  - Drag-and-drop on desktop

  Part of Phase 4 feature completion"
  ```

### Days 19-20: Import/Export
**Main Task**: Complete import/export functionality

#### Day 19: ENEX Import

##### Parse ENEX Format
- [ ] Set up XML parser:
  - [ ] Add xml package
  - [ ] Create parser class
  - [ ] Handle large files
  - [ ] Stream processing

- [ ] Extract note data:
  - [ ] Parse note elements
  - [ ] Extract title
  - [ ] Get content (ENML)
  - [ ] Parse created date
  - [ ] Parse updated date
  - [ ] Extract tags
  - [ ] Get attachments

##### Convert ENML to Markdown
- [ ] Handle ENML elements:
  - [ ] Convert `<div>` to paragraphs
  - [ ] Convert `<en-todo>` to checkboxes
  - [ ] Handle lists (`<ul>`, `<ol>`)
  - [ ] Convert formatting tags
  - [ ] Process tables
  - [ ] Handle code blocks

- [ ] Process attachments:
  - [ ] Extract base64 data
  - [ ] Save to storage
  - [ ] Update references
  - [ ] Handle images
  - [ ] Process PDFs
  - [ ] Store other files

##### Import Notes to Database
- [ ] Create import batch:
  - [ ] Validate note data
  - [ ] Create note records
  - [ ] Assign to folder
  - [ ] Apply tags
  - [ ] Save attachments
  - [ ] Track progress

- [ ] Handle import errors:
  - [ ] Log failed notes
  - [ ] Continue processing
  - [ ] Show error summary
  - [ ] Retry option

#### Day 20: Obsidian Import and Export Polish

##### Implement Obsidian Vault Import
- [ ] Directory traversal:
  - [ ] Scan for .md files
  - [ ] Preserve folder structure
  - [ ] Find attachments folder
  - [ ] Track relationships

- [ ] Process Markdown files:
  - [ ] Read file content
  - [ ] Parse frontmatter
  - [ ] Extract metadata
  - [ ] Convert wiki links
  - [ ] Process images
  - [ ] Handle attachments

- [ ] Recreate structure:
  - [ ] Create folders
  - [ ] Import notes
  - [ ] Copy attachments
  - [ ] Maintain links
  - [ ] Set metadata

##### Polish Export Functions
- [ ] Markdown export:
  - [ ] Include metadata
  - [ ] Export attachments
  - [ ] Preserve formatting
  - [ ] Handle special blocks

- [ ] PDF export:
  - [ ] Apply styling
  - [ ] Embed images
  - [ ] Page breaks
  - [ ] Headers/footers
  - [ ] Table of contents

- [ ] Batch export:
  - [ ] Select multiple notes
  - [ ] Choose format
  - [ ] Zip if multiple files
  - [ ] Progress indicator

##### Test Import/Export
- [ ] Test ENEX import:
  - [ ] Small notebook
  - [ ] Large notebook
  - [ ] Various content types
- [ ] Test Obsidian import:
  - [ ] Simple vault
  - [ ] Complex structure
  - [ ] With attachments
- [ ] Test exports:
  - [ ] All formats
  - [ ] Special characters
  - [ ] Large notes

##### Commit Import/Export
- [ ] Create commit:
  ```bash
  git commit -m "feat: complete import/export functionality

  - Full ENEX import with ENML conversion
  - Obsidian vault import with structure
  - Polished PDF and Markdown export
  - Batch operations support
  - Comprehensive error handling

  Part of Phase 4 feature completion"
  ```

### Days 21-22: Share Extension
**Main Task**: Quick capture via system share

#### Day 21: iOS Share Extension

##### Create Share Extension Target
- [ ] Add extension in Xcode:
  - [ ] New target: Share Extension
  - [ ] Configure bundle ID
  - [ ] Set up provisioning
  - [ ] Configure entitlements

- [ ] Set up app groups:
  - [ ] Create app group
  - [ ] Add to main app
  - [ ] Add to extension
  - [ ] Configure shared storage

##### Implement Share Handler
- [ ] Handle text content:
  - [ ] Extract shared text
  - [ ] Create note title
  - [ ] Format content
  - [ ] Save to shared storage

- [ ] Handle URLs:
  - [ ] Extract URL
  - [ ] Fetch page title
  - [ ] Get description
  - [ ] Save as web clip

- [ ] Handle images:
  - [ ] Save image data
  - [ ] Generate thumbnail
  - [ ] Create note with image
  - [ ] Handle multiple images

##### Create iOS UI
- [ ] Design share sheet:
  - [ ] Title field
  - [ ] Content preview
  - [ ] Folder selector
  - [ ] Tag field
  - [ ] Save button

- [ ] Add quick actions:
  - [ ] Quick save
  - [ ] Save and open
  - [ ] Cancel

#### Day 22: Android Share and Testing

##### Configure Android Intent Filter
- [ ] Update AndroidManifest.xml:
  ```xml
  <intent-filter>
    <action android:name="android.intent.action.SEND"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <data android:mimeType="text/*"/>
    <data android:mimeType="image/*"/>
  </intent-filter>
  ```
- [ ] Handle multiple types
- [ ] Configure permissions

##### Implement Intent Handler
- [ ] Process shared data:
  - [ ] Get intent extras
  - [ ] Extract content type
  - [ ] Process based on type
  - [ ] Create note

- [ ] Handle in Flutter:
  - [ ] Set up method channel
  - [ ] Receive shared data
  - [ ] Process in background
  - [ ] Save to database

##### Test Share Extension
- [ ] iOS testing:
  - [ ] Share from Safari
  - [ ] Share from Photos
  - [ ] Share from other apps
  - [ ] Test all content types

- [ ] Android testing:
  - [ ] Share from Chrome
  - [ ] Share from Gallery
  - [ ] Share from other apps
  - [ ] Verify all types work

- [ ] Edge cases:
  - [ ] Large content
  - [ ] No network
  - [ ] App not running
  - [ ] Multiple shares

##### Commit Share Extension
- [ ] Create commit:
  ```bash
  git commit -m "feat: implement share extension for quick capture

  - iOS share extension with app groups
  - Android intent filter for sharing
  - Support for text, URLs, and images
  - Background processing
  - Quick capture UI

  Part of Phase 4 feature completion"
  ```

### Day 23: Templates System
**Main Task**: Note templates for quick creation

#### Create Template Infrastructure

##### Design Template Model
- [ ] Define template structure:
  ```dart
  class NoteTemplate {
    String id;
    String name;
    String content;
    String? icon;
    List<String> tags;
    Map<String, dynamic> variables;
  }
  ```
- [ ] Template storage:
  - [ ] Database table
  - [ ] JSON storage
  - [ ] User vs system templates

##### Build Default Templates
- [ ] **Meeting Notes**:
  - [ ] Date/time header
  - [ ] Attendees section
  - [ ] Agenda items
  - [ ] Action items
  - [ ] Notes section

- [ ] **Daily Journal**:
  - [ ] Date header
  - [ ] Mood tracker
  - [ ] Gratitude section
  - [ ] Today's goals
  - [ ] Reflection area

- [ ] **Task List**:
  - [ ] Title area
  - [ ] Priority tasks
  - [ ] Standard tasks
  - [ ] Notes section

- [ ] **Project Plan**:
  - [ ] Project name
  - [ ] Objectives
  - [ ] Milestones
  - [ ] Resources
  - [ ] Timeline

##### Implement Template Variables
- [ ] Variable system:
  - [ ] `{{date}}` - Current date
  - [ ] `{{time}}` - Current time
  - [ ] `{{day}}` - Day of week
  - [ ] `{{month}}` - Current month
  - [ ] `{{year}}` - Current year

- [ ] Variable replacement:
  - [ ] Parse template content
  - [ ] Find variables
  - [ ] Replace with values
  - [ ] Format output

#### Create Template UI

##### Template Picker
- [ ] Design picker screen:
  - [ ] Grid/list view
  - [ ] Template previews
  - [ ] Search functionality
  - [ ] Categories/filters

- [ ] Template selection:
  - [ ] Tap to select
  - [ ] Preview option
  - [ ] Create note button
  - [ ] Cancel option

##### Custom Template Creation
- [ ] Template editor:
  - [ ] Name field
  - [ ] Content editor
  - [ ] Variable insertion
  - [ ] Preview mode
  - [ ] Save functionality

- [ ] Template management:
  - [ ] Edit templates
  - [ ] Delete templates
  - [ ] Duplicate templates
  - [ ] Export/import

#### Test Template System
- [ ] Create notes from templates
- [ ] Test variable replacement
- [ ] Create custom templates
- [ ] Edit existing templates
- [ ] Performance with many templates

#### Commit Templates
- [ ] Create commit:
  ```bash
  git commit -m "feat: implement note templates system

  - Default templates for common use cases
  - Variable system for dynamic content
  - Template picker UI
  - Custom template creation
  - Template management features

  Part of Phase 4 feature completion"
  ```

### Days 24-25: Tasks & Reminders UI
**Main Task**: Complete task management interface

#### Day 24: Task Enhancement

##### Enhance Checkbox Functionality
- [ ] Add task metadata:
  - [ ] Due date field
  - [ ] Priority selector
  - [ ] Reminder time
  - [ ] Recurrence pattern
  - [ ] Notes field

- [ ] Task properties UI:
  - [ ] Long-press menu
  - [ ] Task detail sheet
  - [ ] Date picker
  - [ ] Time picker
  - [ ] Priority buttons

##### Create Task Model
- [ ] Define task structure:
  ```dart
  class Task {
    String id;
    String noteId;
    String content;
    DateTime? dueDate;
    DateTime? reminderTime;
    TaskPriority priority;
    TaskStatus status;
    String? recurrence;
  }
  ```
- [ ] Database schema:
  - [ ] Tasks table
  - [ ] Relationships
  - [ ] Indices

##### Implement Task Operations
- [ ] Task CRUD:
  - [ ] Create task
  - [ ] Update properties
  - [ ] Mark complete
  - [ ] Delete task
  - [ ] Bulk operations

- [ ] Task sync:
  - [ ] Sync to remote
  - [ ] Handle conflicts
  - [ ] Real-time updates

#### Day 25: Task List and Calendar

##### Build Task List View
- [ ] Task list screen:
  - [ ] Section headers
  - [ ] Task items
  - [ ] Quick complete
  - [ ] Swipe actions
  - [ ] Pull to refresh

- [ ] Task sections:
  - [ ] Overdue tasks
  - [ ] Today's tasks
  - [ ] Tomorrow's tasks
  - [ ] This week
  - [ ] No date

- [ ] Task filtering:
  - [ ] By status
  - [ ] By priority
  - [ ] By project/note
  - [ ] By tag

##### Implement Calendar View
- [ ] Calendar widget:
  - [ ] Monthly view
  - [ ] Week view
  - [ ] Day markers
  - [ ] Task indicators
  - [ ] Navigation

- [ ] Day view:
  - [ ] Tasks for day
  - [ ] Time slots
  - [ ] Quick add
  - [ ] Drag to reschedule

##### Set Up Notifications
- [ ] Local notifications:
  - [ ] Schedule reminders
  - [ ] Notification content
  - [ ] Action buttons
  - [ ] Deep linking

- [ ] Notification management:
  - [ ] View scheduled
  - [ ] Cancel reminders
  - [ ] Snooze option
  - [ ] Settings

##### Test Task System
- [ ] Create tasks with properties
- [ ] Test reminders fire
- [ ] Calendar navigation
- [ ] Task completion flow
- [ ] Sync across devices

##### Commit Task UI
- [ ] Create commit:
  ```bash
  git commit -m "feat: complete task management UI

  - Enhanced checkbox with metadata
  - Task list with sections and filtering
  - Calendar view for tasks
  - Local notifications for reminders
  - Full task lifecycle management

  Phase 4 Core Features complete - MVP ready!"
  ```

**Phase 4 Success Metrics**:
- [ ] ✅ Folders fully functional
- [ ] ✅ Import/export working
- [ ] ✅ Share extension operational
- [ ] ✅ Templates implemented
- [ ] ✅ Tasks and reminders complete
- [ ] ✅ All core features tested

---

## 🎨 Phase 5: UI/UX Polish
**Duration**: Days 26-28
**Goal**: Refined and consistent user experience
**Status**: ⏳ Not Started

### Day 26: Saved Searches & Filtering
**Main Task**: Advanced search functionality

#### Implement Search Parser
- [ ] Parse search syntax:
  - [ ] Keywords
  - [ ] Operators (AND, OR, NOT)
  - [ ] Field searches (folder:, tag:)
  - [ ] Special filters (has:)
  - [ ] Date ranges

- [ ] Search tokens:
  - [ ] `folder:name`
  - [ ] `tag:label`
  - [ ] `has:attachment`
  - [ ] `created:>2024-01-01`
  - [ ] `modified:<7d`

#### Create Preset Search Chips
- [ ] Implement chips:
  - [ ] 📎 Attachments - `has:attachment`
  - [ ] 📧 Email Notes - `tag:email`
  - [ ] 🌐 Web Clips - `tag:web`
  - [ ] 📥 Inbox - `folder:inbox`

- [ ] Chip functionality:
  - [ ] Tap to filter
  - [ ] Show count badges
  - [ ] Multi-select support
  - [ ] Clear all option

#### Build Custom Saved Searches
- [ ] Save search UI:
  - [ ] Name input
  - [ ] Icon picker
  - [ ] Query builder
  - [ ] Test search
  - [ ] Save button

- [ ] Manage saved searches:
  - [ ] Edit saved search
  - [ ] Delete saved search
  - [ ] Reorder searches
  - [ ] Export/import

#### Test Search System
- [ ] Test query parsing
- [ ] Test all operators
- [ ] Test preset chips
- [ ] Test saved searches
- [ ] Performance with large datasets

### Day 27: Note Organization
**Main Task**: Pinning and sorting features

#### Implement Note Pinning
- [ ] Add pin functionality:
  - [ ] Pin/unpin toggle
  - [ ] Pin indicator UI
  - [ ] Pinned section
  - [ ] Pin order
  - [ ] Sync pin state

- [ ] Pin UI elements:
  - [ ] Pin icon in note
  - [ ] Pin option in menu
  - [ ] Pinned section header
  - [ ] Drag to reorder pins

#### Add Sorting Options
- [ ] Implement sort modes:
  - [ ] Date created (newest/oldest)
  - [ ] Date modified (newest/oldest)
  - [ ] Title (A-Z/Z-A)
  - [ ] Manual order

- [ ] Sort UI:
  - [ ] Sort menu button
  - [ ] Sort option list
  - [ ] Current sort indicator
  - [ ] Reverse order toggle

- [ ] Persist preferences:
  - [ ] Save sort choice
  - [ ] Per-folder sorting
  - [ ] Global default
  - [ ] Sync preference

#### Test Organization Features
- [ ] Pin/unpin notes
- [ ] Reorder pinned notes
- [ ] Test all sort modes
- [ ] Verify persistence
- [ ] Test with filters active

### Day 28: UI Consistency
**Main Task**: Polish and standardize UI

#### Remove Unused Screens
- [ ] Identify unused:
  ```bash
  # Find potentially unused screens
  grep -r "class.*Screen" lib/ui --include="*.dart"
  ```
- [ ] Delete if unused:
  - [ ] Old reminder screens
  - [ ] Legacy task screens
  - [ ] Duplicate dialogs
  - [ ] Test screens

#### Standardize UI Elements
- [ ] Consistent spacing:
  - [ ] Padding values
  - [ ] Margin values
  - [ ] List item heights
  - [ ] Card spacing

- [ ] Typography:
  - [ ] Header styles
  - [ ] Body text
  - [ ] Caption text
  - [ ] Button text

- [ ] Colors:
  - [ ] Primary colors
  - [ ] Accent colors
  - [ ] Error colors
  - [ ] Background colors

#### Add Loading States
- [ ] Loading indicators:
  - [ ] List loading
  - [ ] Card skeletons
  - [ ] Progress bars
  - [ ] Shimmer effects

- [ ] Empty states:
  - [ ] No notes message
  - [ ] No search results
  - [ ] No tasks
  - [ ] Error states

#### Polish Animations
- [ ] Page transitions
- [ ] List animations
- [ ] Drawer animations
- [ ] Dialog animations
- [ ] Micro-interactions

#### Test UI Polish
- [ ] Visual regression tests
- [ ] Different screen sizes
- [ ] Dark/light themes
- [ ] Accessibility check
- [ ] Performance check

#### Commit UI Polish
- [ ] Create commit:
  ```bash
  git commit -m "polish: UI consistency and UX improvements

  - Advanced search with saved searches
  - Note pinning and sorting
  - Standardized UI elements
  - Loading and empty states
  - Polished animations

  Phase 5 UI/UX Polish complete"
  ```

**Phase 5 Success Metrics**:
- [ ] ✅ Search fully functional
- [ ] ✅ Organization features complete
- [ ] ✅ Consistent UI throughout
- [ ] ✅ Smooth animations
- [ ] ✅ Good empty/loading states

---

## 🧪 Phase 6: Testing & Quality
**Duration**: Days 29-32
**Goal**: Production-grade quality assurance
**Status**: ⏳ Not Started

### Day 29: Test Infrastructure
**Main Task**: Modernize testing setup

#### Fix Deprecated Test APIs
- [ ] Update test methods:
  - [ ] Replace `setMockMethodCallHandler`
  - [ ] Update widget test APIs
  - [ ] Fix integration test methods
  - [ ] Update mock packages

- [ ] Fix test imports:
  - [ ] Remove deprecated imports
  - [ ] Update to new APIs
  - [ ] Fix package versions

#### Update Mocks
- [ ] Regenerate mocks:
  ```bash
  flutter pub run build_runner build --delete-conflicting-outputs
  ```
- [ ] Update mock implementations
- [ ] Fix mock method signatures
- [ ] Add missing mocks

#### Create Test Fixtures
- [ ] Sample data:
  - [ ] Test notes
  - [ ] Test folders
  - [ ] Test tasks
  - [ ] Test users

- [ ] Test utilities:
  - [ ] Database setup
  - [ ] Mock services
  - [ ] Test helpers
  - [ ] Assertion helpers

#### Set Up Code Coverage
- [ ] Configure coverage:
  - [ ] Coverage collection
  - [ ] Coverage reports
  - [ ] Coverage badges
  - [ ] CI integration

### Day 30: Unit & Widget Tests
**Main Task**: Comprehensive unit testing

#### Test Services
- [ ] Task service tests:
  - [ ] CRUD operations
  - [ ] Sync logic
  - [ ] Error handling
  - [ ] Edge cases

- [ ] Repository tests:
  - [ ] Database operations
  - [ ] Cache behavior
  - [ ] Error scenarios
  - [ ] Performance

- [ ] Provider tests:
  - [ ] State management
  - [ ] Async operations
  - [ ] Error states
  - [ ] Disposal

#### Test Widgets
- [ ] Core widgets:
  - [ ] Note editor
  - [ ] Task list
  - [ ] Folder tree
  - [ ] Search bar

- [ ] Widget interactions:
  - [ ] User input
  - [ ] Gestures
  - [ ] Navigation
  - [ ] State changes

#### Achieve Coverage Goals
- [ ] Run coverage:
  ```bash
  flutter test --coverage
  genhtml coverage/lcov.info -o coverage/html
  ```
- [ ] Target 80% coverage
- [ ] Add missing tests
- [ ] Fix failing tests

### Day 31: Integration Tests
**Main Task**: End-to-end testing

#### Test User Flows
- [ ] Note management:
  - [ ] Create note
  - [ ] Edit note
  - [ ] Delete note
  - [ ] Search notes
  - [ ] Move to folder

- [ ] Task workflow:
  - [ ] Create task
  - [ ] Set reminder
  - [ ] Mark complete
  - [ ] View in calendar

- [ ] Import/export:
  - [ ] Import ENEX
  - [ ] Import Obsidian
  - [ ] Export PDF
  - [ ] Batch export

#### Test Sync Scenarios
- [ ] Online sync:
  - [ ] Create and sync
  - [ ] Update and sync
  - [ ] Delete and sync
  - [ ] Conflict resolution

- [ ] Offline mode:
  - [ ] Offline creation
  - [ ] Queue changes
  - [ ] Sync on reconnect
  - [ ] Handle failures

#### Test Edge Cases
- [ ] Large datasets
- [ ] Slow network
- [ ] No network
- [ ] Invalid data
- [ ] Concurrent edits

### Day 32: Performance & Security
**Main Task**: Performance optimization and security audit

#### Performance Profiling
- [ ] Run profiler:
  - [ ] CPU profiling
  - [ ] Memory profiling
  - [ ] GPU profiling
  - [ ] Network profiling

- [ ] Identify bottlenecks:
  - [ ] Slow queries
  - [ ] Memory leaks
  - [ ] Render issues
  - [ ] Network waste

#### Optimize Performance
- [ ] Database optimization:
  - [ ] Query optimization
  - [ ] Batch operations
  - [ ] Index usage
  - [ ] Cache strategy

- [ ] UI optimization:
  - [ ] List virtualization
  - [ ] Image optimization
  - [ ] Lazy loading
  - [ ] Debouncing

#### Security Audit
- [ ] Check for vulnerabilities:
  - [ ] SQL injection
  - [ ] XSS attacks
  - [ ] Data leaks
  - [ ] Weak encryption

- [ ] Validate security:
  - [ ] Input validation
  - [ ] Authentication
  - [ ] Authorization
  - [ ] Data encryption

#### Commit Testing Phase
- [ ] Create commit:
  ```bash
  git commit -m "test: comprehensive testing and quality assurance

  - Modernized test infrastructure
  - 80%+ code coverage achieved
  - Full integration test suite
  - Performance optimizations
  - Security audit complete

  Phase 6 Testing & Quality complete"
  ```

**Phase 6 Success Metrics**:
- [ ] ✅ 80%+ code coverage
- [ ] ✅ All tests passing
- [ ] ✅ Performance benchmarks met
- [ ] ✅ Security audit passed
- [ ] ✅ No memory leaks

---

## 🚀 Phase 7: Production Hardening
**Duration**: Days 33-35
**Goal**: Production-ready reliability
**Status**: ⏳ Not Started

### Day 33: Error Handling
**Main Task**: Comprehensive error management

#### Verify Error Boundaries
- [ ] Check coverage:
  - [ ] All screens wrapped
  - [ ] Critical widgets protected
  - [ ] Async operations covered
  - [ ] Network calls wrapped

- [ ] Error UI:
  - [ ] Error messages
  - [ ] Retry buttons
  - [ ] Fallback UI
  - [ ] Report option

#### Add Try-Catch Blocks
- [ ] Service methods:
  - [ ] Database operations
  - [ ] Network calls
  - [ ] File operations
  - [ ] Parse operations

- [ ] UI operations:
  - [ ] User input handling
  - [ ] Navigation
  - [ ] State updates
  - [ ] Animations

#### Implement Graceful Degradation
- [ ] Offline fallbacks
- [ ] Cached data usage
- [ ] Reduced functionality
- [ ] Queue for later

#### User-Friendly Messages
- [ ] Error translations
- [ ] Clear explanations
- [ ] Action suggestions
- [ ] Contact support

### Day 34: Monitoring & Analytics
**Main Task**: Production monitoring setup

#### Configure Sentry
- [ ] Set up Sentry:
  ```dart
  await SentryFlutter.init(
    (options) {
      options.dsn = ENV.SENTRY_DSN;
      options.environment = ENV.ENVIRONMENT;
      options.tracesSampleRate = 0.3;
      options.beforeSend = beforeSend;
    },
  );
  ```
- [ ] Error filtering
- [ ] User context
- [ ] Breadcrumbs
- [ ] Performance monitoring

#### Set Up Analytics Events
- [ ] User events:
  - [ ] Sign up
  - [ ] Sign in
  - [ ] Note created
  - [ ] Task completed

- [ ] Feature usage:
  - [ ] Import used
  - [ ] Template selected
  - [ ] Search performed
  - [ ] Sync triggered

- [ ] Error events:
  - [ ] Sync failures
  - [ ] Import errors
  - [ ] Crash events
  - [ ] Performance issues

#### Test Monitoring
- [ ] Trigger test errors
- [ ] Verify Sentry receives
- [ ] Check analytics flow
- [ ] Test performance tracking

### Day 35: App Store Preparation
**Main Task**: Store listing materials

#### Create Store Assets
- [ ] Screenshots:
  - [ ] iPhone screenshots
  - [ ] iPad screenshots
  - [ ] Android phone
  - [ ] Android tablet

- [ ] App icon:
  - [ ] iOS versions
  - [ ] Android versions
  - [ ] Store icon

- [ ] Feature graphics:
  - [ ] Banner image
  - [ ] Promo graphics
  - [ ] Social media

#### Write Store Descriptions
- [ ] App title
- [ ] Subtitle
- [ ] Short description
- [ ] Full description
- [ ] Keywords
- [ ] Categories

#### Create Legal Documents
- [ ] Privacy policy
- [ ] Terms of service
- [ ] Data handling
- [ ] GDPR compliance

#### Set Up App Website
- [ ] Landing page
- [ ] Features section
- [ ] Support page
- [ ] Privacy/terms

#### Commit Production Hardening
- [ ] Create commit:
  ```bash
  git commit -m "feat: production hardening complete

  - Comprehensive error handling
  - Monitoring and analytics configured
  - App store assets created
  - Legal documents prepared

  Phase 7 Production Hardening complete"
  ```

**Phase 7 Success Metrics**:
- [ ] ✅ Error handling complete
- [ ] ✅ Monitoring active
- [ ] ✅ Analytics configured
- [ ] ✅ Store assets ready
- [ ] ✅ Legal compliance

---

## 🎁 Phase 8: Release Preparation
**Duration**: Days 36-37
**Goal**: Ready for production deployment
**Status**: ⏳ Not Started

### Day 36: Final Checks
**Main Task**: Final quality verification

#### Run Final Analyzer
- [ ] Zero tolerance check:
  ```bash
  flutter analyze
  # Target: 0 issues
  ```
- [ ] Fix any remaining issues
- [ ] Verify clean analysis

#### Build Release Candidates
- [ ] iOS build:
  ```bash
  flutter build ios --release
  ```
- [ ] Android build:
  ```bash
  flutter build appbundle --release
  ```
- [ ] Verify builds complete

#### Test on Physical Devices
- [ ] iOS devices:
  - [ ] iPhone testing
  - [ ] iPad testing
  - [ ] Different iOS versions

- [ ] Android devices:
  - [ ] Phone testing
  - [ ] Tablet testing
  - [ ] Different Android versions

#### Verify All Features
- [ ] Feature checklist:
  - [ ] Notes CRUD
  - [ ] Folders
  - [ ] Search
  - [ ] Tasks
  - [ ] Import/export
  - [ ] Share extension
  - [ ] Templates
  - [ ] Sync

#### Performance Verification
- [ ] App size check
- [ ] Startup time
- [ ] Memory usage
- [ ] Battery impact

### Day 37: Deployment
**Main Task**: Release to production

#### Deploy to Beta
- [ ] TestFlight deployment
- [ ] Google Play Beta
- [ ] Invite beta testers
- [ ] Monitor feedback

#### Monitor Beta
- [ ] Crash reports
- [ ] Performance metrics
- [ ] User feedback
- [ ] Bug reports

#### Prepare Hotfix Process
- [ ] Hotfix branch setup
- [ ] Quick release process
- [ ] Emergency contacts
- [ ] Rollback plan

#### Submit to Stores
- [ ] App Store submission
- [ ] Google Play submission
- [ ] Review responses ready
- [ ] Fast track if needed

#### Create Release
- [ ] Tag release:
  ```bash
  git tag -a v1.0.0 -m "Release version 1.0.0"
  git push origin v1.0.0
  ```
- [ ] Release notes
- [ ] Announcement ready
- [ ] Support prepared

#### Final Commit
- [ ] Create commit:
  ```bash
  git commit -m "release: v1.0.0 - Production release

  - All features complete
  - Zero analyzer issues
  - Full test coverage
  - Production monitoring active
  - Store submissions complete

  🎉 Duru Notes v1.0.0 released!"
  ```

**Phase 8 Success Metrics**:
- [ ] ✅ Zero analyzer issues
- [ ] ✅ Builds successful
- [ ] ✅ Beta feedback positive
- [ ] ✅ Store approved
- [ ] ✅ Production deployed

---

## 📅 Daily Progress Log Template

### Day [X] - [Date]
**Phase**: [Current Phase]
**Focus**: [Main focus for today]

#### Morning Standup
- [ ] Review yesterday's progress
- [ ] Check blockers
- [ ] Plan today's tasks
- [ ] Update TODO list

#### Tasks Completed
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

#### Blockers Encountered
- Issue 1: [Description] - [Resolution]
- Issue 2: [Description] - [Resolution]

#### Tomorrow's Priority
1. [Top priority]
2. [Second priority]
3. [Third priority]

#### Notes
[Any important notes, decisions, or discoveries]

---

## 🛠️ Quick Reference

### Critical Commands
```bash
# Analyze code
flutter analyze --no-fatal-warnings

# Run tests with coverage
flutter test --coverage

# Build release versions
flutter build ios --release
flutter build appbundle --release

# Fix issues automatically
dart fix --apply

# Clean and rebuild
flutter clean && flutter pub get

# Generate code
flutter pub run build_runner build --delete-conflicting-outputs

# Find specific patterns
grep -r "pattern" lib --include="*.dart"

# Count occurrences
grep -r "pattern" lib --include="*.dart" | wc -l

# Check file counts
find lib -name "*_legacy*" | wc -l
```

### Key Files to Monitor
- `/lib/main.dart` - Entry point
- `/lib/core/bootstrap/app_bootstrap.dart` - Initialization
- `/lib/services/unified_task_service.dart` - Core service
- `/lib/data/local/app_db.dart` - Database schema
- `/lib/providers.dart` - Provider definitions
- `/pubspec.yaml` - Dependencies
- `/analysis_options.yaml` - Linter rules
- `/docs/claude/ClaudeTODO.md` - This document

### Git Workflow
```bash
# Create feature branch
git checkout -b feature/phase-0-cleanup

# Stage changes
git add .

# Commit with message
git commit -m "type: description"

# Push to remote
git push origin feature/phase-0-cleanup

# Create pull request
gh pr create

# Merge to main
git checkout main
git merge feature/phase-0-cleanup
```

---

## 🎯 Definition of Done

A task is considered DONE when:
1. ✅ Code is written and working
2. ✅ Tests are written and passing
3. ✅ Documentation is updated
4. ✅ Code review completed (if applicable)
5. ✅ Analyzer shows no issues for changed files
6. ✅ Committed with clear message
7. ✅ Tested on iOS and Android
8. ✅ No regression in existing features

---

## 📞 Emergency Procedures

### If Build Fails
1. Check analyzer output
2. Clean and rebuild
3. Check dependencies
4. Revert recent changes

### If Tests Fail
1. Run specific test
2. Check test output
3. Fix implementation
4. Update test if needed

### If Sync Breaks
1. Check network
2. Verify credentials
3. Check Supabase status
4. Review error logs

### If Performance Degrades
1. Profile the app
2. Check recent changes
3. Review database queries
4. Optimize hot paths

---

## 🏁 Final Checklist Before Release

### Code Quality
- [ ] Zero analyzer issues
- [ ] No print statements
- [ ] No commented code
- [ ] No TODO/FIXME comments
- [ ] All imports organized
- [ ] Consistent code style

### Testing
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] 80%+ code coverage
- [ ] Manual testing complete
- [ ] Beta testing successful

### Documentation
- [ ] README updated
- [ ] API documented
- [ ] Architecture documented
- [ ] Deployment guide ready
- [ ] Release notes written

### Production
- [ ] Environment variables set
- [ ] Monitoring configured
- [ ] Analytics active
- [ ] Error tracking enabled
- [ ] Performance acceptable

### Store
- [ ] Screenshots ready
- [ ] Descriptions written
- [ ] Keywords selected
- [ ] Privacy policy live
- [ ] Terms of service live

---

## 🎉 Completion Celebration

When all phases are complete:
1. 🎊 Tag the release
2. 🚀 Deploy to production
3. 📣 Announce the release
4. 🎉 Celebrate the achievement
5. 📈 Monitor user feedback
6. 🔄 Plan next iteration

---

**Remember**:
- Quality over speed
- Test everything
- Document as you go
- Commit frequently
- Ask for help when stuck

**You've got this! Let's ship Duru Notes to production! 🚀**

---

*End of Document - Total Tasks: ~500+ checkboxes for complete tracking*

