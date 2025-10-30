import 'dart:async';
import 'dart:convert';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/domain/entities/template.dart';
import 'package:duru_notes/infrastructure/mappers/template_mapper.dart';
import 'package:duru_notes/services/security/security_audit_trail.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Core template repository implementation
class TemplateCoreRepository implements ITemplateRepository {
  TemplateCoreRepository({
    required this.db,
    required this.client,
    required INotesRepository notesRepository,
    String? Function()? userIdResolver,
  }) : _logger = LoggerFactory.instance,
       _notesRepository = notesRepository,
       _userIdResolver = userIdResolver;

  final AppDb db;
  final SupabaseClient client;
  final AppLogger _logger;
  final _uuid = const Uuid();
  final INotesRepository _notesRepository;
  final String? Function()? _userIdResolver;
  final SecurityAuditTrail _securityAuditTrail = SecurityAuditTrail();

  String? _currentUserId() =>
      _userIdResolver?.call() ?? client.auth.currentUser?.id;

  Future<void> _enqueuePendingOp({
    required String entityId,
    required String kind,
    String? payload,
  }) async {
    final userId = _currentUserId();
    if (userId == null) {
      _logger.warning(
        'Skipping template enqueue - no authenticated user',
        data: {'entityId': entityId, 'kind': kind},
      );
      return;
    }

    await db.enqueue(
      userId: userId,
      entityId: entityId,
      kind: kind,
      payload: payload,
    );
  }

  void _captureRepositoryException({
    required String method,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.error,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = level;
          scope.setTag('layer', 'repository');
          scope.setTag('repository', 'TemplateCoreRepository');
          scope.setTag('method', method);
          if (data != null && data.isNotEmpty) {
            scope.setContexts('payload', data);
          }
        },
      ),
    );
  }

  void _auditAccess(String resource, {required bool granted, String? reason}) {
    unawaited(
      _securityAuditTrail.logAccess(
        resource: resource,
        granted: granted,
        reason: reason,
      ),
    );
  }

  String? _requireUserId({required String method, Map<String, dynamic>? data}) {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      _logger.warning('$method denied - unauthenticated user', data: data);
      _captureRepositoryException(
        method: method,
        error: StateError('Unauthenticated access'),
        stackTrace: StackTrace.current,
        data: data,
        level: SentryLevel.warning,
      );
      _auditAccess('templates.$method', granted: false, reason: 'missing_user');
      return null;
    }
    return userId;
  }

  @override
  Future<List<Template>> getAllTemplates() async {
    try {
      // Security: Return system templates + user's own templates only
      final userId = _currentUserId();
      if (userId == null || userId.isEmpty) {
        _logger.warning(
          'Cannot get templates without authenticated user, returning system templates only',
        );
        final systemTemplates = await db.getSystemTemplates();
        final templates = TemplateMapper.toDomainList(systemTemplates);
        _auditAccess(
          'templates.getAllTemplates',
          granted: true,
          reason: 'system_only count=${templates.length}',
        );
        return templates;
      }

      final allTemplates =
          await (db.select(db.localTemplates)
                ..where(
                  (t) =>
                      (t.isSystem.equals(
                        true,
                      )) | // System templates available to all
                      (t.userId.equals(userId)),
                ) // User's own templates
                ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
              .get();

      final templates = TemplateMapper.toDomainList(allTemplates);
      _auditAccess(
        'templates.getAllTemplates',
        granted: true,
        reason: 'count=${templates.length}',
      );
      return templates;
    } catch (e, stack) {
      _logger.error('Failed to get all templates', error: e, stackTrace: stack);
      _captureRepositoryException(
        method: 'getAllTemplates',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'templates.getAllTemplates',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <Template>[];
    }
  }

  @override
  Future<List<Template>> getSystemTemplates() async {
    try {
      // System templates are available to all users
      final localTemplates = await db.getSystemTemplates();
      final templates = TemplateMapper.toDomainList(localTemplates);
      _auditAccess(
        'templates.getSystemTemplates',
        granted: true,
        reason: 'count=${templates.length}',
      );
      return templates;
    } catch (e, stack) {
      _logger.error(
        'Failed to get system templates',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getSystemTemplates',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'templates.getSystemTemplates',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <Template>[];
    }
  }

  @override
  Future<List<Template>> getUserTemplates() async {
    try {
      // Security: Only return templates belonging to current user
      final userId = _requireUserId(method: 'getUserTemplates');
      if (userId == null) {
        return const <Template>[];
      }

      final localTemplates =
          await (db.select(db.localTemplates)
                ..where((t) => t.userId.equals(userId))
                ..where((t) => t.isSystem.equals(false))
                ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
              .get();

      final templates = TemplateMapper.toDomainList(localTemplates);
      _auditAccess(
        'templates.getUserTemplates',
        granted: true,
        reason: 'count=${templates.length}',
      );
      return templates;
    } catch (e, stack) {
      _logger.error(
        'Failed to get user templates',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getUserTemplates',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'templates.getUserTemplates',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <Template>[];
    }
  }

  @override
  Future<Template?> getTemplateById(String id) async {
    try {
      // Security: Verify template is system template OR belongs to current user
      final userId = _currentUserId();
      if (userId == null || userId.isEmpty) {
        _logger.warning(
          'Cannot get template without authenticated user, checking system templates only',
        );
        final systemTemplate =
            await (db.select(db.localTemplates)
                  ..where((t) => t.id.equals(id))
                  ..where((t) => t.isSystem.equals(true)))
                .getSingleOrNull();
        if (systemTemplate == null) {
          _auditAccess(
            'templates.getTemplateById',
            granted: false,
            reason: 'unauthenticated_not_found',
          );
          return null;
        }
        _auditAccess(
          'templates.getTemplateById',
          granted: true,
          reason: 'system_template',
        );
        return TemplateMapper.toDomain(systemTemplate);
      }

      final localTemplate =
          await (db.select(db.localTemplates)
                ..where((t) => t.id.equals(id))
                ..where(
                  (t) =>
                      (t.isSystem.equals(
                        true,
                      )) | // System templates available to all
                      (t.userId.equals(userId)),
                )) // User's own templates
              .getSingleOrNull();

      if (localTemplate == null) {
        _auditAccess(
          'templates.getTemplateById',
          granted: false,
          reason: 'not_found',
        );
        return null;
      }

      final template = TemplateMapper.toDomain(localTemplate);
      _auditAccess(
        'templates.getTemplateById',
        granted: true,
        reason: 'templateId=$id',
      );

      return template;
    } catch (e, stack) {
      _logger.error(
        'Failed to get template by id: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getTemplateById',
        error: e,
        stackTrace: stack,
        data: {'templateId': id},
      );
      _auditAccess(
        'templates.getTemplateById',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return null;
    }
  }

  @override
  Future<Template> createTemplate(Template template) async {
    try {
      final userId = _requireUserId(
        method: 'createTemplate',
        data: {'templateName': template.name},
      );
      if (userId == null) {
        throw StateError('Cannot create template without authenticated user');
      }

      // Create template with new ID if not provided
      final templateToCreate = template.id.isEmpty
          ? template.copyWith(id: _uuid.v4())
          : template;

      // Map to infrastructure model
      final localTemplate = TemplateMapper.toInfrastructure(
        templateToCreate,
      ).copyWith(userId: Value(userId));

      // Insert into database
      await db.upsertTemplate(localTemplate);

      // Enqueue for sync if it's a user template
      if (!templateToCreate.isSystem) {
        await _enqueuePendingOp(
          entityId: templateToCreate.id,
          kind: 'upsert_template',
          payload: jsonEncode({'userId': userId, 'isSystem': false}),
        );
      }

      _auditAccess(
        'templates.createTemplate',
        granted: true,
        reason: 'templateId=${templateToCreate.id}',
      );
      return templateToCreate;
    } catch (e, stack) {
      _logger.error(
        'Failed to create template: ${template.name}',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'createTemplate',
        error: e,
        stackTrace: stack,
        data: {'templateId': template.id, 'templateName': template.name},
      );
      _auditAccess(
        'templates.createTemplate',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<Template> updateTemplate(Template template) async {
    try {
      // Security: Verify user is authenticated
      final userId = _requireUserId(
        method: 'updateTemplate',
        data: {'templateId': template.id},
      );
      if (userId == null) {
        throw StateError('Cannot update template without authenticated user');
      }

      // Security: Verify template exists and belongs to user (or is system template)
      final existing =
          await (db.select(db.localTemplates)
                ..where((t) => t.id.equals(template.id))
                ..where(
                  (t) =>
                      (t.isSystem.equals(
                        true,
                      )) | // Can't update system templates anyway
                      (t.userId.equals(userId)),
                )) // Must own the template
              .getSingleOrNull();

      if (existing == null) {
        final missingError = StateError(
          'Template not found or does not belong to user',
        );
        _logger.warning(
          'Template update attempted on non-existent template',
          data: {'templateId': template.id, 'userId': userId},
        );
        _captureRepositoryException(
          method: 'updateTemplate',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'templateId': template.id, 'userId': userId},
          level: SentryLevel.warning,
        );
        _auditAccess(
          'templates.updateTemplate',
          granted: false,
          reason: 'not_found',
        );
        throw missingError;
      }

      // Don't allow updating system templates
      if (existing.isSystem) {
        final systemTemplateError = StateError('Cannot modify system template');
        _logger.warning(
          'Attempted to modify system template',
          data: {'templateId': template.id},
        );
        _captureRepositoryException(
          method: 'updateTemplate',
          error: systemTemplateError,
          stackTrace: StackTrace.current,
          data: {'templateId': template.id},
          level: SentryLevel.warning,
        );
        _auditAccess(
          'templates.updateTemplate',
          granted: false,
          reason: 'system_template',
        );
        throw systemTemplateError;
      }

      // Create updated template with new timestamp
      final updatedTemplate = template.copyWith(
        updatedAt: DateTime.now().toUtc(),
      );

      // Map to infrastructure model
      final localTemplate = TemplateMapper.toInfrastructure(
        updatedTemplate,
      ).copyWith(userId: Value(userId));

      // Update in database
      await db.upsertTemplate(localTemplate);

      // Enqueue for sync
      await _enqueuePendingOp(
        entityId: updatedTemplate.id,
        kind: 'upsert_template',
        payload: jsonEncode({
          'userId': userId,
          'isSystem': updatedTemplate.isSystem,
        }),
      );

      _auditAccess(
        'templates.updateTemplate',
        granted: true,
        reason: 'templateId=${updatedTemplate.id}',
      );
      return updatedTemplate;
    } catch (e, stack) {
      _logger.error(
        'Failed to update template: ${template.id}',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'updateTemplate',
        error: e,
        stackTrace: stack,
        data: {'templateId': template.id},
      );
      _auditAccess(
        'templates.updateTemplate',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteTemplate(String id) async {
    try {
      // Security: Verify user is authenticated
      final userId = _requireUserId(
        method: 'deleteTemplate',
        data: {'templateId': id},
      );
      if (userId == null) {
        throw StateError('Cannot delete template without authenticated user');
      }

      // Security: Verify template exists and belongs to user
      final existing =
          await (db.select(db.localTemplates)
                ..where((t) => t.id.equals(id))
                ..where((t) => t.userId.equals(userId)))
              .getSingleOrNull();

      if (existing == null) {
        _logger.warning(
          'Template $id not found or does not belong to user $userId',
        );
        _auditAccess(
          'templates.deleteTemplate',
          granted: false,
          reason: 'not_found',
        );
        return;
      }

      // Don't allow deleting system templates
      if (existing.isSystem) {
        final systemTemplateError = StateError('Cannot delete system template');
        _logger.warning(
          'Attempted to delete system template',
          data: {'templateId': id},
        );
        _captureRepositoryException(
          method: 'deleteTemplate',
          error: systemTemplateError,
          stackTrace: StackTrace.current,
          data: {'templateId': id},
          level: SentryLevel.warning,
        );
        _auditAccess(
          'templates.deleteTemplate',
          granted: false,
          reason: 'system_template',
        );
        throw systemTemplateError;
      }

      // Delete from database
      final deleted = await db.deleteTemplate(id);
      if (!deleted) {
        throw Exception('Failed to delete template from database');
      }

      // Enqueue for sync deletion
      await _enqueuePendingOp(
        entityId: id,
        kind: 'delete_template',
        payload: jsonEncode({
          'userId': existing.userId,
          'isSystem': existing.isSystem,
        }),
      );

      _logger.info('Deleted template: $id');
      _auditAccess(
        'templates.deleteTemplate',
        granted: true,
        reason: 'templateId=$id',
      );
    } catch (e, stack) {
      _logger.error(
        'Failed to delete template: $id',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'deleteTemplate',
        error: e,
        stackTrace: stack,
        data: {'templateId': id},
      );
      _auditAccess(
        'templates.deleteTemplate',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  @override
  Stream<List<Template>> watchTemplates() {
    try {
      // Create a StreamController to emit template changes
      late StreamController<List<Template>> controller;
      Timer? timer;

      void emitTemplates() async {
        try {
          final templates = await getAllTemplates();
          if (!controller.isClosed) {
            controller.add(templates);
          }
        } catch (e, stack) {
          _logger.error(
            'Failed to emit templates for watch stream',
            error: e,
            stackTrace: stack,
          );
          _captureRepositoryException(
            method: 'watchTemplates.emit',
            error: e,
            stackTrace: stack,
          );
          if (!controller.isClosed) {
            controller.addError(e, stack);
          }
        }
      }

      controller = StreamController<List<Template>>(
        onListen: () {
          // Emit initial data
          emitTemplates();

          // Set up periodic refresh (since Drift doesn't provide stream for custom queries)
          timer = Timer.periodic(
            const Duration(seconds: 5),
            (_) => emitTemplates(),
          );
        },
        onCancel: () {
          timer?.cancel();
        },
      );

      return controller.stream;
    } catch (e, stack) {
      _logger.error(
        'Failed to create template watch stream',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'watchTemplates',
        error: e,
        stackTrace: stack,
      );
      return Stream.error(e, stack);
    }
  }

  /// Create a template from a note
  Future<Template> createTemplateFromNote({
    required String noteTitle,
    required String noteContent,
    required String templateName,
    String? templateDescription,
    Map<String, dynamic> variables = const {},
  }) async {
    try {
      final userId = _requireUserId(
        method: 'createTemplateFromNote',
        data: {'templateName': templateName, 'noteTitle': noteTitle},
      );
      if (userId == null) {
        throw StateError('Cannot create template without authenticated user');
      }

      // Extract variables from note content (simple implementation)
      final extractedVariables = _extractVariablesFromContent(noteContent);
      final mergedVariables = {...extractedVariables, ...variables};

      final template = Template(
        id: _uuid.v4(),
        name: templateName,
        content: noteContent,
        variables: mergedVariables,
        isSystem: false,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      return await createTemplate(template);
    } catch (e, stack) {
      _logger.error(
        'Failed to create template from note',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'createTemplateFromNote',
        error: e,
        stackTrace: stack,
        data: {'templateName': templateName},
      );
      _auditAccess(
        'templates.createTemplateFromNote',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  /// Apply template to create a note
  /// Returns the created note ID
  @override
  Future<String> applyTemplate({
    required String templateId,
    required Map<String, dynamic> variableValues,
  }) async {
    try {
      final template = await getTemplateById(templateId);
      if (template == null) {
        final missingError = StateError('Template not found');
        _logger.warning(
          'Template apply attempted on non-existent template',
          data: {'templateId': templateId},
        );
        _captureRepositoryException(
          method: 'applyTemplate',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'templateId': templateId},
          level: SentryLevel.warning,
        );
        _auditAccess(
          'templates.applyTemplate',
          granted: false,
          reason: 'not_found',
        );
        throw missingError;
      }

      String processedContent = template.content;

      Map<String, dynamic> normalizeMap(Map<String, dynamic> map) {
        return map.map((key, value) => MapEntry(key.toString(), value));
      }

      final normalizedVariables = normalizeMap(template.variables);
      final resolvedVariables = normalizeMap(variableValues);

      for (final entry in resolvedVariables.entries) {
        final placeholder = '{{${entry.key}}}';
        processedContent = processedContent.replaceAll(
          placeholder,
          entry.value?.toString() ?? '',
        );
      }

      for (final entry in normalizedVariables.entries) {
        final placeholder = '{{${entry.key}}}';
        if (processedContent.contains(placeholder)) {
          processedContent = processedContent.replaceAll(
            placeholder,
            entry.value?.toString() ?? '',
          );
        }
      }

      final userId = _requireUserId(
        method: 'applyTemplate',
        data: {'templateId': templateId},
      );
      if (userId == null) {
        throw StateError(
          'User must be authenticated to create note from template',
        );
      }

      String? resolveStringValue(Map<String, dynamic> source, String key) {
        if (source.containsKey(key)) {
          final value = source[key];
          if (value == null) return null;
          if (value is String) return value;
          return value.toString();
        }
        return null;
      }

      List<String> resolveStringList(dynamic value) {
        if (value == null) return const [];
        if (value is List) {
          return value
              .map((e) => e?.toString() ?? '')
              .where((element) => element.trim().isNotEmpty)
              .toList();
        }
        if (value is String) {
          return value
              .split(',')
              .map((e) => e.trim())
              .where((element) => element.isNotEmpty)
              .toList();
        }
        return const [];
      }

      List<Map<String, String?>> resolveLinks(dynamic value) {
        if (value == null) return const [];
        if (value is List) {
          return value.map<Map<String, String?>>((entry) {
            if (entry is Map) {
              return {
                'title':
                    entry['title']?.toString() ??
                    entry['text']?.toString() ??
                    entry['target']?.toString(),
                'targetId':
                    entry['id']?.toString() ?? entry['targetId']?.toString(),
              };
            }
            final text = entry.toString();
            return {'title': text, 'targetId': null};
          }).toList();
        }
        if (value is String && value.trim().isNotEmpty) {
          return [
            {'title': value.trim(), 'targetId': null},
          ];
        }
        return const [];
      }

      Map<String, dynamic>? resolveMetadata(dynamic value) {
        if (value == null) return null;
        if (value is Map<String, dynamic>) {
          return value;
        }
        if (value is Map) {
          return value.map<String, dynamic>(
            (key, dynamic val) => MapEntry(key.toString(), val),
          );
        }
        if (value is String && value.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(value);
            if (decoded is Map<String, dynamic>) {
              return decoded;
            }
          } catch (_) {
            return {'value': value};
          }
        }
        return null;
      }

      String resolveTitle() {
        final variableTitle =
            resolveStringValue(resolvedVariables, 'title') ??
            resolveStringValue(resolvedVariables, 'noteTitle') ??
            resolveStringValue(normalizedVariables, 'title') ??
            resolveStringValue(normalizedVariables, 'noteTitle');
        if (variableTitle != null && variableTitle.trim().isNotEmpty) {
          return variableTitle.trim();
        }
        final firstLine = processedContent.trim().split('\n').first;
        if (firstLine.startsWith('#')) {
          return firstLine.replaceFirst(RegExp(r'^#+\s*'), '').trim();
        }
        return template.name.isNotEmpty ? template.name : 'New Note';
      }

      List<String> resolveTags() {
        final fromValues = resolveStringList(resolvedVariables['tags']);
        if (fromValues.isNotEmpty) return fromValues;
        return resolveStringList(normalizedVariables['tags']);
      }

      List<Map<String, String?>> resolveLinkList() {
        final fromValues = resolveLinks(resolvedVariables['links']);
        if (fromValues.isNotEmpty) return fromValues;
        return resolveLinks(normalizedVariables['links']);
      }

      final noteTitle = resolveTitle();
      final tags = resolveTags();
      final links = resolveLinkList();
      final folderId =
          resolveStringValue(resolvedVariables, 'folderId') ??
          resolveStringValue(normalizedVariables, 'folderId');
      final metadata =
          resolveMetadata(resolvedVariables['metadata']) ??
          resolveMetadata(normalizedVariables['metadata']);
      final attachmentMeta =
          resolveMetadata(resolvedVariables['attachmentMeta']) ??
          resolveMetadata(normalizedVariables['attachmentMeta']);
      final isPinned =
          (resolveStringValue(resolvedVariables, 'isPinned') ??
                  resolveStringValue(normalizedVariables, 'isPinned'))
              ?.toLowerCase() ==
          'true';

      final createdNote = await _notesRepository.createOrUpdate(
        title: noteTitle,
        body: processedContent.trim(),
        folderId: folderId,
        tags: tags,
        links: links,
        metadataJson: metadata,
        attachmentMeta: attachmentMeta,
        isPinned: isPinned,
      );

      if (createdNote == null) {
        final creationError = StateError('Failed to create note from template');
        _captureRepositoryException(
          method: 'applyTemplate',
          error: creationError,
          stackTrace: StackTrace.current,
          data: {'templateId': templateId},
        );
        throw creationError;
      }

      _logger.info(
        'Template applied successfully',
        data: {
          'templateId': templateId,
          'noteId': createdNote.id,
          'tags': tags.length,
          'links': links.length,
        },
      );
      _auditAccess(
        'templates.applyTemplate',
        granted: true,
        reason: 'templateId=$templateId noteId=${createdNote.id}',
      );

      return createdNote.id;
    } catch (e, stack) {
      _logger.error(
        'Failed to apply template: $templateId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'applyTemplate',
        error: e,
        stackTrace: stack,
        data: {'templateId': templateId},
      );
      _auditAccess(
        'templates.applyTemplate',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  /// Get template usage statistics
  Future<Map<String, int>> getTemplateUsageStats() async {
    try {
      final templates = await getAllTemplates();
      final stats = <String, int>{};

      // This is a simplified implementation
      // In a real system, you'd track usage in a separate table
      for (final template in templates) {
        stats[template.id] = 0; // Placeholder for actual usage count
      }

      _auditAccess(
        'templates.getTemplateUsageStats',
        granted: true,
        reason: 'count=${stats.length}',
      );
      return stats;
    } catch (e, stack) {
      _logger.error(
        'Failed to get template usage stats',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'getTemplateUsageStats',
        error: e,
        stackTrace: stack,
      );
      _auditAccess(
        'templates.getTemplateUsageStats',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <String, int>{};
    }
  }

  /// Search templates by name or content
  Future<List<Template>> searchTemplates(String query) async {
    try {
      if (query.isEmpty) {
        final templates = await getAllTemplates();
        _auditAccess(
          'templates.searchTemplates',
          granted: true,
          reason: 'empty_query count=${templates.length}',
        );
        return templates;
      }

      final allTemplates = await getAllTemplates();
      final normalizedQuery = query.toLowerCase();

      final results = allTemplates.where((template) {
        final matchesName = template.name.toLowerCase().contains(
          normalizedQuery,
        );
        final matchesContent = template.content.toLowerCase().contains(
          normalizedQuery,
        );
        return matchesName || matchesContent;
      }).toList();

      _auditAccess(
        'templates.searchTemplates',
        granted: true,
        reason: 'queryLength=${query.length} count=${results.length}',
      );
      return results;
    } catch (e, stack) {
      _logger.error(
        'Failed to search templates with query: $query',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'searchTemplates',
        error: e,
        stackTrace: stack,
        data: {'queryLength': query.length},
      );
      _auditAccess(
        'templates.searchTemplates',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      return const <Template>[];
    }
  }

  /// Duplicate an existing template
  @override
  Future<Template> duplicateTemplate({
    required String templateId,
    String? newName,
  }) async {
    try {
      final original = await getTemplateById(templateId);
      if (original == null) {
        final missingError = StateError('Template not found');
        _logger.warning(
          'Attempted to duplicate non-existent template',
          data: {'templateId': templateId},
        );
        _captureRepositoryException(
          method: 'duplicateTemplate',
          error: missingError,
          stackTrace: StackTrace.current,
          data: {'templateId': templateId},
          level: SentryLevel.warning,
        );
        throw missingError;
      }

      final duplicatedTemplate = Template(
        id: _uuid.v4(),
        name: newName ?? '${original.name} (Copy)',
        content: original.content,
        variables: Map<String, dynamic>.from(original.variables),
        isSystem: false, // Duplicates are always user templates
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final created = await createTemplate(duplicatedTemplate);
      _auditAccess(
        'templates.duplicateTemplate',
        granted: true,
        reason: 'source=$templateId duplicate=${created.id}',
      );
      return created;
    } catch (e, stack) {
      _logger.error(
        'Failed to duplicate template: $templateId',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'duplicateTemplate',
        error: e,
        stackTrace: stack,
        data: {'templateId': templateId},
      );
      _auditAccess(
        'templates.duplicateTemplate',
        granted: false,
        reason: 'error=${e.runtimeType}',
      );
      rethrow;
    }
  }

  /// Validate template content for variables
  bool validateTemplate(Template template) {
    try {
      final content = template.content;
      final variables = template.variables;

      // Find all variable placeholders in content
      final placeholderRegex = RegExp(r'\{\{([^}]+)\}\}');
      final matches = placeholderRegex.allMatches(content);

      // Check if all placeholders have corresponding variables
      for (final match in matches) {
        final variableName = match.group(1)?.trim();
        if (variableName != null && !variables.containsKey(variableName)) {
          _logger.warning(
            'Template ${template.id} has undefined variable: $variableName',
          );
          return false;
        }
      }

      // Check if all variables are used in content
      for (final variableName in variables.keys) {
        final placeholder = '{{$variableName}}';
        if (!content.contains(placeholder)) {
          _logger.warning(
            'Template ${template.id} has unused variable: $variableName',
          );
          // This is just a warning, not an error
        }
      }

      return true;
    } catch (e, stack) {
      _logger.error(
        'Failed to validate template: ${template.id}',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'validateTemplate',
        error: e,
        stackTrace: stack,
        data: {'templateId': template.id},
      );
      return false;
    }
  }

  // Private helper methods

  /// Extract variables from content (simple implementation)
  Map<String, dynamic> _extractVariablesFromContent(String content) {
    final variables = <String, dynamic>{};
    final placeholderRegex = RegExp(r'\{\{([^}]+)\}\}');
    final matches = placeholderRegex.allMatches(content);

    for (final match in matches) {
      final variableName = match.group(1)?.trim();
      if (variableName != null) {
        // Set default value as empty string
        variables[variableName] = '';
      }
    }

    return variables;
  }

  /// Initialize system templates if they don't exist
  Future<void> ensureSystemTemplatesExist() async {
    try {
      final existingSystemTemplates = await getSystemTemplates();

      if (existingSystemTemplates.isEmpty) {
        await _createDefaultSystemTemplates();
      }
    } catch (e, stack) {
      _logger.error(
        'Failed to ensure system templates exist',
        error: e,
        stackTrace: stack,
      );
      _captureRepositoryException(
        method: 'ensureSystemTemplatesExist',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Create default system templates
  Future<void> _createDefaultSystemTemplates() async {
    final systemTemplates = [
      Template(
        id: 'sys_meeting_notes',
        name: 'Meeting Notes',
        content: '''# Meeting Notes - {{meeting_title}}

**Date:** {{date}}
**Attendees:** {{attendees}}
**Duration:** {{duration}}

## Agenda
{{agenda}}

## Discussion Points
{{discussion}}

## Action Items
{{action_items}}

## Next Steps
{{next_steps}}''',
        variables: {
          'meeting_title': 'Weekly Team Meeting',
          'date': DateTime.now().toString().split(' ')[0],
          'attendees': 'Team members',
          'duration': '1 hour',
          'agenda': '- Topic 1\n- Topic 2',
          'discussion': 'Key discussion points',
          'action_items': '- [ ] Action 1\n- [ ] Action 2',
          'next_steps': 'Schedule follow-up meeting',
        },
        isSystem: true,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
      Template(
        id: 'sys_project_plan',
        name: 'Project Plan',
        content: '''# {{project_name}} - Project Plan

**Project Manager:** {{project_manager}}
**Start Date:** {{start_date}}
**End Date:** {{end_date}}
**Status:** {{status}}

## Project Overview
{{overview}}

## Objectives
{{objectives}}

## Deliverables
{{deliverables}}

## Timeline
{{timeline}}

## Resources
{{resources}}

## Risk Assessment
{{risks}}''',
        variables: {
          'project_name': 'New Project',
          'project_manager': 'Project Manager Name',
          'start_date': DateTime.now().toString().split(' ')[0],
          'end_date': 'TBD',
          'status': 'Planning',
          'overview': 'Project description and goals',
          'objectives': '- Objective 1\n- Objective 2',
          'deliverables': '- Deliverable 1\n- Deliverable 2',
          'timeline': 'Phase 1: Weeks 1-4\nPhase 2: Weeks 5-8',
          'resources': 'Team members, budget, tools',
          'risks': 'Potential risks and mitigation strategies',
        },
        isSystem: true,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
      Template(
        id: 'sys_daily_journal',
        name: 'Daily Journal',
        content: '''# Daily Journal - {{date}}

## Mood: {{mood}}

## Today's Goals
{{goals}}

## Accomplishments
{{accomplishments}}

## Challenges
{{challenges}}

## Grateful For
{{gratitude}}

## Tomorrow's Priority
{{tomorrow_priority}}

## Notes
{{notes}}''',
        variables: {
          'date': DateTime.now().toString().split(' ')[0],
          'mood': '😊',
          'goals': '- Goal 1\n- Goal 2',
          'accomplishments': 'What went well today',
          'challenges': 'Obstacles faced',
          'gratitude': 'Three things I\'m grateful for',
          'tomorrow_priority': 'Most important task for tomorrow',
          'notes': 'Additional thoughts and reflections',
        },
        isSystem: true,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ),
    ];

    for (final template in systemTemplates) {
      try {
        final localTemplate = TemplateMapper.toInfrastructure(template);
        await db.upsertTemplate(localTemplate);
      } catch (e) {
        _logger.error(
          'Failed to create system template: ${template.name}',
          error: e,
        );
      }
    }

    _logger.info('Created ${systemTemplates.length} system templates');
  }
}
