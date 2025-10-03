import 'package:duru_notes/core/migration/state_migration_helper.dart';
import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/template.dart' as domain_template;
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/infrastructure/repositories/template_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/template_core_repository.dart';
import 'package:duru_notes/services/template_migration_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Template repository provider
final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  final db = ref.watch(appDbProvider);
  return TemplateRepository(db: db);
});

/// Template core repository provider (domain architecture)
final templateCoreRepositoryProvider = Provider<ITemplateRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final client = Supabase.instance.client;
  return TemplateCoreRepository(db: db, client: client);
});

/// Template migration service provider
final templateMigrationServiceProvider =
    Provider<TemplateMigrationService>((ref) {
  final db = ref.watch(appDbProvider);
  return TemplateMigrationService(db);
});

/// Template list provider - fetches all templates with migration
final templateListProvider = FutureProvider<List<LocalTemplate>>((ref) async {
  // Run migration if needed
  final migrationService = ref.watch(templateMigrationServiceProvider);
  if (await migrationService.needsMigration()) {
    await migrationService.migrateTemplates();
  }

  final repository = ref.watch(templateRepositoryProvider);
  return repository.getAllTemplates();
});

/// Template list stream provider - real-time updates
final templateListStreamProvider =
    StreamProvider<List<LocalTemplate>>((ref) async* {
  final db = ref.watch(appDbProvider);
  yield* db.select(db.localTemplates).watch();
});

/// System templates only
final systemTemplateListProvider =
    FutureProvider<List<LocalTemplate>>((ref) async {
  final repository = ref.watch(templateRepositoryProvider);
  return repository.getSystemTemplates();
});

/// User templates only
final userTemplateListProvider =
    FutureProvider<List<LocalTemplate>>((ref) async {
  final repository = ref.watch(templateRepositoryProvider);
  return repository.getUserTemplates();
});

/// Domain templates provider - switches between legacy and domain
final domainTemplatesProvider = FutureProvider<List<domain_template.Template>>((ref) async {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('templates')) {
    // Use domain repository
    final repository = ref.watch(templateCoreRepositoryProvider);
    return repository.getAllTemplates();
  } else {
    // Convert from legacy
    final localTemplates = await ref.watch(templateListProvider.future);
    return StateMigrationHelper.convertTemplatesToDomain(localTemplates);
  }
});

/// Domain templates stream provider
final domainTemplatesStreamProvider = StreamProvider<List<domain_template.Template>>((ref) {
  final config = ref.watch(migrationConfigProvider);

  if (config.isFeatureEnabled('templates')) {
    final repository = ref.watch(templateCoreRepositoryProvider);
    return repository.watchTemplates();
  } else {
    // Convert legacy stream by watching the stream provider and mapping its data
    return ref.watch(templateListStreamProvider.stream).map(
      (localTemplates) => StateMigrationHelper.convertTemplatesToDomain(localTemplates),
    );
  }
});