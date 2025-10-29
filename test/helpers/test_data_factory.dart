/* COMMENTED OUT - 3 errors
 * This file uses old models/APIs. Needs rewrite.
 */

/*
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/note_link.dart';
import 'package:duru_notes/models/note_kind.dart';

/// Factory for creating test data with sensible defaults
///
/// Usage:
/// ```dart
/// final note = TestDataFactory.note(title: 'My Note');
/// final folder = TestDataFactory.folder(name: 'Work');
/// ```
class TestDataFactory {
  static int _noteCounter = 0;
  static int _folderCounter = 0;
  static int _taskCounter = 0;

  /// Create a domain.Note with sensible defaults
  ///
  /// All parameters are optional - defaults provided for required fields
  static domain.Note note({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool deleted = false,
    String? encryptedMetadata,
    bool isPinned = false,
    NoteKind noteType = NoteKind.note,
    String? folderId,
    int version = 1,
    String userId = 'test-user-1',
    String? attachmentMeta,
    String? metadata,
    List<String> tags = const [],
    List<domain.NoteLinkReference> links = const [],
  }) {
    final counter = _noteCounter++;
    final now = DateTime.now();

    return domain.Note(
      id: id ?? 'test-note-$counter',
      title: title ?? 'Test Note $counter',
      body: body ?? 'Test note content $counter',
      createdAt: createdAt ?? now.subtract(Duration(hours: counter)),
      updatedAt: updatedAt ?? now.subtract(Duration(hours: counter)),
      deleted: deleted,
      encryptedMetadata: encryptedMetadata,
      isPinned: isPinned,
      noteType: noteType,
      folderId: folderId,
      version: version,
      userId: userId,
      attachmentMeta: attachmentMeta,
      metadata: metadata,
      tags: tags,
      links: links,
    );
  }

  /// Create a domain.Folder with sensible defaults
  static domain.Folder folder({
    String? id,
    String? name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    String userId = 'test-user-1',
    String? path,
    bool deleted = false,
  }) {
    final counter = _folderCounter++;
    final now = DateTime.now();

    return domain.Folder(
      id: id ?? 'test-folder-$counter',
      name: name ?? 'Test Folder $counter',
      parentId: parentId,
      color: color,
      icon: icon,
      description: description,
      sortOrder: sortOrder + counter,
      createdAt: createdAt ?? now.subtract(Duration(hours: counter)),
      updatedAt: updatedAt ?? now.subtract(Duration(hours: counter)),
      userId: userId,
      path: path,
      deleted: deleted,
    );
  }

  /// Create a list of notes with sequential IDs and timestamps
  ///
  /// Useful for pagination tests
  static List<domain.Note> notes(
    int count, {
    String Function(int index)? idGenerator,
    String Function(int index)? titleGenerator,
    String Function(int index)? bodyGenerator,
    DateTime? startTime,
  }) {
    final start = startTime ?? DateTime.now();
    return List.generate(
      count,
      (i) => note(
        id: idGenerator?.call(i) ?? 'test-note-$i',
        title: titleGenerator?.call(i) ?? 'Test Note $i',
        body: bodyGenerator?.call(i) ?? 'Content $i',
        createdAt: start.subtract(Duration(hours: i)),
        updatedAt: start.subtract(Duration(hours: i)),
      ),
    );
  }

  /// Create a list of folders with sequential IDs
  static List<domain.Folder> folders(
    int count, {
    String Function(int index)? idGenerator,
    String Function(int index)? nameGenerator,
    String? parentId,
  }) {
    return List.generate(
      count,
      (i) => folder(
        id: idGenerator?.call(i) ?? 'test-folder-$i',
        name: nameGenerator?.call(i) ?? 'Test Folder $i',
        parentId: parentId,
      ),
    );
  }

  /// Reset all counters (useful in setUp/tearDown)
  static void reset() {
    _noteCounter = 0;
    _folderCounter = 0;
    _taskCounter = 0;
  }
}
*/
