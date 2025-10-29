import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/template.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/infrastructure/repositories/template_core_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDb db;
  late SupabaseClient supabaseClient;
  late TemplateCoreRepository repository;

  setUp(() async {
    db = AppDb.forTesting(NativeDatabase.memory());
    supabaseClient = SupabaseClient('https://test.supabase.co', 'test-key');
    repository = TemplateCoreRepository(
      db: db,
      client: supabaseClient,
      notesRepository: _StubNotesRepository(),
      userIdResolver: () => 'user-123',
    );

    await _seedTemplates(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('getAllTemplates returns user and system templates only', () async {
    final results = await repository.getAllTemplates();
    final templateIds = results.map((template) => template.id).toSet();

    expect(
      templateIds,
      containsAll(<String>{'system-template', 'user-template'}),
    );
    expect(templateIds, isNot(contains('other-template')));
  });

  test(
    'getTemplateById enforces ownership while allowing system templates',
    () async {
      final userTemplate = await repository.getTemplateById('user-template');
      final systemTemplate = await repository.getTemplateById(
        'system-template',
      );
      final otherTemplate = await repository.getTemplateById('other-template');

      expect(userTemplate, isNotNull);
      expect(systemTemplate, isNotNull);
      expect(otherTemplate, isNull);
    },
  );

  test(
    'createTemplate assigns user ownership and enqueues sync operation',
    () async {
      final now = DateTime.utc(2025, 10, 26, 12);
      final newTemplate = Template(
        id: '',
        name: 'Launch Debrief',
        content: 'Summary of launch-day learnings',
        variables: const {},
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      );

      final created = await repository.createTemplate(newTemplate);
      expect(created.id, isNotEmpty);

      final inserted = await db.getTemplate(created.id);
      expect(inserted, isNotNull);
      expect(inserted!.userId, equals('user-123'));
      expect(inserted.isSystem, isFalse);

      final pendingOps = await db.getPendingOpsForUser('user-123');
      expect(pendingOps, hasLength(1));
      expect(pendingOps.first.kind, equals('upsert_template'));
    },
  );

  test(
    'createTemplate throws when no authenticated user is available',
    () async {
      final unauthenticatedRepository = TemplateCoreRepository(
        db: db,
        client: supabaseClient,
        notesRepository: _StubNotesRepository(),
        userIdResolver: () => null,
      );

      final template = Template(
        id: '',
        name: 'Unauthorized Template',
        content: 'Should not be created',
        variables: const {},
        isSystem: false,
        createdAt: DateTime.utc(2025, 10, 26),
        updatedAt: DateTime.utc(2025, 10, 26),
      );

      await expectLater(
        unauthenticatedRepository.createTemplate(template),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'deleteTemplate enforces ownership and prevents system template removal',
    () async {
      final beforeDeletion = await repository.getAllTemplates();

      await repository.deleteTemplate('system-template');

      final afterDeletion = await repository.getAllTemplates();
      expect(afterDeletion.length, equals(beforeDeletion.length));
      expect(
        afterDeletion.map((template) => template.id),
        contains('system-template'),
      );

      await repository.deleteTemplate('user-template');

      final remaining = await repository.getAllTemplates();
      expect(
        remaining.map((template) => template.id),
        isNot(contains('user-template')),
      );

      final pendingOps = await db.getPendingOpsForUser('user-123');
      final deleteOps = pendingOps.where((op) => op.kind == 'delete_template');
      expect(deleteOps.length, equals(1));
    },
  );
}

Future<void> _seedTemplates(AppDb db) async {
  final now = DateTime.utc(2025, 10, 20);

  await db
      .into(db.localTemplates)
      .insert(
        LocalTemplatesCompanion.insert(
          id: 'system-template',
          title: 'System Template',
          body: 'System-wide template',
          isSystem: const Value(true),
          category: 'system',
          description: 'Global template available to all users',
          icon: 'star',
          createdAt: now,
          updatedAt: now,
        ),
      );

  await db
      .into(db.localTemplates)
      .insert(
        LocalTemplatesCompanion.insert(
          id: 'user-template',
          userId: const Value('user-123'),
          title: 'Mission Template',
          body: 'Private mission template',
          isSystem: const Value(false),
          category: 'mission',
          description: 'Template owned by the active user',
          icon: 'rocket_launch',
          createdAt: now,
          updatedAt: now,
        ),
      );

  await db
      .into(db.localTemplates)
      .insert(
        LocalTemplatesCompanion.insert(
          id: 'other-template',
          userId: const Value('user-456'),
          title: 'Other User Template',
          body: 'Should stay hidden',
          isSystem: const Value(false),
          category: 'mission',
          description: 'Belongs to a different user',
          icon: 'visibility_off',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

class _StubNotesRepository implements INotesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unexpected call: ${invocation.memberName}');
}
