import 'dart:io';
import 'dart:math' as math;

import 'package:duru_notes/core/performance/performance_optimizations.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/drag_drop/note_drag_drop.dart';
import 'package:duru_notes/features/folders/folder_picker_component.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/theme/material3_theme.dart';
import 'package:duru_notes/services/export_service.dart';
import 'package:duru_notes/services/import_service.dart';
import 'package:duru_notes/ui/help_screen.dart';
import 'package:duru_notes/ui/modern_edit_note_screen.dart';
import 'package:duru_notes/ui/settings_screen.dart';
import 'package:duru_notes/ui/widgets/folder_chip.dart';
import 'package:duru_notes/ui/widgets/stats_card.dart';
import 'package:duru_notes/search/saved_search_registry.dart';
import 'package:duru_notes/ui/widgets/saved_search_chips.dart';
import 'package:duru_notes/ui/tag_notes_screen.dart';
import 'package:duru_notes/ui/note_search_delegate.dart';
import 'package:duru_notes/services/incoming_mail_folder_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duru_notes/features/folders/folder_icon_helpers.dart';

/// Redesigned notes list screen with Material 3 design and modern UX
class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fabAnimationController;
  late AnimationController _listAnimationController;
  late AnimationController _headerAnimationController;
  late Animation<double> _fabAnimation;
  // late Animation<double> _headerSlideAnimation;  // Reserved for header slide animation
  late Animation<double> _headerFadeAnimation;
  Animation<double> _headerHeightAnimation = const AlwaysStoppedAnimation<double>(1);
  
  bool _isFabExpanded = false;
  String _sortBy = 'date'; // date, title, modified
  bool _isGridView = false;
  final Set<String> _selectedNoteIds = {};
  bool _isSelectionMode = false;
  bool _isHeaderCollapsed = false;

  @override
  void initState() {
    super.initState();
    // Listen for scroll to implement infinite loading and header collapse
    _scrollController.addListener(_onScroll);
    
    // Initialize animations
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _listAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    // _headerSlideAnimation = Tween<double>(
    //   begin: 0,
    //   end: -1,
    // ).animate(CurvedAnimation(
    //   parent: _headerAnimationController,
    //   curve: Curves.easeInOut,
    // ));
    _headerFadeAnimation = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeInOut,
    ));
    _headerHeightAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _headerAnimationController, curve: Curves.easeInOut),
    );
    
    // Start list animation
    _listAnimationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _listAnimationController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Handle infinite loading
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final hasMore = ref.read(hasMoreNotesProvider);
      final isLoading = ref.read(notesLoadingProvider);
      
      if (hasMore && !isLoading) {
        ref.read(notesPageProvider.notifier).loadMore();
      }
    }
    
    // Handle header collapse/expand animation
    const collapseThreshold = 120.0;
    final shouldCollapse = _scrollController.offset > collapseThreshold;
    
    if (shouldCollapse != _isHeaderCollapsed) {
      setState(() {
        _isHeaderCollapsed = shouldCollapse;
      });
      
      if (shouldCollapse) {
        _headerAnimationController.forward();
      } else {
        _headerAnimationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final notesAsync = ref.watch(filteredNotesProvider);
    final hasMore = ref.watch(hasMoreNotesProvider);
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildModernAppBar(context, l10n),
      body: Column(
        children: [
          // Saved search chips with counts
          SavedSearchChips(
            onTap: (preset) => _handleSavedSearchTap(context, preset),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            getTagCounts: () async {
              final db = ref.read(appDbProvider);
              final tags = await db.getTagsWithCounts();
              return Map.fromEntries(
                tags.map((t) => MapEntry(t.tag, t.count)),
              );
            },
            getFolderCount: (folderName) async {
              if (folderName == 'Incoming Mail') {
                final folderId = await ref.read(incomingMailFolderManagerProvider)
                    .ensureIncomingMailFolderId();
                final db = ref.read(appDbProvider);
                return await db.getNotesCountInFolder(folderId);
              }
              return 0;
            },
          ),
          
          // User stats card with animation
          if (user != null) _buildUserStatsCard(context, user),
          
          // Folder navigation
          _buildFolderNavigation(context),
          
          // Notes list
          Expanded(
            child: _buildNotesContent(context, notesAsync, hasMore),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ModernEditNoteScreen(),
            ),
          );
        },
        tooltip: 'Create New Note',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
  
  PreferredSizeWidget _buildModernAppBar(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    
    return AppBar(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isSelectionMode
            ? Text(
                '${_selectedNoteIds.length} selected',
                key: const ValueKey('selection_title'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              )
            : Text(
                l10n.notesListTitle,
                key: const ValueKey('main_title'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
      leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _exitSelectionMode,
              tooltip: 'Exit selection',
            )
          : null,
      actionsIconTheme: isCompact ? const IconThemeData(size: 22) : null,
      actions: _isSelectionMode
          ? _buildSelectionActions()
          : [
                  // Search toggle
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: _enterSearch,
                    tooltip: 'Search notes',
                  ),
                  // View toggle
                  IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                        key: ValueKey(_isGridView),
                      ),
                    ),
                    onPressed: _toggleViewMode,
                    tooltip: _isGridView ? 'List View' : 'Grid View',
                  ),
                  // Sort and more options
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    tooltip: 'More options',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: _handleMenuSelection,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'sort',
                        child: ListTile(
                          leading: Icon(Icons.sort_rounded),
                          title: Text('Sort'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'import',
                        child: ListTile(
                          leading: const Icon(Icons.upload_file_rounded),
                          title: Text(l10n.importNotes),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          leading: const Icon(Icons.download_rounded),
                          title: Text(l10n.exportNotes),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'settings',
                        child: ListTile(
                          leading: const Icon(Icons.settings_rounded),
                          title: Text(l10n.settings),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'help',
                        child: ListTile(
                          leading: const Icon(Icons.help_outline_rounded),
                          title: Text(l10n.help),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'logout',
                        child: ListTile(
                          leading: Icon(
                            Icons.logout_rounded,
                            color: colorScheme.error,
                          ),
                          title: Text(
                            l10n.signOut,
                            style: TextStyle(color: colorScheme.error),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
      );
  }
  
  Widget _buildUserStatsCard(BuildContext context, User user) {
    return AnimatedBuilder(
      animation: _headerFadeAnimation,
      child: Consumer(
        builder: (context, ref, child) {
          final notesAsync = ref.watch(notesPageProvider);
          return notesAsync.maybeWhen(
            data: (notesPage) {
              final totalNotes = notesPage.items.length;
              final todayNotes = notesPage.items.where((note) {
                final today = DateTime.now();
                return note.updatedAt.year == today.year &&
                    note.updatedAt.month == today.month &&
                    note.updatedAt.day == today.day;
              }).length;
              
              final foldersAsync = ref.watch(rootFoldersProvider);
              final folderCount = foldersAsync.maybeWhen(
                data: (folders) => folders.length,
                orElse: () => 0,
              );
              
              return StatsCard(
                greeting: _getGreeting(),
                email: user.email ?? 'User',
                stats: [
                  StatItem(
                    icon: Icons.note_rounded,
                    value: '$totalNotes',
                    label: 'Notes',
                  ),
                  StatItem(
                    icon: Icons.today_rounded,
                    value: '$todayNotes',
                    label: 'Today',
                  ),
                  StatItem(
                    icon: Icons.folder_rounded,
                    value: '$folderCount',
                    label: 'Folders',
                  ),
                ],
                isCollapsed: _isHeaderCollapsed,
                onToggleCollapse: () {
                  setState(() {
                    _isHeaderCollapsed = !_isHeaderCollapsed;
                  });
                  if (_isHeaderCollapsed) {
                    _headerAnimationController.forward();
                  } else {
                    _headerAnimationController.reverse();
                  }
                },
              );
            },
            orElse: () => const SizedBox.shrink(),
          );
        },
      ),
      builder: (context, child) {
        return Column(
          children: [
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: _headerHeightAnimation.value,
                child: Opacity(
                  opacity: _headerFadeAnimation.value,
                  child: child,
                ),
              ),
            ),
            if (_isHeaderCollapsed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isHeaderCollapsed = false);
                    _headerAnimationController.reverse();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.expand_more, size: 18),
                            SizedBox(width: 6),
                            Text('Show header'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
          
    );
  }
  
  Widget _buildFolderNavigation(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final foldersAsync = ref.watch(rootFoldersProvider);
        final currentFolder = ref.watch(currentFolderProvider);
        
        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // All Notes chip
                FolderChip(
                  label: 'All Notes',
                  icon: Icons.note_rounded,
                  isSelected: currentFolder == null,
                  onTap: () {
                    ref.read(currentFolderProvider.notifier).setCurrentFolder(null);
                  },
                ),
                
                const SizedBox(width: 8),
                
                // Folder chips with drag-drop support
                ...foldersAsync.maybeWhen(
                  data: (folders) => folders.map((folder) => 
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FolderDropTarget(
                        folder: folder,
                        onNoteDropped: _handleNoteDrop,
                        child: FolderChip(
                          label: folder.name,
                          icon: FolderIconHelpers.getFolderIcon(folder.icon, fallback: Icons.folder_rounded),
                          color: FolderIconHelpers.getFolderColor(folder.color),
                          isSelected: currentFolder?.id == folder.id,
                          onTap: () {
                            ref.read(currentFolderProvider.notifier).setCurrentFolder(folder);
                          },
                        ),
                      ),
                    )
                  ).toList(),
                  orElse: () => <Widget>[],
                ),
                
                // Create folder chip
                FolderChip(
                  label: 'New Folder',
                  icon: Icons.add_rounded,
                  onTap: () => _showFolderPicker(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildNotesContent(BuildContext context, AsyncValue<List<LocalNote>> notesAsync, bool hasMore) {
    return notesAsync.when(
      data: (notes) {
        final filteredNotes = notes;
        
        if (filteredNotes.isEmpty) {
          return _buildEmptyState(context);
        }
        
        final sortedNotes = _sortNotes(filteredNotes);
        
        return RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await ref.read(notesPageProvider.notifier).refresh();
            ref.invalidate(filteredNotesProvider);
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isGridView
                ? _buildModernGridView(context, sortedNotes, hasMore)
                : _buildModernListView(context, sortedNotes, hasMore),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => _buildErrorState(context, error.toString()),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    
    // Regular empty state
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: isCompact ? 16 : 24, bottom: MediaQuery.of(context).padding.bottom + (isCompact ? 16 : 24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_add_rounded, size: isCompact ? 48 : 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
            SizedBox(height: isCompact ? 12 : 16),
            Text(l10n.noNotesYet, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: isCompact ? (Theme.of(context).textTheme.titleLarge?.fontSize ?? 22) - 2 : null), textAlign: TextAlign.center),
            SizedBox(height: isCompact ? 6 : 8),
            Text(l10n.tapToCreateFirstNote, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: isCompact ? (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) - 1 : null), textAlign: TextAlign.center),
            SizedBox(height: isCompact ? 16 : 24),
            FilledButton.icon(
              onPressed: () => _createNewNote(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.createFirstNote, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: isCompact ? 13 : null)),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 22, vertical: isCompact ? 12 : 14),
                minimumSize: const Size(0, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text('Something went wrong', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Unable to load your notes. Please try again.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(notesPageProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // Removed _buildEmptyFolderState - handled by main empty state logic

  Widget _buildModernNoteCard(BuildContext context, LocalNote note, {bool isGrid = false}) {
    final isSelected = _selectedNoteIds.contains(note.id);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Get folder information
    final noteFolderState = ref.watch(noteFolderProvider);
    final folderId = noteFolderState.noteFolders[note.id];
    String? folderName;
    Color? folderColor;
    
    if (folderId != null) {
      final foldersAsync = ref.watch(rootFoldersProvider);
      foldersAsync.whenData((folders) {
        final folder = folders.where((f) => f.id == folderId).firstOrNull;
        if (folder != null) {
          folderName = folder.name;
          folderColor = FolderIconHelpers.getFolderColor(folder.color);
        }
      });
    }
    
    return DraggableNoteItem(
      note: note,
      enabled: !_isSelectionMode,
      onDragStarted: () {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Drag to a folder above to move this note'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
      child: Card(
        elevation: isSelected ? 6 : 2,
        shadowColor: colorScheme.shadow.withOpacity(0.15),
        color: isSelected 
            ? theme.customColors.selectedNoteBackground
            : theme.customColors.noteCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected 
              ? BorderSide(color: colorScheme.primary.withOpacity(0.3), width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () {
            if (_isSelectionMode) {
              _toggleNoteSelection(note.id);
            } else {
              _editNote(note);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              _enterSelectionMode(note.id);
            }
          },
          onSecondaryTap: () => _showNoteOptions(note),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getNoteIcon(note), 
                      size: 20, 
                      color: isSelected ? colorScheme.primary : colorScheme.primary.withOpacity(0.8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? colorScheme.onPrimaryContainer : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _editNote(note);
                          case 'move':
                            _showAddToFolderForSingleNote(note);
                          case 'duplicate':
                            _duplicateNote(note);
                          case 'delete':
                            _deleteNote(note);
                          case 'share':
                            _shareNote(note);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'move', child: Text('Move to folder')),
                        const PopupMenuItem(value: 'share', child: Text('Share')),
                        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check, 
                          color: colorScheme.onPrimary, 
                          size: 16,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _generatePreview(note.body),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected ? colorScheme.onPrimaryContainer.withOpacity(0.8) : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (folderName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: folderColor?.withOpacity(0.2) ?? colorScheme.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: folderColor?.withOpacity(0.3) ?? colorScheme.primary.withOpacity(0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          folderName ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: folderColor ?? colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _formatDate(note.updatedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected ? colorScheme.onPrimaryContainer.withOpacity(0.7) : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _generatePreview(String body) {
    if (body.trim().isEmpty) return 'No content';
    
    // Remove markdown formatting for preview
    final preview = body
        .replaceAll(RegExp('#+ '), '') // Remove headers
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // Remove bold
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // Remove italic
        .replaceAll(RegExp('`(.*?)`'), r'$1') // Remove code
        .replaceAll(RegExp(r'\n+'), ' ') // Replace newlines with spaces
        .trim();
    
    return preview.length > 100 ? '${preview.substring(0, 97)}...' : preview;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  void _createNewNote(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const ModernEditNoteScreen(),
      ),
    );
  }

  void _createNewNoteInFolder(BuildContext context, LocalFolder folder) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ModernEditNoteScreen(
          initialFolder: folder,
        ),
      ),
    );
  }

  void _editNote(LocalNote note) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ModernEditNoteScreen(
          noteId: note.id,
          initialTitle: note.title,
          initialBody: note.body,
        ),
      ),
    );
  }

  void _deleteNote(LocalNote note) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title.isNotEmpty ? note.title : 'Untitled'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                final repo = ref.read(notesRepositoryProvider);
                await repo.delete(note.id);
                
                // Refresh the notes list
                await ref.read(notesPageProvider.notifier).refresh();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Note deleted'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              } on Exception catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting note: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).importNotesTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).chooseWhatToImport),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).singleMarkdownFiles),
            Text(AppLocalizations.of(context).evernoteFiles),
            Text(AppLocalizations.of(context).obsidianVaultFolders),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).featuresSecurityValidation),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showImportTypeSelection(context);
            },
            child: Text(AppLocalizations.of(context).selectImportType),
          ),
        ],
      ),
    );
  }

  void _showImportTypeSelection(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Import Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.description, color: Theme.of(context).colorScheme.primary),
              title: const Text('Markdown Files'),
              subtitle: const Text('Import single .md or .markdown files'),
              onTap: () {
                Navigator.pop(context);
                _pickMarkdownFiles(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.file_copy, color: Theme.of(context).colorScheme.tertiary),
              title: const Text('Evernote Export'),
              subtitle: const Text('Import .enex files from Evernote'),
              onTap: () {
                Navigator.pop(context);
                _pickEnexFile(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.folder, color: Theme.of(context).colorScheme.secondary),
              title: const Text('Obsidian Vault'),
              subtitle: const Text('Import entire Obsidian vault folder'),
              onTap: () {
                Navigator.pop(context);
                _pickObsidianVault(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMarkdownFiles(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final files = result.files
            .where((file) => file.path != null)
            .map((file) => File(file.path!))
            .toList();

        if (files.isNotEmpty) {
          await _processImportFiles(context, files, ImportType.markdown);
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        _showErrorDialog(context, 'Failed to select Markdown files: $e');
      }
    }
  }

  Future<void> _pickEnexFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['enex'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await _processImportFiles(context, [file], ImportType.enex);
      }
    } on Exception catch (e) {
      if (mounted) {
        _showErrorDialog(context, 'Failed to select Evernote file: $e');
      }
    }
  }

  Future<void> _pickObsidianVault(BuildContext context) async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();

      if (result != null) {
        final directory = Directory(result);
        await _processObsidianImport(context, directory);
      }
    } on Exception catch (e) {
      if (mounted) {
        _showErrorDialog(context, 'Failed to select Obsidian vault: $e');
      }
    }
  }

  Future<void> _processImportFiles(
    BuildContext context,
    List<File> files,
    ImportType type,
  ) async {
    final importService = ref.read(importServiceProvider);
    
    // Show progress dialog
    final progressKey = GlobalKey<_ImportProgressDialogState>();
    
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ImportProgressDialog(key: progressKey),
    );

    try {
      final results = <ImportResult>[];
      
      for (final file in files) {
        ImportResult result;
        
        switch (type) {
          case ImportType.markdown:
            result = await importService.importMarkdown(
              file,
              onProgress: (progress) => progressKey.currentState?.updateProgress(progress),
            );
          case ImportType.enex:
            result = await importService.importEnex(
              file,
              onProgress: (progress) => progressKey.currentState?.updateProgress(progress),
            );
          case ImportType.obsidian:
            // This shouldn't happen for file-based imports
            throw Exception('Invalid import type for file');
        }
        
        results.add(result);
      }

      // Close progress dialog
      if (context.mounted) {
        Navigator.pop(context);
        
        // Show summary
        await _showImportSummary(context, results);
        
        // Refresh notes list
        await ref.read(notesPageProvider.notifier).refresh();
      }
    } on Exception catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog
        _showErrorDialog(context, 'Import failed: $e');
      }
    }
  }

  Future<void> _processObsidianImport(
    BuildContext context,
    Directory directory,
  ) async {
    final importService = ref.read(importServiceProvider);
    
    // Show progress dialog
    final progressKey = GlobalKey<_ImportProgressDialogState>();
    
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ImportProgressDialog(key: progressKey),
    );

    try {
      final result = await importService.importObsidian(
        directory,
        onProgress: (progress) => progressKey.currentState?.updateProgress(progress),
      );

      // Close progress dialog
      if (context.mounted) {
        Navigator.pop(context);
        
        // Show summary
        await _showImportSummary(context, [result]);
        
        // Refresh notes list
        await ref.read(notesPageProvider.notifier).refresh();
      }
    } on Exception catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog
        _showErrorDialog(context, 'Obsidian import failed: $e');
      }
    }
  }

  Future<void> _showImportSummary(
    BuildContext context,
    List<ImportResult> results,
  ) async {
    final totalSuccess = results.fold<int>(0, (sum, r) => sum + r.successCount);
    final totalErrors = results.fold<int>(0, (sum, r) => sum + r.errors.length);
    final totalDuration = results.fold<Duration>(
      Duration.zero,
      (sum, r) => sum + r.duration,
    );

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              totalErrors == 0 ? Icons.check_circle : Icons.warning,
              color: totalErrors == 0 ? Theme.of(context).colorScheme.tertiary : Theme.of(context).customColors.onWarningContainer,
            ),
            const SizedBox(width: 8),
            const Text('Import Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ Successfully imported: $totalSuccess notes'),
            if (totalErrors > 0) ...[
              const SizedBox(height: 8),
              Text('⚠️ Errors encountered: $totalErrors'),
            ],
            const SizedBox(height: 8),
            Text('⏱️ Import took: ${totalDuration.inSeconds} seconds'),
            if (totalErrors > 0) ...[
              const SizedBox(height: 16),
              const Text('Error details:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: results
                        .expand((r) => r.errors)
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• ${e.source}: ${e.message}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    final isExportError = message.toLowerCase().contains('export');
    final isPdfTimeout = message.contains('timed out') && message.contains('PDF');
    final isNetworkError = message.contains('network') || message.contains('fonts');
    
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text(isExportError ? 'Export Error' : 'Import Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (isPdfTimeout) ...[
              const SizedBox(height: 16),
              const Text(
                'PDF export may fail in simulator due to network restrictions. Try:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Test on a physical device'),
              const Text('• Check your internet connection'),
              const Text('• Try exporting as Markdown instead'),
            ] else if (isNetworkError) ...[
              const SizedBox(height: 16),
              const Text(
                'Network-related issue detected. Try:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Check your internet connection'),
              const Text('• Try again in a few moments'),
              const Text('• Use a different export format'),
            ],
          ],
        ),
        actions: [
          if (isPdfTimeout)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Retry with Markdown format
                final currentNotes = ref.read(currentNotesProvider);
                if (currentNotes.isNotEmpty) {
                  _exportNotes(context, [currentNotes.first], ExportFormat.markdown, ExportScope.latest);
                }
              },
              child: const Text('Try Markdown'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    final currentNotes = ref.read(currentNotesProvider);
    
    if (currentNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No notes to export'),
          backgroundColor: Theme.of(context).customColors.warningContainer,
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Notes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Export your notes to various formats:'),
            const SizedBox(height: 16),
            Text('Available notes: ${currentNotes.length}'),
            const SizedBox(height: 8),
            const Text('• Export as Markdown files'),
            const Text('• Export as PDF documents'),
            const Text('• Export as HTML files'),
            const SizedBox(height: 16),
            const Text('Features: Rich formatting, metadata, attachments'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showExportTypeSelection(context);
            },
            child: const Text('Choose Format'),
          ),
        ],
      ),
    );
  }

  void _showExportTypeSelection(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Export Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.description, color: Theme.of(context).colorScheme.primary),
              title: const Text('Markdown'),
              subtitle: const Text('Export as .md files with full formatting'),
              onTap: () {
                Navigator.pop(context);
                _showExportScopeSelection(context, ExportFormat.markdown);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.error),
              title: const Text('PDF'),
              subtitle: const Text('Export as PDF documents for sharing'),
              onTap: () {
                Navigator.pop(context);
                _showExportScopeSelection(context, ExportFormat.pdf);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.web, color: Theme.of(context).colorScheme.tertiary),
              title: const Text('HTML'),
              subtitle: const Text('Export as web pages with styling'),
              onTap: () {
                Navigator.pop(context);
                _showExportScopeSelection(context, ExportFormat.html);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showExportScopeSelection(BuildContext context, ExportFormat format) {
    final currentNotes = ref.read(currentNotesProvider);
    
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export as ${format.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.note, color: Theme.of(context).colorScheme.primary),
              title: const Text('Export All Notes'),
              subtitle: Text('Export all ${currentNotes.length} notes'),
              onTap: () {
                Navigator.pop(context);
                _exportNotes(context, currentNotes, format, ExportScope.all);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.star, color: Theme.of(context).customColors.onWarningContainer),
              title: const Text('Export Recent Notes'),
              subtitle: const Text('Export notes from the last 30 days'),
              onTap: () {
                Navigator.pop(context);
                final recentNotes = _getRecentNotes(currentNotes, 30);
                _exportNotes(context, recentNotes, format, ExportScope.recent);
              },
            ),
            if (currentNotes.length > 10) ...[
              const Divider(),
              ListTile(
                leading: Icon(Icons.filter_list, color: Theme.of(context).colorScheme.secondary),
                title: const Text('Export Latest 10'),
                subtitle: const Text('Export the 10 most recent notes'),
                onTap: () {
                  Navigator.pop(context);
                  final latestNotes = currentNotes.take(10).toList();
                  _exportNotes(context, latestNotes, format, ExportScope.latest);
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  List<LocalNote> _getRecentNotes(List<LocalNote> notes, int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return notes.where((note) => note.updatedAt.isAfter(cutoffDate)).toList();
  }

  Future<void> _exportNotes(
    BuildContext context,
    List<LocalNote> notes,
    ExportFormat format,
    ExportScope scope,
  ) async {
    if (notes.isEmpty) {
      _showErrorDialog(context, 'No notes to export in the selected scope');
      return;
    }

    final exportService = ref.read(exportServiceProvider);
    
    // Show progress dialog with cancel functionality
    final progressKey = GlobalKey<_ExportProgressDialogState>();
    var isCancelled = false;
    
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExportProgressDialog(
        key: progressKey,
        totalNotes: notes.length,
        format: format,
        onCancel: () {
          isCancelled = true;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Export cancelled'),
              backgroundColor: Theme.of(context).customColors.warningContainer,
            ),
          );
        },
      ),
    );

    try {
      final results = <ExportResult>[];
      const exportOptions = ExportOptions(
        
      );

      for (var i = 0; i < notes.length; i++) {
        // Check if export was cancelled
        if (isCancelled) {
          final logger = ref.read(loggerProvider);
          logger.info('Export cancelled by user', data: {
            'completed_notes': i,
            'total_notes': notes.length,
            'format': format.name,
          });
          return;
        }
        
        final note = notes[i];
        progressKey.currentState?.updateCurrentNote(i + 1, note.title);
        
        ExportResult result;
        
        try {
          switch (format) {
            case ExportFormat.markdown:
              result = await exportService.exportToMarkdown(
                note,
                onProgress: (progress) => progressKey.currentState?.updateProgress(progress),
              );
            case ExportFormat.pdf:
              result = await exportService.exportToPdf(
                note,
                onProgress: (progress) => progressKey.currentState?.updateProgress(progress),
              ).timeout(
                const Duration(minutes: 2),
                onTimeout: () => ExportResult.failure(
                  error: 'PDF export timed out. This may be due to network issues loading fonts.',
                  errorCode: 'EXPORT_TIMEOUT',
                  processingTime: const Duration(minutes: 2),
                  format: ExportFormat.pdf,
                ),
              );
            case ExportFormat.html:
              result = await exportService.exportToHtml(
                note,
                onProgress: (progress) => progressKey.currentState?.updateProgress(progress),
              );
            case ExportFormat.txt:
            case ExportFormat.docx:
              result = ExportResult.failure(
                error: 'Export format ${format.displayName} not yet implemented',
                errorCode: 'FORMAT_NOT_IMPLEMENTED',
                processingTime: Duration.zero,
                format: format,
              );
          }
        } catch (e) {
          result = ExportResult.failure(
            error: 'Failed to export note "${note.title}": $e',
            errorCode: 'EXPORT_ERROR',
            processingTime: Duration.zero,
            format: format,
          );
        }
        
        results.add(result);
      }

      // Close progress dialog
      if (context.mounted) {
        Navigator.pop(context);
        
        // Show export summary with share option
        await _showExportSummary(context, results, format, scope);
      }
    } on Exception catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog
        _showErrorDialog(context, 'Export failed: $e');
      }
    }
  }

  Future<void> _showExportSummary(
    BuildContext context,
    List<ExportResult> results,
    ExportFormat format,
    ExportScope scope,
  ) async {
    final successfulResults = results.where((r) => r.success).toList();
    final failedResults = results.where((r) => !r.success).toList();
    final totalSize = successfulResults.fold<int>(0, (sum, r) => sum + (r.fileSize ?? 0));
    
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              failedResults.isEmpty ? Icons.check_circle : Icons.warning,
              color: failedResults.isEmpty ? Theme.of(context).colorScheme.tertiary : Theme.of(context).customColors.onWarningContainer,
            ),
            const SizedBox(width: 8),
            const Text('Export Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Format: ${format.displayName}'),
            Text('Scope: ${scope.displayName}'),
            const SizedBox(height: 16),
            Text('✅ Successfully exported: ${successfulResults.length} notes'),
            if (failedResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('❌ Failed exports: ${failedResults.length}'),
            ],
            if (totalSize > 0) ...[
              const SizedBox(height: 8),
              Text('📁 Total size: ${_formatFileSize(totalSize)}'),
            ],
            if (successfulResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Files saved to Downloads folder', 
                style: TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (failedResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Failed exports:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: failedResults
                        .map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• ${r.error ?? 'Unknown error'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (successfulResults.isNotEmpty) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _shareExportedFiles(successfulResults, format);
              },
              child: const Text('Share Files'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openExportsFolder();
              },
              child: const Text('Open Folder'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Enhanced UX Helper Methods
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning!';
    if (hour >= 12 && hour < 18) return 'Good afternoon!';
    if (hour >= 18 && hour < 22) return 'Good evening!';
    return 'Good night!';
  }

  // Removed _buildStatCard - now using DuruStatsCard component

  List<Widget> _buildSelectionActions() {
    return [
      IconButton(
        icon: const Icon(Icons.select_all),
        onPressed: () {
          final notes = ref.read(currentNotesProvider);
          setState(() {
            _selectedNoteIds.addAll(notes.map((n) => n.id));
          });
        },
        tooltip: 'Select All',
      ),
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: _selectedNoteIds.isNotEmpty ? _shareSelectedNotes : null,
        tooltip: 'Share',
      ),
      IconButton(
        icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
        onPressed: _selectedNoteIds.isNotEmpty ? _deleteSelectedNotes : null,
        tooltip: 'Delete',
      ),
    ];
  }

  List<LocalNote> _sortNotes(List<LocalNote> notes) {
    final sorted = List<LocalNote>.from(notes);
    switch (_sortBy) {
      case 'title':
        sorted.sort((a, b) => a.title.compareTo(b.title));
      case 'created':
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // Using updatedAt as createdAt is not available
      default: // date
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return sorted;
  }

  Widget _buildModernListView(BuildContext context, List<LocalNote> notes, bool hasMore) {
    return ListView.builder(
      key: const ValueKey('modern_list_view'),
      controller: _scrollController,
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 100,
      ),
      itemCount: notes.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= notes.length) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final note = notes[index];
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.3, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _listAnimationController,
            curve: Interval(
              math.max(0, (index - 3) / notes.length),
              math.min(1, (index + 1) / notes.length),
              curve: Curves.easeOutCubic,
            ),
          )),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _listAnimationController,
              curve: Interval(
                math.max(0, (index - 3) / notes.length),
                math.min(1, (index + 1) / notes.length),
                curve: Curves.easeIn,
              ),
            ),
            child: _buildModernNoteCard(context, note),
          ),
        );
      },
    );
  }

  Widget _buildModernGridView(BuildContext context, List<LocalNote> notes, bool hasMore) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 3 : 2;
    
    return GridView.builder(
      key: const ValueKey('modern_grid_view'),
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 100,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: notes.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= notes.length) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        final note = notes[index];
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: _listAnimationController,
            curve: Interval(
              math.max(0, (index - 6) / notes.length),
              math.min(1, (index + 1) / notes.length),
              curve: Curves.elasticOut,
            ),
          ),
          child: _buildModernNoteCard(context, note, isGrid: true),
        );
      },
    );
  }

  Widget _buildModernFAB(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (_isSelectionMode) {
      // Show selection FAB
      return FloatingActionButton.extended(
        onPressed: _showAddToFolderDialog,
        backgroundColor: colorScheme.tertiaryContainer,
        foregroundColor: colorScheme.onTertiaryContainer,
        icon: const Icon(Icons.folder_copy_rounded),
        label: Text('Move ${_selectedNoteIds.length} note${_selectedNoteIds.length == 1 ? '' : 's'}'),
      );
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Quick actions with improved animations
        AnimatedSlide(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          offset: _isFabExpanded ? Offset.zero : const Offset(0, 1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isFabExpanded ? 1.0 : 0.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildModernMiniFAB(
                  icon: Icons.checklist_rounded,
                  label: 'Checklist',
                  color: colorScheme.tertiary,
                  onPressed: () {
                    _toggleFab();
                    _createChecklist();
                  },
                ),
                const SizedBox(height: 12),
                _buildModernMiniFAB(
                  icon: Icons.mic_rounded,
                  label: 'Voice Note',
                  color: colorScheme.secondary,
                  onPressed: () {
                    _toggleFab();
                    _createVoiceNote();
                  },
                ),
                const SizedBox(height: 12),
                _buildModernMiniFAB(
                  icon: Icons.note_add_rounded,
                  label: 'Text Note',
                  color: colorScheme.primary,
                  onPressed: () {
                    _toggleFab();
                    _createNewNote(context);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Main FAB with rotation animation
        FloatingActionButton(
          onPressed: _toggleFab,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          tooltip: 'Create Note',
          child: AnimatedBuilder(
            animation: _fabAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _fabAnimation.value * math.pi / 4,
                child: Icon(
                  _isFabExpanded ? Icons.close_rounded : Icons.add_rounded,
                  size: 28,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModernMiniFAB({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          elevation: 2,
          shadowColor: theme.colorScheme.shadow.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.small(
          heroTag: label,
          backgroundColor: color,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 3,
          onPressed: onPressed,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }

  void _toggleFab() {
    HapticFeedback.lightImpact();
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  
  void _enterSearch() async {
    HapticFeedback.lightImpact();
    
    // Get current notes for search
    final notesAsync = ref.read(filteredNotesProvider);
    final notes = notesAsync.maybeWhen(
      data: (notes) => notes,
      orElse: () => <LocalNote>[],
    );
    
    // Create and show search delegate
    final delegate = NoteSearchDelegate(
      notes: notes,
      resolveFolderIdByName: (name) async {
        if (name == 'Incoming Mail') {
          return await ref.read(incomingMailFolderManagerProvider)
              .ensureIncomingMailFolderId();
        }
        final db = ref.read(appDbProvider);
        final folder = await db.findFolderByName(name);
        return folder?.id;
      },
      getFolderNoteIdSet: (folderId) async {
        final db = ref.read(appDbProvider);
        final noteIds = await db.getNoteIdsInFolder(folderId);
        return noteIds.toSet();
      },
    );
    
    final result = await showSearch(
      context: context,
      delegate: delegate,
    );
    
    // Handle search result if needed
    if (result != null && result is LocalNote) {
      // Note was selected from search results
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ModernEditNoteScreen(noteId: result.id),
        ),
      );
    }
  }
  
  void _toggleViewMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isGridView = !_isGridView;
    });
  }
  
  void _handleMenuSelection(String value) {
    HapticFeedback.selectionClick();
    switch (value) {
      case 'sort':
        _showSortDialog(context);
      case 'import':
        _showImportDialog(context);
      case 'export':
        _showExportDialog(context);
      case 'settings':
        _showSettingsDialog(context);
      case 'help':
        _showHelpScreen(context);
      case 'logout':
        _confirmLogout(context);
    }
  }
  
  void _showSortDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Sort Notes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSortOption('Date Modified', 'date', Icons.calendar_today_rounded),
            _buildSortOption('Title', 'title', Icons.sort_by_alpha_rounded),
            _buildSortOption('Date Created', 'created', Icons.access_time_rounded),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSortOption(String title, String value, IconData icon) {
    final theme = Theme.of(context);
    final isSelected = _sortBy == value;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected 
            ? theme.colorScheme.primary 
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected 
              ? theme.colorScheme.primary 
              : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected 
          ? Icon(
              Icons.check_rounded,
              color: theme.colorScheme.primary,
            )
          : null,
      onTap: () {
        Navigator.pop(context);
        HapticFeedback.selectionClick();
        setState(() {
          _sortBy = value;
        });
      },
    );
  }
  
  void _handleNoteDrop(LocalNote note, LocalFolder? targetFolder) {
    // Handle null case (drop to unfiled)
    if (targetFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dropping to "Unfiled" not yet implemented'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Execute async operation without await since callback must be synchronous
    _performNoteDrop(note, targetFolder);
  }
  
  Future<void> _performNoteDrop(LocalNote note, LocalFolder targetFolder) async {
    try {
      final repo = ref.read(notesRepositoryProvider);
      await repo.addNoteToFolder(note.id, targetFolder.id);
      
      // Refresh the filtered notes
      ref.invalidate(filteredNotesProvider);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved "${note.title}" to ${targetFolder.name}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // TODO: Implement undo functionality
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move note: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _enterSelectionMode(String noteId) {
    setState(() {
      _isSelectionMode = true;
      _selectedNoteIds.add(noteId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedNoteIds.clear();
    });
  }

  void _toggleNoteSelection(String noteId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedNoteIds.contains(noteId)) {
        _selectedNoteIds.remove(noteId);
        if (_selectedNoteIds.isEmpty) {
          _exitSelectionMode();
        }
      } else {
        _selectedNoteIds.add(noteId);
      }
    });
  }

  IconData? _getNoteIcon(LocalNote note) {
    final body = note.body.toLowerCase();
    if (body.contains('- [ ]') || body.contains('- [x]')) {
      return Icons.checklist;
    } else if (body.contains('```')) {
      return Icons.code;
    } else if (body.contains('http://') || body.contains('https://')) {
      return Icons.link;
    } else if (body.contains('![]')) {
      return Icons.image;
    }
    return null;
  }

  void _showNoteOptions(LocalNote note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Add to Folder'),
              onTap: () {
                Navigator.pop(context);
                _showAddToFolderForSingleNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(context);
                _duplicateNote(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archive'),
              onTap: () {
                Navigator.pop(context);
                _archiveNote(note);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteNote(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createVoiceNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Voice note feature coming soon!'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  void _createPhotoNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Photo note feature coming soon!'),
        backgroundColor: Theme.of(context).customColors.warningContainer,
      ),
    );
  }

  void _createChecklist() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const ModernEditNoteScreen(
          initialBody: '## Checklist\n\n- [ ] Task 1\n- [ ] Task 2\n- [ ] Task 3',
        ),
      ),
    );
  }

  Future<void> _shareNote(LocalNote note) async {
    final exportService = ref.read(exportServiceProvider);
    final result = await exportService.exportToMarkdown(note);
    if (result.success && result.file != null) {
      await exportService.shareFile(result.file!, ExportFormat.markdown);
    }
  }

  Future<void> _shareSelectedNotes() async {
    // Implementation for sharing multiple notes
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing ${_selectedNoteIds.length} notes...'),
      ),
    );
    _exitSelectionMode();
  }

  Future<void> _deleteSelectedNotes() async {
    final count = _selectedNoteIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notes'),
        content: Text('Are you sure you want to delete $count notes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      final repo = ref.read(notesRepositoryProvider);
      for (final id in _selectedNoteIds) {
        await repo.delete(id);
      }
      await ref.read(notesPageProvider.notifier).refresh();
      _exitSelectionMode();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $count notes'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showAddToFolderDialog() async {
    if (_selectedNoteIds.isEmpty) return;
    
    // Show folder picker
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FolderPicker(
        title: 'Move to Folder',
        onFolderSelected: (folderId) async {
          var successCount = 0;
          var errorCount = 0;
          
          for (final noteId in _selectedNoteIds) {
            try {
              if (folderId != null) {
                await ref.read(noteFolderProvider.notifier).addNoteToFolder(noteId, folderId);
              } else {
                await ref.read(noteFolderProvider.notifier).removeNoteFromFolder(noteId);
              }
              successCount++;
            } catch (e) {
              errorCount++;
            }
          }
          
          _exitSelectionMode();
          
          if (mounted) {
            if (errorCount == 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(folderId != null 
                      ? 'Moved $successCount notes to folder'
                      : 'Moved $successCount notes to Unfiled'),
                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$successCount notes moved, $errorCount failed'),
                  backgroundColor: Theme.of(context).customColors.warningContainer,
                ),
              );
            }
          }
          
          // Refresh the current view
          await ref.read(notesPageProvider.notifier).refresh();
        },
      ),
    );
  }

  // Remove the old _buildFilterChip method as we're using DuruFolderChip component

  void _showFolderPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FolderPicker(
        title: 'Create Folder',
        showUnfiledOption: false,
        onFolderSelected: (folderId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Folder functionality coming soon!'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _showAddToFolderForSingleNote(LocalNote note) async {
    // Show folder picker for single note
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FolderPicker(
        title: 'Move to Folder',
        onFolderSelected: (folderId) async {
          try {
            if (folderId != null) {
              await ref.read(noteFolderProvider.notifier).addNoteToFolder(note.id, folderId);
            } else {
              await ref.read(noteFolderProvider.notifier).removeNoteFromFolder(note.id);
            }
            
            // Refresh the filtered notes
            ref.invalidate(filteredNotesProvider);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(folderId != null 
                      ? 'Note moved to folder' 
                      : 'Note moved to Unfiled'),
                  behavior: SnackBarBehavior.fixed,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to move note'),
                  behavior: SnackBarBehavior.fixed,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _duplicateNote(LocalNote note) async {
    final repo = ref.read(notesRepositoryProvider);
    await repo.createOrUpdate(
      title: '${note.title} (Copy)',
      body: note.body,
    );
    await ref.read(notesPageProvider.notifier).refresh();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note duplicated'),
        ),
      );
    }
  }

  void _archiveNote(LocalNote note) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Archive feature coming soon!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Future<void> _shareExportedFiles(List<ExportResult> results, ExportFormat format) async {
    try {
      final exportService = ref.read(exportServiceProvider);
      final successfulFiles = results
          .where((r) => r.success && r.file != null)
          .map((r) => r.file!)
          .toList();

      if (successfulFiles.isEmpty) {
        _showErrorDialog(context, 'No files available to share');
        return;
      }

      // Share the first file (or could implement multi-file sharing)
      final shared = await exportService.shareFile(successfulFiles.first, format);
      
      if (!shared) {
        _showErrorDialog(context, 'Failed to share exported file');
      }
    } catch (e) {
      _showErrorDialog(context, 'Error sharing files: $e');
    }
  }

  Future<void> _openExportsFolder() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Files are saved in app Documents folder. Use "Share Files" to access them.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      _showErrorDialog(context, 'Could not open exports folder: $e');
    }
  }

  void _showHelpScreen(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const HelpScreen(),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Production-grade logout: clear local data and per-user keys before sign-out
              try {
                final client = Supabase.instance.client;
                final uid = client.auth.currentUser?.id;
                // Clear local database and per-user last pull key via SyncService
                final sync = ref.read(syncServiceProvider);
                await sync.reset();
                // Delete per-user master key
                if (uid != null && uid.isNotEmpty) {
                  await ref.read(keyManagerProvider).deleteMasterKey(uid);
                }
                // IMPORTANT: Also clear the AMK from AccountKeyService
                await ref.read(accountKeyServiceProvider).clearLocalAmk();
              } catch (_) {}
              // Finally sign out from Supabase
              await Supabase.instance.client.auth.signOut();
            },
            child: Text('Sign Out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
  
  void _handleSavedSearchTap(BuildContext context, SavedSearchPreset preset) async {
    HapticFeedback.selectionClick();
    
    // If preset has a query token, open search with it prefilled
    if (preset.queryToken != null) {
      final notesAsync = ref.read(filteredNotesProvider);
      final notes = notesAsync.maybeWhen(
        data: (notes) => notes,
        orElse: () => <LocalNote>[],
      );
      
      final delegate = NoteSearchDelegate(
        notes: notes,
        initialQuery: preset.queryToken,
        resolveFolderIdByName: (folderName) async {
          // Map "Inbox" to "Incoming Mail"
          final actualName = folderName.toLowerCase() == 'inbox' ? 'Incoming Mail' : folderName;
          
          // Special handling for "Incoming Mail"
          if (actualName == 'Incoming Mail') {
            final user = Supabase.instance.client.auth.currentUser;
            if (user == null) return null;
            
            final repository = ref.read(notesRepositoryProvider);
            final folderManager = IncomingMailFolderManager(
              repository: repository,
              userId: user.id,
            );
            return folderManager.ensureIncomingMailFolderId();
          }
          
          // For other folders, find by name
          final db = ref.read(appDbProvider);
          final folder = await db.findFolderByName(actualName);
          return folder?.id;
        },
        getFolderNoteIdSet: (folderId) async {
          final db = ref.read(appDbProvider);
          final noteIds = await db.getNoteIdsInFolder(folderId);
          return noteIds.toSet();
        },
      );
      
      // Show search and immediately show results
      await showSearch(
        context: context,
        delegate: delegate,
      );
    }
    // If preset has a tag, navigate to TagNotesScreen
    else if (preset.tag != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TagNotesScreen(tag: preset.tag!),
        ),
      );
    }
    // If preset has a folder name (e.g., Inbox -> Incoming Mail)
    else if (preset.folderName != null) {
      try {
        // Get the user ID
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;
        
        // Create the folder manager to resolve the folder ID
        final repository = ref.read(notesRepositoryProvider);
        final folderManager = IncomingMailFolderManager(
          repository: repository,
          userId: user.id,
        );
        
        // Ensure the folder exists and get its ID
        final folderId = await folderManager.ensureIncomingMailFolderId();
        
        // Get all folders from repository to find the folder object
        final allFolders = await repository.listFolders();
        final targetFolder = allFolders.firstWhere(
          (folder) => folder.id == folderId,
          orElse: () => LocalFolder(
            id: folderId,
            name: preset.folderName!,
            parentId: null,
            path: '/${preset.folderName}',
            color: '#2196F3',
            icon: '📧',
            description: '',
            sortOrder: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            deleted: false,
          ),
        );
        
        // Use the same method as folder chips to select the folder
        ref.read(currentFolderProvider.notifier).setCurrentFolder(targetFolder);
      } catch (e) {
        debugPrint('Error resolving folder for saved search: $e');
      }
    }
  }
}

/// Enum for import types
enum ImportType {
  markdown,
  enex,
  obsidian,
}

/// Enum for export scope
enum ExportScope {
  all('All Notes'),
  recent('Recent Notes'),
  latest('Latest Notes');

  const ExportScope(this.displayName);
  final String displayName;
}

/// Progress dialog widget for import operations
class _ImportProgressDialog extends StatefulWidget {
  const _ImportProgressDialog({super.key});

  @override
  State<_ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<_ImportProgressDialog> {
  ImportProgress? _currentProgress;

  void updateProgress(ImportProgress progress) {
    if (mounted) {
      setState(() {
        _currentProgress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentProgress;
    
    return AlertDialog(
      title: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Importing Notes'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progress != null) ...[
            Text('Status: ${progress.phaseDescription}'),
            const SizedBox(height: 8),
            Text('File: ${progress.currentFile}'),
            const SizedBox(height: 8),
            Text('Progress: ${progress.current}/${progress.total}'),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ] else ...[
            const Text('Initializing import...'),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

/// Progress dialog widget for export operations
class _ExportProgressDialog extends StatefulWidget {

  const _ExportProgressDialog({
    required this.totalNotes, required this.format, super.key,
    this.onCancel,
  });
  final int totalNotes;
  final ExportFormat format;
  final VoidCallback? onCancel;

  @override
  State<_ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<_ExportProgressDialog> {
  ExportProgress? _currentProgress;
  int _currentNoteIndex = 0;
  String _currentNoteTitle = '';
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  void updateProgress(ExportProgress progress) {
    if (mounted) {
      setState(() {
        _currentProgress = progress;
      });
    }
  }

  void updateCurrentNote(int index, String title) {
    if (mounted) {
      setState(() {
        _currentNoteIndex = index;
        _currentNoteTitle = title;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentProgress;
    final overallProgress = widget.totalNotes > 0 
        ? (_currentNoteIndex / widget.totalNotes) 
        : 0.0;
    
    // Calculate estimated time remaining
    final estimatedTimeRemaining = _calculateEstimatedTime();
    
    return AlertDialog(
      title: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Exporting to ${widget.format.displayName}'),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Note: $_currentNoteIndex/${widget.totalNotes}'),
          const SizedBox(height: 8),
          Text(
            'Current: ${_currentNoteTitle.length > 30 ? '${_currentNoteTitle.substring(0, 30)}...' : _currentNoteTitle}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (estimatedTimeRemaining != null) ...[
            const SizedBox(height: 8),
            Text(
              'Estimated time remaining: $estimatedTimeRemaining',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Overall Progress:'),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: overallProgress,
            backgroundColor: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          if (progress != null) ...[
            Text('Status: ${progress.phase.description}'),
            const SizedBox(height: 8),
            if (progress.currentOperation != null)
              Text('${progress.currentOperation}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.percentage / 100,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ] else ...[
            const Text('Initializing export...'),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
      ),
      actions: [
        if (widget.onCancel != null)
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel'),
          ),
      ],
    );
  }

  String? _calculateEstimatedTime() {
    if (_currentNoteIndex == 0 || widget.totalNotes <= 1) return null;
    
    final elapsed = DateTime.now().difference(_startTime ?? DateTime.now());
    final avgTimePerNote = elapsed.inSeconds / _currentNoteIndex;
    final remainingNotes = widget.totalNotes - _currentNoteIndex;
    final estimatedSeconds = (avgTimePerNote * remainingNotes).round();
    
    if (estimatedSeconds < 60) {
      return '${estimatedSeconds}s';
    } else {
      final minutes = (estimatedSeconds / 60).floor();
      final seconds = estimatedSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
  }
}
