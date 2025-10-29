import 'package:duru_notes/core/providers/database_providers.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/template.dart' as domain_template;
import 'package:duru_notes/infrastructure/mappers/template_mapper.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    as repository_providers;
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show templateCoreRepositoryProvider;

/// Template list provider - fetches all templates and converts to infrastructure LocalTemplate
/// UI components expect LocalTemplate for display properties (category, description, icon)
final templateListProvider = FutureProvider.autoDispose<List<LocalTemplate>>((ref) async {
  final repository = ref.watch(repository_providers.templateCoreRepositoryProvider);
  final domainTemplates = await repository.getAllTemplates();
  return TemplateMapper.toInfrastructureList(domainTemplates);
});

/// Template list stream provider - real-time updates
final templateListStreamProvider =
    StreamProvider.autoDispose<List<LocalTemplate>>((ref) async* {
  final db = ref.watch(appDbProvider);
  yield* db.select(db.localTemplates).watch();
});

/// System templates only - converted to LocalTemplate for UI
final systemTemplateListProvider =
    FutureProvider.autoDispose<List<LocalTemplate>>((ref) async {
  final repository = ref.watch(repository_providers.templateCoreRepositoryProvider);
  final domainTemplates = await repository.getSystemTemplates();
  return TemplateMapper.toInfrastructureList(domainTemplates);
});

/// User templates only - converted to LocalTemplate for UI
final userTemplateListProvider =
    FutureProvider.autoDispose<List<LocalTemplate>>((ref) async {
  final repository = ref.watch(repository_providers.templateCoreRepositoryProvider);
  final domainTemplates = await repository.getUserTemplates();
  return TemplateMapper.toInfrastructureList(domainTemplates);
});

/// Domain templates provider - now always uses domain repository
final domainTemplatesProvider = FutureProvider.autoDispose<List<domain_template.Template>>((ref) async {
  // Always use domain repository
  final repository = ref.watch(repository_providers.templateCoreRepositoryProvider);
  return repository.getAllTemplates();
});

/// Domain templates stream provider - now always uses domain repository
final domainTemplatesStreamProvider = StreamProvider.autoDispose<List<domain_template.Template>>((ref) {
  // Always use domain repository
  final repository = ref.watch(repository_providers.templateCoreRepositoryProvider);
  return repository.watchTemplates();
});
