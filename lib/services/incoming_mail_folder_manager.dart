import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:duru_notes/repository/notes_repository.dart';

/// Manager for ensuring an "Incoming Mail" folder exists and routing notes to it
class IncomingMailFolderManager {
  IncomingMailFolderManager({
    required NotesRepository repository,
    required String userId,
  }) : _repository = repository,
       _userId = userId;
  
  final NotesRepository _repository;
  final String _userId;
  final _uuid = const Uuid();
  
  static const String _folderName = 'Incoming Mail';
  static const String _folderIdKeyPrefix = 'incoming_mail_folder_';
  static const String _folderIcon = '📧';
  static const String _folderColor = '#2196F3'; // Material blue
  
  /// Ensure the "Incoming Mail" folder exists and return its ID
  Future<String> ensureIncomingMailFolderId() async {
    try {
      // Check cache first
      final cachedId = await _getCachedFolderId();
      if (cachedId != null) {
        // Verify the folder still exists and is not deleted
        final folder = await _repository.getFolder(cachedId);
        if (folder != null && !folder.deleted) {
          // Don't log every cache hit - this is normal operation
          return cachedId;
        }
        // Cached folder is invalid, clear cache
        debugPrint('[IncomingMailFolder] Cached folder invalid, clearing cache');
        await _clearCachedFolderId();
      }
      
      // Search for existing folder - be more thorough
      final folders = await _repository.listFolders();
      
      // Collect all matching folders (case-insensitive)
      final matchingFolders = <LocalFolder>[];
      
      for (final folder in folders) {
        if (!folder.deleted) {
          // Check exact match (case-insensitive)
          if (folder.name.trim().toLowerCase() == _folderName.trim().toLowerCase()) {
            matchingFolders.add(folder);
          } else {
            // Check normalized match (handle extra spaces)
            final normalizedFolderName = folder.name.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
            final normalizedTargetName = _folderName.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
            if (normalizedFolderName == normalizedTargetName) {
              matchingFolders.add(folder);
            }
          }
        }
      }
      
      // If we found matching folders, use the oldest one as canonical
      if (matchingFolders.isNotEmpty) {
        // Sort by creation date to get the oldest
        matchingFolders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final canonicalFolder = matchingFolders.first;
        
        await _cacheFolderId(canonicalFolder.id);
        debugPrint('[IncomingMailFolder] Found existing folder: ${canonicalFolder.id} - ${canonicalFolder.name}');
        
        // If there are duplicates, merge them
        if (matchingFolders.length > 1) {
          debugPrint('[IncomingMailFolder] Found ${matchingFolders.length} duplicate folders, merging...');
          await _mergeDuplicateFolders(canonicalFolder, matchingFolders.skip(1).toList());
        }
        
        return canonicalFolder.id;
      }
      
      // Create new folder if not found
      final newFolderId = _uuid.v4();
      await _repository.createOrUpdateFolder(
        id: newFolderId,
        name: _folderName,
        parentId: null, // Root level folder
        color: _folderColor,
        icon: _folderIcon,
        description: 'Automatically organized notes from incoming emails',
      );
      
      await _cacheFolderId(newFolderId);
      debugPrint('[IncomingMailFolder] Created new folder: $newFolderId');
      return newFolderId;
    } catch (e) {
      debugPrint('[IncomingMailFolder] Error ensuring folder: $e');
      // Return null on error and let the note be created without a folder
      rethrow;
    }
  }
  
  /// Add a note to the Incoming Mail folder
  Future<void> addNoteToIncomingMail(String noteId) async {
    try {
      final folderId = await ensureIncomingMailFolderId();
      await _repository.addNoteToFolder(noteId, folderId);
      debugPrint('[IncomingMailFolder] Added note $noteId to folder $folderId');
    } catch (e) {
      debugPrint('[IncomingMailFolder] Error adding note to folder: $e');
      // Don't fail the entire operation if folder assignment fails
    }
  }
  
  /// Clear the cached folder ID (useful on logout or folder deletion)
  Future<void> clearCache() async {
    await _clearCachedFolderId();
  }
  
  // Private helper methods
  
  Future<String?> _getCachedFolderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_folderIdKeyPrefix$_userId');
    } catch (e) {
      debugPrint('[IncomingMailFolder] Error reading cache: $e');
      return null;
    }
  }
  
  Future<void> _cacheFolderId(String folderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_folderIdKeyPrefix$_userId', folderId);
    } catch (e) {
      debugPrint('[IncomingMailFolder] Error caching folder ID: $e');
    }
  }
  
  Future<void> _clearCachedFolderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_folderIdKeyPrefix$_userId');
      debugPrint('[IncomingMailFolder] Cache cleared for user: $_userId');
    } catch (e) {
      debugPrint('[IncomingMailFolder] Error clearing cache: $e');
    }
  }
  
  /// Merge duplicate folders into the canonical folder
  Future<void> _mergeDuplicateFolders(LocalFolder canonicalFolder, List<LocalFolder> duplicates) async {
    for (final duplicate in duplicates) {
      try {
        // Get all notes in the duplicate folder
        final notesInDuplicate = await _repository.getNotesInFolder(duplicate.id);
        
        // Move each note to the canonical folder
        for (final note in notesInDuplicate) {
          try {
            // Remove from duplicate folder
            await _repository.removeNoteFromFolder(note.id);
            // Add to canonical folder
            await _repository.addNoteToFolder(note.id, canonicalFolder.id);
            debugPrint('[IncomingMailFolder] Moved note ${note.id} from duplicate ${duplicate.id} to canonical ${canonicalFolder.id}');
          } catch (e) {
            debugPrint('[IncomingMailFolder] Error moving note ${note.id}: $e');
          }
        }
        
        // Soft-delete the duplicate folder
        await _repository.deleteFolder(duplicate.id);
        debugPrint('[IncomingMailFolder] Soft-deleted duplicate folder: ${duplicate.id}');
      } catch (e) {
        debugPrint('[IncomingMailFolder] Error merging duplicate folder ${duplicate.id}: $e');
      }
    }
  }
}
