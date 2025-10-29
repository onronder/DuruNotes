import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/note.dart' as note_domain;
import 'package:duru_notes/domain/entities/template.dart' as template_domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/infrastructure/repositories/template_core_repository.dart';
import 'package:duru_notes/models/note_kind.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _CapturingNotesRepository implements INotesRepository {
  final List<Map<String, dynamic>> capturedCalls = [];
  final List<note_domain.Note> createdNotes = [];

  @override
  Future<note_domain.Note?> createOrUpdate({
    required String title,
    required String body,
    String? id,
    String? folderId,
    List<String> tags = const [],
    List<Map<String, String?>> links = const [],
    Map<String, dynamic>? attachmentMeta,
    Map<String, dynamic>? metadataJson,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) async {
    final timestamp = DateTime.now();
    final note = note_domain.Note(
      id: id ?? 'note-${createdNotes.length + 1}',
      title: title,
      body: body,
      createdAt: createdAt ?? timestamp,
      updatedAt: updatedAt ?? timestamp,
      deleted: false,
      encryptedMetadata: null,
      isPinned: isPinned ?? false,
      noteType: NoteKind.note,
      folderId: folderId,
      version: 1,
      userId: 'user-123',
      attachmentMeta: attachmentMeta?.toString(),
      metadata: metadataJson?.toString(),
      tags: tags,
      links: const [],
    );

    createdNotes.add(note);
    capturedCalls.add({
      'title': title,
      'body': body,
      'folderId': folderId,
      'tags': List<String>.from(tags),
      'links': List<Map<String, String?>>.from(links),
      'metadata': metadataJson,
      'attachmentMeta': attachmentMeta,
      'isPinned': isPinned ?? false,
    });

    return note;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness() : db = AppDb.forTesting(NativeDatabase.memory()) {
    _notesRepository.capturedCalls.clear();
    _notesRepository.createdNotes.clear();
    supabaseClient = SupabaseClient('https://test.supabase.co', 'test-key');
    templateRepository = TemplateCoreRepository(
      db: db,
      client: supabaseClient,
      notesRepository: _notesRepository,
      userIdResolver: () => 'user-123',
    );
  }

  final AppDb db;
  late final SupabaseClient supabaseClient;
  late final TemplateCoreRepository templateRepository;

  static final _CapturingNotesRepository _notesRepository =
      _CapturingNotesRepository();

  Future<void> dispose() async {
    await db.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Template management integration', () {
    late _Harness harness;

    setUp(() async {
      harness = _Harness();
      await _seedSystemTemplate(harness.db);
    });

    tearDown(() async {
      await harness.dispose();
    });

    test('creates user template and enqueues sync operation', () async {
      final repository = harness.templateRepository;
      final createdAt = DateTime.utc(2025, 1, 1);

      final template = template_domain.Template(
        id: '',
        name: 'Release Postmortem',
        content: '# Postmortem\nSummary goes here.',
        variables: const {
          'tags': ['retro'],
        },
        isSystem: false,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      final created = await repository.createTemplate(template);
      expect(created.id, isNotEmpty);

      final stored = await harness.db.getTemplate(created.id);
      expect(stored, isNotNull);
      expect(stored!.userId, equals('user-123'));
      expect(stored.title, equals('Release Postmortem'));
      expect(stored.isSystem, isFalse);

      final pending = await harness.db.getPendingOpsForUser('user-123');
      expect(
        pending.where(
          (op) => op.entityId == created.id && op.kind == 'upsert_template',
        ),
        isNotEmpty,
      );
    });

    test(
      'applies template with variable substitution and note creation',
      () async {
        final repository = harness.templateRepository;
        final now = DateTime.utc(2025, 1, 2);

        final template = template_domain.Template(
          id: 'template-apply',
          name: 'Daily Stand-up',
          content: '''# {{title}}
- Yesterday: {{yesterday}}
- Today: {{today}}
- Blockers: {{blockers}}''',
          variables: const {
            'tags': ['standup', 'daily'],
            'isPinned': 'true',
          },
          isSystem: false,
          createdAt: now,
          updatedAt: now,
        );

        await repository.createTemplate(template);

        final noteId = await repository.applyTemplate(
          templateId: 'template-apply',
          variableValues: const {
            'title': 'Daily Sync – Oct 26',
            'yesterday': 'Shipped analytics fixes',
            'today': 'Integrating template coverage',
            'blockers': 'None',
            'folderId': 'team-updates',
            'links': [
              {'title': 'Ticket-123', 'id': 'ticket-123'},
            ],
            'metadata': {'createdFrom': 'standup-template'},
          },
        );

        expect(noteId, isNotEmpty);
        final captured = _Harness._notesRepository.capturedCalls.last;

        expect(captured['title'], equals('Daily Sync – Oct 26'));
        expect(captured['body'], contains('Shipped analytics fixes'));
        expect(captured['folderId'], equals('team-updates'));
        expect(captured['tags'], containsAll(['standup', 'daily']));
        expect(captured['isPinned'], isTrue);
        expect(captured['links'], hasLength(1));
        expect(captured['metadata'], {'createdFrom': 'standup-template'});
      },
    );

    test('applyTemplate requires authenticated user', () async {
      final repository = TemplateCoreRepository(
        db: harness.db,
        client: harness.supabaseClient,
        notesRepository: _Harness._notesRepository,
        userIdResolver: () => null,
      );

      await expectLater(
        () => repository.applyTemplate(
          templateId: 'system_template',
          variableValues: const {},
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

Future<void> _seedSystemTemplate(AppDb db) async {
  final now = DateTime.utc(2025, 1, 1);

  await db
      .into(db.localTemplates)
      .insert(
        LocalTemplatesCompanion.insert(
          id: 'system_template',
          title: '📋 Checklist',
          body: '- [ ] Item 1\n- [ ] Item 2',
          isSystem: const Value(true),
          category: 'system',
          description: 'Reusable checklist template',
          icon: 'checklist',
          createdAt: now,
          updatedAt: now,
        ),
      );
}
