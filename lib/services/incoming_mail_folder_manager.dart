import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/domain/repositories/i_folder_repository.dart';
import 'package:duru_notes/domain/entities/folder.dart' as domain;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Manager for ensuring an "Incoming Mail" folder exists and routing notes to it
class IncomingMailFolderManager {
  IncomingMailFolderManager({
    required IFolderRepository folderRepository,
    required String userId,
  }) : _folderRepository = folderRepository,
       _userId = userId;

  final IFolderRepository _folderRepository;
  final String _userId;
  final AppLogger _logger = LoggerFactory.instance;
  final _uuid = const Uuid();

  static const String _folderName = 'Incoming Mail';
  static const String _folderIdKeyPrefix = 'incoming_mail_folder_';
  static const String _folderIcon = '📧';
  static const String _folderColor = '#2196F3'; // Material blue
  static const String _pendingAssignmentsKeyPrefix = 'incoming_mail_pending_';

  /// Get the "Incoming Mail" folder ID if it exists (does NOT create folder)
  /// Returns null if the folder doesn't exist
  /// Use this for checking folder counts, resolving folder names, etc.
  Future<String?> getIncomingMailFolderId() async {
    try {
      // Check cache first
      final cachedId = await _getCachedFolderId();
      if (cachedId != null) {
        // Verify the folder still exists and is not deleted
        final domainFolder = await _folderRepository.getFolder(cachedId);
        if (domainFolder != null) {
          return cachedId;
        }
        // Cached folder is invalid, clear cache
        _logger.debug(
          '[IncomingMailFolder] Cached folder invalid, clearing cache',
        );
        await _clearCachedFolderId();
      }

      // Search for existing folder - be more thorough
      final folders = await _folderRepository.listFolders();

      // Collect all matching folders (case-insensitive)
      final matchingFolders = <domain.Folder>[];

      for (final folder in folders) {
        // Check exact match (case-insensitive)
        if (folder.name.trim().toLowerCase() ==
            _folderName.trim().toLowerCase()) {
          matchingFolders.add(folder);
        } else {
          // Check normalized match (handle extra spaces)
          final normalizedFolderName = folder.name
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim()
              .toLowerCase();
          final normalizedTargetName = _folderName
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim()
              .toLowerCase();
          if (normalizedFolderName == normalizedTargetName) {
            matchingFolders.add(folder);
          }
        }
      }

      // If we found matching folders, use the oldest one as canonical
      if (matchingFolders.isNotEmpty) {
        // Sort by creation date to get the oldest
        matchingFolders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final canonicalFolder = matchingFolders.first;

        await _cacheFolderId(canonicalFolder.id);
        _logger.debug(
          '[IncomingMailFolder] Found existing folder: ${canonicalFolder.id}',
        );

        // If there are duplicates, merge them in background
        if (matchingFolders.length > 1) {
          _logger.info(
            '[IncomingMailFolder] Found ${matchingFolders.length} duplicate folders, will merge',
          );
          unawaited(
            _mergeDuplicateFolders(
              canonicalFolder,
              matchingFolders.skip(1).toList(),
            ),
          );
        }

        return canonicalFolder.id;
      }

      // Folder doesn't exist - DO NOT CREATE IT
      _logger.debug(
        '[IncomingMailFolder] Folder does not exist (not creating)',
      );
      return null;
    } catch (e, stackTrace) {
      _logger.error(
        '[IncomingMailFolder] Error getting folder ID',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Ensure the "Incoming Mail" folder exists and return its ID
  /// Creates the folder if it doesn't exist
  /// ONLY use this when actually processing incoming emails!
  Future<String> ensureIncomingMailFolderId() async {
    try {
      // First try to get existing folder
      final existingId = await getIncomingMailFolderId();
      if (existingId != null) {
        return existingId;
      }

      // Create new folder only if it doesn't exist
      _logger.info(
        '[IncomingMailFolder] Creating Incoming Mail folder for email processing',
      );
      final newFolderId = _uuid.v4();
      await _folderRepository.createOrUpdateFolder(
        id: newFolderId,
        name: _folderName,
        color: _folderColor,
        icon: _folderIcon,
        description: 'Automatically organized notes from incoming emails',
      );

      await _cacheFolderId(newFolderId);
      _logger.info('[IncomingMailFolder] Created new folder: $newFolderId');
      return newFolderId;
    } catch (e, stackTrace) {
      _logger.error(
        '[IncomingMailFolder] Error ensuring folder exists',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Add a note to the Incoming Mail folder
  Future<void> addNoteToIncomingMail(String noteId) async {
    try {
      final folderId = await ensureIncomingMailFolderId();
      await _folderRepository.addNoteToFolder(noteId, folderId);
      await _removePendingAssignment(noteId);
      _logger.debug(
        '[IncomingMailFolder] Added note $noteId to folder $folderId',
      );
    } catch (e) {
      _logger.debug('[IncomingMailFolder] Error adding note to folder: $e');
      unawaited(_storePendingAssignment(noteId));
    }
  }

  /// Retry assigning any notes that previously failed to reach Incoming Mail
  Future<void> processPendingAssignments() async {
    final pending = await _loadPendingAssignments();
    if (pending.isEmpty) {
      return;
    }

    final remaining = <String>[];
    for (final noteId in pending) {
      try {
        await addNoteToIncomingMail(noteId);
      } catch (_) {
        // addNoteToIncomingMail already queues the note on failure
        remaining.add(noteId);
      }
    }

    await _savePendingAssignments(remaining);
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
      _logger.debug('[IncomingMailFolder] Error reading cache: $e');
      return null;
    }
  }

  Future<void> _cacheFolderId(String folderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_folderIdKeyPrefix$_userId', folderId);
    } catch (e) {
      _logger.debug('[IncomingMailFolder] Error caching folder ID: $e');
    }
  }

  Future<void> _clearCachedFolderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_folderIdKeyPrefix$_userId');
      _logger.debug('[IncomingMailFolder] Cache cleared for user: $_userId');
    } catch (e) {
      _logger.debug('[IncomingMailFolder] Error clearing cache: $e');
    }
  }

  Future<List<String>> _loadPendingAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('$_pendingAssignmentsKeyPrefix$_userId') ??
          <String>[];
    } catch (e) {
      _logger.debug(
        '[IncomingMailFolder] Error loading pending assignments: $e',
      );
      return <String>[];
    }
  }

  Future<void> _savePendingAssignments(List<String> noteIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        '$_pendingAssignmentsKeyPrefix$_userId',
        noteIds,
      );
    } catch (e) {
      _logger.debug(
        '[IncomingMailFolder] Error saving pending assignments: $e',
      );
    }
  }

  Future<void> _storePendingAssignment(String noteId) async {
    final pending = await _loadPendingAssignments();
    if (!pending.contains(noteId)) {
      pending.add(noteId);
      await _savePendingAssignments(pending);
    }
  }

  Future<void> _removePendingAssignment(String noteId) async {
    final pending = await _loadPendingAssignments();
    if (pending.remove(noteId)) {
      await _savePendingAssignments(pending);
    }
  }

  /// Merge duplicate folders into the canonical folder
  Future<void> _mergeDuplicateFolders(
    domain.Folder canonicalFolder,
    List<domain.Folder> duplicates,
  ) async {
    for (final duplicate in duplicates) {
      try {
        // Get all notes in the duplicate folder
        final domainNotesInDuplicate = await _folderRepository.getNotesInFolder(
          duplicate.id,
        );

        // Move each note to the canonical folder
        for (final domainNote in domainNotesInDuplicate) {
          try {
            // Remove from duplicate folder
            await _folderRepository.removeNoteFromFolder(domainNote.id);
            // Add to canonical folder
            await _folderRepository.addNoteToFolder(
              domainNote.id,
              canonicalFolder.id,
            );
            _logger.debug(
              '[IncomingMailFolder] Moved note ${domainNote.id} from duplicate ${duplicate.id} to canonical ${canonicalFolder.id}',
            );
          } catch (e) {
            _logger.debug(
              '[IncomingMailFolder] Error moving note ${domainNote.id}: $e',
            );
          }
        }

        // Soft-delete the duplicate folder
        await _folderRepository.deleteFolder(duplicate.id);
        _logger.debug(
          '[IncomingMailFolder] Soft-deleted duplicate folder: ${duplicate.id}',
        );
      } catch (e) {
        _logger.debug(
          '[IncomingMailFolder] Error merging duplicate folder ${duplicate.id}: $e',
        );
      }
    }
  }
}
