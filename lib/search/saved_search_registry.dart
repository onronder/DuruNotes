// lib/search/saved_search_registry.dart
import 'package:flutter/material.dart';

enum SavedSearchKey { attachments, emailNotes, inbox, webNotes }

class SavedSearchPreset {
  final SavedSearchKey key;
  final String label;
  final IconData icon;

  /// Preferred token (if NoteSearchDelegate supports programmatic queries)
  final String? queryToken;

  /// Fallback: tag to navigate via TagNotesScreen
  final String? tag;

  /// Fallback: folder display name to resolve via IncomingMailFolderManager
  final String? folderName;

  const SavedSearchPreset({
    required this.key,
    required this.label,
    required this.icon,
    this.queryToken,
    this.tag,
    this.folderName,
  });
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
      queryToken: 'has:attachment',
      tag: 'Attachment',
    ),
    SavedSearchPreset(
      key: SavedSearchKey.emailNotes,
      label: 'Email Notes',
      icon: Icons.email,
      queryToken: 'from:email',
      tag: 'Email',
    ),
    SavedSearchPreset(
      key: SavedSearchKey.inbox,
      label: 'Inbox',
      icon: Icons.inbox,
      // We will resolve to Incoming Mail folder id when tapped
      folderName: kIncomingMailFolderName,
    ),
    SavedSearchPreset(
      key: SavedSearchKey.webNotes,
      label: 'Web Clips',
      icon: Icons.language,
      queryToken: 'from:web',
      tag: 'Web',
    ),
  ];
}
