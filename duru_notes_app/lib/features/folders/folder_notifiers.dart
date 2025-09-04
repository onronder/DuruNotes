import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_db.dart';
import '../../repository/notes_repository.dart';

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

  final LocalFolder folder;
  final int level;
  final bool isExpanded;
  final bool hasChildren;
  final int noteCount;
  final List<FolderTreeNode> children;

  FolderTreeNode copyWith({
    LocalFolder? folder,
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
  });

  final List<LocalFolder> folders;
  final Set<String> expandedFolders;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  FolderHierarchyState copyWith({
    List<LocalFolder>? folders,
    Set<String>? expandedFolders,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return FolderHierarchyState(
      folders: folders ?? this.folders,
      expandedFolders: expandedFolders ?? this.expandedFolders,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Get root folders (no parent)
  List<LocalFolder> get rootFolders {
    final filtered = searchQuery.isEmpty
        ? folders.where((f) => f.parentId == null && !f.deleted).toList()
        : folders.where((f) => 
            !f.deleted && 
            f.name.toLowerCase().contains(searchQuery.toLowerCase())
          ).toList();
    
    filtered.sort((a, b) {
      final sortCompare = a.sortOrder.compareTo(b.sortOrder);
      return sortCompare != 0 ? sortCompare : a.name.compareTo(b.name);
    });
    return filtered;
  }

  /// Get child folders for a parent
  List<LocalFolder> getChildFolders(String parentId) {
    final children = folders
        .where((f) => f.parentId == parentId && !f.deleted)
        .toList();
    
    children.sort((a, b) {
      final sortCompare = a.sortOrder.compareTo(b.sortOrder);
      return sortCompare != 0 ? sortCompare : a.name.compareTo(b.name);
    });
    return children;
  }

  /// Check if folder is expanded
  bool isExpanded(String folderId) => expandedFolders.contains(folderId);

  /// Get folder by ID
  LocalFolder? getFolderById(String id) {
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
        noteCount: 0, // TODO: Get actual note count
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
        noteCount: 0, // TODO: Get actual note count
        children: hasChildren && isExpanded(folder.id)
            ? _buildChildNodes(folder.id, level + 1)
            : [],
      );
    }).toList();
  }
}

/// Notifier for managing folder hierarchy and expansion states
class FolderHierarchyNotifier extends StateNotifier<FolderHierarchyState> {
  FolderHierarchyNotifier(this._repository) 
      : super(const FolderHierarchyState(folders: [], expandedFolders: {})) {
    _init();
  }

  final NotesRepository _repository;
  Timer? _debounceTimer;

  Future<void> _init() async {
    await loadFolders();
  }

  /// Load all folders from repository
  Future<void> loadFolders() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final folders = await _repository.listFolders();
      state = state.copyWith(
        folders: folders,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      if (kDebugMode) print('Error loading folders: $e');
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
  }

  /// Collapse all folders
  void collapseAll() {
    state = state.copyWith(expandedFolders: <String>{});
  }

  /// Expand all folders
  void expandAll() {
    final allFolderIds = state.folders.map((f) => f.id).toSet();
    state = state.copyWith(expandedFolders: allFolderIds);
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
    
    void buildNodes(List<LocalFolder> folders, int level) {
      for (final folder in folders) {
        final hasChildren = state.getChildFolders(folder.id).isNotEmpty;
        final isExpanded = state.isExpanded(folder.id);
        
        nodes.add(FolderTreeNode(
          folder: folder,
          level: level,
          isExpanded: isExpanded,
          hasChildren: hasChildren,
          noteCount: 0, // TODO: Get actual note count
        ));
        
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
  void addFolder(LocalFolder folder) {
    final folders = List<LocalFolder>.from(state.folders)..add(folder);
    state = state.copyWith(folders: folders);
    
    // Auto-expand parent if it exists
    if (folder.parentId != null) {
      expandPath(folder.parentId!);
    }
  }

  /// Update folder in state (called after edit)
  void updateFolder(LocalFolder updatedFolder) {
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
    state = state.copyWith(
      folders: folders,
      expandedFolders: expandedFolders,
    );
  }

  /// Alias for loadFolders - for backward compatibility
  Future<void> refresh() async {
    return await loadFolders();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
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
  FolderNotifier(this._repository) : super(const FolderOperationState());

  final NotesRepository _repository;

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
      state = state.copyWith(isCreating: true, error: null);
      
      final folderId = await _repository.createOrUpdateFolder(
        name: name,
        parentId: parentId,
        color: color,
        icon: icon,
        description: description,
        sortOrder: sortOrder,
      );
      
      state = state.copyWith(isCreating: false);
      return folderId;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: e.toString(),
      );
      if (kDebugMode) print('Error creating folder: $e');
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
      state = state.copyWith(isUpdating: true, error: null);
      
      await _repository.createOrUpdateFolder(
        id: id,
        name: name,
        parentId: parentId,
        color: color,
        icon: icon,
        description: description,
        sortOrder: sortOrder,
      );
      
      state = state.copyWith(isUpdating: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isUpdating: false,
        error: e.toString(),
      );
      if (kDebugMode) print('Error updating folder: $e');
      return false;
    }
  }

  /// Delete a folder
  Future<bool> deleteFolder(String folderId) async {
    try {
      state = state.copyWith(isDeleting: true, error: null);
      
      await _repository.deleteFolder(folderId);
      
      state = state.copyWith(isDeleting: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isDeleting: false,
        error: e.toString(),
      );
      if (kDebugMode) print('Error deleting folder: $e');
      return false;
    }
  }

  /// Move folder to new parent
  Future<bool> moveFolder(String folderId, String? newParentId) async {
    try {
      state = state.copyWith(isUpdating: true, error: null);
      
      await _repository.moveFolder(folderId, newParentId);
      
      state = state.copyWith(isUpdating: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isUpdating: false,
        error: e.toString(),
      );
      if (kDebugMode) print('Error moving folder: $e');
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
    state = state.copyWith(error: null);
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
  NoteFolderNotifier(this._repository) 
      : super(const NoteFolderState(noteFolders: {})) {
    _loadRelationships();
  }

  final NotesRepository _repository;

  Future<void> _loadRelationships() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      // This would need to be implemented in the repository
      // For now, we'll manage relationships on-demand
      
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      if (kDebugMode) print('Error loading note-folder relationships: $e');
    }
  }

  /// Add note to folder
  Future<bool> addNoteToFolder(String noteId, String folderId) async {
    try {
      await _repository.addNoteToFolder(noteId, folderId);
      
      final updatedRelationships = Map<String, String>.from(state.noteFolders)
        ..[noteId] = folderId;
      
      state = state.copyWith(
        noteFolders: updatedRelationships,
        error: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      if (kDebugMode) print('Error adding note to folder: $e');
      return false;
    }
  }

  /// Remove note from folder
  Future<bool> removeNoteFromFolder(String noteId) async {
    try {
      await _repository.removeNoteFromFolder(noteId);
      
      final updatedRelationships = Map<String, String>.from(state.noteFolders)
        ..remove(noteId);
      
      state = state.copyWith(
        noteFolders: updatedRelationships,
        error: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      if (kDebugMode) print('Error removing note from folder: $e');
      return false;
    }
  }

  /// Move note to different folder
  Future<bool> moveNoteToFolder(String noteId, String folderId) async {
    return await addNoteToFolder(noteId, folderId);
  }

  /// Get folder for note (async version that checks repository)
  Future<LocalFolder?> getFolderForNote(String noteId) async {
    try {
      return await _repository.getFolderForNote(noteId);
    } catch (e) {
      if (kDebugMode) print('Error getting folder for note: $e');
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
    state = state.copyWith(error: null);
  }
}

/// Notifier for current folder selection
class CurrentFolderNotifier extends StateNotifier<LocalFolder?> {
  CurrentFolderNotifier() : super(null);

  void setCurrentFolder(LocalFolder? folder) {
    state = folder;
  }

  void clearCurrentFolder() {
    state = null;
  }
}