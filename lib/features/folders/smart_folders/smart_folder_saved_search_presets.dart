// lib/features/folders/smart_folders/smart_folder_saved_search_presets.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:duru_notes/features/folders/smart_folders/smart_folder_types.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:uuid/uuid.dart';

/// Extension to handle saved search presets as smart folders
class SmartFolderSavedSearchPresets {
  static const _uuid = Uuid();
  
  /// Get predefined smart folders for saved searches
  static List<SmartFolderConfig> getSavedSearchPresets() {
    return [
      attachmentsSmartFolder,
      emailNotesSmartFolder,
      webClipsSmartFolder,
      // Note: Inbox folder is handled differently as it's folder-based, not rule-based
    ];
  }
  
  /// Attachments Smart Folder
  static final attachmentsSmartFolder = SmartFolderConfig(
    id: 'saved_search_attachments',
    name: 'Attachments',
    type: SmartFolderType.custom,
    rules: [
      SmartFolderRule(
        id: _uuid.v4(),
        field: RuleField.content,
        operator: RuleOperator.contains,
        value: '#Attachment',
      ),
    ],
    customIcon: Icons.attach_file,
    customColor: Colors.orange,
    maxResults: 200,
  );
  
  /// Email Notes Smart Folder
  static final emailNotesSmartFolder = SmartFolderConfig(
    id: 'saved_search_email',
    name: 'Email Notes',
    type: SmartFolderType.custom,
    rules: [
      SmartFolderRule(
        id: _uuid.v4(),
        field: RuleField.content,
        operator: RuleOperator.contains,
        value: '#Email',
      ),
    ],
    customIcon: Icons.email,
    customColor: Colors.blue,
    maxResults: 200,
  );
  
  /// Web Clips Smart Folder
  static final webClipsSmartFolder = SmartFolderConfig(
    id: 'saved_search_web',
    name: 'Web Clips',
    type: SmartFolderType.custom,
    rules: [
      SmartFolderRule(
        id: _uuid.v4(),
        field: RuleField.content,
        operator: RuleOperator.contains,
        value: '#Web',
      ),
    ],
    customIcon: Icons.language,
    customColor: Colors.green,
    maxResults: 200,
  );
  
  /// Check if a note matches saved search criteria (with metadata support)
  /// This is a more accurate evaluation than the basic rule engine
  static bool evaluateNoteForSavedSearch(LocalNote note, String presetId) {
    switch (presetId) {
      case 'saved_search_attachments':
        return _hasAttachments(note);
        
      case 'saved_search_email':
        return _isEmailNote(note);
        
      case 'saved_search_web':
        return _isWebClip(note);
        
      default:
        return false;
    }
  }
  
  /// Check if note has attachments
  static bool _hasAttachments(LocalNote note) {
    // First check metadata
    if (note.encryptedMetadata != null) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        final attachments = meta['attachments'];
        if (attachments != null) {
          final count = attachments['count'] as int?;
          if (count != null && count > 0) {
            return true;
          }
        }
      } catch (e) {
        // Fallback to tag check
      }
    }
    
    // Fallback: check for #Attachment tag
    return note.body.contains('#Attachment');
  }
  
  /// Check if note is from email
  static bool _isEmailNote(LocalNote note) {
    // First check metadata source
    if (note.encryptedMetadata != null) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        if (meta['source'] == 'email_in' || meta['source'] == 'email_inbox') {
          return true;
        }
      } catch (e) {
        // Fallback to tag check
      }
    }
    
    // Fallback: check for #Email tag
    return note.body.contains('#Email');
  }
  
  /// Check if note is a web clip
  static bool _isWebClip(LocalNote note) {
    // First check metadata source
    if (note.encryptedMetadata != null) {
      try {
        final meta = jsonDecode(note.encryptedMetadata!);
        if (meta['source'] == 'web') {
          return true;
        }
      } catch (e) {
        // Fallback to tag check
      }
    }
    
    // Fallback: check for #Web tag
    return note.body.contains('#Web');
  }
}

/// Enhanced SmartFolderEngine for saved searches
/// This extends the basic evaluation to support metadata-based rules
extension SavedSearchSmartFolderEngine on List<LocalNote> {
  /// Filter notes for a saved search smart folder
  List<LocalNote> filterForSavedSearch(String presetId) {
    return where((note) => 
      SmartFolderSavedSearchPresets.evaluateNoteForSavedSearch(note, presetId)
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
    return allNotes.any((note) => 
      SmartFolderSavedSearchPresets.evaluateNoteForSavedSearch(note, presetId)
    );
  }
  
  /// Get count of notes for a preset
  Future<int> getCount(String presetId, List<LocalNote> allNotes) async {
    return allNotes.where((note) => 
      SmartFolderSavedSearchPresets.evaluateNoteForSavedSearch(note, presetId)
    ).length;
  }
}
