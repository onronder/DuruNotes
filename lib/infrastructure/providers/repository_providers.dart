import 'package:duru_notes/providers.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_search_repository.dart';
import 'package:duru_notes/domain/repositories/i_tag_repository.dart';
import 'package:duru_notes/domain/repositories/i_template_repository.dart';
import 'package:duru_notes/infrastructure/repositories/notes_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/search_repository.dart';
import 'package:duru_notes/infrastructure/repositories/tag_repository.dart';
import 'package:duru_notes/infrastructure/repositories/folder_core_repository.dart';
import 'package:duru_notes/infrastructure/repositories/template_core_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the notes core repository
final notesCoreRepositoryProvider = Provider<INotesRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final crypto = ref.watch(cryptoBoxProvider);
  final client = Supabase.instance.client;
  final api = SupabaseNoteApi(client);
  final indexer = ref.watch(noteIndexerProvider);

  return NotesCoreRepository(
    db: db,
    crypto: crypto,
    api: api,
    client: client,
    indexer: indexer,
  );
});

/// Provider for the tag repository
final tagRepositoryProvider = Provider<ITagRepository>((ref) {
  final db = ref.watch(appDbProvider);

  return TagRepository(
    db: db,
  );
});

/// Provider for the search repository
final searchRepositoryProvider = Provider<ISearchRepository>((ref) {
  final db = ref.watch(appDbProvider);

  return SearchRepository(
    db: db,
  );
});

/// Provider for the folder repository
final folderRepositoryInterfaceProvider = Provider<IFolderRepository>((ref) {
  // Use the existing FolderRepository implementation
  return ref.watch(folderRepositoryProvider) as IFolderRepository;
});

/// Provider for the template repository
final templateRepositoryInterfaceProvider = Provider<ITemplateRepository>((ref) {
  // Use the existing TemplateRepository implementation
  return ref.watch(templateRepositoryProvider) as ITemplateRepository;
});

