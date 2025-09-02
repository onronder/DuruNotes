import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/monitoring/app_logger.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import 'edit_note_screen_simple.dart';
import 'help_screen.dart';
import 'note_search_delegate.dart';
import 'settings_screen.dart';

/// Main notes list screen showing user's notes with enhanced UX
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
  late Animation<double> _fabAnimation;
  bool _isFabExpanded = false;
  String _sortBy = 'date'; // date, title, modified
  bool _isGridView = false;
  final Set<String> _selectedNoteIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    // Listen for scroll to implement infinite loading
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
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    
    // Start list animation
    _listAnimationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _listAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // User is near the bottom, load more if available
      final hasMore = ref.read(hasMoreNotesProvider);
      final isLoading = ref.read(notesLoadingProvider);
      
      if (hasMore && !isLoading) {
        ref.read(notesPageProvider.notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final notesAsync = ref.watch(notesPageProvider);
    final hasMore = ref.watch(hasMoreNotesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isSelectionMode
              ? Text('${_selectedNoteIds.length} selected')
              : Text(AppLocalizations.of(context).notesListTitle),
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? _buildSelectionActions()
            : [
                // View toggle
                IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isGridView ? Icons.view_list : Icons.grid_view,
                      key: ValueKey(_isGridView),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                ),
                // Sort button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort Notes',
                  onSelected: (value) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _sortBy = value;
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'date',
                      child: ListTile(
                        leading: Icon(
                          Icons.calendar_today,
                          color: _sortBy == 'date'
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: const Text('Date Modified'),
                        contentPadding: EdgeInsets.zero,
                        selected: _sortBy == 'date',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'title',
                      child: ListTile(
                        leading: Icon(
                          Icons.sort_by_alpha,
                          color: _sortBy == 'title'
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: const Text('Title'),
                        contentPadding: EdgeInsets.zero,
                        selected: _sortBy == 'title',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'created',
                      child: ListTile(
                        leading: Icon(
                          Icons.access_time,
                          color: _sortBy == 'created'
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        title: const Text('Date Created'),
                        contentPadding: EdgeInsets.zero,
                        selected: _sortBy == 'created',
                      ),
                    ),
                  ],
                ),
                // Search button
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final notes = ref.read(currentNotesProvider);
                    final result = await showSearch<LocalNote?>(
                      context: context,
                      delegate: NoteSearchDelegate(notes: notes),
                    );
                    if (result != null) {
                      _editNote(result);
                    }
                  },
                  tooltip: 'Search Notes',
                ),
          // Menu with import and other options
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
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
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: Text(AppLocalizations.of(context).importNotes),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: const Icon(Icons.download),
                  title: Text(AppLocalizations.of(context).exportNotes),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: Text(AppLocalizations.of(context).settings),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'help',
                child: ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(AppLocalizations.of(context).help),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    AppLocalizations.of(context).signOut, 
                    style: const TextStyle(color: Colors.red)
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced user info banner with stats
          if (user != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: EdgeInsets.zero,
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Hero(
                            tag: 'user_avatar',
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(
                                user.email?.substring(0, 1).toUpperCase() ?? 'U',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email ?? 'User',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.onTertiary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Synced',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onTertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Quick stats
                      Consumer(
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
                              
                              return Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      Icons.note,
                                      '$totalNotes',
                                      'Total Notes',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      Icons.today,
                                      '$todayNotes',
                                      'Today',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      Icons.folder,
                                      '0',
                                      'Folders',
                                    ),
                                  ),
                                ],
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Notes list
          Expanded(
            child: notesAsync.when(
              data: (notesPage) {
                final notes = notesPage.items;
                if (notes.isEmpty) {
                  return _buildEmptyState();
                }
                
                // Sort notes based on selection
                final sortedNotes = _sortNotes(notes);
                
                return RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    await ref.read(notesPageProvider.notifier).refresh();
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isGridView
                        ? _buildGridView(sortedNotes, hasMore)
                        : _buildListView(sortedNotes, hasMore),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error, 
                      size: 64, 
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text('Error loading notes: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(notesPageProvider.notifier).refresh();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildExpandableFAB(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.note_add_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context).noNotesYet,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).tapToCreateFirstNote,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _createNewNote(context),
                  icon: const Icon(Icons.add),
                  label: Text(AppLocalizations.of(context).createFirstNote),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteCard(LocalNote note, {bool isGrid = false}) {
    final isSelected = _selectedNoteIds.contains(note.id);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: isGrid
          ? const EdgeInsets.all(8)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_isSelectionMode) {
              _toggleNoteSelection(note.id);
            } else {
              _editNote(note);
            }
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            if (!_isSelectionMode) {
              _enterSelectionMode(note.id);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Card(
            elevation: isSelected ? 4 : 1,
            shadowColor: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isSelected
                  ? BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : BorderSide.none,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(isGrid ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with icon
                      Row(
                        children: [
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            )
                          else if (_getNoteIcon(note) != null)
                            Icon(
                              _getNoteIcon(note),
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                              size: 20,
                            ),
                          if (isSelected || _getNoteIcon(note) != null)
                            const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              note.title.isNotEmpty
                                  ? note.title
                                  : AppLocalizations.of(context).untitled,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: isGrid ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Preview
                      Text(
                        _generatePreview(note.body),
                        maxLines: isGrid ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 8),
                      // Footer with date and actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _formatDate(note.updatedAt),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (!_isSelectionMode && !isGrid)
                            IconButton(
                              icon: const Icon(Icons.more_vert, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showNoteOptions(note),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Progress indicator for syncing (placeholder for future implementation)
                if (false) // note.syncing ?? false - field not yet available
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
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
        .replaceAll(RegExp(r'#+ '), '') // Remove headers
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // Remove bold
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // Remove italic
        .replaceAll(RegExp(r'`(.*?)`'), r'$1') // Remove code
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
        builder: (context) => const EditNoteScreen(),
      ),
    );
  }

  void _editNote(LocalNote note) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => EditNoteScreen(
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
                    const SnackBar(
                      content: Text('Note deleted'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } on Exception catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting note: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Markdown Files'),
              subtitle: const Text('Import single .md or .markdown files'),
              onTap: () {
                Navigator.pop(context);
                _pickMarkdownFiles(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.file_copy, color: Colors.green),
              title: const Text('Evernote Export'),
              subtitle: const Text('Import .enex files from Evernote'),
              onTap: () {
                Navigator.pop(context);
                _pickEnexFile(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder, color: Colors.purple),
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
              color: totalErrors == 0 ? Colors.green : Colors.orange,
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
            Icon(Icons.error, color: Colors.red),
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
        const SnackBar(
          content: Text('No notes to export'),
          backgroundColor: Colors.orange,
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
            Text('Export your notes to various formats:'),
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
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Markdown'),
              subtitle: const Text('Export as .md files with full formatting'),
              onTap: () {
                Navigator.pop(context);
                _showExportScopeSelection(context, ExportFormat.markdown);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF'),
              subtitle: const Text('Export as PDF documents for sharing'),
              onTap: () {
                Navigator.pop(context);
                _showExportScopeSelection(context, ExportFormat.pdf);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.web, color: Colors.green),
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
              leading: const Icon(Icons.note, color: Colors.blue),
              title: const Text('Export All Notes'),
              subtitle: Text('Export all ${currentNotes.length} notes'),
              onTap: () {
                Navigator.pop(context);
                _exportNotes(context, currentNotes, format, ExportScope.all);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
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
                leading: const Icon(Icons.filter_list, color: Colors.purple),
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
    bool isCancelled = false;
    
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
            const SnackBar(
              content: Text('Export cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        },
      ),
    );

    try {
      final results = <ExportResult>[];
      final exportOptions = const ExportOptions(
        includeMetadata: true,
        includeTimestamps: true,
        includeAttachments: true,
      );

      for (int i = 0; i < notes.length; i++) {
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
                options: exportOptions,
                onProgress: (progress) => progressKey.currentState?.updateProgress(progress),
              );
            case ExportFormat.pdf:
              result = await exportService.exportToPdf(
                note,
                options: exportOptions,
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
                options: exportOptions,
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
              color: failedResults.isEmpty ? Colors.green : Colors.orange,
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
    if (hour < 12) return 'Good morning!';
    if (hour < 17) return 'Good afternoon!';
    return 'Good evening!';
  }

  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
        icon: const Icon(Icons.delete, color: Colors.red),
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

  Widget _buildListView(List<LocalNote> notes, bool hasMore) {
    return ListView.builder(
      key: const ValueKey('list_view'),
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: notes.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= notes.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final note = notes[index];
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _listAnimationController,
            curve: Interval(
              (index / notes.length).clamp(0.0, 1.0),
              ((index + 1) / notes.length).clamp(0.0, 1.0),
              curve: Curves.easeOut,
            ),
          )),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _listAnimationController,
              curve: Interval(
                (index / notes.length).clamp(0.0, 1.0),
                ((index + 1) / notes.length).clamp(0.0, 1.0),
                curve: Curves.easeIn,
              ),
            ),
            child: _buildNoteCard(note),
          ),
        );
      },
    );
  }

  Widget _buildGridView(List<LocalNote> notes, bool hasMore) {
    return GridView.builder(
      key: const ValueKey('grid_view'),
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
        childAspectRatio: 1.0,
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
              (index / notes.length).clamp(0.0, 1.0),
              ((index + 1) / notes.length).clamp(0.0, 1.0),
              curve: Curves.elasticOut,
            ),
          ),
          child: _buildNoteCard(note, isGrid: true),
        );
      },
    );
  }

  Widget _buildExpandableFAB(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Quick actions
        AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          offset: _isFabExpanded ? Offset.zero : const Offset(0, 2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isFabExpanded ? 1.0 : 0.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildMiniFAB(
                  icon: Icons.mic,
                  label: 'Voice Note',
                  color: Colors.purple,
                  onPressed: () {
                    _toggleFab();
                    _createVoiceNote();
                  },
                ),
                const SizedBox(height: 12),
                _buildMiniFAB(
                  icon: Icons.camera_alt,
                  label: 'Photo Note',
                  color: Colors.orange,
                  onPressed: () {
                    _toggleFab();
                    _createPhotoNote();
                  },
                ),
                const SizedBox(height: 12),
                _buildMiniFAB(
                  icon: Icons.checklist,
                  label: 'Checklist',
                  color: Colors.green,
                  onPressed: () {
                    _toggleFab();
                    _createChecklist();
                  },
                ),
                const SizedBox(height: 12),
                _buildMiniFAB(
                  icon: Icons.note_add,
                  label: 'Text Note',
                  color: Theme.of(context).colorScheme.primary,
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
        // Main FAB
        FloatingActionButton(
          onPressed: _toggleFab,
          tooltip: 'Create Note',
          child: AnimatedBuilder(
            animation: _fabAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _fabAnimation.value * math.pi / 4,
                child: Icon(
                  _isFabExpanded ? Icons.close : Icons.add,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMiniFAB({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.small(
          heroTag: label,
          backgroundColor: color,
          onPressed: onPressed,
          child: Icon(icon, color: Colors.white),
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
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
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
      const SnackBar(
        content: Text('Voice note feature coming soon!'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _createPhotoNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo note feature coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _createChecklist() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => EditNoteScreen(
          initialBody: '## Checklist\n\n- [ ] Task 1\n- [ ] Task 2\n- [ ] Task 3',
        ),
      ),
    );
  }

  void _shareNote(LocalNote note) async {
    final exportService = ref.read(exportServiceProvider);
    final result = await exportService.exportToMarkdown(note);
    if (result.success && result.file != null) {
      await exportService.shareFile(result.file!, ExportFormat.markdown);
    }
  }

  void _shareSelectedNotes() async {
    // Implementation for sharing multiple notes
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing ${_selectedNoteIds.length} notes...'),
      ),
    );
    _exitSelectionMode();
  }

  void _deleteSelectedNotes() async {
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _duplicateNote(LocalNote note) async {
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
      const SnackBar(
        content: Text('Archive feature coming soon!'),
        backgroundColor: Colors.blue,
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
        const SnackBar(
          content: Text('Files are saved in app Documents folder. Use "Share Files" to access them.'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 4),
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
              await Supabase.instance.client.auth.signOut();
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
              backgroundColor: Colors.grey[300],
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
  final int totalNotes;
  final ExportFormat format;
  final VoidCallback? onCancel;

  const _ExportProgressDialog({
    super.key,
    required this.totalNotes,
    required this.format,
    this.onCancel,
  });

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
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Overall Progress:'),
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
              backgroundColor: Colors.grey[300],
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