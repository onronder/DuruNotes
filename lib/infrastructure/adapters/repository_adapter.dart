import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
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
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:duru_notes/repository/folder_repository.dart';
import 'package:duru_notes/repository/template_repository.dart';
import 'package:duru_notes/repository/task_repository.dart';

/// Configuration for migration between legacy and domain repositories
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

/// Repository adapter that provides unified interface for both legacy and domain repositories
/// Implements dual repository pattern for backward compatibility during migration
class RepositoryAdapter {
  RepositoryAdapter({
    required this.migrationConfig,
    required this.domainNotesRepo,
    required this.domainFoldersRepo,
    required this.domainTemplatesRepo,
    required this.domainTasksRepo,
    required this.legacyNotesRepo,
    required this.legacyFoldersRepo,
    required this.legacyTemplatesRepo,
    required this.legacyTasksRepo,
  }) : _logger = LoggerFactory.instance;

  final MigrationConfig migrationConfig;

  // Domain repositories
  final INotesRepository domainNotesRepo;
  final IFolderRepository domainFoldersRepo;
  final ITemplateRepository domainTemplatesRepo;
  final ITaskRepository domainTasksRepo;

  // Legacy repositories
  final NotesRepository legacyNotesRepo;
  final FolderRepository legacyFoldersRepo;
  final TemplateRepository legacyTemplatesRepo;
  final TaskRepository legacyTasksRepo;

  final AppLogger _logger;

  // Notes operations
  Future<dynamic> getNoteById(String id) async {
    try {
      if (migrationConfig.isFeatureEnabled('notes')) {
        return await domainNotesRepo.getNoteById(id);
      } else {
        final localNote = await legacyNotesRepo.getNoteById(id);
        if (localNote == null) return null;

        // Convert LocalNote to domain Note for consistency
        final tags = await legacyNotesRepo.db.getTagsForNote(id);
        final links = await legacyNotesRepo.db.getLinksFromNote(id);
        final domainLinks = links.map(NoteMapper.linkToDomain).toList();

        return NoteMapper.toDomain(localNote, tags: tags, links: domainLinks);
      }
    } catch (e, stack) {
      _logger.error('Failed to get note by id: $id', e, stack);
      rethrow;
    }
  }

  Future<List<dynamic>> getAllNotes() async {
    try {
      if (migrationConfig.isFeatureEnabled('notes')) {
        return await domainNotesRepo.localNotes();
      } else {
        final localNotes = await legacyNotesRepo.localNotes();

        // Convert to domain notes for consistency
        final List<domain.Note> domainNotes = [];
        for (final localNote in localNotes) {
          final tags = await legacyNotesRepo.db.getTagsForNote(localNote.id);
          final links = await legacyNotesRepo.db.getLinksFromNote(localNote.id);
          final domainLinks = links.map(NoteMapper.linkToDomain).toList();

          domainNotes.add(NoteMapper.toDomain(
            localNote,
            tags: tags,
            links: domainLinks,
          ));
        }
        return domainNotes;
      }
    } catch (e, stack) {
      _logger.error('Failed to get all notes', e, stack);
      return [];
    }
  }

  Future<dynamic> createOrUpdateNote({
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
      if (migrationConfig.isFeatureEnabled('notes')) {
        return await domainNotesRepo.createOrUpdate(
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
      } else {
        return await legacyNotesRepo.createOrUpdate(
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
      }
    } catch (e, stack) {
      _logger.error('Failed to create/update note', e, stack);
      rethrow;
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      if (migrationConfig.isFeatureEnabled('notes')) {
        await domainNotesRepo.deleteNote(id);
      } else {
        await legacyNotesRepo.deleteNote(id);
      }
    } catch (e, stack) {
      _logger.error('Failed to delete note: $id', e, stack);
      rethrow;
    }
  }

  Stream<List<dynamic>> watchNotes({
    String? folderId,
    List<String>? anyTags,
    List<String>? noneTags,
    bool pinnedFirst = true,
  }) {
    try {
      if (migrationConfig.isFeatureEnabled('notes')) {
        return domainNotesRepo.watchNotes(
          folderId: folderId,
          anyTags: anyTags,
          noneTags: noneTags,
          pinnedFirst: pinnedFirst,
        );
      } else {
        // Convert legacy stream to domain entities
        return legacyNotesRepo.watchNotes(
          folderId: folderId,
          anyTags: anyTags,
          noneTags: noneTags,
          pinnedFirst: pinnedFirst,
        ).asyncMap((localNotes) async {
          final List<domain.Note> domainNotes = [];
          for (final localNote in localNotes) {
            final tags = await legacyNotesRepo.db.getTagsForNote(localNote.id);
            final links = await legacyNotesRepo.db.getLinksFromNote(localNote.id);
            final domainLinks = links.map(NoteMapper.linkToDomain).toList();

            domainNotes.add(NoteMapper.toDomain(
              localNote,
              tags: tags,
              links: domainLinks,
            ));
          }
          return domainNotes;
        });
      }
    } catch (e, stack) {
      _logger.error('Failed to create notes watch stream', e, stack);
      return Stream.error(e, stack);
    }
  }

  // Folder operations
  Future<dynamic> getFolderById(String id) async {
    try {
      if (migrationConfig.isFeatureEnabled('folders')) {
        return await domainFoldersRepo.getFolder(id);
      } else {
        final localFolder = await legacyFoldersRepo.getFolderById(id);
        if (localFolder == null) return null;
        return FolderMapper.toDomain(localFolder);
      }
    } catch (e, stack) {
      _logger.error('Failed to get folder by id: $id', e, stack);
      rethrow;
    }
  }

  Future<List<dynamic>> getAllFolders() async {
    try {
      if (migrationConfig.isFeatureEnabled('folders')) {
        return await domainFoldersRepo.listFolders();
      } else {
        final localFolders = await legacyFoldersRepo.allFolders();
        return FolderMapper.toDomainList(localFolders);
      }
    } catch (e, stack) {
      _logger.error('Failed to get all folders', e, stack);
      return [];
    }
  }

  Future<dynamic> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
  }) async {
    try {
      if (migrationConfig.isFeatureEnabled('folders')) {
        return await domainFoldersRepo.createFolder(
          name: name,
          parentId: parentId,
          color: color,
          icon: icon,
          description: description,
        );
      } else {
        final folderId = await legacyFoldersRepo.createFolder(
          name: name,
          parentId: parentId,
          color: color ?? '#048ABF',
          icon: icon ?? 'folder',
          description: description,
        );
        final localFolder = await legacyFoldersRepo.getFolderById(folderId);
        return localFolder != null ? FolderMapper.toDomain(localFolder) : null;
      }
    } catch (e, stack) {
      _logger.error('Failed to create folder: $name', e, stack);
      rethrow;
    }
  }

  // Template operations
  Future<List<dynamic>> getAllTemplates() async {
    try {
      if (migrationConfig.isFeatureEnabled('templates')) {
        return await domainTemplatesRepo.getAllTemplates();
      } else {
        final localTemplates = await legacyTemplatesRepo.getAllTemplates();
        return TemplateMapper.toDomainList(localTemplates);
      }
    } catch (e, stack) {
      _logger.error('Failed to get all templates', e, stack);
      return [];
    }
  }

  Future<dynamic> getTemplateById(String id) async {
    try {
      if (migrationConfig.isFeatureEnabled('templates')) {
        return await domainTemplatesRepo.getTemplateById(id);
      } else {
        final localTemplate = await legacyTemplatesRepo.getTemplateById(id);
        if (localTemplate == null) return null;
        return TemplateMapper.toDomain(localTemplate);
      }
    } catch (e, stack) {
      _logger.error('Failed to get template by id: $id', e, stack);
      rethrow;
    }
  }

  Future<dynamic> createTemplate(dynamic template) async {
    try {
      if (migrationConfig.isFeatureEnabled('templates')) {
        if (template is Template) {
          return await domainTemplatesRepo.createTemplate(template);
        } else {
          throw ArgumentError('Expected Template object for domain repository');
        }
      } else {
        Template domainTemplate;
        if (template is Template) {
          domainTemplate = template;
        } else {
          // Convert if needed
          domainTemplate = template as Template;
        }

        final localTemplate = TemplateMapper.toInfrastructure(domainTemplate);
        await legacyTemplatesRepo.createTemplate(localTemplate);
        return domainTemplate;
      }
    } catch (e, stack) {
      _logger.error('Failed to create template', e, stack);
      rethrow;
    }
  }

  // Task operations
  Future<List<dynamic>> getTasksForNote(String noteId) async {
    try {
      if (migrationConfig.isFeatureEnabled('tasks')) {
        return await domainTasksRepo.getTasksForNote(noteId);
      } else {
        final localTasks = await legacyTasksRepo.getTasksForNote(noteId);
        return TaskMapper.toDomainList(localTasks);
      }
    } catch (e, stack) {
      _logger.error('Failed to get tasks for note: $noteId', e, stack);
      return [];
    }
  }

  Future<List<dynamic>> getAllTasks() async {
    try {
      if (migrationConfig.isFeatureEnabled('tasks')) {
        return await domainTasksRepo.getAllTasks();
      } else {
        final localTasks = await legacyTasksRepo.getAllTasks();
        return TaskMapper.toDomainList(localTasks);
      }
    } catch (e, stack) {
      _logger.error('Failed to get all tasks', e, stack);
      return [];
    }
  }

  Future<dynamic> createTask(dynamic task) async {
    try {
      if (migrationConfig.isFeatureEnabled('tasks')) {
        if (task is domain.Task) {
          return await domainTasksRepo.createTask(task);
        } else {
          throw ArgumentError('Expected Task object for domain repository');
        }
      } else {
        domain.Task domainTask;
        if (task is domain.Task) {
          domainTask = task;
        } else {
          // Convert if needed
          domainTask = task as domain.Task;
        }

        final localTask = TaskMapper.toInfrastructure(domainTask);
        await legacyTasksRepo.createTask(localTask);
        return domainTask;
      }
    } catch (e, stack) {
      _logger.error('Failed to create task', e, stack);
      rethrow;
    }
  }

  // Utility methods for conversion between types
  LocalNote domainNoteToLocal(domain.Note note) {
    return NoteMapper.toInfrastructure(note);
  }

  domain.Note localNoteToDomain(LocalNote note, {List<String>? tags, List<domain.NoteLink>? links}) {
    return NoteMapper.toDomain(note, tags: tags, links: links);
  }

  LocalFolder domainFolderToLocal(domain.Folder folder) {
    return FolderMapper.toInfrastructure(folder);
  }

  domain.Folder localFolderToDomain(LocalFolder folder) {
    return FolderMapper.toDomain(folder);
  }

  LocalTemplate domainTemplateToLocal(Template template) {
    return TemplateMapper.toInfrastructure(template);
  }

  Template localTemplateToDomain(LocalTemplate template) {
    return TemplateMapper.toDomain(template);
  }

  NoteTask domainTaskToLocal(domain.Task task) {
    return TaskMapper.toInfrastructure(task);
  }

  domain.Task localTaskToDomain(NoteTask task) {
    return TaskMapper.toDomain(task);
  }

  // Migration control methods
  Future<void> enableFeatureForUser(String feature, String userId) async {
    try {
      _logger.info('Enabling feature $feature for user $userId');

      // Here you would typically update user preferences or feature flags
      // For now, we'll just log the action

      _logger.info('Feature $feature enabled for user $userId');
    } catch (e, stack) {
      _logger.error('Failed to enable feature $feature for user $userId', e, stack);
      rethrow;
    }
  }

  Future<void> disableFeatureForUser(String feature, String userId) async {
    try {
      _logger.info('Disabling feature $feature for user $userId');

      // Here you would typically update user preferences or feature flags
      // For now, we'll just log the action

      _logger.info('Feature $feature disabled for user $userId');
    } catch (e, stack) {
      _logger.error('Failed to disable feature $feature for user $userId', e, stack);
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
          'notes': migrationConfig.isFeatureEnabled('notes'),
          'folders': migrationConfig.isFeatureEnabled('folders'),
          'templates': migrationConfig.isFeatureEnabled('templates'),
          'tasks': migrationConfig.isFeatureEnabled('tasks'),
        },
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e, stack) {
      _logger.error('Failed to get migration status', e, stack);
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Validate data consistency between legacy and domain repositories
  Future<Map<String, dynamic>> validateDataConsistency() async {
    try {
      final results = <String, dynamic>{
        'notes': await _validateNotesConsistency(),
        'folders': await _validateFoldersConsistency(),
        'templates': await _validateTemplatesConsistency(),
        'tasks': await _validateTasksConsistency(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      final hasIssues = results.values
          .where((v) => v is Map<String, dynamic>)
          .any((v) => (v as Map<String, dynamic>)['issues_found'] == true);

      results['overall_status'] = hasIssues ? 'issues_found' : 'consistent';

      return results;
    } catch (e, stack) {
      _logger.error('Failed to validate data consistency', e, stack);
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'overall_status': 'error',
      };
    }
  }

  Future<Map<String, dynamic>> _validateNotesConsistency() async {
    try {
      // Get counts from both repositories
      final domainNotes = await domainNotesRepo.localNotes();
      final legacyNotes = await legacyNotesRepo.localNotes();

      return {
        'domain_count': domainNotes.length,
        'legacy_count': legacyNotes.length,
        'count_matches': domainNotes.length == legacyNotes.length,
        'issues_found': domainNotes.length != legacyNotes.length,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'issues_found': true,
      };
    }
  }

  Future<Map<String, dynamic>> _validateFoldersConsistency() async {
    try {
      final domainFolders = await domainFoldersRepo.listFolders();
      final legacyFolders = await legacyFoldersRepo.allFolders();

      return {
        'domain_count': domainFolders.length,
        'legacy_count': legacyFolders.length,
        'count_matches': domainFolders.length == legacyFolders.length,
        'issues_found': domainFolders.length != legacyFolders.length,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'issues_found': true,
      };
    }
  }

  Future<Map<String, dynamic>> _validateTemplatesConsistency() async {
    try {
      final domainTemplates = await domainTemplatesRepo.getAllTemplates();
      final legacyTemplates = await legacyTemplatesRepo.getAllTemplates();

      return {
        'domain_count': domainTemplates.length,
        'legacy_count': legacyTemplates.length,
        'count_matches': domainTemplates.length == legacyTemplates.length,
        'issues_found': domainTemplates.length != legacyTemplates.length,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'issues_found': true,
      };
    }
  }

  Future<Map<String, dynamic>> _validateTasksConsistency() async {
    try {
      final domainTasks = await domainTasksRepo.getAllTasks();
      final legacyTasks = await legacyTasksRepo.getAllTasks();

      return {
        'domain_count': domainTasks.length,
        'legacy_count': legacyTasks.length,
        'count_matches': domainTasks.length == legacyTasks.length,
        'issues_found': domainTasks.length != legacyTasks.length,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'issues_found': true,
      };
    }
  }
}