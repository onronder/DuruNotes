/* COMMENTED OUT - 6 errors - uses old APIs
 * This class uses old models/APIs that no longer exist.
 * Needs rewrite to use new architecture.
 */

/*
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_kind.dart';

/// Factory for creating in-memory test databases
///
/// This eliminates the need to mock Drift's complex query builder pattern.
/// Instead, tests use a real database in memory.
///
/// Usage:
/// ```dart
/// test('example', () async {
///   final db = TestDatabaseFactory.createTestDb();
///
///   // Insert test data
///   await db.into(db.localNotes).insert(LocalLocalNotesCompanion.insert(
///     id: 'test-1',
///     title: 'Test Note',
///     body: 'Content',
///     userId: 'test-user',
///   ));
///
///   // Test repository operations
///   final note = await repository.getNoteById('test-1');
///   expect(note, isNotNull);
///
///   // Cleanup
///   await db.close();
/// });
/// ```
class TestDatabaseFactory {
  /// Create a new in-memory database for testing
  ///
  /// Each test should create its own database to ensure isolation.
  /// The database is empty and must be populated with test data.
  ///
  /// Returns a fresh AppDb instance backed by an in-memory SQLite database.
  static AppDb createTestDb() {
    return AppDb();
  }

  /// Create a database with common test data pre-populated
  ///
  /// Useful for tests that need a standard set of test data.
  static Future<AppDb> createTestDbWithData({
    List<LocalLocalNotesCompanion>? notes,
    List<NoteNoteTasksCompanion>? tasks,
  }) async {
    final db = createTestDb();

    if (notes != null) {
      for (final note in notes) {
        await db.into(db.localNotes).insert(note);
      }
    }

    if (tasks != null) {
      for (final task in tasks) {
        await db.into(db.noteTasks).insert(task);
      }
    }

    return db;
  }

  /// Create a LocalNote companion for insertion
  ///
  /// Provides sensible defaults for required fields.
  /// Matches Drift's generated LocalLocalNotesCompanion.insert() signature exactly.
  static LocalLocalNotesCompanion createNoteCompanion({
    required String id,
    String? title,
    String? body,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
    String? encryptedMetadata,
    bool? isPinned,
    NoteKind? noteType,
    int? version,
    String? attachmentMeta,
    String? metadata,
    String? titleEncrypted,
    String? bodyEncrypted,
    String? metadataEncrypted,
    int? encryptionVersion,
  }) {
    final now = DateTime.now();
    return LocalLocalNotesCompanion.insert(
      id: id,
      updatedAt: updatedAt ?? now,  // Required raw DateTime (not Value)
      title: title != null ? Value(title) : const Value.absent(),
      body: body != null ? Value(body) : const Value.absent(),
      userId: userId != null ? Value(userId) : const Value.absent(),
      createdAt: Value(createdAt ?? now),
      deleted: Value(deleted ?? false),
      encryptedMetadata: encryptedMetadata != null ? Value(encryptedMetadata) : const Value.absent(),
      isPinned: Value(isPinned ?? false),
      noteType: Value(noteType ?? NoteKind.note),
      version: Value(version ?? 1),
      attachmentMeta: attachmentMeta != null ? Value(attachmentMeta) : const Value.absent(),
      metadata: metadata != null ? Value(metadata) : const Value.absent(),
      titleEncrypted: titleEncrypted != null ? Value(titleEncrypted) : const Value.absent(),
      bodyEncrypted: bodyEncrypted != null ? Value(bodyEncrypted) : const Value.absent(),
      metadataEncrypted: metadataEncrypted != null ? Value(metadataEncrypted) : const Value.absent(),
      encryptionVersion: Value(encryptionVersion ?? 0),
    );
  }

  /// Create a NoteTask companion for insertion
  ///
  /// Matches Drift's generated NoteNoteTasksCompanion.insert() signature exactly.
  static NoteNoteTasksCompanion createTaskCompanion({
    required String id,
    required String noteId,
    required String content,
    String? contentHash,
    TaskStatus? status,
    TaskPriority? priority,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dueDate,
    String? parentTaskId,
    int? reminderId,
    bool? deleted,
    int? encryptionVersion,
  }) {
    final now = DateTime.now();
    return NoteNoteTasksCompanion.insert(
      id: id,
      noteId: noteId,
      content: content,
      contentHash: contentHash ?? 'hash',  // Required raw String (not Value)
      status: status != null ? Value(status) : Value(TaskStatus.open),
      priority: priority != null ? Value(priority) : Value(TaskPriority.medium),
      position: Value(position ?? 0),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(updatedAt ?? now),
      dueDate: dueDate != null ? Value(dueDate) : const Value.absent(),
      parentTaskId: parentTaskId != null ? Value(parentTaskId) : const Value.absent(),
      reminderId: reminderId != null ? Value(reminderId) : const Value.absent(),
      deleted: Value(deleted ?? false),
      encryptionVersion: Value(encryptionVersion ?? 0),
    );
  }

}*/