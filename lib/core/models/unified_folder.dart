// Unified Folder type that bridges LocalFolder and domain.Folder
// This removes the need for conditional logic based on migration status

import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:duru_notes/data/local/app_db.dart';

abstract class UnifiedFolder {
  String get id;
  String get name;
  String? get parentId;
  String? get icon;
  String? get color;
  DateTime get createdAt;
  DateTime get updatedAt;
  bool get deleted;
  String get userId;
  int get version;
  int get noteCount;
  List<String> get noteIds;
  Map<String, dynamic>? get metadata;

  // Factory constructors to create from different sources
  factory UnifiedFolder.fromLocal(LocalFolder folder) = _UnifiedFolderFromLocal;
  factory UnifiedFolder.fromDomain(domain.Folder folder) = _UnifiedFolderFromDomain;
  
  // Smart factory that detects type
  factory UnifiedFolder.from(dynamic folder) {
    if (folder is LocalFolder) return UnifiedFolder.fromLocal(folder);
    if (folder is domain.Folder) return UnifiedFolder.fromDomain(folder);
    if (folder is UnifiedFolder) return folder;
    throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
  }

  // Convert to the required format
  LocalFolder toLocal();
  domain.Folder toDomain();

  // Helper methods
  bool get isRoot => parentId == null;
  bool get isEmpty => noteCount == 0;
}

class _UnifiedFolderFromLocal implements UnifiedFolder {
  final LocalFolder _folder;

  _UnifiedFolderFromLocal(this._folder);

  @override
  String get id => _folder.id;

  @override
  String get name => _folder.name;

  @override
  String? get parentId => _folder.parentId;

  @override
  String? get icon => _folder.icon;

  @override
  String? get color => _folder.color;

  @override
  DateTime get createdAt => _folder.createdAt;

  @override
  DateTime get updatedAt => _folder.updatedAt;

  @override
  bool get deleted => _folder.deleted;

  @override
  String get userId => ''; // LocalFolder doesn't have userId

  @override
  int get version => 1; // LocalFolder doesn't have version

  @override
  int get noteCount => 0; // Would need to query separately

  @override
  List<String> get noteIds => [];

  @override
  Map<String, dynamic>? get metadata => null; // LocalFolder doesn't have metadata

  @override
  bool get isRoot => parentId == null;

  @override
  bool get isEmpty => noteCount == 0;

  @override
  LocalFolder toLocal() => _folder;

  @override
  domain.Folder toDomain() => domain.Folder(
    id: _folder.id,
    name: _folder.name,
    parentId: _folder.parentId,
    icon: _folder.icon,
    color: _folder.color,
    description: _folder.description,
    sortOrder: _folder.sortOrder,
    createdAt: _folder.createdAt,
    updatedAt: _folder.updatedAt,
    userId: '',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UnifiedFolderFromLocal && _folder.id == other._folder.id;

  @override
  int get hashCode => _folder.id.hashCode;
}

class _UnifiedFolderFromDomain implements UnifiedFolder {
  final domain.Folder _folder;

  _UnifiedFolderFromDomain(this._folder);

  @override
  String get id => _folder.id;

  @override
  String get name => _folder.name;

  @override
  String? get parentId => _folder.parentId;

  @override
  String? get icon => _folder.icon;

  @override
  String? get color => _folder.color;

  @override
  DateTime get createdAt => _folder.createdAt;

  @override
  DateTime get updatedAt => _folder.updatedAt;

  @override
  bool get deleted => false; // domain.Folder doesn't have deleted flag

  @override
  String get userId => _folder.userId;

  @override
  int get version => 1; // domain.Folder doesn't have version

  @override
  int get noteCount => 0; // domain.Folder doesn't have noteIds

  @override
  List<String> get noteIds => []; // domain.Folder doesn't have noteIds

  @override
  Map<String, dynamic>? get metadata => null;

  @override
  bool get isRoot => parentId == null;

  @override
  bool get isEmpty => noteCount == 0;

  @override
  LocalFolder toLocal() => LocalFolder(
    id: _folder.id,
    userId: _folder.userId,
    name: _folder.name,
    parentId: _folder.parentId,
    path: '/${_folder.name}', // Generate path from name
    sortOrder: _folder.sortOrder,
    icon: _folder.icon,
    color: _folder.color,
    description: _folder.description ?? '',
    createdAt: _folder.createdAt,
    updatedAt: _folder.updatedAt,
    deleted: false,
  );

  @override
  domain.Folder toDomain() => _folder;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UnifiedFolderFromDomain && _folder.id == other._folder.id;

  @override
  int get hashCode => _folder.id.hashCode;
}

// Unified folder list that works with a single type
class UnifiedFolderList {
  final List<UnifiedFolder> folders;
  final bool hasMore;
  final int currentPage;
  final int totalCount;

  UnifiedFolderList({
    required this.folders,
    this.hasMore = false,
    this.currentPage = 0,
    this.totalCount = 0,
  });

  UnifiedFolderList copyWith({
    List<UnifiedFolder>? folders,
    bool? hasMore,
    int? currentPage,
    int? totalCount,
  }) {
    return UnifiedFolderList(
      folders: folders ?? this.folders,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  // Helper to get folders as a tree structure
  List<UnifiedFolder> get rootFolders => folders.where((f) => f.isRoot).toList();
  
  List<UnifiedFolder> getChildren(String parentId) => 
      folders.where((f) => f.parentId == parentId).toList();
}