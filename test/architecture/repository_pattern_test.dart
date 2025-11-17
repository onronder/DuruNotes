/// Repository Pattern Enforcement Tests
///
/// **Purpose**: Prevent service layer from bypassing repository pattern
/// **Created**: 2025-11-17
/// **Related**: ARCHITECTURE_VIOLATIONS.md v1.0.0, DELETION_PATTERNS.md v1.0.0
///
/// These tests scan the codebase at compile time to detect architectural violations.
/// They fail if services make direct database calls that should go through repositories.
///
/// **Runs in**: CI pipeline (prevents merging code with violations)
/// **Exemptions**: See _allowedExceptions list below

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Repository Pattern Enforcement', () {
    test('Services must not directly call AppDb delete methods', () {
      // Scan all service files for architectural violations
      final serviceDir = Directory('lib/services');

      if (!serviceDir.existsSync()) {
        fail('lib/services directory not found');
      }

      final serviceFiles = serviceDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      if (serviceFiles.isEmpty) {
        fail('No service files found in lib/services/');
      }

      final violations = <String>[];

      // Patterns that indicate repository pattern bypass
      final forbiddenPatterns = [
        // Task operations
        '_db.deleteTaskById',
        '_db.deleteTasksForNote',
        // Note: _db.getTaskById is exempted for reminder bridge coordination
        // See ARCHITECTURE_VIOLATIONS.md "Architectural Exemptions" section
        '_db.createTask',
        '_db.updateTask',
        '_db.completeTask',
        '_db.toggleTaskStatus',

        // Note operations
        '_db.deleteNoteById',
        '_db.deleteNotesInFolder',

        // Folder operations
        '_db.deleteFolderById',

        // Reminder operations (intentionally hard-deleted, but should document)
        // '_db.deleteReminderById',  // Exempted - reminders are ephemeral
      ];

      for (final file in serviceFiles) {
        final content = file.readAsStringSync();
        final fileName = file.path.replaceFirst(RegExp(r'^.*/lib/services/'), '');

        // Skip files with explicit exemptions
        if (_isExempted(fileName, content)) {
          continue;
        }

        for (final pattern in forbiddenPatterns) {
          if (content.contains(pattern)) {
            // Check if it's in a comment (allowed)
            final lines = content.split('\n');
            for (var i = 0; i < lines.length; i++) {
              if (lines[i].contains(pattern)) {
                final trimmed = lines[i].trim();
                // Skip if it's a comment
                if (trimmed.startsWith('//') || trimmed.startsWith('*')) {
                  continue;
                }

                violations.add(
                  '$fileName:${i + 1}: Found `$pattern`\n'
                  '  → Should use repository pattern instead\n'
                  '  → See DELETION_PATTERNS.md for correct usage',
                );
              }
            }
          }
        }
      }

      if (violations.isNotEmpty) {
        final message = '''

❌ REPOSITORY PATTERN VIOLATIONS DETECTED

Services must not bypass the repository layer by calling AppDb methods directly.

Found ${violations.length} violation(s):

${violations.join('\n\n')}

REQUIRED FIXES:
1. Inject the appropriate repository (e.g., TaskCoreRepository, NoteRepository)
2. Use repository methods instead of direct AppDb calls
3. See DELETION_PATTERNS.md v1.0.0 for correct patterns
4. See ARCHITECTURE_VIOLATIONS.md v1.0.0 for remediation guide

ARCHITECTURE:
  UI Layer → Service Layer → Repository Layer → Database Layer
                            ☝️ Services must stop here

WHY THIS MATTERS:
- Repositories handle encryption/decryption
- Repositories implement soft delete (30-day trash retention)
- Repositories enqueue sync operations
- Repositories provide audit trails
- Direct database calls bypass all of the above!

''';
        fail(message);
      }
    });

    test('Services should use repository interfaces, not concrete implementations', () {
      // This test ensures services depend on abstractions (ITaskRepository)
      // rather than concrete implementations (TaskCoreRepository)

      final serviceDir = Directory('lib/services');
      final violations = <String>[];

      if (!serviceDir.existsSync()) {
        return; // Skip if services don't exist
      }

      final serviceFiles = serviceDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      for (final file in serviceFiles) {
        final content = file.readAsStringSync();
        final fileName = file.path.replaceFirst(RegExp(r'^.*/lib/services/'), '');

        // Check for concrete repository usage in field declarations
        final concretePatterns = [
          'TaskCoreRepository',  // Should be ITaskRepository
          'NoteCoreRepository',  // Should be INoteRepository
          'FolderCoreRepository', // Should be IFolderRepository
        ];

        for (final pattern in concretePatterns) {
          // Look for field declarations like: final TaskCoreRepository _repo;
          final regex = RegExp(r'final\s+' + pattern + r'\s+\w+;');
          if (regex.hasMatch(content)) {
            violations.add(
              '$fileName: Uses concrete `$pattern`\n'
              '  → Should use interface (e.g., I$pattern)',
            );
          }
        }
      }

      if (violations.isNotEmpty) {
        final message = '''

⚠️ DEPENDENCY INVERSION PRINCIPLE VIOLATION

Services should depend on repository interfaces, not concrete implementations.

Found ${violations.length} violation(s):

${violations.join('\n\n')}

RECOMMENDED FIX:
- Change: final TaskCoreRepository _taskRepository;
- To:     final ITaskRepository _taskRepository;

WHY:
- Enables mocking in tests
- Follows SOLID principles (Dependency Inversion)
- Allows swapping implementations without changing services

''';

        // This is a warning, not a hard failure (for now)
        print(message);
      }
    });

    test('Database layer hard-delete methods should be private', () {
      // Ensure AppDb hard-delete methods are private (start with _)
      // This prevents accidental bypasses

      final appDbFile = File('lib/data/local/app_db.dart');

      if (!appDbFile.existsSync()) {
        return; // Skip if file doesn't exist
      }

      final content = appDbFile.readAsStringSync();
      final violations = <String>[];

      // Methods that should be private (hard delete = permanent removal)
      final shouldBePrivateMethods = [
        'deleteTaskById',
        'deleteNoteById',
        'deleteFolderById',
        'deleteTasksForNote',
        'deleteNotesInFolder',
      ];

      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];

        for (final method in shouldBePrivateMethods) {
          // Look for public method declarations
          if (line.contains('Future<void> $method(') ||
              line.contains('Future<void>$method(')) {
            violations.add(
              'app_db.dart:${i + 1}: Method `$method` should be private\n'
              '  → Rename to `_$method` to prevent service layer bypass',
            );
          }
        }
      }

      if (violations.isNotEmpty) {
        final message = '''

⚠️ DATABASE LAYER ENCAPSULATION VIOLATION

Hard-delete methods in AppDb should be private to enforce repository pattern.

Found ${violations.length} violation(s):

${violations.join('\n\n')}

REQUIRED FIX:
Make these methods private by prefixing with underscore:
- deleteTaskById → _deleteTaskById
- deleteNoteById → _deleteNoteById

Only repositories should call hard-delete methods (for purge automation).
Services must use repository.deleteX() for soft delete.

''';

        // Hard failure - this is a critical architectural issue
        fail(message);
      }
    });
  });
}

/// Checks if a file/content is exempted from repository pattern enforcement
bool _isExempted(String fileName, String content) {
  // Files that legitimately need direct DB access
  final exemptedFiles = [
    'database_optimizer.dart',  // DB maintenance operations
    'purge_scheduler_service.dart',  // Needs raw DB access for purge
  ];

  if (exemptedFiles.any((exempt) => fileName.contains(exempt))) {
    return true;
  }

  // Check for explicit exemption comment
  if (content.contains('// EXEMPTION: Direct DB access approved')) {
    return true;
  }

  // Check if file contains infrastructure code markers
  if (content.contains('// Infrastructure: DB-level operations')) {
    return true;
  }

  return false;
}
