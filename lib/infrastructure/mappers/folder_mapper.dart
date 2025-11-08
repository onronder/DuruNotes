import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps between domain Folder entity and infrastructure LocalFolder
class FolderMapper {
  // Cache userId to avoid repeated auth calls (500μs overhead per call)
  static String? _cachedUserId;
  static DateTime? _cacheTime;
  static const _cacheValidityMinutes = 5;

  /// Get current user ID with caching
  static String _getCurrentUserId() {
    // Return cached value if still valid
    if (_cachedUserId != null && _cacheTime != null) {
      final age = DateTime.now().difference(_cacheTime!);
      if (age.inMinutes < _cacheValidityMinutes) {
        return _cachedUserId!;
      }
    }

    // Cache expired or not set - refresh
    _cachedUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _cacheTime = DateTime.now();
    return _cachedUserId!;
  }

  /// Convert infrastructure LocalFolder to domain Folder
  static domain.Folder toDomain(LocalFolder localFolder) {
    // Use cached userId to avoid 500μs auth call overhead
    final userId = _getCurrentUserId();

    return domain.Folder(
      id: localFolder.id,
      name: localFolder.name,
      parentId: localFolder.parentId,
      color: localFolder.color,
      icon: localFolder.icon,
      description: localFolder.description,
      sortOrder: localFolder.sortOrder,
      createdAt: localFolder.createdAt,
      updatedAt: localFolder.updatedAt,
      deletedAt: localFolder.deletedAt,
      scheduledPurgeAt: localFolder.scheduledPurgeAt,
      userId: userId,
    );
  }

  /// Convert domain Folder to infrastructure LocalFolder
  static LocalFolder toInfrastructure(domain.Folder folder) {
    return LocalFolder(
      id: folder.id,
      userId: folder.userId,
      name: folder.name,
      parentId: folder.parentId,
      path: '/${folder.name}', // Path will be computed properly by triggers
      color: folder.color ?? '#048ABF',
      icon: folder.icon ?? 'folder',
      description: folder.description ?? '',
      sortOrder: folder.sortOrder,
      createdAt: folder.createdAt,
      updatedAt: folder.updatedAt,
      deleted: folder.deletedAt != null,
      deletedAt: folder.deletedAt,
      scheduledPurgeAt: folder.scheduledPurgeAt,
    );
  }

  /// Convert LocalFolder list to domain Folder list
  static List<domain.Folder> toDomainList(List<LocalFolder> localFolders) {
    return localFolders.map((folder) => toDomain(folder)).toList();
  }

  /// Convert domain Folder list to LocalFolder list
  static List<LocalFolder> toInfrastructureList(List<domain.Folder> folders) {
    return folders.map((folder) => toInfrastructure(folder)).toList();
  }
}
