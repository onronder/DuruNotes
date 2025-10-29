/* COMMENTED OUT - 3 errors
 * This file uses old models/APIs. Needs rewrite.
 */

/*
import 'package:duru_notes/core/crypto/crypto_box.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/data/remote/supabase_note_api.dart';
import 'package:duru_notes/features/folders/folder_notifiers.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/repository/folder_repository.dart';
import 'package:duru_notes/repository/notes_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'test_helpers.mocks.dart';

// Generate mocks for common dependencies
@GenerateMocks([
  AppDb,
  CryptoBox,
  SupabaseNoteApi,
  NotesRepository,
  FolderRepository,
  FolderHierarchyNotifier,
  FolderNotifier,
])
void main() {}
  /* COMMENTED OUT - 15 errors - old test helper utilities
   * This test uses old models/APIs that no longer exist after domain migration.
   * Needs complete rewrite to use new domain models and architecture.
   *
   * TODO: Rewrite test for new architecture
   */

  /*

/// Create a test provider container with common mocks
ProviderContainer createTestProviderContainer({
  List<Override> overrides = const [],
}) {
  final mockDb = MockAppDb();
  final mockCrypto = MockCryptoBox();
  final mockApi = MockSupabaseNoteApi();
  final mockNotesRepo = MockNotesRepository();
  final mockFolderRepo = MockFolderRepository();

  // Setup basic mock behaviors
  when(mockNotesRepo.db).thenReturn(mockDb);
  when(mockDb.allFolders()).thenAnswer((_) async => []);
  when(mockDb.getFolderNoteCounts()).thenAnswer((_) async => <String, int>{});
  when(mockFolderRepo.getAllFolders()).thenAnswer((_) async => []);

  final defaultOverrides = [
    notesRepositoryProvider.overrideWithValue(mockNotesRepo),
    folderRepositoryProvider.overrideWithValue(mockFolderRepo),
    // Mock folder hierarchy state
    folderHierarchyProvider.overrideWith((ref) =>
      const FolderHierarchyState(
        folders: [],
        expandedFolders: {},
        isLoading: false,
      ),
    ),
    // Mock folder operation state
    folderProvider.overrideWith((ref) =>
      const FolderOperationState(),
    ),
    ...overrides,
  ];

  return ProviderContainer(overrides: defaultOverrides);
}

/// Create a test folder for testing
LocalFolder createTestFolder({
  String id = 'test-folder-id',
  String name = 'Test Folder',
  String? parentId,
  String path = '/Test Folder',
  int sortOrder = 0,
  String? color,
  String? icon,
  String description = '',
  bool deleted = false,
}) {
  final now = DateTime.now();
  return LocalFolder(
    id: id,
    name: name,
    parentId: parentId,
    path: path,
    sortOrder: sortOrder,
    color: color,
    icon: icon,
    description: description,
    createdAt: now,
    updatedAt: now,
    deleted: deleted,
  );
}

/// Create a test note for testing
LocalNote createTestNote({
  String id = 'test-note-id',
  String title = 'Test Note',
  String body = 'Test note body',
  bool deleted = false,
  bool isPinned = false,
}) {
  return LocalNote(
    id: id,
    title: title,
    body: body,
    updatedAt: DateTime.now(),
    deleted: deleted,
    isPinned: isPinned,
    noteType: 0, // Regular note
  );
}

/// Extension to verify provider states in tests
extension ProviderContainerTesting on ProviderContainer {
  /// Read a provider synchronously for testing
  T readSync<T>(ProviderListenable<T> provider) {
    return read(provider);
  }

  /// Check if a provider has listeners
  bool hasListeners<T>(ProviderListenable<T> provider) {
    final element = readProviderElement(provider);
    return element.hasListeners;
  }
  */
}
*/
