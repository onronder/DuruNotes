// lib/search/saved_search_registry.dart
import 'package:flutter/material.dart';

enum SavedSearchKey { attachments, emailNotes, webNotes, inbox }

class SavedSearchPreset {
  const SavedSearchPreset({
    required this.key,
    required this.label,
    required this.icon,
    this.queryToken,
    this.tag,
    this.folderName,
  });
  final SavedSearchKey key;
  final String label;
  final IconData icon;

  /// Preferred token (if NoteSearchDelegate supports programmatic queries)
  final String? queryToken;

  /// Fallback: tag to navigate via TagNotesScreen
  final String? tag;

  /// Fallback: folder display name to resolve via IncomingMailFolderManager
  final String? folderName;
}

class SavedSearchRegistry {
  /// NOTE: Folder name is the canonical display name used by IncomingMailFolderManager.
  /// Your inventory shows "Incoming Mail" as the folder name.
  static const String kIncomingMailFolderName = 'Incoming Mail';

  static const List<SavedSearchPreset> presets = [
    SavedSearchPreset(
      key: SavedSearchKey.attachments,
      label: 'Attachments',
      icon: Icons.attach_file,
      tag: 'Attachment',
    ),
    SavedSearchPreset(
      key: SavedSearchKey.emailNotes,
      label: 'Email Notes',
      icon: Icons.email,
      tag: 'Email',
    ),
    SavedSearchPreset(
      key: SavedSearchKey.webNotes,
      label: 'Web Clips',
      icon: Icons.language,
      tag: 'Web',
    ),
    SavedSearchPreset(
      key: SavedSearchKey.inbox,
      label: 'Inbox',
      icon: Icons.inbox,
      folderName: kIncomingMailFolderName,
    ),
  ];
}
