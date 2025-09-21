import 'dart:convert';

import 'package:duru_notes/features/folders/smart_folders/smart_folder_engine.dart';
import 'package:duru_notes/features/folders/smart_folders/smart_folder_saved_search_presets.dart';
import 'package:duru_notes/features/folders/smart_folders/smart_folder_types.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for smart folder engine
final smartFolderEngineProvider = Provider<SmartFolderEngine>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return SmartFolderEngine(repository);
});

/// State for smart folder management
class SmartFoldersState {
  const SmartFoldersState({
    this.folders = const [],
    this.isLoading = false,
    this.error,
    this.folderContents = const {},
    this.folderStats = const {},
  });
  final List<SmartFolderConfig> folders;
  final bool isLoading;
  final String? error;
  final Map<String, List<LocalNote>> folderContents;
  final Map<String, SmartFolderStats> folderStats;

  SmartFoldersState copyWith({
    List<SmartFolderConfig>? folders,
    bool? isLoading,
    String? error,
    Map<String, List<LocalNote>>? folderContents,
    Map<String, SmartFolderStats>? folderStats,
  }) {
    return SmartFoldersState(
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      folderContents: folderContents ?? this.folderContents,
      folderStats: folderStats ?? this.folderStats,
    );
  }
}

/// Notifier for managing smart folders
class SmartFoldersNotifier extends StateNotifier<SmartFoldersState> {
  SmartFoldersNotifier(this._engine) : super(const SmartFoldersState()) {
    _loadSmartFolders();
  }

  final SmartFolderEngine _engine;
  SharedPreferences? _prefs;

  /// Load smart folders from storage
  Future<void> _loadSmartFolders() async {
    try {
      state = state.copyWith(isLoading: true);

      _prefs ??= await SharedPreferences.getInstance();
      final foldersJson = _prefs!.getStringList('smart_folders') ?? [];

      final folders = foldersJson
          .map(
            (json) => SmartFolderConfig.fromJson(
              jsonDecode(json) as Map<String, dynamic>,
            ),
          )
          .toList();

      // Add default templates if no folders exist
      if (folders.isEmpty) {
        folders.addAll(SmartFolderTemplates.all);
        // Add saved search presets
        folders.addAll(SmartFolderSavedSearchPresets.getSavedSearchPresets());
        await _saveSmartFolders(folders);
      }

      state = state.copyWith(folders: folders, isLoading: false);

      // Load content for all folders
      await refreshAllFolders();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Save smart folders to storage
  Future<void> _saveSmartFolders(List<SmartFolderConfig> folders) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final foldersJson =
          folders.map((folder) => jsonEncode(folder.toJson())).toList();
      await _prefs!.setStringList('smart_folders', foldersJson);
    } catch (e) {
      state = state.copyWith(error: 'Failed to save smart folders: $e');
    }
  }

  /// Add or update a smart folder
  Future<void> saveSmartFolder(SmartFolderConfig config) async {
    try {
      final folders = List<SmartFolderConfig>.from(state.folders);
      final existingIndex = folders.indexWhere((f) => f.id == config.id);

      if (existingIndex != -1) {
        folders[existingIndex] = config;
      } else {
        folders.add(config);
      }

      await _saveSmartFolders(folders);
      state = state.copyWith(folders: folders);

      // Refresh this folder's content
      await refreshFolder(config.id);
    } catch (e) {
      state = state.copyWith(error: 'Failed to save smart folder: $e');
    }
  }

  /// Delete a smart folder
  Future<void> deleteSmartFolder(String folderId) async {
    try {
      final folders = state.folders.where((f) => f.id != folderId).toList();
      await _saveSmartFolders(folders);

      // Clean up state
      final contents = Map<String, List<LocalNote>>.from(state.folderContents);
      contents.remove(folderId);

      final stats = Map<String, SmartFolderStats>.from(state.folderStats);
      stats.remove(folderId);

      state = state.copyWith(
        folders: folders,
        folderContents: contents,
        folderStats: stats,
      );

      // Stop watching this folder
      _engine.stopWatching(folderId);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete smart folder: $e');
    }
  }

  /// Refresh all smart folders
  Future<void> refreshAllFolders() async {
    try {
      state = state.copyWith(isLoading: true);

      final contents = <String, List<LocalNote>>{};
      final stats = <String, SmartFolderStats>{};

      // Get total notes count for statistics
      final allNotes = await _engine.getAllNotes();
      final totalNotesCount = allNotes.length;

      for (final folder in state.folders) {
        final notes = await _engine.getNotesForSmartFolder(folder);
        contents[folder.id] = notes;
        stats[folder.id] = SmartFolderStats.fromNotes(notes, totalNotesCount);
      }

      state = state.copyWith(
        folderContents: contents,
        folderStats: stats,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh a specific smart folder
  Future<void> refreshFolder(String folderId) async {
    try {
      final folder = state.folders.firstWhere((f) => f.id == folderId);
      final notes = await _engine.getNotesForSmartFolder(folder);

      // Get total notes for stats
      final allNotes = await _engine.getAllNotes();
      final stats = SmartFolderStats.fromNotes(notes, allNotes.length);

      final contents = Map<String, List<LocalNote>>.from(state.folderContents);
      contents[folderId] = notes;

      final folderStats = Map<String, SmartFolderStats>.from(state.folderStats);
      folderStats[folderId] = stats;

      state = state.copyWith(
        folderContents: contents,
        folderStats: folderStats,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to refresh folder: $e');
    }
  }

  /// Get notes for a specific smart folder
  List<LocalNote> getNotesForFolder(String folderId) {
    return state.folderContents[folderId] ?? [];
  }

  /// Get statistics for a specific smart folder
  SmartFolderStats? getStatsForFolder(String folderId) {
    return state.folderStats[folderId];
  }

  /// Stream notes for a smart folder with auto-refresh
  Stream<List<LocalNote>> watchSmartFolder(String folderId) {
    final folder = state.folders.firstWhere((f) => f.id == folderId);
    return _engine.watchSmartFolder(folder);
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith();
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }
}

/// Provider for smart folders state
final smartFoldersProvider =
    StateNotifierProvider<SmartFoldersNotifier, SmartFoldersState>((ref) {
  final engine = ref.watch(smartFolderEngineProvider);
  return SmartFoldersNotifier(engine);
});

/// Provider for smart folder templates
final smartFolderTemplatesProvider = Provider<List<SmartFolderConfig>>((ref) {
  return SmartFolderTemplates.all;
});

/// Provider for notes in a specific smart folder
final ProviderFamily<List<LocalNote>, String> smartFolderNotesProvider =
    Provider.family<List<LocalNote>, String>((ref, folderId) {
  final smartFoldersState = ref.watch(smartFoldersProvider);
  return smartFoldersState.folderContents[folderId] ?? [];
});

/// Provider for smart folder statistics
final ProviderFamily<SmartFolderStats?, String> smartFolderStatsProvider =
    Provider.family<SmartFolderStats?, String>((ref, folderId) {
  final smartFoldersState = ref.watch(smartFoldersProvider);
  return smartFoldersState.folderStats[folderId];
});

/// Provider for streaming smart folder notes
final StreamProviderFamily<List<LocalNote>, String> smartFolderStreamProvider =
    StreamProvider.family<List<LocalNote>, String>((ref, folderId) {
  final notifier = ref.watch(smartFoldersProvider.notifier);
  return notifier.watchSmartFolder(folderId);
});

/// Provider to check if smart folders feature is enabled
final smartFoldersEnabledProvider = Provider<bool>((ref) {
  // Could be tied to a user setting or feature flag
  return true;
});

/// Provider for smart folder by ID
final ProviderFamily<SmartFolderConfig?, String> smartFolderByIdProvider =
    Provider.family<SmartFolderConfig?, String>((ref, folderId) {
  final smartFoldersState = ref.watch(smartFoldersProvider);
  try {
    return smartFoldersState.folders.firstWhere((f) => f.id == folderId);
  } catch (e) {
    return null;
  }
});

/// Provider for smart folder count
final smartFolderCountProvider = Provider<int>((ref) {
  final smartFoldersState = ref.watch(smartFoldersProvider);
  return smartFoldersState.folders.length;
});

/// Helper extensions for smart folder operations
extension SmartFoldersNotifierExtensions on SmartFoldersNotifier {
  /// Duplicate a smart folder with a new name
  Future<void> duplicateSmartFolder(String folderId, String newName) async {
    final originalFolder = state.folders.firstWhere((f) => f.id == folderId);
    final duplicatedFolder = originalFolder.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: newName,
    );
    await saveSmartFolder(duplicatedFolder);
  }

  /// Export smart folder configuration
  String exportSmartFolder(String folderId) {
    final folder = state.folders.firstWhere((f) => f.id == folderId);
    return jsonEncode(folder.toJson());
  }

  /// Import smart folder configuration
  Future<void> importSmartFolder(String configJson) async {
    try {
      final config = SmartFolderConfig.fromJson(
        jsonDecode(configJson) as Map<String, dynamic>,
      );
      await saveSmartFolder(config);
    } catch (e) {
      state = state.copyWith(error: 'Failed to import smart folder: $e');
    }
  }

  /// Reset to default smart folders
  Future<void> resetToDefaults() async {
    await _saveSmartFolders(SmartFolderTemplates.all);
    state = state.copyWith(folders: SmartFolderTemplates.all);
    await refreshAllFolders();
  }
}
