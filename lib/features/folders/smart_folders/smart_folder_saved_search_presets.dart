// lib/features/folders/smart_folders/smart_folder_saved_search_presets.dart
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/smart_folders/smart_folder_types.dart';
import 'package:duru_notes/search/saved_search_registry.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Extension to handle saved search presets as smart folders
class SmartFolderSavedSearchPresets {
  static const _uuid = Uuid();

  /// Convert a SavedSearchPreset to SmartFolderConfig
  static SmartFolderConfig _convertToSmartFolder(SavedSearchPreset preset) {
    // Use the centralized ID generation from SavedSearchRegistry
    final id = SavedSearchRegistry.keyToId(preset.key);
    
    // Determine tag value for rules
    final tagValue = preset.tag != null ? '#${preset.tag}' : null;
    
    // Determine color based on preset
    Color color;
    switch (preset.key) {
      case SavedSearchKey.attachments:
        color = Colors.orange;
        break;
      case SavedSearchKey.emailNotes:
        color = Colors.blue;
        break;
      case SavedSearchKey.webNotes:
        color = Colors.green;
        break;
      case SavedSearchKey.inbox:
        color = Colors.purple;
        break;
    }
    
    // Create rules only if we have a tag (inbox uses folder-based filtering)
    final rules = tagValue != null
        ? [
            SmartFolderRule(
              id: _uuid.v4(),
              field: RuleField.content,
              operator: RuleOperator.contains,
              value: tagValue,
            ),
          ]
        : <SmartFolderRule>[];
    
    return SmartFolderConfig(
      id: id,
      name: preset.label,
      type: SmartFolderType.custom,
      rules: rules,
      customIcon: preset.icon,
      customColor: color,
      maxResults: 200,
    );
  }

  /// Get predefined smart folders for saved searches
  static List<SmartFolderConfig> getSavedSearchPresets() {
    // Use SavedSearchRegistry as the single source of truth
    // Filter out inbox since it's folder-based, not rule-based
    return SavedSearchRegistry.presets
        .where((preset) => preset.key != SavedSearchKey.inbox)
        .map(_convertToSmartFolder)
        .toList();
  }

  /// Get smart folder by preset key
  static SmartFolderConfig? getSmartFolderByKey(SavedSearchKey key) {
    final preset = SavedSearchRegistry.presets
        .firstWhere((p) => p.key == key, orElse: () => throw StateError('Preset not found'));
    if (key == SavedSearchKey.inbox) {
      // Inbox is handled differently as it's folder-based
      return null;
    }
    return _convertToSmartFolder(preset);
  }

  /// Cached smart folders for performance
  static final attachmentsSmartFolder = getSmartFolderByKey(SavedSearchKey.attachments)!;
  static final emailNotesSmartFolder = getSmartFolderByKey(SavedSearchKey.emailNotes)!;
  static final webClipsSmartFolder = getSmartFolderByKey(SavedSearchKey.webNotes)!;

  /// Check if a note matches saved search criteria (with metadata support)
  /// This delegates to the centralized detection logic in AppDb
  static bool evaluateNoteForSavedSearch(LocalNote note, String presetId) {
    // Convert string ID to enum key using the bridging utility
    final key = SavedSearchRegistry.idToKey(presetId);
    if (key == null) return false;
    
    // Use centralized detection functions from AppDb to avoid duplication
    switch (key) {
      case SavedSearchKey.attachments:
        return AppDb.noteHasAttachments(note);

      case SavedSearchKey.emailNotes:
        return AppDb.noteIsFromEmail(note);

      case SavedSearchKey.webNotes:
        return AppDb.noteIsFromWeb(note);

      case SavedSearchKey.inbox:
        // Inbox is folder-based, not tag-based
        return false;
    }
  }
}

/// Enhanced SmartFolderEngine for saved searches
/// This extends the basic evaluation to support metadata-based rules
extension SavedSearchSmartFolderEngine on List<LocalNote> {
  /// Filter notes for a saved search smart folder
  List<LocalNote> filterForSavedSearch(String presetId) {
    return where(
      (note) => SmartFolderSavedSearchPresets.evaluateNoteForSavedSearch(
        note,
        presetId,
      ),
    ).toList();
  }
}

/// Provider integration for saved search smart folders
class SavedSearchSmartFolderProvider {
  final List<SmartFolderConfig> _presets =
      SmartFolderSavedSearchPresets.getSavedSearchPresets();

  /// Get all saved search smart folders
  List<SmartFolderConfig> get presets => _presets;

  /// Get notes for a saved search smart folder
  Future<List<LocalNote>> getNotesForPreset(
    String presetId,
    List<LocalNote> allNotes,
  ) async {
    final filtered = allNotes.filterForSavedSearch(presetId);

    // Sort by updated date (most recent first)
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // Apply max results limit
    final preset = _presets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => SmartFolderSavedSearchPresets.attachmentsSmartFolder,
    );

    if (filtered.length > preset.maxResults) {
      return filtered.take(preset.maxResults).toList();
    }

    return filtered;
  }

  /// Check if a preset has any matching notes
  Future<bool> hasNotes(String presetId, List<LocalNote> allNotes) async {
    return allNotes.any(
      (note) => SmartFolderSavedSearchPresets.evaluateNoteForSavedSearch(
        note,
        presetId,
      ),
    );
  }

  /// Get count of notes for a preset
  Future<int> getCount(String presetId, List<LocalNote> allNotes) async {
    return allNotes
        .where(
          (note) => SmartFolderSavedSearchPresets.evaluateNoteForSavedSearch(
            note,
            presetId,
          ),
        )
        .length;
  }
}
