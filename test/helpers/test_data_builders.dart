import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Build a test LocalNote with correct required parameters
LocalNote buildTestLocalNote({
  String? id,
  String? titleEncrypted,
  String? bodyEncrypted,
  String? metadataEncrypted,
  int? encryptionVersion,
  DateTime? updatedAt,
  bool? deleted,
  String? encryptedMetadata,
  bool? isPinned,
  NoteKind? noteType,
  int? version,
  String? userId,
  String? attachmentMeta,
  String? metadata,
}) {
  final now = DateTime.now();
  return LocalNote(
    id: id ?? _uuid.v4(),
    titleEncrypted: titleEncrypted ?? 'Encrypted Test Title',
    bodyEncrypted: bodyEncrypted ?? 'Encrypted Test Body',
    metadataEncrypted: metadataEncrypted,
    encryptionVersion: encryptionVersion ?? 1,
    updatedAt: updatedAt ?? now,
    deleted: deleted ?? false,
    encryptedMetadata: encryptedMetadata,
    isPinned: isPinned ?? false,
    noteType: noteType ?? NoteKind.note,
    version: version ?? 1,
    userId: userId,
    attachmentMeta: attachmentMeta,
    metadata: metadata,
  );
}

/// Build a test NoteTask with correct required parameters
NoteTask buildTestNoteTask({
  String? id,
  String? noteId,
  String? contentEncrypted,
  String? labelsEncrypted,
  String? notesEncrypted,
  int? encryptionVersion,
  TaskStatus? status,
  TaskPriority? priority,
  DateTime? dueDate,
  DateTime? completedAt,
  String? completedBy,
  int? position,
  String? contentHash,
  int? reminderId,
  int? estimatedMinutes,
  int? actualMinutes,
  String? parentTaskId,
  DateTime? createdAt,
  DateTime? updatedAt,
  bool? deleted,
}) {
  final now = DateTime.now();
  return NoteTask(
    id: id ?? _uuid.v4(),
    noteId: noteId ?? _uuid.v4(),
    contentEncrypted: contentEncrypted ?? 'Encrypted Test Task',
    labelsEncrypted: labelsEncrypted,
    notesEncrypted: notesEncrypted,
    encryptionVersion: encryptionVersion ?? 1,
    status: status ?? TaskStatus.todo,
    priority: priority ?? TaskPriority.medium,
    dueDate: dueDate,
    completedAt: completedAt,
    completedBy: completedBy,
    position: position ?? 0,
    contentHash: contentHash ?? '',
    reminderId: reminderId,
    estimatedMinutes: estimatedMinutes,
    actualMinutes: actualMinutes,
    parentTaskId: parentTaskId,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    deleted: deleted ?? false,
  );
}

/// Build a test LocalFolder with correct required parameters
LocalFolder buildTestLocalFolder({
  String? id,
  String? userId,
  String? name,
  String? parentId,
  String? path,
  int? sortOrder,
  String? color,
  String? icon,
  String? description,
  DateTime? createdAt,
  DateTime? updatedAt,
  bool? deleted,
}) {
  final now = DateTime.now();
  final folderId = id ?? _uuid.v4();
  final folderName = name ?? 'Test Folder';
  return LocalFolder(
    id: folderId,
    userId: userId ?? 'test-user-id',
    name: folderName,
    parentId: parentId,
    path: path ?? '/$folderName',
    sortOrder: sortOrder ?? 0,
    color: color,
    icon: icon,
    description: description ?? '',
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    deleted: deleted ?? false,
  );
}

/// Build a test SavedSearch with correct required parameters
SavedSearch buildTestSavedSearch({
  String? id,
  String? userId,
  String? name,
  String? query,
  String? searchType,
  String? parameters,
  int? sortOrder,
  String? color,
  String? icon,
  bool? isPinned,
  DateTime? createdAt,
  DateTime? lastUsedAt,
  int? usageCount,
}) {
  final now = DateTime.now();
  return SavedSearch(
    id: id ?? _uuid.v4(),
    userId: userId ?? 'test-user-id',
    name: name ?? 'Test Search',
    query: query ?? 'test query',
    searchType: searchType ?? 'text',
    parameters: parameters,
    sortOrder: sortOrder ?? 0,
    color: color,
    icon: icon,
    isPinned: isPinned ?? false,
    createdAt: createdAt ?? now,
    lastUsedAt: lastUsedAt,
    usageCount: usageCount ?? 0,
  );
}
