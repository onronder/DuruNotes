import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/template.dart' as domain;
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show migrationConfigProvider;
import 'package:duru_notes/core/providers/database_providers.dart' show appDbProvider;
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/features/folders/providers/folders_repository_providers.dart'
    show folderCoreRepositoryProvider;
import 'package:duru_notes/features/tasks/providers/tasks_repository_providers.dart'
    show taskCoreRepositoryProvider;
import 'package:duru_notes/features/templates/providers/templates_providers.dart'
    show templateCoreRepositoryProvider;
import 'package:duru_notes/services/unified_search_service.dart'
    show unifiedSearchServiceProvider, SearchOptions, SearchResultType;

// DEPRECATED: This file is being replaced by the new unified architecture
// Use the providers from features/*/providers/*_unified_providers.dart instead
// This file will be removed once migration is complete

import 'package:duru_notes/core/models/unified_note.dart' as models;
import 'package:duru_notes/core/models/unified_task.dart' as models;
import 'package:duru_notes/core/models/unified_folder.dart' as models;

/// Unified types now use the strongly typed models
typedef UnifiedNote = models.UnifiedNote;
typedef UnifiedFolder = models.UnifiedFolder;
typedef UnifiedTask = models.UnifiedTask;
typedef UnifiedTemplate = dynamic; // Still need to create UnifiedTemplate

/// Unified notes provider - no more feature flags!
final unifiedNotesProvider = FutureProvider.autoDispose<List<UnifiedNote>>((ref) async {
  final logger = LoggerFactory.instance;

  try {
    logger.info('[UnifiedProvider] Loading notes with unified architecture');

    // Always use domain repository
    final repository = ref.watch(notesCoreRepositoryProvider);
    final notes = await repository.localNotes();

    // Convert to UnifiedNote type
    return notes.map((domain.Note n) => UnifiedNote.from(n)).toList();
  } catch (e, stack) {
    logger.error('[UnifiedProvider] Failed to load notes', error: e, stackTrace: stack);
    return [];
  }
});

/// Unified folders provider - no more feature flags!
final unifiedFoldersProvider = FutureProvider.autoDispose<List<UnifiedFolder>>((ref) async {
  final logger = LoggerFactory.instance;

  try {
    logger.info('[UnifiedProvider] Loading folders with unified architecture');

    // Always use domain repository
    final repository = ref.watch(folderCoreRepositoryProvider);
    final folders = await repository.listFolders();

    // Convert to UnifiedFolder type
    return folders.map((f) => UnifiedFolder.from(f)).toList();
  } catch (e, stack) {
    LoggerFactory.instance.error('[UnifiedProvider] Failed to load folders', error: e, stackTrace: stack);
    return [];
  }
});

/// Unified tasks provider - no more feature flags!
final unifiedTasksProvider = FutureProvider.autoDispose<List<UnifiedTask>>((ref) async {
  final logger = LoggerFactory.instance;

  try {
    logger.info('[UnifiedProvider] Loading tasks with unified architecture');

    // Always use domain repository
    final repository = ref.watch(taskCoreRepositoryProvider);

    // Task repository can be null if user is not authenticated
    if (repository == null) {
      logger.warning('[UnifiedProvider] Task repository not available (user not authenticated)');
      return [];
    }

    final tasks = await repository.getAllTasks();

    // Convert to UnifiedTask type
    return tasks.map((t) => UnifiedTask.from(t)).toList();
  } catch (e, stack) {
    logger.error('[UnifiedProvider] Failed to load tasks', error: e, stackTrace: stack);
    return [];
  }
});

// Note: The rest of this file will be removed once migration is complete
// Legacy task provider removed - use unifiedTasksProvider instead

/// Unified templates provider
final unifiedTemplatesProvider = FutureProvider.autoDispose<List<UnifiedTemplate>>((ref) async {
  final config = ref.watch(migrationConfigProvider);
  final logger = LoggerFactory.instance;

  try {
    if (config.isFeatureEnabled('templates')) {
      logger.info('[UnifiedProvider] Using domain templates');

      // Use domain repository
      final repository = ref.watch(templateCoreRepositoryProvider);
      final templates = await repository.getAllTemplates();

      return templates;
    } else {
      logger.info('[UnifiedProvider] Using legacy templates');

      // Use legacy repository
      final db = ref.watch(appDbProvider);
      final templates = await db.getAllTemplates();

      return templates;
    }
  } catch (e, stack) {
    logger.error('[UnifiedProvider] Failed to load templates', error: e, stackTrace: stack);
    return [];
  }
});

/// Helper to get note ID - UnifiedNote now only wraps domain entities
String getUnifiedNoteId(UnifiedNote note) {
  return note.id;
}

/// Helper to get note title - UnifiedNote now only wraps domain entities
String getUnifiedNoteTitle(UnifiedNote note) {
  return note.title;
}

/// Helper to get note body - UnifiedNote now only wraps domain entities
String getUnifiedNoteBody(UnifiedNote note) {
  return note.body;
}

/// Helper to get note pinned status - UnifiedNote now only wraps domain entities
bool getUnifiedNoteIsPinned(UnifiedNote note) {
  return note.isPinned;
}

/// Helper to get note folder ID - UnifiedNote now only wraps domain entities
String? getUnifiedNoteFolderId(UnifiedNote note) {
  return note.folderId;
}

/// Helper to get note tags - UnifiedNote now only wraps domain entities
List<String> getUnifiedNoteTags(UnifiedNote note) {
  return note.tags;
}

/// Helper to get folder ID - UnifiedFolder now has direct property access
String getUnifiedFolderId(UnifiedFolder folder) {
  return folder.id;
}

/// Helper to get folder name - UnifiedFolder now has direct property access
String getUnifiedFolderName(UnifiedFolder folder) {
  return folder.name;
}

/// Helper to get task ID - UnifiedTask now only wraps domain entities
String getUnifiedTaskId(UnifiedTask task) {
  return task.id;
}

/// Helper to get task title - UnifiedTask now only wraps domain entities
String getUnifiedTaskTitle(UnifiedTask task) {
  return task.content;
}

/// Helper to check if task is completed - UnifiedTask now only wraps domain entities
bool getUnifiedTaskIsCompleted(UnifiedTask task) {
  return task.isCompleted;
}

/// Unified search provider
final unifiedSearchProvider = FutureProvider.autoDispose.family<List<UnifiedNote>, String>((ref, query) async {
  final config = ref.watch(migrationConfigProvider);
  final logger = LoggerFactory.instance;

  try {
    if (config.isFeatureEnabled('notes')) {
      logger.info('[UnifiedSearch] Using domain search service for: $query');

      final trimmedQuery = query.trim();
      final repository = ref.watch(notesCoreRepositoryProvider);

      // Empty query → return recent notes without invoking the search stack
      if (trimmedQuery.isEmpty) {
        final allNotes = await repository.localNotes();
        return allNotes.map((domain.Note n) => UnifiedNote.from(n)).toList();
      }

      final searchService = ref.watch(unifiedSearchServiceProvider);
      final results = await searchService.search(
        trimmedQuery,
        options: const SearchOptions(
          types: [SearchResultType.note],
          limit: 200,
        ),
      );

      final seenIds = <String>{};
      final unifiedNotes = <UnifiedNote>[];

      for (final item in results) {
        if (item.type != SearchResultType.note) continue;

        domain.Note? note;
        final data = item.data;

        if (data is domain.Note) {
          note = data;
        } else if (data is UnifiedNote) {
          if (seenIds.add(data.id)) {
            unifiedNotes.add(UnifiedNote.from(data));
          }
          continue;
        } else if (data is String) {
          note = await repository.getNoteById(data);
        }

        if (note == null) {
          logger.warning(
            '[UnifiedSearch] Skipping unexpected search result data type',
            data: {'runtimeType': data.runtimeType.toString()},
          );
          continue;
        }

        if (seenIds.add(note.id)) {
          unifiedNotes.add(UnifiedNote.from(note));
        }
      }

      if (unifiedNotes.isNotEmpty) {
        return unifiedNotes;
      }

      // Fallback: index may still be warming up – fall back to simple filtering
      logger.info('[UnifiedSearch] FTS returned no results, using fallback filter');
      final allNotes = await repository.localNotes();
      final queryLower = trimmedQuery.toLowerCase();
      final filtered = allNotes.where((n) =>
        n.title.toLowerCase().contains(queryLower) ||
        n.body.toLowerCase().contains(queryLower),
      );
      return filtered.map((domain.Note n) => UnifiedNote.from(n)).toList();
    } else {
      logger.info('[UnifiedSearch] Using legacy search for: $query');

      // Use legacy search
      final db = ref.watch(appDbProvider);
      final results = await db.searchNotes(query);

      return results.map((n) => UnifiedNote.from(n)).toList();
    }
  } catch (e, stack) {
    logger.error('[UnifiedSearch] Search failed for: $query', error: e, stackTrace: stack);
    return [];
  }
});

/// Unified note by ID provider
final unifiedNoteByIdProvider = FutureProvider.autoDispose.family<UnifiedNote?, String>((ref, noteId) async {
  final config = ref.watch(migrationConfigProvider);
  final logger = LoggerFactory.instance;

  try {
    if (config.isFeatureEnabled('notes')) {
      logger.info('[UnifiedProvider] Getting domain note: $noteId');

      // Use domain repository
      final repository = ref.watch(notesCoreRepositoryProvider);
      final note = await repository.getNoteById(noteId);

      return note != null ? UnifiedNote.from(note) : null;
    } else {
      logger.info('[UnifiedProvider] Getting legacy note: $noteId');

      // Use legacy database directly
      final db = ref.watch(appDbProvider);
      final note = await db.getNote(noteId);

      return note != null ? UnifiedNote.from(note) : null;
    }
  } catch (e, stack) {
    logger.error('[UnifiedProvider] Failed to get note: $noteId', error: e, stackTrace: stack);
    return null;
  }
});

/// Provider for creating notes with unified interface
class UnifiedNoteCreator {
  final Ref ref;

  UnifiedNoteCreator(this.ref);

  Future<UnifiedNote?> createNote({
    required String title,
    required String body,
    String? folderId,
    List<String>? tags,
    bool isPinned = false,
  }) async {
    final config = ref.read(migrationConfigProvider);
    final logger = LoggerFactory.instance;

    try {
      if (config.isFeatureEnabled('notes')) {
        logger.info('[UnifiedCreator] Creating domain note');

        // Use domain repository's createOrUpdate method
        final repository = ref.read(notesCoreRepositoryProvider);

        final created = await repository.createOrUpdate(
          title: title,
          body: body,
          folderId: folderId,
          tags: tags ?? [],
          isPinned: isPinned,
        );

        return created != null ? UnifiedNote.from(created) : null;
      } else {
        logger.info('[UnifiedCreator] Creating legacy note');

        // Create legacy note
        final db = ref.read(appDbProvider);
        final noteId = const Uuid().v4();
        final now = DateTime.now();
        await db.into(db.localNotes).insert(
          LocalNotesCompanion(
            id: Value(noteId),
            titleEncrypted: Value(title),  // Legacy path uses plaintext in encrypted field
            bodyEncrypted: Value(body),
            updatedAt: Value(now),
            deleted: const Value(false),
            version: const Value(1),
            userId: const Value(''),
          ),
        );
        final note = await db.getNote(noteId);

        // Add to folder if specified
        if (note != null && folderId != null) {
          // Use folder repository to add note to folder
          final folderRepo = ref.read(folderCoreRepositoryProvider);
          await folderRepo.addNoteToFolder(note.id, folderId);
        }

        // Add tags if specified
        if (note != null && tags != null && tags.isNotEmpty) {
          for (final tag in tags) {
            await db.into(db.noteTags).insert(
              NoteTagsCompanion(
                noteId: Value(note.id),
                tag: Value(tag),
              ),
            );
          }
        }

        return note != null ? UnifiedNote.from(note) : null;
      }
    } catch (e, stack) {
      logger.error('[UnifiedCreator] Failed to create note', error: e, stackTrace: stack);
      return null;
    }
  }
}

/// Provider for the unified note creator
final unifiedNoteCreatorProvider = Provider<UnifiedNoteCreator>((ref) {
  return UnifiedNoteCreator(ref);
});

/// Helper to get template ID regardless of type
String getUnifiedTemplateId(UnifiedTemplate template) {
  if (template is domain.Template) {
    return template.id;
  } else if ((template as dynamic).id != null) {
    return (template as dynamic).id as String; // LocalTemplate from database
  }
  throw ArgumentError('Unknown template type: ${template.runtimeType}');
}

/// Helper to get template title/name regardless of type
String getUnifiedTemplateTitle(UnifiedTemplate template) {
  if (template is domain.Template) {
    return template.name;
  } else if ((template as dynamic).title != null) {
    return (template as dynamic).title as String; // LocalTemplate from database
  }
  throw ArgumentError('Unknown template type: ${template.runtimeType}');
}

/// Helper to get template content/body regardless of type
String getUnifiedTemplateContent(UnifiedTemplate template) {
  if (template is domain.Template) {
    return template.content;
  } else if ((template as dynamic).body != null) {
    return (template as dynamic).body as String; // LocalTemplate from database
  }
  throw ArgumentError('Unknown template type: ${template.runtimeType}');
}

/// Helper to get template description regardless of type
String getUnifiedTemplateDescription(UnifiedTemplate template) {
  if (template is domain.Template) {
    // domain.Template doesn't have description field
    return 'Template ${template.name}';
  } else if ((template as dynamic).description != null) {
    return (template as dynamic).description as String; // LocalTemplate from database
  }
  return '';
}

/// Helper to get template category regardless of type
String getUnifiedTemplateCategory(UnifiedTemplate template) {
  if (template is domain.Template) {
    // domain.Template doesn't have category field - could derive from variables
    return 'other';
  } else if ((template as dynamic).category != null) {
    return (template as dynamic).category as String; // LocalTemplate from database
  }
  return 'other';
}

/// Helper to check if template is system regardless of type
bool getUnifiedTemplateIsSystem(UnifiedTemplate template) {
  if (template is domain.Template) {
    return template.isSystem;
  } else if ((template as dynamic).isSystem != null) {
    return (template as dynamic).isSystem as bool; // LocalTemplate from database
  }
  return false;
}

/// Helper to get template variables regardless of type
Map<String, dynamic> getUnifiedTemplateVariables(UnifiedTemplate template) {
  if (template is domain.Template) {
    return template.variables;
  } else {
    // LocalTemplate stores tags as JSON array, not variables
    try {
      if ((template as dynamic).tags != null) {
        final tags = json.decode((template as dynamic).tags as String) as List<dynamic>;
        return {'tags': tags};
      }
    } catch (e) {
      // If parsing fails, return empty map
    }
    return {};
  }
}

/// Helper to get template created date regardless of type
DateTime getUnifiedTemplateCreatedAt(UnifiedTemplate template) {
  if (template is domain.Template) {
    return template.createdAt;
  } else if ((template as dynamic).createdAt != null) {
    return (template as dynamic).createdAt as DateTime; // LocalTemplate from database
  }
  return DateTime.now();
}

/// Helper to get template updated date regardless of type
DateTime getUnifiedTemplateUpdatedAt(UnifiedTemplate template) {
  if (template is domain.Template) {
    return template.updatedAt;
  } else if ((template as dynamic).updatedAt != null) {
    return (template as dynamic).updatedAt as DateTime; // LocalTemplate from database
  }
  return DateTime.now();
}
