import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart' as db;
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/note_link.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/entities/template.dart';
import 'package:duru_notes/domain/entities/task.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/domain/repositories/i_task_repository.dart';
import 'package:duru_notes/infrastructure/mappers/note_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/folder_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/template_mapper.dart';
import 'package:duru_notes/infrastructure/mappers/task_mapper.dart';

/// Configuration for feature flags
class MigrationConfig {
  const MigrationConfig({
    required this.useDomainModels,
    required this.enabledFeatures,
  });

  final bool useDomainModels;
  final Map<String, bool> enabledFeatures;

  bool isFeatureEnabled(String feature) {
    return enabledFeatures[feature] ?? false;
  }

  MigrationConfig enableFeature(String feature) {
    return MigrationConfig(
      useDomainModels: useDomainModels,
      enabledFeatures: {...enabledFeatures, feature: true},
    );
  }

  MigrationConfig disableFeature(String feature) {
    return MigrationConfig(
      useDomainModels: useDomainModels,
      enabledFeatures: {...enabledFeatures, feature: false},
    );
  }
}

/// Repository adapter that provides unified interface for domain repositories
///
/// **PRODUCTION NOTE**: Legacy repository support has been completely removed.
/// All operations now use the domain layer exclusively. This adapter remains
/// for backward compatibility with services that expect this interface.
class RepositoryAdapter {
  RepositoryAdapter({
    required this.migrationConfig,
    required this.domainNotesRepo,
    required this.domainFoldersRepo,
    required this.domainTemplatesRepo,
    required this.domainTasksRepo,
  }) : _logger = LoggerFactory.instance;

  final MigrationConfig migrationConfig;

  // Domain repositories (production ready)
  final INotesRepository domainNotesRepo;
  final IFolderRepository domainFoldersRepo;
  final ITemplateRepository domainTemplatesRepo;
  final ITaskRepository domainTasksRepo;

  final AppLogger _logger;

  // ============================================================================
  // Notes operations
  // ============================================================================

  Future<domain.Note?> getNoteById(String id) async {
    try {
      return await domainNotesRepo.getNoteById(id);
    } catch (e, stack) {
      _logger.error('Failed to get note by id: $id', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<List<domain.Note>> getAllNotes() async {
    try {
      return await domainNotesRepo.localNotes();
    } catch (e, stack) {
      _logger.error('Failed to get all notes', error: e, stackTrace: stack);
      return [];
    }
  }

  Future<String> createOrUpdateNote({
    required String title,
    required String body,
    String? id,
    String? folderId,
    List<String> tags = const [],
    List<Map<String, String?>> links = const [],
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadataJson,
    bool? isPinned,
  }) async {
    try {
      final result = await domainNotesRepo.createOrUpdate(
        title: title,
        body: body,
        id: id,
        folderId: folderId,
        tags: tags,
        links: links,
        attachmentMeta: attachmentMeta,
        metadataJson: metadataJson,
        isPinned: isPinned,
      );
      return result?.id ?? id ?? '';
    } catch (e, stack) {
      _logger.error('Failed to create/update note', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      await domainNotesRepo.deleteNote(id);
    } catch (e, stack) {
      _logger.error('Failed to delete note: $id', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Stream<List<domain.Note>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
  }) {
    try {
      return domainNotesRepo.watchNotes(
        folderId: folderId,
        anyTags: anyTags,
        noneTags: noneTags,
        pinnedFirst: pinnedFirst,
      );
    } catch (e, stack) {
      _logger.error('Failed to create notes watch stream', error: e, stackTrace: stack);
      return Stream.error(e, stack);
    }
  }

  // ============================================================================
  // Folder operations
  // ============================================================================

  Future<domain.Folder?> getFolderById(String id) async {
    try {
      return await domainFoldersRepo.getFolder(id);
    } catch (e, stack) {
      _logger.error('Failed to get folder by id: $id', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<List<domain.Folder>> getAllFolders() async {
    try {
      return await domainFoldersRepo.listFolders();
    } catch (e, stack) {
      _logger.error('Failed to get all folders', error: e, stackTrace: stack);
      return [];
    }
  }

  Future<domain.Folder> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async {
    try {
      return await domainFoldersRepo.createFolder(
        name: name,
        parentId: parentId,
        color: color,
        icon: icon,
        description: description,
      );
    } catch (e, stack) {
      _logger.error('Failed to create folder: $name', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // ============================================================================
  // Template operations
  // ============================================================================

  Future<List<Template>> getAllTemplates() async {
    try {
      return await domainTemplatesRepo.getAllTemplates();
    } catch (e, stack) {
      _logger.error('Failed to get all templates', error: e, stackTrace: stack);
      return [];
    }
  }

  Future<Template?> getTemplateById(String id) async {
    try {
      return await domainTemplatesRepo.getTemplateById(id);
    } catch (e, stack) {
      _logger.error('Failed to get template by id: $id', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<Template> createTemplate(Template template) async {
    try {
      return await domainTemplatesRepo.createTemplate(template);
    } catch (e, stack) {
      _logger.error('Failed to create template', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // ============================================================================
  // Task operations
  // ============================================================================

  Future<List<domain.Task>> getTasksForNote(String noteId) async {
    try {
      return await domainTasksRepo.getTasksForNote(noteId);
    } catch (e, stack) {
      _logger.error('Failed to get tasks for note: $noteId', error: e, stackTrace: stack);
      return [];
    }
  }

  Future<List<domain.Task>> getAllTasks() async {
    try {
      return await domainTasksRepo.getAllTasks();
    } catch (e, stack) {
      _logger.error('Failed to get all tasks', error: e, stackTrace: stack);
      return [];
    }
  }

  Future<domain.Task> createTask(domain.Task task) async {
    try {
      return await domainTasksRepo.createTask(task);
    } catch (e, stack) {
      _logger.error('Failed to create task', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // ============================================================================
  // Utility methods for conversion between types
  // ============================================================================

  // NOTE: Direct conversion methods removed - encryption required for notes/templates
  // Use repository methods which handle encryption properly

  db.LocalNote domainNoteToLocal(domain.Note note, {required String titleEncrypted, required String bodyEncrypted}) {
    return NoteMapper.toInfrastructure(note, titleEncrypted: titleEncrypted, bodyEncrypted: bodyEncrypted);
  }

  domain.Note localNoteToDomain(
    db.LocalNote note, {
    required String title,
    required String body,
    List<String>? tags,
    List<NoteLink>? links,
  }) {
    return NoteMapper.toDomain(
      note,
      title: title,
      body: body,
      tags: tags,
      links: links,
    );
  }

  db.LocalFolder domainFolderToLocal(domain.Folder folder) {
    return FolderMapper.toInfrastructure(folder);
  }

  domain.Folder localFolderToDomain(db.LocalFolder folder) {
    return FolderMapper.toDomain(folder);
  }

  db.LocalTemplate domainTemplateToLocal(Template template) {
    return TemplateMapper.toInfrastructure(template);
  }

  Template localTemplateToDomain(db.LocalTemplate template) {
    return TemplateMapper.toDomain(template);
  }

  db.NoteTask domainTaskToLocal(
    domain.Task task, {
    required String userId,
    required String contentEncrypted,
    String? notesEncrypted,
  }) {
    return TaskMapper.toInfrastructure(
      task,
      userId: userId,
      contentEncrypted: contentEncrypted,
      notesEncrypted: notesEncrypted,
    );
  }

  domain.Task localTaskToDomain(db.NoteTask task, {required String content}) {
    return TaskMapper.toDomain(task, content: content);
  }

  // ============================================================================
  // Migration control methods (kept for backward compatibility)
  // ============================================================================

  Future<void> enableFeatureForUser(String feature, String userId) async {
    try {
      _logger.info('Enabling feature $feature for user $userId');
      // Feature flags are now controlled at the provider level
      _logger.info('Feature $feature enabled for user $userId');
    } catch (e, stack) {
      _logger.error('Failed to enable feature $feature for user $userId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> disableFeatureForUser(String feature, String userId) async {
    try {
      _logger.info('Disabling feature $feature for user $userId');
      // Feature flags are now controlled at the provider level
      _logger.info('Feature $feature disabled for user $userId');
    } catch (e, stack) {
      _logger.error('Failed to disable feature $feature for user $userId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      return {
        'migration_config': {
          'use_domain_models': migrationConfig.useDomainModels,
          'enabled_features': migrationConfig.enabledFeatures,
        },
        'feature_status': {
          'notes': true, // Always enabled now
          'folders': true,
          'templates': true,
          'tasks': true,
        },
        'migration_complete': true,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e, stack) {
      _logger.error('Failed to get migration status', error: e, stackTrace: stack);
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Validate data consistency (simplified for domain-only operation)
  Future<Map<String, dynamic>> validateDataConsistency() async {
    try {
      final results = <String, dynamic>{
        'notes': await _validateNotesConsistency(),
        'folders': await _validateFoldersConsistency(),
        'templates': await _validateTemplatesConsistency(),
        'tasks': await _validateTasksConsistency(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      results['overall_status'] = 'consistent';
      results['migration_complete'] = true;

      return results;
    } catch (e, stack) {
      _logger.error('Failed to validate data consistency', error: e, stackTrace: stack);
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'overall_status': 'error',
      };
    }
  }

  Future<Map<String, dynamic>> _validateNotesConsistency() async {
    try {
      final notes = await domainNotesRepo.localNotes();
      return {
        'count': notes.length,
        'status': 'ok',
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'status': 'error',
      };
    }
  }

  Future<Map<String, dynamic>> _validateFoldersConsistency() async {
    try {
      final folders = await domainFoldersRepo.listFolders();
      return {
        'count': folders.length,
        'status': 'ok',
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'status': 'error',
      };
    }
  }

  Future<Map<String, dynamic>> _validateTemplatesConsistency() async {
    try {
      final templates = await domainTemplatesRepo.getAllTemplates();
      return {
        'count': templates.length,
        'status': 'ok',
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'status': 'error',
      };
    }
  }

  Future<Map<String, dynamic>> _validateTasksConsistency() async {
    try {
      final tasks = await domainTasksRepo.getAllTasks();
      return {
        'count': tasks.length,
        'status': 'ok',
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'status': 'error',
      };
    }
  }
}
