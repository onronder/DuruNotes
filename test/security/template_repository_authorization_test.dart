import 'dart:convert';

import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/template.dart';
import 'package:duru_notes/infrastructure/repositories/template_core_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../helpers/security_test_setup.dart';
import '../services/quick_capture_service_test.mocks.dart';

class _TemplateRepositoryHarness {
  _TemplateRepositoryHarness() {
    db = AppDb.forTesting(NativeDatabase.memory());
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    userA = MockUser();
    userB = MockUser();
    notesRepository = MockINotesRepository();

    when(mockSupabase.auth).thenReturn(mockAuth);
    when(userA.id).thenReturn('user-a');
    when(userB.id).thenReturn('user-b');

    when(mockAuth.currentUser).thenAnswer((_) => _resolveUser(activeUserId));

    repository = TemplateCoreRepository(
      db: db,
      client: mockSupabase,
      notesRepository: notesRepository,
      userIdResolver: () => activeUserId,
    );

    when(
      notesRepository.createOrUpdate(
        title: anyNamed('title'),
        body: anyNamed('body'),
        id: anyNamed('id'),
        folderId: anyNamed('folderId'),
        tags: anyNamed('tags'),
        links: anyNamed('links'),
        metadataJson: anyNamed('metadataJson'),
        attachmentMeta: anyNamed('attachmentMeta'),
        isPinned: anyNamed('isPinned'),
        createdAt: anyNamed('createdAt'),
        updatedAt: anyNamed('updatedAt'),
      ),
    ).thenAnswer((invocation) async {
      final title = invocation.namedArguments[#title] as String;
      final body = invocation.namedArguments[#body] as String;
      final folderId = invocation.namedArguments[#folderId] as String?;
      final tags =
          (invocation.namedArguments[#tags] as List<String>?) ?? const [];
      final metadata =
          invocation.namedArguments[#metadataJson] as Map<String, dynamic>?;
      final attachmentMeta =
          invocation.namedArguments[#attachmentMeta] as Map<String, dynamic>?;
      final isPinned = invocation.namedArguments[#isPinned] as bool? ?? false;

      final note = domain.Note(
        id: 'note-${createdNotes.length}',
        title: title,
        body: body,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        deleted: false,
        isPinned: isPinned,
        noteType: NoteKind.note,
        folderId: folderId,
        version: 1,
        userId: activeUserId ?? '',
        tags: tags,
        metadata: metadata != null ? jsonEncode(metadata) : null,
        attachmentMeta: attachmentMeta != null
            ? jsonEncode(attachmentMeta)
            : null,
        encryptedMetadata: null,
        links: const [],
      );
      createdNotes.add({
        'note': note,
        'tags': tags,
        'metadata': metadata,
        'attachmentMeta': attachmentMeta,
      });
      return note;
    });
  }

  late AppDb db;
  late TemplateCoreRepository repository;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser userA;
  late MockUser userB;
  late MockINotesRepository notesRepository;
  final List<Map<String, dynamic>> createdNotes = [];
  String? activeUserId = 'user-a';

  MockUser? _resolveUser(String? id) {
    if (id == 'user-a') return userA;
    if (id == 'user-b') return userB;
    return null;
  }

  void useUserA() => setActiveUser('user-a');
  void useUserB() => setActiveUser('user-b');
  void clearUser() => setActiveUser(null);

  void setActiveUser(String? userId) {
    activeUserId = userId;
  }

  Future<void> insertTemplate({
    required String id,
    required DateTime timestamp,
    String? ownerId,
    bool isSystem = false,
    String name = 'Template',
    String content = 'Template Content',
    Map<String, dynamic> variables = const {},
    int sortOrder = 0,
  }) async {
    await db
        .into(db.localTemplates)
        .insert(
          LocalTemplatesCompanion.insert(
            id: id,
            userId: ownerId == null
                ? const drift.Value.absent()
                : drift.Value(ownerId),
            title: name,
            body: content,
            tags: const drift.Value('[]'),
            isSystem: drift.Value(isSystem),
            category: 'general',
            description: 'template description',
            icon: 'description',
            sortOrder: drift.Value(sortOrder),
            metadata: drift.Value(jsonEncode({'variables': variables})),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  Future<void> dispose() async {
    await db.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TemplateCoreRepository authorization', () {
    late _TemplateRepositoryHarness harness;

    setUp(() async {
      await SecurityTestSetup.setupMockEncryption();
      harness = _TemplateRepositoryHarness();
    });

    tearDown(() async {
      await harness.dispose();
      SecurityTestSetup.teardownEncryption();
    });

    Template buildTemplate({
      required String name,
      String id = '',
      bool isSystem = false,
      Map<String, dynamic> variables = const {},
      String content = 'Template body',
    }) {
      final now = DateTime.utc(2025, 10, 29);
      return Template(
        id: id,
        name: name,
        content: content,
        variables: variables,
        isSystem: isSystem,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('getAllTemplates returns system + user templates only', () async {
      final now = DateTime.utc(2025, 10, 29);
      await harness.insertTemplate(
        id: 'system-template',
        timestamp: now,
        isSystem: true,
        content: '# System Template',
        name: 'System',
      );
      await harness.insertTemplate(
        id: 'user-a-template',
        timestamp: now,
        ownerId: 'user-a',
        content: '# A Template',
        name: 'User A Template',
      );
      await harness.insertTemplate(
        id: 'user-b-template',
        timestamp: now,
        ownerId: 'user-b',
        content: '# B Template',
        name: 'User B Template',
      );

      harness.useUserA();

      final templates = await harness.repository.getAllTemplates();
      final ids = templates.map((t) => t.id).toList();

      expect(ids, containsAll(['system-template', 'user-a-template']));
      expect(ids, isNot(contains('user-b-template')));
    });

    test('getTemplateById hides other users templates', () async {
      final now = DateTime.utc(2025, 10, 29);
      await harness.insertTemplate(
        id: 'private-template',
        timestamp: now,
        ownerId: 'user-a',
      );

      harness.useUserB();

      final template = await harness.repository.getTemplateById(
        'private-template',
      );
      expect(template, isNull);
    });

    test('createTemplate associates template with current user', () async {
      harness.useUserA();
      final template = buildTemplate(
        name: 'User Template',
        content: 'Hello {{name}}',
      );

      final created = await harness.repository.createTemplate(template);
      expect(created.id, isNotEmpty);

      final stored = await (harness.db.select(
        harness.db.localTemplates,
      )..where((t) => t.id.equals(created.id))).getSingle();

      expect(stored.userId, equals('user-a'));
      expect(stored.isSystem, isFalse);

      final pending = await (harness.db.select(
        harness.db.pendingOps,
      )..where((op) => op.userId.equals('user-a'))).get();
      expect(pending, isNotEmpty);
      expect(pending.last.entityId, created.id);
      expect(pending.last.kind, 'upsert_template');
      expect(pending.last.payload, contains('"userId":"user-a"'));
    });

    test('createTemplate throws when user not authenticated', () async {
      harness.clearUser();
      final template = buildTemplate(name: 'Unauth Template');

      expect(
        () => harness.repository.createTemplate(template),
        throwsStateError,
      );
    });

    test('updateTemplate rejects updates from non-owner', () async {
      final now = DateTime.utc(2025, 10, 29);
      await harness.insertTemplate(
        id: 'edit-template',
        timestamp: now,
        ownerId: 'user-a',
        name: 'Original',
        content: 'Original content',
      );

      final existing = await harness.repository.getTemplateById(
        'edit-template',
      );
      expect(existing, isNotNull);

      harness.useUserB();

      expect(
        () => harness.repository.updateTemplate(
          existing!.copyWith(name: 'Hacked'),
        ),
        throwsStateError,
      );

      harness.useUserA();
      final unchanged = await harness.repository.getTemplateById(
        'edit-template',
      );
      expect(unchanged!.name, equals('Original'));
    });

    test('deleteTemplate removes template for owner only', () async {
      final now = DateTime.utc(2025, 10, 29);
      await harness.insertTemplate(
        id: 'delete-template',
        timestamp: now,
        ownerId: 'user-a',
      );

      harness.useUserB();
      await harness.repository.deleteTemplate('delete-template');

      harness.useUserA();
      var template = await harness.repository.getTemplateById(
        'delete-template',
      );
      expect(template, isNotNull);

      await harness.repository.deleteTemplate('delete-template');
      template = await harness.repository.getTemplateById('delete-template');
      expect(template, isNull);

      final pending = await (harness.db.select(
        harness.db.pendingOps,
      )..where((op) => op.userId.equals('user-a'))).get();
      expect(pending.map((op) => op.kind), contains('delete_template'));
    });

    test('applyTemplate creates note for owning user', () async {
      final now = DateTime.utc(2025, 10, 29);
      await harness.insertTemplate(
        id: 'apply-template',
        timestamp: now,
        ownerId: 'user-a',
        content: '# Meeting Notes\n{{notes}}',
        variables: {
          'title': 'Meeting Notes',
          'tags': ['meeting'],
        },
      );

      harness.useUserA();
      harness.createdNotes.clear();

      final noteId = await harness.repository.applyTemplate(
        templateId: 'apply-template',
        variableValues: {'notes': 'Agenda items'},
      );

      expect(noteId, isNotEmpty);
      expect(harness.createdNotes, isNotEmpty);
      final created = harness.createdNotes.last['note'] as domain.Note;
      expect(created.title, equals('Meeting Notes'));
      expect(created.body, contains('Agenda items'));
      expect(created.tags, contains('meeting'));
    });

    test('applyTemplate rejects access for non-owner', () async {
      final now = DateTime.utc(2025, 10, 29);
      await harness.insertTemplate(
        id: 'restricted-template',
        timestamp: now,
        ownerId: 'user-a',
      );

      harness.useUserB();

      expect(
        () => harness.repository.applyTemplate(
          templateId: 'restricted-template',
          variableValues: const {},
        ),
        throwsStateError,
      );
      expect(harness.createdNotes, isEmpty);
    });
  });
}
