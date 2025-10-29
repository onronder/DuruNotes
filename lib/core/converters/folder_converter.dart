import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;

/// Converter utility for converting between LocalFolder and domain.Folder
class FolderConverter {
  /// Convert LocalFolder (infrastructure) to domain.Folder
  static domain.Folder fromLocal(LocalFolder local, {String? userId}) {
    return domain.Folder(
      id: local.id,
      name: local.name,
      parentId: local.parentId,
      color: local.color,
      icon: local.icon,
      description: local.description,
      sortOrder: local.sortOrder,
      createdAt: local.createdAt,
      updatedAt: local.updatedAt,
      userId: userId ?? '', // LocalFolder doesn't have userId
    );
  }

  /// Convert domain.Folder to LocalFolder
  static LocalFolder toLocal(domain.Folder folder) {
    return LocalFolder(
      id: folder.id,
      userId: folder.userId,
      name: folder.name,
      parentId: folder.parentId,
      path: folder.parentId != null ? '/${folder.parentId}/${folder.name}' : '/${folder.name}',
      color: folder.color,
      icon: folder.icon,
      description: folder.description ?? '',
      sortOrder: folder.sortOrder,
      createdAt: folder.createdAt,
      updatedAt: folder.updatedAt,
      deleted: false, // Domain folders don't have deleted field, assume not deleted
    );
  }

  /// Convert `List<LocalFolder>` to `List<domain.Folder>`
  static List<domain.Folder> fromLocalList(List<LocalFolder> localFolders, {String? userId}) {
    return localFolders.map((local) => fromLocal(local, userId: userId)).toList();
  }

  /// Convert `List<domain.Folder>` to `List<LocalFolder>`
  static List<LocalFolder> toLocalList(List<domain.Folder> domainFolders) {
    return domainFolders.map((folder) => toLocal(folder)).toList();
  }

  /// Smart conversion that handles both types
  static domain.Folder ensureDomainFolder(dynamic folder, {String? userId}) {
    if (folder is domain.Folder) {
      return folder;
    } else if (folder is LocalFolder) {
      return fromLocal(folder, userId: userId);
    } else {
      throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
    }
  }

  /// Smart conversion that handles both types to LocalFolder
  static LocalFolder ensureLocalFolder(dynamic folder) {
    if (folder is LocalFolder) {
      return folder;
    } else if (folder is domain.Folder) {
      return toLocal(folder);
    } else {
      throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
    }
  }

  /// Get ID from any folder type
  static String getFolderId(dynamic folder) {
    if (folder is domain.Folder) {
      return folder.id;
    } else if (folder is LocalFolder) {
      return folder.id;
    } else {
      throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
    }
  }

  /// Get name from any folder type
  static String getFolderName(dynamic folder) {
    if (folder is domain.Folder) {
      return folder.name;
    } else if (folder is LocalFolder) {
      return folder.name;
    } else {
      throw ArgumentError('Unknown folder type: ${folder.runtimeType}');
    }
  }
}