import 'package:duru_notes/features/folders/batch_operations/batch_selection_provider.dart';
import 'package:duru_notes/features/folders/folder_picker_component.dart';
import 'package:duru_notes/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keyboard shortcuts configuration
class KeyboardShortcuts {
  // Selection shortcuts
  static const selectAll = SingleActivator(LogicalKeyboardKey.keyA, meta: true);
  static const selectNone = SingleActivator(LogicalKeyboardKey.keyD, meta: true);
  static const invertSelection = SingleActivator(LogicalKeyboardKey.keyI, meta: true);
  
  // Navigation shortcuts
  static const expandAll = SingleActivator(LogicalKeyboardKey.keyE, meta: true);
  static const collapseAll = SingleActivator(LogicalKeyboardKey.keyW, meta: true);
  static const nextFolder = SingleActivator(LogicalKeyboardKey.arrowDown);
  static const previousFolder = SingleActivator(LogicalKeyboardKey.arrowUp);
  
  // Action shortcuts
  static const deleteSelected = SingleActivator(LogicalKeyboardKey.delete);
  static const deleteSelectedAlt = SingleActivator(LogicalKeyboardKey.backspace, meta: true);
  static const moveToFolder = SingleActivator(LogicalKeyboardKey.keyM, meta: true);
  static const createFolder = SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true);
  static const refreshFolders = SingleActivator(LogicalKeyboardKey.keyR, meta: true);
  
  // Search shortcuts
  static const searchFolders = SingleActivator(LogicalKeyboardKey.keyF, meta: true);
  static const clearSearch = SingleActivator(LogicalKeyboardKey.escape);
  
  // Batch operation shortcuts
  static const archiveSelected = SingleActivator(LogicalKeyboardKey.keyA, meta: true, shift: true);
  static const favoriteSelected = SingleActivator(LogicalKeyboardKey.keyS, meta: true);
  static const shareSelected = SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true);
  static const exportSelected = SingleActivator(LogicalKeyboardKey.keyE, meta: true, shift: true);
  
  // Quick folder access (1-9)
  static List<SingleActivator> get quickFolderShortcuts => List.generate(9, (index) =>
      SingleActivator(LogicalKeyboardKey(0x00000031 + index), meta: true)); // 1-9 keys
}

/// Widget that handles keyboard shortcuts for folder operations
class KeyboardShortcutsHandler extends ConsumerStatefulWidget {
  const KeyboardShortcutsHandler({
    required this.child, super.key,
    this.focusNode,
  });

  final Widget child;
  final FocusNode? focusNode;

  @override
  ConsumerState<KeyboardShortcutsHandler> createState() => _KeyboardShortcutsHandlerState();
}

class _KeyboardShortcutsHandlerState extends ConsumerState<KeyboardShortcutsHandler> {
  late FocusNode _focusNode;
  final Map<SingleActivator, Intent> _shortcuts = {};

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _setupShortcuts();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _setupShortcuts() {
    _shortcuts.clear();
    
    // Selection shortcuts
    _shortcuts[KeyboardShortcuts.selectAll] = const _SelectAllIntent();
    _shortcuts[KeyboardShortcuts.selectNone] = const _SelectNoneIntent();
    _shortcuts[KeyboardShortcuts.invertSelection] = const _InvertSelectionIntent();
    
    // Navigation shortcuts
    _shortcuts[KeyboardShortcuts.expandAll] = const _ExpandAllIntent();
    _shortcuts[KeyboardShortcuts.collapseAll] = const _CollapseAllIntent();
    _shortcuts[KeyboardShortcuts.nextFolder] = const _NextFolderIntent();
    _shortcuts[KeyboardShortcuts.previousFolder] = const _PreviousFolderIntent();
    
    // Action shortcuts
    _shortcuts[KeyboardShortcuts.deleteSelected] = const _DeleteSelectedIntent();
    _shortcuts[KeyboardShortcuts.deleteSelectedAlt] = const _DeleteSelectedIntent();
    _shortcuts[KeyboardShortcuts.moveToFolder] = const _MoveToFolderIntent();
    _shortcuts[KeyboardShortcuts.createFolder] = const _CreateFolderIntent();
    _shortcuts[KeyboardShortcuts.refreshFolders] = const _RefreshFoldersIntent();
    
    // Search shortcuts
    _shortcuts[KeyboardShortcuts.searchFolders] = const _SearchFoldersIntent();
    _shortcuts[KeyboardShortcuts.clearSearch] = const _ClearSearchIntent();
    
    // Batch operation shortcuts
    _shortcuts[KeyboardShortcuts.archiveSelected] = const _ArchiveSelectedIntent();
    _shortcuts[KeyboardShortcuts.favoriteSelected] = const _FavoriteSelectedIntent();
    _shortcuts[KeyboardShortcuts.shareSelected] = const _ShareSelectedIntent();
    _shortcuts[KeyboardShortcuts.exportSelected] = const _ExportSelectedIntent();
    
    // Quick folder access shortcuts (1-9)
    for (var i = 0; i < KeyboardShortcuts.quickFolderShortcuts.length; i++) {
      _shortcuts[KeyboardShortcuts.quickFolderShortcuts[i]] = _QuickFolderAccessIntent(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      child: Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: _buildActions(),
          child: Focus(
            autofocus: true,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Map<Type, Action<Intent>> _buildActions() {
    return {
      _SelectAllIntent: CallbackAction<_SelectAllIntent>(onInvoke: (_) => _selectAll()),
      _SelectNoneIntent: CallbackAction<_SelectNoneIntent>(onInvoke: (_) => _selectNone()),
      _InvertSelectionIntent: CallbackAction<_InvertSelectionIntent>(onInvoke: (_) => _invertSelection()),
      _ExpandAllIntent: CallbackAction<_ExpandAllIntent>(onInvoke: (_) => _expandAll()),
      _CollapseAllIntent: CallbackAction<_CollapseAllIntent>(onInvoke: (_) => _collapseAll()),
      _NextFolderIntent: CallbackAction<_NextFolderIntent>(onInvoke: (_) => _nextFolder()),
      _PreviousFolderIntent: CallbackAction<_PreviousFolderIntent>(onInvoke: (_) => _previousFolder()),
      _DeleteSelectedIntent: CallbackAction<_DeleteSelectedIntent>(onInvoke: (_) => _deleteSelected()),
      _MoveToFolderIntent: CallbackAction<_MoveToFolderIntent>(onInvoke: (_) => _moveToFolder()),
      _CreateFolderIntent: CallbackAction<_CreateFolderIntent>(onInvoke: (_) => _createFolder()),
      _RefreshFoldersIntent: CallbackAction<_RefreshFoldersIntent>(onInvoke: (_) => _refreshFolders()),
      _SearchFoldersIntent: CallbackAction<_SearchFoldersIntent>(onInvoke: (_) => _searchFolders()),
      _ClearSearchIntent: CallbackAction<_ClearSearchIntent>(onInvoke: (_) => _clearSearch()),
      _ArchiveSelectedIntent: CallbackAction<_ArchiveSelectedIntent>(onInvoke: (_) => _archiveSelected()),
      _FavoriteSelectedIntent: CallbackAction<_FavoriteSelectedIntent>(onInvoke: (_) => _favoriteSelected()),
      _ShareSelectedIntent: CallbackAction<_ShareSelectedIntent>(onInvoke: (_) => _shareSelected()),
      _ExportSelectedIntent: CallbackAction<_ExportSelectedIntent>(onInvoke: (_) => _exportSelected()),
      _QuickFolderAccessIntent: CallbackAction<_QuickFolderAccessIntent>(
        onInvoke: (intent) => _quickFolderAccess(intent.index),
      ),
    };
  }

  // Selection actions
  void _selectAll() {
    final allNotes = ref.read(currentNotesProvider);
    final allIds = allNotes.map((note) => note.id).toList();
    ref.read(batchSelectionProvider.notifier).selectAll(allIds);
    
    _showShortcutFeedback('Selected all notes');
    HapticFeedback.selectionClick();
  }

  void _selectNone() {
    ref.read(batchSelectionProvider.notifier).clearSelection();
    
    _showShortcutFeedback('Cleared selection');
    HapticFeedback.selectionClick();
  }

  void _invertSelection() {
    final allNotes = ref.read(currentNotesProvider);
    final allIds = allNotes.map((note) => note.id).toList();
    ref.read(batchSelectionProvider.notifier).invertSelection(allIds);
    
    _showShortcutFeedback('Inverted selection');
    HapticFeedback.selectionClick();
  }

  // Navigation actions
  void _expandAll() {
    ref.read(folderHierarchyProvider.notifier).expandAll();
    
    _showShortcutFeedback('Expanded all folders');
    HapticFeedback.lightImpact();
  }

  void _collapseAll() {
    ref.read(folderHierarchyProvider.notifier).collapseAll();
    
    _showShortcutFeedback('Collapsed all folders');
    HapticFeedback.lightImpact();
  }

  void _nextFolder() {
    // TODO: Implement folder navigation
    _showShortcutFeedback('Next folder');
    HapticFeedback.selectionClick();
  }

  void _previousFolder() {
    // TODO: Implement folder navigation
    _showShortcutFeedback('Previous folder');
    HapticFeedback.selectionClick();
  }

  // Action shortcuts
  void _deleteSelected() {
    final selectionState = ref.read(batchSelectionProvider);
    if (!selectionState.hasSelection) return;
    
    _confirmDelete();
  }

  void _moveToFolder() {
    final selectionState = ref.read(batchSelectionProvider);
    if (!selectionState.hasSelection) return;
    
    _showFolderPicker();
  }

  void _createFolder() {
    // TODO: Show create folder dialog
    _showShortcutFeedback('Create folder shortcut');
    HapticFeedback.mediumImpact();
  }

  void _refreshFolders() {
    ref.read(folderHierarchyProvider.notifier).loadFolders();
    
    _showShortcutFeedback('Refreshing folders...');
    HapticFeedback.lightImpact();
  }

  // Search actions
  void _searchFolders() {
    // TODO: Focus search bar
    _showShortcutFeedback('Focus search');
    HapticFeedback.selectionClick();
  }

  void _clearSearch() {
    ref.read(folderHierarchyProvider.notifier).clearSearch();
    
    _showShortcutFeedback('Cleared search');
    HapticFeedback.selectionClick();
  }

  // Batch operation actions
  void _archiveSelected() {
    final selectionState = ref.read(batchSelectionProvider);
    if (!selectionState.hasSelection) return;
    
    ref.read(batchOperationsProvider.notifier).toggleArchiveSelectedNotes(true);
    _showShortcutFeedback('Archived selected notes');
  }

  void _favoriteSelected() {
    final selectionState = ref.read(batchSelectionProvider);
    if (!selectionState.hasSelection) return;
    
    ref.read(batchOperationsProvider.notifier).toggleFavoriteSelectedNotes(true);
    _showShortcutFeedback('Favorited selected notes');
  }

  void _shareSelected() {
    final selectionState = ref.read(batchSelectionProvider);
    if (!selectionState.hasSelection) return;
    
    ref.read(batchOperationsProvider.notifier).shareSelectedNotes();
    _showShortcutFeedback('Sharing selected notes...');
  }

  void _exportSelected() {
    final selectionState = ref.read(batchSelectionProvider);
    if (!selectionState.hasSelection) return;
    
    _showExportOptions();
  }

  // Quick folder access
  void _quickFolderAccess(int folderIndex) {
    final folders = ref.read(folderListProvider);
    if (folderIndex < folders.length) {
      final folder = folders[folderIndex];
      // TODO: Navigate to folder or set as current
      _showShortcutFeedback('Quick access: ${folder.name}');
    }
  }

  // Helper methods
  void _confirmDelete() {
    final count = ref.read(batchSelectionProvider).selectedCount;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notes'),
        content: Text('Delete $count selected note${count > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(batchOperationsProvider.notifier).deleteSelectedNotes();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFolderPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FolderPicker(
        title: 'Move ${ref.read(batchSelectionProvider).selectedCount} notes to...',
        onFolderSelected: (folderId) {
          ref.read(batchOperationsProvider.notifier).moveNotesToFolder(folderId);
        },
      ),
    );
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Markdown'),
              trailing: const Text('⌘⇧M'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(batchOperationsProvider.notifier).exportSelectedNotes('markdown');
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('PDF'),
              trailing: const Text('⌘⇧P'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(batchOperationsProvider.notifier).exportSelectedNotes('pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON'),
              trailing: const Text('⌘⇧J'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(batchOperationsProvider.notifier).exportSelectedNotes('json');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShortcutFeedback(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.fixed,
        margin: const EdgeInsets.only(
          bottom: 100,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      ),
    );
  }
}

// Helper intent classes for shortcuts
// class _ShortcutIntent extends Intent {  // Generic intent - using specific intents instead
//   const _ShortcutIntent(this.action);
//   final String action;
// }

// Specific intent types for better action handling
class _SelectAllIntent extends Intent { const _SelectAllIntent(); }
class _SelectNoneIntent extends Intent { const _SelectNoneIntent(); }
class _InvertSelectionIntent extends Intent { const _InvertSelectionIntent(); }
class _ExpandAllIntent extends Intent { const _ExpandAllIntent(); }
class _CollapseAllIntent extends Intent { const _CollapseAllIntent(); }
class _NextFolderIntent extends Intent { const _NextFolderIntent(); }
class _PreviousFolderIntent extends Intent { const _PreviousFolderIntent(); }
class _DeleteSelectedIntent extends Intent { const _DeleteSelectedIntent(); }
class _MoveToFolderIntent extends Intent { const _MoveToFolderIntent(); }
class _CreateFolderIntent extends Intent { const _CreateFolderIntent(); }
class _RefreshFoldersIntent extends Intent { const _RefreshFoldersIntent(); }
class _SearchFoldersIntent extends Intent { const _SearchFoldersIntent(); }
class _ClearSearchIntent extends Intent { const _ClearSearchIntent(); }
class _ArchiveSelectedIntent extends Intent { const _ArchiveSelectedIntent(); }
class _FavoriteSelectedIntent extends Intent { const _FavoriteSelectedIntent(); }
class _ShareSelectedIntent extends Intent { const _ShareSelectedIntent(); }
class _ExportSelectedIntent extends Intent { const _ExportSelectedIntent(); }
class _QuickFolderAccessIntent extends Intent { 
  const _QuickFolderAccessIntent(this.index);
  final int index;
}

/// Widget that displays available keyboard shortcuts
class KeyboardShortcutsHelp extends StatelessWidget {
  const KeyboardShortcutsHelp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('Keyboard Shortcuts'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildShortcutSection(
                'Selection',
                [
                  const _ShortcutItem('Select All', '⌘A'),
                  const _ShortcutItem('Clear Selection', '⌘D'),
                  const _ShortcutItem('Invert Selection', '⌘I'),
                ],
                theme,
              ),
              
              const SizedBox(height: 16),
              
              _buildShortcutSection(
                'Navigation',
                [
                  const _ShortcutItem('Expand All Folders', '⌘E'),
                  const _ShortcutItem('Collapse All Folders', '⌘W'),
                  const _ShortcutItem('Next Folder', '↓'),
                  const _ShortcutItem('Previous Folder', '↑'),
                  const _ShortcutItem('Quick Folder Access', '⌘1-9'),
                ],
                theme,
              ),
              
              const SizedBox(height: 16),
              
              _buildShortcutSection(
                'Actions',
                [
                  const _ShortcutItem('Delete Selected', 'Delete'),
                  const _ShortcutItem('Move to Folder', '⌘M'),
                  const _ShortcutItem('Create Folder', '⌘⇧N'),
                  const _ShortcutItem('Refresh Folders', '⌘R'),
                  const _ShortcutItem('Search Folders', '⌘F'),
                  const _ShortcutItem('Clear Search', 'Esc'),
                ],
                theme,
              ),
              
              const SizedBox(height: 16),
              
              _buildShortcutSection(
                'Batch Operations',
                [
                  const _ShortcutItem('Archive Selected', '⌘⇧A'),
                  const _ShortcutItem('Favorite Selected', '⌘S'),
                  const _ShortcutItem('Share Selected', '⌘⇧S'),
                  const _ShortcutItem('Export Selected', '⌘⇧E'),
                ],
                theme,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildShortcutSection(
    String title,
    List<_ShortcutItem> shortcuts,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...shortcuts.map((shortcut) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  shortcut.description,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  shortcut.shortcut,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}

class _ShortcutItem {

  const _ShortcutItem(this.description, this.shortcut);
  final String description;
  final String shortcut;
}

/// Provider for keyboard shortcuts enabled state
final keyboardShortcutsEnabledProvider = StateProvider<bool>((ref) => true);

/// Extension to show keyboard shortcuts help
extension KeyboardShortcutsContext on BuildContext {
  void showKeyboardShortcutsHelp() {
    showDialog(
      context: this,
      builder: (context) => const KeyboardShortcutsHelp(),
    );
  }
}
