import 'dart:async';

import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/domain/repositories/i_notes_repository.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/services/sync/folder_sync_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper class for representing folder tree nodes with nesting
class FolderTreeNode {
  const FolderTreeNode({
    required this.folder,
    required this.level,
    required this.isExpanded,
    required this.hasChildren,
    this.noteCount = 0,
    this.children = const [],
  });

  final domain.Folder folder;
  final int level;
  final bool isExpanded;
  final bool hasChildren;
  final int noteCount;
  final List<FolderTreeNode> children;

  FolderTreeNode copyWith({
    domain.Folder? folder,
    int? level,
    bool? isExpanded,
    bool? hasChildren,
    int? noteCount,
    List<FolderTreeNode>? children,
  }) {
    return FolderTreeNode(
      folder: folder ?? this.folder,
      level: level ?? this.level,
      isExpanded: isExpanded ?? this.isExpanded,
      hasChildren: hasChildren ?? this.hasChildren,
      noteCount: noteCount ?? this.noteCount,
      children: children ?? this.children,
    );
  }
}

/// State class for folder hierarchy with expansion states
class FolderHierarchyState {
  const FolderHierarchyState({
    required this.folders,
    required this.expandedFolders,
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.noteCounts = const {},
  });

  final List<domain.Folder> folders;
  final Set<String> expandedFolders;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final Map<String, int> noteCounts;

  FolderHierarchyState copyWith({
    List<domain.Folder>? folders,
    Set<String>? expandedFolders,
    bool? isLoading,
    String? error,
    String? searchQuery,
    Map<String, int>? noteCounts,
  }) {
    return FolderHierarchyState(
      folders: folders ?? this.folders,
      expandedFolders: expandedFolders ?? this.expandedFolders,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
      noteCounts: noteCounts ?? this.noteCounts,
    );
  }

  /// Get root folders (no parent)
  /// Note: Repository should filter deleted folders before returning
  List<domain.Folder> get rootFolders {
    final filtered = searchQuery.isEmpty
        ? folders.where((f) => f.parentId == null).toList()
        : folders
              .where(
                (f) => f.name.toLowerCase().contains(searchQuery.toLowerCase()),
              )
              .toList();

    filtered.sort((a, b) {
      final sortCompare = a.sortOrder.compareTo(b.sortOrder);
      return sortCompare != 0 ? sortCompare : a.name.compareTo(b.name);
    });
    return filtered;
  }

  /// Get child folders for a parent
  /// Note: Repository should filter deleted folders before returning
  List<domain.Folder> getChildFolders(String parentId) {
    final children = folders.where((f) => f.parentId == parentId).toList();

    children.sort((a, b) {
      final sortCompare = a.sortOrder.compareTo(b.sortOrder);
      return sortCompare != 0 ? sortCompare : a.name.compareTo(b.name);
    });
    return children;
  }

  /// Check if folder is expanded
  bool isExpanded(String folderId) => expandedFolders.contains(folderId);

  /// Get folder by ID
  domain.Folder? getFolderById(String id) {
    return folders.where((f) => f.id == id).firstOrNull;
  }

  /// Get expanded folder IDs
  Set<String> get expandedIds => expandedFolders;

  /// Get root nodes as FolderTreeNode objects
  List<FolderTreeNode> get rootNodes {
    return rootFolders.map((folder) {
      final hasChildren = getChildFolders(folder.id).isNotEmpty;
      return FolderTreeNode(
        folder: folder,
        level: 0,
        isExpanded: isExpanded(folder.id),
        hasChildren: hasChildren,
        noteCount: noteCounts[folder.id] ?? 0,
        children: hasChildren && isExpanded(folder.id)
            ? _buildChildNodes(folder.id, 1)
            : [],
      );
    }).toList();
  }

  /// Build child nodes recursively
  List<FolderTreeNode> _buildChildNodes(String parentId, int level) {
    final children = getChildFolders(parentId);
    return children.map((folder) {
      final hasChildren = getChildFolders(folder.id).isNotEmpty;
      return FolderTreeNode(
        folder: folder,
        level: level,
        isExpanded: isExpanded(folder.id),
        hasChildren: hasChildren,
        noteCount: noteCounts[folder.id] ?? 0,
        children: hasChildren && isExpanded(folder.id)
            ? _buildChildNodes(folder.id, level + 1)
            : [],
      );
    }).toList();
  }
}

/// Notifier for managing folder hierarchy and expansion states
class FolderHierarchyNotifier extends StateNotifier<FolderHierarchyState> {
  FolderHierarchyNotifier(IFolderRepository? repository)
    : _repository = repository,
      super(const FolderHierarchyState(folders: [], expandedFolders: {})) {
    _init();
  }

  /// PRODUCTION FIX: Empty factory for unauthenticated state
  factory FolderHierarchyNotifier.empty() {
    return _EmptyFolderHierarchyNotifier();
  }

  final IFolderRepository? _repository;
  Timer? _debounceTimer;
  Timer? _refreshDebounceTimer;
  DateTime? _lastRefreshTime;

  /// Minimum time between refreshes (prevents excessive API calls)
  static const Duration minRefreshInterval = Duration(milliseconds: 500);

  Future<void> _init() async {
    await _loadExpansionState();
    await loadFolders();
  }

  /// Load all folders from repository
  Future<void> loadFolders() async {
    // Check if notifier is still mounted
    if (!mounted) return;

    try {
      // Guard against null repository (unauthenticated)
      if (_repository == null) return;

      state = state.copyWith(isLoading: true);
      final folders = await _repository.listFolders();

      // Check again after async operation
      if (!mounted) return;

      final counts = await _repository.getFolderNoteCounts();
      await _repository.ensureFolderIntegrity();

      // Final check before updating state
      if (!mounted) return;

      state = state.copyWith(
        folders: folders,
        isLoading: false,
        noteCounts: counts,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
      if (kDebugMode) debugPrint('Error loading folders: $e');
    }
  }

  /// Toggle folder expansion state
  void toggleExpansion(String folderId) {
    final expandedFolders = Set<String>.from(state.expandedFolders);
    if (expandedFolders.contains(folderId)) {
      expandedFolders.remove(folderId);
    } else {
      expandedFolders.add(folderId);
    }
    state = state.copyWith(expandedFolders: expandedFolders);
    unawaited(_persistExpansionState(expandedFolders));
  }

  /// Expand folder and all its parents
  void expandPath(String folderId) {
    final expandedFolders = Set<String>.from(state.expandedFolders);

    // Add the folder itself
    expandedFolders.add(folderId);

    // Expand all parent folders
    String? currentId = folderId;
    while (currentId != null) {
      final folder = state.getFolderById(currentId);
      if (folder?.parentId != null) {
        expandedFolders.add(folder!.parentId!);
        currentId = folder.parentId;
      } else {
        break;
      }
    }

    state = state.copyWith(expandedFolders: expandedFolders);
    unawaited(_persistExpansionState(expandedFolders));
  }

  /// Collapse all folders
  void collapseAll() {
    state = state.copyWith(expandedFolders: <String>{});
    unawaited(_persistExpansionState(<String>{}));
  }

  /// Expand all folders
  void expandAll() {
    final allFolderIds = state.folders.map((f) => f.id).toSet();
    state = state.copyWith(expandedFolders: allFolderIds);
    unawaited(_persistExpansionState(allFolderIds));
  }

  /// Update search query with debouncing
  void updateSearchQuery(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      state = state.copyWith(searchQuery: query.trim());
    });
  }

  /// Clear search
  void clearSearch() {
    _debounceTimer?.cancel();
    state = state.copyWith(searchQuery: '');
  }

  /// Get visible folder tree nodes (flattened tree structure)
  List<FolderTreeNode> getVisibleNodes() {
    final nodes = <FolderTreeNode>[];

    void buildNodes(List<domain.Folder> folders, int level) {
      for (final folder in folders) {
        final hasChildren = state.getChildFolders(folder.id).isNotEmpty;
        final isExpanded = state.isExpanded(folder.id);

        nodes.add(
          FolderTreeNode(
            folder: folder,
            level: level,
            isExpanded: isExpanded,
            hasChildren: hasChildren,
          ),
        );

        // Add child nodes if expanded
        if (isExpanded && hasChildren) {
          final children = state.getChildFolders(folder.id);
          buildNodes(children, level + 1);
        }
      }
    }

    buildNodes(state.rootFolders, 0);
    return nodes;
  }

  /// Add a folder to the state (called after creation)
  void addFolder(domain.Folder folder) {
    final folders = List<domain.Folder>.from(state.folders)..add(folder);
    final updatedCounts = Map<String, int>.from(state.noteCounts);
    updatedCounts.putIfAbsent(folder.id, () => 0);
    state = state.copyWith(folders: folders, noteCounts: updatedCounts);

    // Auto-expand parent if it exists
    if (folder.parentId != null && folder.parentId!.isNotEmpty) {
      expandPath(folder.parentId!);
    }
  }

  /// Update folder in state (called after edit)
  void updateFolder(domain.Folder updatedFolder) {
    final folders = state.folders.map((f) {
      return f.id == updatedFolder.id ? updatedFolder : f;
    }).toList();
    state = state.copyWith(folders: folders);
  }

  /// Remove folder from state (called after deletion)
  void removeFolder(String folderId) {
    final folders = state.folders.where((f) => f.id != folderId).toList();
    final expandedFolders = Set<String>.from(state.expandedFolders)
      ..remove(folderId);
    final updatedCounts = Map<String, int>.from(state.noteCounts)
      ..remove(folderId);
    state = state.copyWith(
      folders: folders,
      expandedFolders: expandedFolders,
      noteCounts: updatedCounts,
    );
    unawaited(_persistExpansionState(expandedFolders));
  }

  /// Refresh folders with debouncing to prevent excessive API calls
  /// Use this method in UI to refresh folder list
  Future<void> refresh() async {
    // Cancel any pending refresh
    _refreshDebounceTimer?.cancel();

    // Check if we need to wait before refreshing
    final now = DateTime.now();
    if (_lastRefreshTime != null) {
      final timeSinceLastRefresh = now.difference(_lastRefreshTime!);
      if (timeSinceLastRefresh < minRefreshInterval) {
        // Schedule refresh after minimum interval
        _refreshDebounceTimer = Timer(
          minRefreshInterval - timeSinceLastRefresh,
          () => _performRefresh(),
        );
        return;
      }
    }

    // Perform immediate refresh
    await _performRefresh();
  }

  /// Internal method to perform the actual refresh
  Future<void> _performRefresh() async {
    _lastRefreshTime = DateTime.now();
    await loadFolders();
  }

  /// Force refresh immediately (bypasses debouncing)
  /// Use sparingly - prefer refresh() for UI operations
  Future<void> forceRefresh() async {
    _refreshDebounceTimer?.cancel();
    _lastRefreshTime = DateTime.now();
    await loadFolders();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _refreshDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadExpansionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_expansionPrefsKey()) ?? <String>[];
      if (stored.isNotEmpty) {
        state = state.copyWith(expandedFolders: stored.toSet());
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading folder expansion state: $e');
    }
  }

  Future<void> _persistExpansionState(Set<String> expanded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_expansionPrefsKey(), expanded.toList());
    } catch (e) {
      if (kDebugMode) debugPrint('Error persisting folder expansion state: $e');
    }
  }

  String _expansionPrefsKey() {
    try {
      final userId = _repository?.getCurrentUserId();
      return '_folder_expanded_${userId ?? 'default'}';
    } catch (_) {
      return '_folder_expanded_default';
    }
  }
}

/// State class for folder operations
class FolderOperationState {
  const FolderOperationState({
    this.isCreating = false,
    this.isUpdating = false,
    this.isDeleting = false,
    this.error,
  });

  final bool isCreating;
  final bool isUpdating;
  final bool isDeleting;
  final String? error;

  bool get isLoading => isCreating || isUpdating || isDeleting;

  FolderOperationState copyWith({
    bool? isCreating,
    bool? isUpdating,
    bool? isDeleting,
    String? error,
  }) {
    return FolderOperationState(
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      isDeleting: isDeleting ?? this.isDeleting,
      error: error ?? this.error,
    );
  }
}

/// Notifier for folder CRUD operations
class FolderNotifier extends StateNotifier<FolderOperationState> {
  FolderNotifier(
    IFolderRepository? repository,
    FolderSyncCoordinator? syncCoordinator,
  ) : _repository = repository,
      _syncCoordinator = syncCoordinator,
      super(const FolderOperationState());

  /// PRODUCTION FIX: Empty factory for unauthenticated state
  factory FolderNotifier.empty() {
    return _EmptyFolderNotifier();
  }

  final IFolderRepository? _repository;
  final FolderSyncCoordinator? _syncCoordinator;

  /// Maximum folders per user (prevents abuse and database bloat)
  static const int maxFoldersPerUser = 500;

  /// Create a new folder
  Future<String?> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) async {
    try {
      // Guard against null coordinator (unauthenticated)
      if (_syncCoordinator == null) return null;

      // Validation: Check folder count limit
      if (_repository != null) {
        final folders = await _repository.listFolders();
        if (folders.length >= maxFoldersPerUser) {
          final errorMsg =
              'Folder limit reached ($maxFoldersPerUser folders). Please delete some folders before creating new ones.';
          state = state.copyWith(isCreating: false, error: errorMsg);
          if (kDebugMode) debugPrint('[FolderNotifier] $errorMsg');
          return null;
        }
      }

      // Validation: Check folder name
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        const errorMsg = 'Folder name cannot be empty';
        state = state.copyWith(isCreating: false, error: errorMsg);
        if (kDebugMode) debugPrint('[FolderNotifier] $errorMsg');
        return null;
      }

      if (trimmedName.length > 255) {
        const errorMsg = 'Folder name is too long (max 255 characters)';
        state = state.copyWith(isCreating: false, error: errorMsg);
        if (kDebugMode) debugPrint('[FolderNotifier] $errorMsg');
        return null;
      }

      state = state.copyWith(isCreating: true, error: null);

      // Use sync coordinator for creation with audit and conflict resolution
      final folderId = await _syncCoordinator.createFolder(
        name: trimmedName,
        parentId: parentId,
        color: color,
        icon: icon,
        description: description,
      );

      state = state.copyWith(isCreating: false);
      return folderId;
    } catch (e) {
      state = state.copyWith(isCreating: false, error: e.toString());
      if (kDebugMode) debugPrint('Error creating folder: $e');
      return null;
    }
  }

  /// Update an existing folder
  Future<bool> updateFolder({
    required String id,
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) async {
    try {
      // Guard against null coordinator (unauthenticated)
      if (_syncCoordinator == null) return false;

      state = state.copyWith(isUpdating: true);

      // Use sync coordinator for update with audit and conflict resolution
      final success = await _syncCoordinator.updateFolder(
        id: id,
        name: name,
        parentId: parentId,
        color: color,
        icon: icon,
        description: description,
      );

      state = state.copyWith(isUpdating: false);
      return success;
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
      if (kDebugMode) debugPrint('Error updating folder: $e');
      return false;
    }
  }

  /// Delete a folder
  Future<bool> deleteFolder(String folderId) async {
    try {
      // Guard against null coordinator (unauthenticated)
      if (_syncCoordinator == null) return false;

      state = state.copyWith(isDeleting: true);

      // Use sync coordinator for deletion with audit
      final success = await _syncCoordinator.deleteFolder(folderId);

      state = state.copyWith(isDeleting: false);
      return success;
    } catch (e) {
      state = state.copyWith(isDeleting: false, error: e.toString());
      if (kDebugMode) debugPrint('Error deleting folder: $e');
      return false;
    }
  }

  /// Move folder to new parent
  Future<bool> moveFolder(String folderId, String? newParentId) async {
    try {
      // Guard against null repository (unauthenticated)
      if (_repository == null) return false;

      state = state.copyWith(isUpdating: true);

      // moveFolder expects positional parameters, not named
      await _repository.moveFolder(folderId, newParentId);

      state = state.copyWith(isUpdating: false);
      return true;
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
      if (kDebugMode) debugPrint('Error moving folder: $e');
      return false;
    }
  }

  /// Refresh folders by triggering a reload
  Future<void> refresh() async {
    // This notifier handles operations, so refreshing means clearing error state
    // The actual folder list is managed by FolderHierarchyNotifier
    clearError();
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith();
  }
}

/// State for note-folder relationships
class NoteFolderState {
  const NoteFolderState({
    required this.noteFolders,
    this.isLoading = false,
    this.error,
  });

  final Map<String, String> noteFolders; // noteId -> folderId
  final bool isLoading;
  final String? error;

  NoteFolderState copyWith({
    Map<String, String>? noteFolders,
    bool? isLoading,
    String? error,
  }) {
    return NoteFolderState(
      noteFolders: noteFolders ?? this.noteFolders,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Get folder ID for a note
  String? getFolderForNote(String noteId) => noteFolders[noteId];

  /// Get notes in a specific folder
  List<String> getNotesInFolder(String folderId) {
    return noteFolders.entries
        .where((entry) => entry.value == folderId)
        .map((entry) => entry.key)
        .toList();
  }
}

/// Notifier for note-folder relationships
class NoteFolderNotifier extends StateNotifier<NoteFolderState> {
  NoteFolderNotifier(
    INotesRepository? notesRepository,
    IFolderRepository? folderRepository,
  ) : _notesRepository = notesRepository,
      _folderRepository = folderRepository,
      super(const NoteFolderState(noteFolders: {})) {
    _loadRelationships();
  }

  /// PRODUCTION FIX: Empty constructor for unauthenticated state
  factory NoteFolderNotifier.empty() {
    return _EmptyNoteFolderNotifier();
  }

  final INotesRepository? _notesRepository;
  final IFolderRepository? _folderRepository;

  Future<void> _loadRelationships() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final notesRepository = _notesRepository;
      if (notesRepository == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final notes = await notesRepository.localNotes();
      if (!mounted) return;
      final relationships = <String, String>{};
      for (final note in notes) {
        final folderId = note.folderId;
        if (folderId != null && folderId.isNotEmpty) {
          relationships[note.id] = folderId;
        }
      }

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        noteFolders: relationships,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      if (kDebugMode) debugPrint('Error loading note-folder relationships: $e');
    }
  }

  /// Add note to folder
  Future<bool> addNoteToFolder(String noteId, String folderId) async {
    // PRODUCTION FIX: Guard against null repository
    if (_notesRepository == null) return false;

    try {
      // Update note's folder via notes repository
      await _notesRepository.updateLocalNote(
        noteId,
        folderId: folderId,
        updateFolder: true,
      );

      final updatedRelationships = Map<String, String>.from(state.noteFolders)
        ..[noteId] = folderId;

      state = state.copyWith(noteFolders: updatedRelationships);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      if (kDebugMode) debugPrint('Error adding note to folder: $e');
      return false;
    }
  }

  /// Remove note from folder
  Future<bool> removeNoteFromFolder(String noteId) async {
    // PRODUCTION FIX: Guard against null repository
    if (_notesRepository == null) return false;

    try {
      // Set note's folder to null via notes repository
      await _notesRepository.updateLocalNote(
        noteId,
        folderId: null,
        updateFolder: true,
      );

      final updatedRelationships = Map<String, String>.from(state.noteFolders)
        ..remove(noteId);

      state = state.copyWith(noteFolders: updatedRelationships);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      if (kDebugMode) debugPrint('Error removing note from folder: $e');
      return false;
    }
  }

  /// Move note to different folder
  Future<bool> moveNoteToFolder(String noteId, String folderId) async {
    return addNoteToFolder(noteId, folderId);
  }

  /// Get folder for note (async version that checks repository)
  Future<domain.Folder?> getFolderForNote(String noteId) async {
    // PRODUCTION FIX: Guard against null repository
    if (_folderRepository == null) return null;

    try {
      // Use repository's optimized single-query method
      return await _folderRepository.getFolderForNote(noteId);
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting folder for note: $e');
      return null;
    }
  }

  /// Update relationship in state (called from other parts of app)
  void updateNoteFolder(String noteId, String? folderId) {
    final updatedRelationships = Map<String, String>.from(state.noteFolders);
    if (folderId != null) {
      updatedRelationships[noteId] = folderId;
    } else {
      updatedRelationships.remove(noteId);
    }
    state = state.copyWith(noteFolders: updatedRelationships);
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith();
  }
}

/// Notifier for current folder selection
class CurrentFolderNotifier extends StateNotifier<domain.Folder?> {
  CurrentFolderNotifier() : super(null);

  void setCurrentFolder(domain.Folder? folder) {
    state = folder;
  }

  void clearCurrentFolder() {
    state = null;
  }
}

/// PRODUCTION FIX: Empty notifier for unauthenticated state (Folder CRUD)
class _EmptyFolderNotifier extends FolderNotifier {
  _EmptyFolderNotifier() : super(null, null);

  @override
  Future<String?> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) async {
    return null; // No-op when not authenticated
  }

  @override
  Future<bool> updateFolder({
    required String id,
    required String name,
    String? parentId,
    String? color,
    String? icon,
    String? description,
    int? sortOrder,
  }) async {
    return false; // No-op when not authenticated
  }

  @override
  Future<bool> deleteFolder(String folderId) async {
    return false; // No-op when not authenticated
  }

  @override
  Future<bool> moveFolder(String folderId, String? newParentId) async {
    return false; // No-op when not authenticated
  }
}

/// PRODUCTION FIX: Empty notifier for unauthenticated state (Folder Hierarchy)
class _EmptyFolderHierarchyNotifier extends FolderHierarchyNotifier {
  _EmptyFolderHierarchyNotifier() : super(null);

  @override
  Future<void> loadFolders() async {
    // No-op when not authenticated
  }

  @override
  Future<void> refresh() async {
    // No-op when not authenticated
  }
}

/// PRODUCTION FIX: Empty notifier for unauthenticated state
class _EmptyNoteFolderNotifier extends NoteFolderNotifier {
  _EmptyNoteFolderNotifier() : super(null, null);

  @override
  Future<void> _loadRelationships() async {
    // No-op when not authenticated
  }

  @override
  Future<bool> addNoteToFolder(String noteId, String folderId) async {
    return false; // No-op when not authenticated
  }

  @override
  Future<bool> removeNoteFromFolder(String noteId) async {
    return false; // No-op when not authenticated
  }

  @override
  Future<domain.Folder?> getFolderForNote(String noteId) async {
    return null; // No-op when not authenticated
  }
}
