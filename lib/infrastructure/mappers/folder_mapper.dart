import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps between domain Folder entity and infrastructure LocalFolder
class FolderMapper {
  /// Convert infrastructure LocalFolder to domain Folder
  static domain.Folder toDomain(LocalFolder localFolder) {
    // LocalFolder doesn't have userId field yet - use current user from Supabase
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

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
      userId: userId,
    );
  }

  /// Convert domain Folder to infrastructure LocalFolder
  static LocalFolder toInfrastructure(domain.Folder folder) {
    // LocalFolder doesn't have userId field - it's omitted from local storage
    return LocalFolder(
      id: folder.id,
      name: folder.name,
      parentId: folder.parentId,
      path: '/${folder.name}', // Path will be computed properly by triggers
      color: folder.color ?? '#048ABF',
      icon: folder.icon ?? 'folder',
      description: folder.description ?? '',
      sortOrder: folder.sortOrder,
      createdAt: folder.createdAt,
      updatedAt: folder.updatedAt,
      deleted: false,
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