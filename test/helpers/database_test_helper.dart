import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:flutter_test/flutter_test.dart';

/// Factory for creating in-memory test databases with proper initialization
///
/// Usage:
/// ```dart
/// late AppDb testDb;
///
/// setUp(() async {
///   testDb = await DatabaseTestHelper.createTestDatabase();
/// });
///
/// tearDown(() async {
///   await DatabaseTestHelper.closeDatabase(testDb);
/// });
/// ```
class DatabaseTestHelper {
  /// Create a new in-memory database for testing with proper initialization
  ///
  /// This ensures:
  /// - Flutter binding is initialized
  /// - Database is created in memory (no file I/O)
  /// - All migrations are run
  /// - Database is ready for testing
  static AppDb createTestDatabase() {
    // Ensure Flutter binding is initialized for tests
    TestWidgetsFlutterBinding.ensureInitialized();

    // Create in-memory database
    return AppDb.forTesting(NativeDatabase.memory());
  }

  /// Create a database with migrations applied
  ///
  /// Use this when testing specific migration scenarios
  static Future<AppDb> createTestDatabaseWithMigrations({
    int? fromVersion,
    int? toVersion,
  }) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // For now, just create a standard test database
    // Migration testing would require custom migration strategy
    final db = AppDb.forTesting(NativeDatabase.memory());

    return db;
  }

  /// Close database and cleanup resources
  static Future<void> closeDatabase(AppDb db) async {
    await db.close();
  }

  /// Insert test data helpers
  static Future<void> insertTestNote(
    AppDb db, {
    required String id,
    String? titleEncrypted,
    String? bodyEncrypted,
    String? userId,
    DateTime? updatedAt,
    bool deleted = false,
    bool isPinned = false,
    int encryptionVersion = 1,
  }) async {
    final now = DateTime.now();

    await db
        .into(db.localNotes)
        .insert(
          LocalNotesCompanion.insert(
            id: id,
            titleEncrypted: Value(titleEncrypted ?? ''),
            bodyEncrypted: Value(bodyEncrypted ?? ''),
            createdAt: updatedAt ?? now,
            updatedAt: updatedAt ?? now,
            deleted: Value(deleted),
            isPinned: Value(isPinned),
            userId: Value(userId),
            encryptionVersion: Value(encryptionVersion),
          ),
        );
  }

  /// Insert test saved search
  static Future<void> insertTestSavedSearch(
    AppDb db, {
    required String id,
    String? userId,
    String? name,
    String? query,
    String? searchType,
    int sortOrder = 0,
    bool isPinned = false,
    DateTime? createdAt,
  }) async {
    final now = DateTime.now();

    await db.customStatement(
      '''
      INSERT INTO saved_searches (
        id, user_id, name, query, search_type, parameters, sort_order,
        color, icon, is_pinned, created_at, last_used_at, usage_count
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        userId,
        name ?? 'Test Search $id',
        query ?? 'test query',
        searchType ?? 'text',
        null, // parameters
        sortOrder,
        null, // color
        null, // icon
        isPinned ? 1 : 0,
        (createdAt ?? now).millisecondsSinceEpoch,
        null, // last_used_at
        0, // usage_count
      ],
    );
  }

  /// Insert test folder
  static Future<void> insertTestFolder(
    AppDb db, {
    required String id,
    required String userId,
    required String name,
    String? parentId,
    String? path,
    int sortOrder = 0,
    String? color,
    String? icon,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final now = DateTime.now();

    await db
        .into(db.localFolders)
        .insert(
          LocalFoldersCompanion.insert(
            id: id,
            userId: userId,
            name: name,
            parentId: Value(parentId),
            path: path ?? '/$name',
            sortOrder: Value(sortOrder),
            color: Value(color),
            icon: Value(icon),
            description: Value(description ?? ''),
            createdAt: createdAt ?? now,
            updatedAt: updatedAt ?? now,
          ),
        );
  }

  /// Insert test task
  static Future<void> insertTestTask(
    AppDb db, {
    required String id,
    required String noteId,
    required String userId,
    required String contentEncrypted,
    String? contentHash,
    String? labelsEncrypted,
    String? notesEncrypted,
    TaskStatus status = TaskStatus.open,
    TaskPriority priority = TaskPriority.medium,
    int position = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dueDate,
    String? parentTaskId,
    bool deleted = false,
    int encryptionVersion = 0,
  }) async {
    final now = DateTime.now();

    await db
        .into(db.noteTasks)
        .insert(
          NoteTasksCompanion.insert(
            id: id,
            noteId: noteId,
            userId: userId,
            contentEncrypted: contentEncrypted,
            contentHash:
                contentHash ??
                'test-hash-${DateTime.now().millisecondsSinceEpoch}',
            labelsEncrypted: Value(labelsEncrypted),
            notesEncrypted: Value(notesEncrypted),
            status: Value(status),
            priority: Value(priority),
            position: Value(position),
            createdAt: Value(createdAt ?? now),
            updatedAt: Value(updatedAt ?? now),
            dueDate: Value(dueDate),
            parentTaskId: Value(parentTaskId),
            deleted: Value(deleted),
            encryptionVersion: Value(encryptionVersion),
          ),
        );
  }

  /// Check if a table column exists (useful for migration tests)
  static Future<bool> columnExists(
    AppDb db,
    String tableName,
    String columnName,
  ) async {
    try {
      await db
          .customSelect('SELECT $columnName FROM $tableName LIMIT 1')
          .getSingleOrNull();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Run a specific migration
  static Future<void> runMigration(
    AppDb db,
    MigrationStrategy migration,
    int fromVersion,
    int toVersion,
  ) async {
    await migration.onUpgrade(db.createMigrator(), fromVersion, toVersion);
  }

  /// Get row count for a table
  static Future<int> getTableRowCount(AppDb db, String tableName) async {
    final result = await db
        .customSelect('SELECT COUNT(*) as count FROM $tableName')
        .getSingle();
    return result.data['count'] as int;
  }

  /// Clear all data from a table
  static Future<void> clearTable(AppDb db, String tableName) async {
    await db.customStatement('DELETE FROM $tableName');
  }

  /// Verify database integrity
  static Future<bool> verifyIntegrity(AppDb db) async {
    try {
      final result = await db.customSelect('PRAGMA integrity_check').get();
      return result.isNotEmpty && result.first.data['integrity_check'] == 'ok';
    } catch (e) {
      return false;
    }
  }
}

/// Base class for database tests with automatic setup/teardown
abstract class DatabaseTest {
  late AppDb testDb;

  /// Override to provide custom database initialization
  AppDb createDatabase() {
    return DatabaseTestHelper.createTestDatabase();
  }

  /// Setup method - call in setUp()
  Future<void> initializeDatabase() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    testDb = createDatabase();
  }

  /// Teardown method - call in tearDown()
  Future<void> cleanupDatabase() async {
    await DatabaseTestHelper.closeDatabase(testDb);
  }

  /// Helper to run test with automatic database setup/teardown
  Future<void> runDatabaseTest(Future<void> Function(AppDb db) testBody) async {
    await initializeDatabase();
    try {
      await testBody(testDb);
    } finally {
      await cleanupDatabase();
    }
  }
}
