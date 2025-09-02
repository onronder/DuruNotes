import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/monitoring/app_logger.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import 'edit_note_screen_simple.dart';
import 'help_screen.dart';
import 'settings_screen.dart';

/// Main notes list screen showing user's notes
class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Listen for scroll to implement infinite loading
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
        title: Text(AppLocalizations.of(context).notesListTitle),
        actions: [
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).searchFeatureTemporarilyDisabled),
                  backgroundColor: Colors.orange,
                ),
              );
            },
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
          // Modern user info banner
          if (user != null)
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      user.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back!',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
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
                    child: Text(
                      'Online',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
                
                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(notesPageProvider.notifier).refresh();
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= notes.length) {
                        // Loading indicator at the bottom
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      final note = notes[index];
                      return _buildNoteCard(note);
                    },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNewNote(context),
        tooltip: AppLocalizations.of(context).createNewNote,
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context).createNewNote),
      ),
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

  Widget _buildNoteCard(LocalNote note) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        title: Text(
          note.title.isNotEmpty ? note.title : AppLocalizations.of(context).untitled,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              _generatePreview(note.body),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(note.updatedAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editNote(note);
              case 'delete':
                _deleteNote(note);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => _editNote(note),
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